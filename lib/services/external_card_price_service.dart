import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/tcg_card.dart';
import 'currency_settings.dart';
import 'local_card_price_store.dart';

class ExternalCardPrice {
  const ExternalCardPrice({
    required this.amount,
    required this.currencyCode,
    required this.source,
    this.lastUpdatedMs,
    this.lowAmount,
    this.highAmount,
    this.soldCount = 0,
    this.confidence = '',
    this.pricingMethod = '',
  });

  final double amount;
  final String currencyCode;
  final String source;
  final int? lastUpdatedMs;
  final double? lowAmount;
  final double? highAmount;
  final int soldCount;
  final String confidence;
  final String pricingMethod;

  bool get isValid => amount > 0 && amount.isFinite;

  factory ExternalCardPrice.fromMap(Map<String, dynamic> data) {
    final rawAmount = data['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse((rawAmount ?? '').toString()) ?? 0;

    final rawLastUpdated = data['lastUpdatedMs'];
    final lastUpdatedMs = rawLastUpdated is num
        ? rawLastUpdated.toInt()
        : int.tryParse((rawLastUpdated ?? '').toString());

    double? optionalAmount(String key) {
      final value = data[key];
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse((value ?? '').toString());
      return parsed != null && parsed > 0 && parsed.isFinite ? parsed : null;
    }

    return ExternalCardPrice(
      amount: amount,
      currencyCode: (data['currencyCode'] ?? 'USD').toString().trim().isEmpty
          ? 'USD'
          : (data['currencyCode'] ?? 'USD').toString().trim(),
      source: (data['source'] ?? 'External pricing').toString().trim().isEmpty
          ? 'External pricing'
          : (data['source'] ?? 'External pricing').toString().trim(),
      lastUpdatedMs: lastUpdatedMs,
      lowAmount: optionalAmount('lowAmount'),
      highAmount: optionalAmount('highAmount'),
      soldCount: (data['soldCount'] as num?)?.toInt() ?? 0,
      confidence: (data['confidence'] ?? '').toString().trim(),
      pricingMethod: (data['pricingMethod'] ?? '').toString().trim(),
    );
  }
}

class ExternalCardPriceException implements Exception {
  const ExternalCardPriceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExternalCardPriceService {
  ExternalCardPriceService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west2');

  static String friendlyErrorMessage(Object error) {
    if (error is ExternalCardPriceException) {
      return error.message;
    }

    if (error is FirebaseFunctionsException) {
      final message = (error.message ?? '').trim();
      final lower = message.toLowerCase();

      if (error.code == 'resource-exhausted' ||
          lower.contains('rate limit') ||
          lower.contains('rate_limit') ||
          lower.contains('429')) {
        return 'The card pricing service is busy. Please wait a minute, then try again.';
      }

      if (lower.contains('invalid api key') || lower.contains('401')) {
        return 'The card pricing service rejected its credentials.';
      }

      if (message.isNotEmpty) {
        return 'Could not check the card price: $message';
      }
    }

    return 'Could not check the card price right now. Please try again shortly.';
  }

  static Future<ExternalCardPrice?> lookupRawPrice(TcgCard card) async {
    final cardId = card.id.trim();
    if (cardId.isEmpty) return null;

    try {
      final callable = _functions.httpsCallable('lookupExternalPokemonCardPrice');
      final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'cardId': cardId,
        'name': card.name,
        'setId': card.setId,
        'setName': card.setName,
        'number': card.number,
        'rarity': card.rarity ?? '',
        'marketplaceCode': CurrencySettings.selectedMarketplaceCode,
      }).timeout(const Duration(seconds: 14));

      final data = result.data;
      final found = data['found'] == true;
      if (!found) {
        final reason = (data['reason'] ?? '').toString().trim();
        if (reason == 'rate_limited') {
          throw const ExternalCardPriceException(
            'The card pricing service is busy. Please wait a minute, then try again.',
          );
        }
        await LocalCardPriceStore.remove(cardId);
        return null;
      }

      final price = ExternalCardPrice.fromMap(data);
      if (!price.isValid) return null;
      await LocalCardPriceStore.save(
        cardId: cardId,
        amount: price.amount,
        currencyCode: price.currencyCode,
        source: price.source,
        updatedAtMs: price.lastUpdatedMs,
        lowAmount: price.lowAmount,
        highAmount: price.highAmount,
        soldCount: price.soldCount,
        confidence: price.confidence,
        pricingMethod: price.pricingMethod,
      );
      return price;
    } on TimeoutException {
      throw const ExternalCardPriceException(
        'The card pricing service took too long to reply. Please try again shortly.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw ExternalCardPriceException(friendlyErrorMessage(error));
    }
  }

  static Future<TcgCard> enrichCardWithExternalPrice(
    TcgCard card, {
    bool rethrowErrors = false,
  }) async {
    try {
      final price = await lookupRawPrice(card);
      if (price == null || !price.isValid) {
        return card.copyWith(clearExternalRawPrice: true);
      }

      return card.copyWith(
        externalRawPrice: price.amount,
        externalRawPriceCurrency: price.currencyCode,
        externalRawPriceSource: price.source,
        externalRawPriceUpdatedAtMs: price.lastUpdatedMs,
        externalRawPriceLow: price.lowAmount,
        externalRawPriceHigh: price.highAmount,
        externalRawPriceSoldCount: price.soldCount,
        externalRawPriceConfidence: price.confidence,
        externalRawPriceMethod: price.pricingMethod,
      );
    } catch (_) {
      if (rethrowErrors) rethrow;
      return card;
    }
  }
}
