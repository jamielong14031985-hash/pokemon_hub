import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

class SealedProductListing {
  const SealedProductListing({
    required this.listingId,
    required this.title,
    required this.imageUrl,
    required this.listingUrl,
    required this.priceAmount,
    required this.shippingAmount,
    required this.currencyCode,
    required this.productType,
    required this.productTypeLabel,
    required this.condition,
    required this.sellerName,
    required this.location,
    required this.listingDate,
    required this.listingDateMs,
  });

  final String listingId;
  final String title;
  final String imageUrl;
  final String listingUrl;
  final double priceAmount;
  final double shippingAmount;
  final String currencyCode;
  final String productType;
  final String productTypeLabel;
  final String condition;
  final String sellerName;
  final String location;
  final String listingDate;
  final int listingDateMs;

  double get totalAmount => priceAmount + shippingAmount;
  bool get hasShippingCost => shippingAmount > 0;

  String get listingDateText {
    final trimmed = listingDate.trim();
    if (trimmed.isEmpty && listingDateMs <= 0) return '';
    DateTime? parsed;
    if (listingDateMs > 0) {
      parsed = DateTime.fromMillisecondsSinceEpoch(listingDateMs).toLocal();
    } else {
      parsed = DateTime.tryParse(trimmed)?.toLocal();
    }
    if (parsed == null) return trimmed;
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(parsed.day)}/${twoDigits(parsed.month)}/${parsed.year}';
  }

  factory SealedProductListing.fromMap(Map<String, dynamic> data) {
    double asDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse((value ?? '').toString()) ?? 0;
    }
    int asInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse((value ?? '').toString()) ?? 0;
    }
    String asString(Object? value) => (value ?? '').toString().trim();
    return SealedProductListing(
      listingId: asString(data['listingId']),
      title: asString(data['title']),
      imageUrl: asString(data['imageUrl']),
      listingUrl: asString(data['listingUrl']),
      priceAmount: asDouble(data['priceAmount']),
      shippingAmount: asDouble(data['shippingAmount']),
      currencyCode: asString(data['currencyCode']).toUpperCase(),
      productType: asString(data['productType']),
      productTypeLabel: asString(data['productTypeLabel']),
      condition: asString(data['condition']),
      sellerName: asString(data['sellerName']),
      location: asString(data['location']),
      listingDate: asString(data['listingDate'] ?? data['soldDate']),
      listingDateMs: asInt(data['listingDateMs'] ?? data['soldDateMs']),
    );
  }
}

class SealedProductSearchResult {
  const SealedProductSearchResult({
    required this.items,
    required this.marketplaceCode,
    required this.marketplaceLabel,
    required this.lastUpdatedMs,
    required this.cached,
  });

  final List<SealedProductListing> items;
  final String marketplaceCode;
  final String marketplaceLabel;
  final int? lastUpdatedMs;
  final bool cached;
}

class SealedProductPriceException implements Exception {
  const SealedProductPriceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SealedProductPriceService {
  SealedProductPriceService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west2');

  static String friendlyErrorMessage(Object error) {
    if (error is SealedProductPriceException) return error.message;
    if (error is FirebaseFunctionsException) {
      final message = (error.message ?? '').trim();
      final lower = message.toLowerCase();
      if (error.code == 'failed-precondition' && lower.contains('ebay credentials')) {
        return 'Sealed product listings are not connected yet. Add the eBay app credentials in Firebase Functions first.';
      }
      if (error.code == 'failed-precondition' || error.code == 'permission-denied') {
        return 'eBay rejected the listing search credentials. Check the production eBay client ID and secret.';
      }
      if (error.code == 'resource-exhausted' || lower.contains('rate limit')) {
        return 'eBay is busy right now. Please wait a moment and try again.';
      }
      if (message.isNotEmpty) return message;
    }
    return 'Could not load sealed products for sale right now. Please try again shortly.';
  }

  static Future<SealedProductSearchResult> lookupCurrentListings({
    required String marketplaceCode,
    String query = '',
    String productType = 'all',
  }) async {
    try {
      final callable = _functions.httpsCallable('lookupEbaySealedProducts');
      final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'marketplaceCode': marketplaceCode,
        'query': query.trim(),
        'productType': productType,
        'limit': 10,
      }).timeout(const Duration(seconds: 35));
      final data = response.data;
      final rawItems = data['items'];
      final items = rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => SealedProductListing.fromMap(Map<String, dynamic>.from(item)))
              .where((item) => item.title.isNotEmpty && item.priceAmount > 0)
              .take(10)
              .toList(growable: false)
          : const <SealedProductListing>[];
      final rawLastUpdated = data['lastUpdatedMs'];
      final lastUpdatedMs = rawLastUpdated is num
          ? rawLastUpdated.toInt()
          : int.tryParse((rawLastUpdated ?? '').toString());
      return SealedProductSearchResult(
        items: items,
        marketplaceCode: (data['marketplaceCode'] ?? marketplaceCode).toString().trim(),
        marketplaceLabel: (data['marketplaceLabel'] ?? 'eBay').toString().trim(),
        lastUpdatedMs: lastUpdatedMs,
        cached: data['cached'] == true,
      );
    } on TimeoutException {
      throw const SealedProductPriceException('eBay took too long to return sealed products for sale. Please try again shortly.');
    } on FirebaseFunctionsException catch (error) {
      throw SealedProductPriceException(friendlyErrorMessage(error));
    }
  }
}
