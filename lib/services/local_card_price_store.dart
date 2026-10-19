import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tcg_card.dart';

class CachedCardPrice {
  const CachedCardPrice({
    required this.amount,
    required this.currencyCode,
    required this.source,
    required this.updatedAtMs,
    this.lowAmount,
    this.highAmount,
    this.soldCount = 0,
    this.confidence = '',
    this.pricingMethod = '',
  });

  final double amount;
  final String currencyCode;
  final String source;
  final int updatedAtMs;
  final double? lowAmount;
  final double? highAmount;
  final int soldCount;
  final String confidence;
  final String pricingMethod;

  bool get isValid => amount > 0 && amount.isFinite;

  TcgCard applyTo(TcgCard card) {
    if (!isValid || card.hasExternalRawPrice) return card;
    return card.copyWith(
      externalRawPrice: amount,
      externalRawPriceCurrency: currencyCode,
      externalRawPriceSource: source,
      externalRawPriceUpdatedAtMs: updatedAtMs,
      externalRawPriceLow: lowAmount,
      externalRawPriceHigh: highAmount,
      externalRawPriceSoldCount: soldCount,
      externalRawPriceConfidence: confidence,
      externalRawPriceMethod: pricingMethod,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'amount': amount,
        'currencyCode': currencyCode,
        'source': source,
        'updatedAtMs': updatedAtMs,
        'lowAmount': lowAmount,
        'highAmount': highAmount,
        'soldCount': soldCount,
        'confidence': confidence,
        'pricingMethod': pricingMethod,
      };

  static CachedCardPrice? fromJson(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final rawAmount = map['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse((rawAmount ?? '').toString());
    if (amount == null || amount <= 0 || !amount.isFinite) return null;
    return CachedCardPrice(
      amount: amount,
      currencyCode: (map['currencyCode'] ?? 'USD').toString(),
      source: (map['source'] ?? 'JustTCG').toString(),
      updatedAtMs: (map['updatedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      lowAmount: (map['lowAmount'] as num?)?.toDouble(),
      highAmount: (map['highAmount'] as num?)?.toDouble(),
      soldCount: (map['soldCount'] as num?)?.toInt() ?? 0,
      confidence: (map['confidence'] ?? '').toString(),
      pricingMethod: (map['pricingMethod'] ?? '').toString(),
    );
  }
}

class LocalCardPriceStore {
  LocalCardPriceStore._();

  static const String _storageKey = 'cached_collection_card_prices_v1';

  static Future<Map<String, CachedCardPrice>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <String, CachedCardPrice>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, CachedCardPrice>{};
      final result = <String, CachedCardPrice>{};
      for (final entry in decoded.entries) {
        final price = CachedCardPrice.fromJson(entry.value);
        if (price != null) result[entry.key.toString()] = price;
      }
      return result;
    } catch (_) {
      return <String, CachedCardPrice>{};
    }
  }

  static Future<TcgCard> applySavedPrice(TcgCard card) async {
    final cardId = card.id.trim();
    if (cardId.isEmpty) return card;
    final prices = await loadAll();
    return prices[cardId]?.applyTo(card) ?? card;
  }

  static Future<void> save({
    required String cardId,
    required double amount,
    required String currencyCode,
    required String source,
    int? updatedAtMs,
    double? lowAmount,
    double? highAmount,
    int soldCount = 0,
    String confidence = '',
    String pricingMethod = '',
  }) async {
    final cleanId = cardId.trim();
    if (cleanId.isEmpty || amount <= 0 || !amount.isFinite) return;
    final prices = await loadAll();
    prices[cleanId] = CachedCardPrice(
      amount: amount,
      currencyCode: currencyCode.trim().isEmpty ? 'USD' : currencyCode.trim(),
      source: source.trim().isEmpty ? 'JustTCG' : source.trim(),
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      lowAmount: lowAmount,
      highAmount: highAmount,
      soldCount: soldCount,
      confidence: confidence,
      pricingMethod: pricingMethod,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(<String, Object?>{
        for (final entry in prices.entries) entry.key: entry.value.toJson(),
      }),
    );
  }

  static Future<void> remove(String cardId) async {
    final cleanId = cardId.trim();
    if (cleanId.isEmpty) return;
    final prices = await loadAll();
    if (prices.remove(cleanId) == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(<String, Object?>{
        for (final entry in prices.entries) entry.key: entry.value.toJson(),
      }),
    );
  }
}
