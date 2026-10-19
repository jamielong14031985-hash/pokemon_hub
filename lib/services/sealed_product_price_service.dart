import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_functions/cloud_functions.dart';

import 'sealed_product_identity_service.dart';
import 'sealed_collection_store.dart';

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

/// A UK sold-price estimate based ONLY on confirmed GBP completed sales.
/// Missing prices are null, never a made-up zero or an active listing price.
class SealedUkSoldPrice {
  const SealedUkSoldPrice({
    required this.saleCount,
    required this.averageSoldPrice,
    required this.lastSoldPrice,
    required this.lastSoldDate,
    required this.minSoldPrice,
    required this.maxSoldPrice,
    required this.lowConfidence,
    required this.confidence,
    required this.lastUpdatedMs,
    required this.cachedAtSource,
  });

  final int saleCount;
  final double? averageSoldPrice;
  final double? lastSoldPrice;
  final String lastSoldDate;
  final double? minSoldPrice;
  final double? maxSoldPrice;
  final bool lowConfidence;
  final String confidence;
  final int? lastUpdatedMs;
  final bool cachedAtSource;

  bool get hasPrice => saleCount > 0 && averageSoldPrice != null;

  double? valueForQuantity(int quantity) =>
      averageSoldPrice == null ? null : averageSoldPrice! * quantity;

  static SealedUkSoldPrice fromMap(Map<String, dynamic> data) {
    double? money(Object? value) {
      if (value == null) return null;
      final amount = value is num ? value.toDouble() : double.tryParse('$value');
      return amount != null && amount.isFinite && amount > 0 ? amount : null;
    }
    int integer(Object? value) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    if (data['currencyCode']?.toString().toUpperCase() != 'GBP' ||
        data['priceIncludesShipping'] != false) {
      throw const SealedProductPriceException(
        'Unverified sold-price currency or postage information. No valuation was used.',
      );
    }
    return SealedUkSoldPrice(
      saleCount: integer(data['saleCount']),
      averageSoldPrice: money(data['averageSoldPrice']),
      lastSoldPrice: money(data['lastSoldPrice']),
      lastSoldDate: (data['lastSoldDate'] ?? '').toString(),
      minSoldPrice: money(data['minSoldPrice']),
      maxSoldPrice: money(data['maxSoldPrice']),
      lowConfidence: data['lowConfidence'] == true,
      confidence: (data['confidence'] ?? 'low').toString(),
      lastUpdatedMs: data['lastUpdatedMs'] == null
          ? null : integer(data['lastUpdatedMs']),
      cachedAtSource: data['cached'] == true,
    );
  }
}

class SealedProductPriceService {
  SealedProductPriceService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west2');

  // Saved verified UK SOLD prices belong to the signed-in collector and
  // survive page navigation and app restarts. They are never written to the
  // purchasePrice or the legacy, unverified marketPrice field.
  static const String _savedPricesPrefix = 'pocketchase_sealed_uk_sold_v1_';
  static final Map<String, SealedUkSoldPrice> _soldPrices = {};
  static bool _scopeReady = false;
  static String? _cacheUserId;
  static bool _cacheLoaded = false;
  static Future<void>? _loadFuture;
  static Future<void> _writeQueue = Future<void>.value();

  static void _syncAccountScope() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!_scopeReady || uid != _cacheUserId) {
      _scopeReady = true;
      _cacheUserId = uid;
      _cacheLoaded = false;
      _loadFuture = null;
      _soldPrices.clear();
    }
  }

  static String _soldKey(SealedCollectionItem item) =>
      '${item.id}|${item.title}|${item.productTypeLabel}';

  // Explicitly include the verification conditions in each saved record.
  // Loading uses SealedUkSoldPrice.fromMap to reject malformed or non-GBP data.
  static Map<String, dynamic> _asVerifiedRecord(SealedUkSoldPrice price) => {
    'currencyCode': 'GBP',
    'priceIncludesShipping': false,
    'saleCount': price.saleCount,
    'averageSoldPrice': price.averageSoldPrice,
    'lastSoldPrice': price.lastSoldPrice,
    'lastSoldDate': price.lastSoldDate,
    'minSoldPrice': price.minSoldPrice,
    'maxSoldPrice': price.maxSoldPrice,
    'lowConfidence': price.lowConfidence,
    'confidence': price.confidence,
    'lastUpdatedMs': price.lastUpdatedMs,
    'cached': true,
  };

  /// Restore local verified results without any network/API calls.
  /// Called by both the collection and individual set pages before they show
  /// pricing, so those pages display the same saved price after a restart.
  static Future<void> loadSavedUkSoldPrices() {
    _syncAccountScope();
    if (_cacheLoaded) return Future<void>.value();
    return _loadFuture ??= _restoreSavedPrices(_cacheUserId);
  }

  static Future<void> _restoreSavedPrices(String? uid) async {
    if (uid == null || uid.isEmpty) {
      if (_cacheUserId == uid) _cacheLoaded = true;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_savedPricesPrefix$uid');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final restored = <String, SealedUkSoldPrice>{};
          for (final entry in decoded.entries) {
            if (entry.key is! String || entry.value is! Map) continue;
            try {
              restored[entry.key as String] = SealedUkSoldPrice.fromMap(
                Map<String, dynamic>.from(entry.value as Map),
              );
            } catch (_) {
              // Discard invalid or unverifiable price records, not the rest.
            }
          }
          if (_cacheUserId == uid) {
            _soldPrices.addAll(restored);
          }
        }
      }
    } catch (_) {
      // Local storage problems must never prevent collection browsing.
    } finally {
      if (_cacheUserId == uid) _cacheLoaded = true;
    }
  }

  /// Serialise writes so rapid checks cannot overwrite each other's values.
  /// No automatic lookups or expirations: only a manually requested check
  /// changes these saved prices.
  static Future<void> _saveVerifiedPrices() {
    final uid = _cacheUserId;
    if (uid == null || uid.isEmpty) return Future<void>.value();
    final next = _writeQueue.then((_) async {
      if (_cacheUserId != uid) return;
      final prefs = await SharedPreferences.getInstance();
      if (_cacheUserId != uid) return;
      final data = _soldPrices.map((key, price) =>
          MapEntry(key, _asVerifiedRecord(price)));
      final saved = await prefs.setString(
        '$_savedPricesPrefix$uid', jsonEncode(data));
      if (!saved) {
        throw const SealedProductPriceException(
          'Could not save the updated UK sold price on this device.',
        );
      }
    });
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  static SealedUkSoldPrice? cachedUkSoldPrice(SealedCollectionItem item) {
    _syncAccountScope();
    return _soldPrices[_soldKey(item)];
  }

  static int pricedProductCount(Iterable<SealedCollectionItem> products) =>
      products.where((item) => cachedUkSoldPrice(item)?.hasPrice == true).length;

  /// Sum of products with an actual sold-price average. NOT a complete
  /// collection value until every product has confirmed sales.
  static double pricedSubtotal(Iterable<SealedCollectionItem> products) =>
      products.fold<double>(0, (sum, item) => sum +
          (cachedUkSoldPrice(item)?.valueForQuantity(item.quantity) ?? 0));

  static String gbp(double? amount) => amount == null
      ? '—'
      : '£${amount.toStringAsFixed(2)}';

  static String ukSoldError(Object error) {
    if (error is SealedProductPriceException) return error.message;
    if (error is TimeoutException) {
      return 'CompsAPI took too long. Try checking the sold price again.';
    }
    if (error is FirebaseFunctionsException) {
      final message = (error.message ?? '').trim();
      switch (error.code) {
        case 'unauthenticated':
          return 'Please sign in to PocketChase to check sold prices.';
        case 'invalid-argument':
          return message.isEmpty
              ? 'This product type cannot be valued by CompsAPI yet.'
              : message;
        case 'resource-exhausted':
          return 'The CompsAPI lookup limit was reached. Try again later.';
        case 'failed-precondition':
          return 'CompsAPI configuration needs attention in Firebase.';
        default:
          return message.isNotEmpty ? message : 'Sold prices are temporarily unavailable.';
      }
    }
    return 'Could not check UK sold prices. Please try again.';
  }

  /// Calls the separately deployed UK eBay SOLD function, not the existing
  /// active-listing search. Each product lookup can consume API credits.
  static Future<SealedUkSoldPrice> lookupUkSoldPrice(
    SealedCollectionItem item, {
    bool refresh = false,
  }) async {
    // Hydrate once from persistent local storage before deciding whether
    // CompsAPI is needed. Opening the page never invokes this lookup.
    await loadSavedUkSoldPrices();
    final key = _soldKey(item);
    final previouslySaved = _soldPrices[key];
    final lookupAccount = _cacheUserId;
    if (!refresh && previouslySaved != null) return previouslySaved;
    const supportedTypes = <String>{
      'standard elite trainer box', 'pokemon center elite trainer box',
      'booster box', 'booster bundle', 'ultra-premium collection (upc)',
      'booster pack', 'poster collection', 'illustration collection',
      'first partner illustration collection (2026)',
      'collection box', 'ex box', 'mini tin', 'tin',
    };
    final typeName = item.productTypeLabel.toLowerCase().replaceAll('é', 'e');
    // Older collection entries use "First Partner Illustration Collection"
    // without a year. Accept the actual saved label as well as the 2026 label.
    // A Super-Premium Collection may have the broad "Premium Collection"
    // catalogue label: require its *specific product name* before allowing it.
    // This avoids treating any ordinary Premium Collection as a Super-Premium.
    final normalisedTitle = item.title.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final isFirstPartnerIllustration =
        typeName == 'first partner illustration collection';
    final isSuperPremium =
        normalisedTitle.contains('super premium collection') &&
        (typeName == 'premium collection' ||
         typeName == 'super-premium collection' ||
         typeName == 'super premium collection');
    if (!supportedTypes.contains(typeName) &&
        !isFirstPartnerIllustration && !isSuperPremium) {
      throw const SealedProductPriceException(
        'This sealed product type is not supported by the UK sold-price matcher yet.',
      );
    }
    final isPc = item.productTypeLabel.toLowerCase().contains('pokémon center') ||
        item.productTypeLabel.toLowerCase().contains('pokemon center') ||
        SealedProductIdentityService.detectEdition(item.title) ==
            SealedProductEdition.pokemonCenter;
    try {
      final response = await _functions
          .httpsCallable('lookupCompsSealedSoldPrices')
          .call<Map<String, dynamic>>(<String, dynamic>{
            'productName': item.title,
            'productTypeLabel': item.productTypeLabel,
            'edition': isPc ? 'Pokemon Center' : 'Standard',
            'quantity': item.quantity,
          }).timeout(const Duration(seconds: 85));
      final sold = SealedUkSoldPrice.fromMap(response.data);
      _syncAccountScope();
      if (_cacheUserId != lookupAccount) {
        throw const SealedProductPriceException(
          'Your account changed while checking the price. Please try again.',
        );
      }
      // A failed verification must not erase an already-verified estimate.
      if (refresh && previouslySaved?.hasPrice == true && !sold.hasPrice) {
        throw const SealedProductPriceException(
          'No new verified GBP sales were found. Your saved price was kept.',
        );
      }
      _soldPrices[key] = sold;
      try {
        await _saveVerifiedPrices();
      } catch (_) {
        // Never claim the new result was saved if local storage failed.
        if (previouslySaved == null) {
          _soldPrices.remove(key);
        } else {
          _soldPrices[key] = previouslySaved;
        }
        throw const SealedProductPriceException(
          'Could not save the new price on this device. Your previous saved price was kept.',
        );
      }
      return sold;
    } on TimeoutException catch (error) {
      throw SealedProductPriceException(ukSoldError(error));
    } on FirebaseFunctionsException catch (error) {
      throw SealedProductPriceException(ukSoldError(error));
    }
  }

  static String _productSearchSuffix(
    String productType,
    String etbVariant,
  ) {
    switch (productType) {
      case 'eliteTrainerBox':
        return etbVariant == 'pokemonCenter'
            ? 'Pokemon Center Elite Trainer Box sealed'
            : 'Elite Trainer Box sealed';
      case 'boosterBox':
        return 'Booster Box sealed';
      case 'boosterBundle':
        return 'Booster Bundle sealed';
      case 'ultraPremiumCollection':
        return 'Ultra Premium Collection sealed';
      case 'boosterPack':
        return 'Booster Pack sealed';
      case 'sleevedBooster':
        return 'Sleeved Booster Pack sealed';
      case 'blisterPack':
        return 'Blister Pack sealed';
      case 'checklaneBlister':
        return 'Checklane Blister sealed';
      case 'threePackBlister':
        return 'Three Pack Blister sealed';
      case 'tin':
        return 'Pokemon Tin sealed';
      case 'miniTin':
        return 'Pokemon Mini Tin sealed';
      case 'pokeBallTin':
        return 'Pokemon Poke Ball Tin sealed';
      case 'stackingTin':
        return 'Pokemon Stacking Tin sealed';
      case 'exBox':
        return 'Pokemon ex Box sealed';
      case 'collectionBox':
        return 'Pokemon Collection Box sealed';
      case 'premiumCollection':
        return 'Pokemon Premium Collection sealed';
      case 'premiumTournamentCollection':
        return 'Pokemon Premium Tournament Collection sealed';
      case 'specialCollection':
        return 'Pokemon Special Collection sealed';
      case 'pinCollection':
        return 'Pokemon Pin Collection sealed';
      case 'figureCollection':
        return 'Pokemon Figure Collection sealed';
      case 'illustrationCollection':
        return 'Pokemon Illustration Collection sealed';
      case 'techStickerCollection':
        return 'Pokemon Tech Sticker Collection sealed';
      case 'buildAndBattle':
        return 'Pokemon Build Battle Box sealed';
      case 'buildAndBattleStadium':
        return 'Pokemon Build Battle Stadium sealed';
      case 'collectionChest':
        return 'Pokemon Collector Chest sealed';
      case 'battleDeck':
        return 'Pokemon Battle Deck sealed';
      case 'leagueBattleDeck':
        return 'Pokemon League Battle Deck sealed';
      case 'themeDeck':
        return 'Pokemon Theme Deck sealed';
      case 'worldChampionshipDeck':
        return 'Pokemon World Championship Deck sealed';
      case 'battleAcademy':
        return 'Pokemon Battle Academy sealed';
      case 'trainerToolkit':
        return 'Pokemon Trainer Toolkit sealed';
      case 'trainerKit':
        return 'Pokemon Trainer Kit sealed';
      case 'posterCollection':
        return 'Pokemon Poster Collection sealed';
      case 'binderCollection':
        return 'Pokemon Binder Collection sealed';
      case 'firstPartnerPack':
        return 'Pokemon First Partner Pack sealed';
      case 'surpriseBox':
        return 'Pokemon Surprise Box sealed';
      case 'adventCalendar':
        return 'Pokemon Holiday Calendar sealed';
      default:
        return 'Pokemon sealed';
    }
  }

  static bool _matchesRequestedProduct(
    SealedProductListing item,
    String query,
    String productType,
    String etbVariant,
  ) {
    return SealedProductIdentityService.matches(
      title: item.title,
      query: query,
      productType: productType,
      etbVariant: etbVariant,
    );
  }

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
    String etbVariant = 'standard',
  }) async {
    try {
      final cleanQuery = query.trim();
      final marketplaceQuery = cleanQuery.isEmpty
          ? _productSearchSuffix(productType, etbVariant)
          : '$cleanQuery ${_productSearchSuffix(productType, etbVariant)}';
      final callable = _functions.httpsCallable('lookupEbaySealedProducts');
      const backendTypes = <String>{
        'all',
        'boosterBox',
        'eliteTrainerBox',
        'boosterBundle',
        'ultraPremiumCollection',
      };
      final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'marketplaceCode': marketplaceCode,
        'query': marketplaceQuery,
        'productType': backendTypes.contains(productType) ? productType : 'all',
        'limit': 30,
      }).timeout(const Duration(seconds: 35));
      final data = response.data;
      final rawItems = data['items'];
      final items = rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => SealedProductListing.fromMap(Map<String, dynamic>.from(item)))
              .where((item) => item.title.isNotEmpty && item.priceAmount > 0)
              .where((item) => _matchesRequestedProduct(
                    item,
                    cleanQuery,
                    productType,
                    etbVariant,
                  ))
              .take(20)
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
