import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/tcg_card.dart';

class ExternalCardPrice {
  const ExternalCardPrice({
    required this.amount,
    required this.currencyCode,
    required this.source,
    this.lastUpdatedMs,
  });

  final double amount;
  final String currencyCode;
  final String source;
  final int? lastUpdatedMs;

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

    return ExternalCardPrice(
      amount: amount,
      currencyCode: (data['currencyCode'] ?? 'USD').toString().trim().isEmpty
          ? 'USD'
          : (data['currencyCode'] ?? 'USD').toString().trim(),
      source: (data['source'] ?? 'External pricing').toString().trim().isEmpty
          ? 'External pricing'
          : (data['source'] ?? 'External pricing').toString().trim(),
      lastUpdatedMs: lastUpdatedMs,
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
        return 'JustTCG is rate limited. Please wait a minute, then try Refresh Raw Price again.';
      }

      if (lower.contains('invalid api key') || lower.contains('401')) {
        return 'JustTCG rejected the API key. Check the Firebase JUSTTCG_API_KEY secret.';
      }

      if (message.isNotEmpty) {
        return 'Could not check JustTCG price: $message';
      }
    }

    return 'Could not check JustTCG price right now. Please try again shortly.';
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
      }).timeout(const Duration(seconds: 14));

      final data = result.data;
      final found = data['found'] == true;
      if (!found) {
        final reason = (data['reason'] ?? '').toString().trim();
        if (reason == 'rate_limited') {
          throw const ExternalCardPriceException(
            'JustTCG is rate limited. Please wait a minute, then try Refresh Raw Price again.',
          );
        }
        return null;
      }

      final price = ExternalCardPrice.fromMap(data);
      return price.isValid ? price : null;
    } on TimeoutException {
      throw const ExternalCardPriceException(
        'JustTCG took too long to reply. Please try again shortly.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw ExternalCardPriceException(friendlyErrorMessage(error));
    }
  }

  static Future<TcgCard> enrichCardWithExternalPrice(
    TcgCard card, {
    bool rethrowErrors = false,
  }) async {
    if ((card.rawPrice ?? 0) > 0) return card;

    try {
      final price = await lookupRawPrice(card);
      if (price == null || !price.isValid) return card;

      return card.copyWith(
        externalRawPrice: price.amount,
        externalRawPriceCurrency: price.currencyCode,
        externalRawPriceSource: price.source,
        externalRawPriceUpdatedAtMs: price.lastUpdatedMs,
      );
    } catch (_) {
      if (rethrowErrors) rethrow;
      return card;
    }
  }
}
