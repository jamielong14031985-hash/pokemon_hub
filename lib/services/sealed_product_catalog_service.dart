import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'sealed_product_identity_service.dart';
import 'sealed_expansion_matcher.dart';

class SealedCatalogProduct {
  const SealedCatalogProduct({
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.productType,
    required this.productTypeLabel,
    required this.edition,
    required this.expansionName,
  });

  final String productId;
  final String title;
  final String imageUrl;
  final String productType;
  final String productTypeLabel;
  final String edition;
  final String expansionName;

  String get identityKey => '$productId|$productType|$edition';
}

/// Loads real sealed products and clean catalogue images from TCGCSV's cached
/// TCGplayer catalogue. It does not load prices, sold listings or seller photos.
class SealedProductCatalogService {
  SealedProductCatalogService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Duration _timeout = Duration(seconds: 15);
  static const String _baseUrl = 'https://tcgcsv.com/tcgplayer/3';
  static List<Map<String, dynamic>>? _groupCache;
  static final Map<int, List<Map<String, dynamic>>> _productCache = {};

  static Future<List<SealedCatalogProduct>> searchProducts({
    required String query,
    required String productType,
  }) async {
    final groups = await _groups();
    final queryTokens = _meaningfulTokens(query);
    final firstPartnerSearch = _isFirstPartnerSearch(query, productType);
    final matchingGroups = groups.where((group) {
      final name = (group['name'] ?? '').toString();
      final groupTokens = _meaningfulTokens(name);
      // The TCGplayer product line is "First Partner Collection 2026".
      // Searching "First Partner Series 1" does not contain those group
      // tokens, so also search this verified group by its product titles.
      if (firstPartnerSearch &&
          SealedExpansionMatcher.isFirstPartnerCatalogueGroup(name)) {
        return true;
      }
      return queryTokens.isNotEmpty &&
          queryTokens.every((token) => groupTokens.contains(token));
    }).toList(growable: false);
    // Search the relevant First Partner line first when the user requests it.
    if (firstPartnerSearch) {
      matchingGroups.sort((a, b) {
        final aFirst = SealedExpansionMatcher.isFirstPartnerCatalogueGroup(
            (a['name'] ?? '').toString());
        final bFirst = SealedExpansionMatcher.isFirstPartnerCatalogueGroup(
            (b['name'] ?? '').toString());
        if (aFirst == bFirst) return 0;
        return aFirst ? -1 : 1;
      });
    }
    final groupsToLoad = matchingGroups.take(4);

    if (matchingGroups.isEmpty) return const <SealedCatalogProduct>[];
    final rawProducts = <Map<String, dynamic>>[];
    for (final group in groupsToLoad) {
      final groupId = (group['groupId'] as num?)?.toInt();
      if (groupId == null) continue;
      final expansionName = SealedExpansionMatcher.fromCatalogueGroup(
          (group['name'] ?? '').toString());
      for (final raw in await _products(groupId)) {
        rawProducts.add(<String, dynamic>{
          ...raw,
          '_pocketchaseExpansionName': expansionName,
        });
      }
    }

    final results = <SealedCatalogProduct>[];
    final requestedSeries = _requestedFirstPartnerSeries(query);
    for (final raw in rawProducts) {
      final title = (raw['name'] ?? '').toString().trim();
      if (!_matchesProductType(title, productType)) continue;
      if (firstPartnerSearch) {
        if (!SealedExpansionMatcher.isFirstPartnerIllustrationTitle(title)) {
          continue;
        }
        if (requestedSeries != null &&
            !RegExp('\\bseries $requestedSeries\\b').hasMatch(
                SealedProductIdentityService.normalize(title))) {
          continue;
        }
      }
      final imageUrl = (raw['imageUrl'] ?? '').toString().trim();
      final productId = (raw['productId'] ?? '').toString().trim();
      if (productId.isEmpty) continue;
      // Don't hide a genuine catalogue entry merely because it has no
      // clean image yet. The UI displays a placeholder rather than using
      // an unrelated seller-listing photo.
      final cleanImageUrl = _isHttps(imageUrl) ? imageUrl : '';
      final resolvedProductType =
          SealedExpansionMatcher.isFirstPartnerIllustrationTitle(title)
              ? 'firstPartnerIllustrationCollection'
              : productType;
      final edition = productType == 'eliteTrainerBox' &&
              SealedProductIdentityService.detectEdition(title) ==
                  SealedProductEdition.pokemonCenter
          ? 'pokemonCenter'
          : 'standard';
      results.add(SealedCatalogProduct(
        productId: productId,
        title: title,
        imageUrl: await _approvedImage(
          productId: productId,
          fallback: cleanImageUrl,
        ),
        productType: resolvedProductType,
        productTypeLabel: _productTypeLabel(resolvedProductType, edition),
        edition: edition,
        // Verified individual-product exceptions take priority over broad
        // catalogue groups; other poster collections are left alone.
        expansionName: SealedExpansionMatcher.fromProductTitle(title) ??
            (raw['_pocketchaseExpansionName'] ?? '').toString(),
      ));
    }
    results.sort((a, b) {
      if (a.edition != b.edition) return a.edition.compareTo(b.edition);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return results;
  }

  static Future<List<Map<String, dynamic>>> _groups() async {
    if (_groupCache != null) return _groupCache!;
    final json = await _getJson('$_baseUrl/groups');
    _groupCache = _resultMaps(json);
    return _groupCache!;
  }

  static Future<List<Map<String, dynamic>>> _products(int groupId) async {
    final cached = _productCache[groupId];
    if (cached != null) return cached;
    final json = await _getJson('$_baseUrl/$groupId/products');
    final products = _resultMaps(json);
    _productCache[groupId] = products;
    return products;
  }

  static Future<Map<String, dynamic>> _getJson(String url) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'PocketChase/1.0');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Catalogue returned ${response.statusCode}.');
      }
      final text = await utf8.decoder.bind(response).join().timeout(_timeout);
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('Invalid catalogue data.');
      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close(force: true);
    }
  }

  static List<Map<String, dynamic>> _resultMaps(Map<String, dynamic> json) {
    final raw = json['results'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  // Searches for the 2026 product line work even when the user uses the
  // edition number rather than the catalogue's "Collection 2026" group.
  static bool _isFirstPartnerSearch(String query, String productType) {
    final normalized = SealedProductIdentityService.normalize(query);
    final mentionsFirstPartner = normalized.contains('first partner') ||
        normalized.contains('first partners');
    if (productType == 'firstPartnerIllustrationCollection') {
      return mentionsFirstPartner ||
          normalized.contains('illustration collection') ||
          RegExp(r'\bseries [123]\b').hasMatch(normalized);
    }
    if (productType != 'illustrationCollection' &&
        productType != 'collectionBox') {
      return false;
    }
    return mentionsFirstPartner;
  }

  static int? _requestedFirstPartnerSeries(String query) {
    final normalized = SealedProductIdentityService.normalize(query);
    final explicit = RegExp(r'\bseries (?:number |no )?([123])\b')
        .firstMatch(normalized);
    if (explicit != null) return int.parse(explicit.group(1)!);
    final short = RegExp(r'\bfirst partners?(?: illustration)?(?: collection)? ([123])\b')
        .firstMatch(normalized);
    return short == null ? null : int.parse(short.group(1)!);
  }

  static Set<String> _meaningfulTokens(String value) {
    const ignored = <String>{
      'pokemon', 'tcg', 'sv', 'me', 'swsh', 'xy', 'sun', 'moon', 'scarlet',
      'violet',
    };
    return SealedProductIdentityService.normalize(value)
        .split(' ')
        .where((token) => token.isNotEmpty && !ignored.contains(token))
        .toSet();
  }

  static bool _matchesProductType(String title, String productType) {
    final value = SealedProductIdentityService.normalize(title);
    const excluded = <String>['code card', 'digital bundle', 'empty'];
    if (excluded.any(value.contains) || value.contains(' case')) return false;
    switch (productType) {
      case 'eliteTrainerBox':
        return value.contains('elite trainer box');
      case 'boosterBox':
        return value.contains('booster box') ||
            value.contains('booster display box');
      case 'boosterBundle':
        return value.contains('booster bundle') &&
            !value.contains('display');
      case 'ultraPremiumCollection':
        return value.contains('ultra premium collection');
      case 'boosterPack':
        return value.contains('booster pack') &&
            !value.contains('sleeved') &&
            !value.contains('blister');
      case 'sleevedBooster':
        return value.contains('sleeved booster');
      case 'blisterPack':
        return value.contains('blister') &&
            !value.contains('checklane') &&
            !RegExp(r'\b(?:3|three) pack blister\b').hasMatch(value);
      case 'checklaneBlister':
        return value.contains('checklane blister');
      case 'threePackBlister':
        return RegExp(r'\b(?:3|three) pack blister\b').hasMatch(value);
      case 'tin':
        return value.contains('tin') &&
            !value.contains('mini tin') &&
            !value.contains('poke ball tin') &&
            !value.contains('pokeball tin') &&
            !value.contains('stacking tin');
      case 'miniTin':
        return value.contains('mini tin');
      case 'pokeBallTin':
        return value.contains('poke ball tin') || value.contains('pokeball tin');
      case 'stackingTin':
        return value.contains('stacking tin');
      case 'exBox':
        return RegExp(r'\bex box\b').hasMatch(value) &&
            !value.contains('bundle');
      case 'collectionBox':
        return value.contains('collection box') ||
            SealedExpansionMatcher.isFirstPartnerIllustrationTitle(title);
      case 'firstPartnerIllustrationCollection':
        return SealedExpansionMatcher.isFirstPartnerIllustrationTitle(title);
      case 'premiumCollection':
        return value.contains('premium collection') &&
            !value.contains('ultra premium');
      case 'premiumTournamentCollection':
        return value.contains('premium tournament collection');
      case 'specialCollection':
        return value.contains('special collection');
      case 'pinCollection':
        return value.contains('pin collection');
      case 'figureCollection':
        return value.contains('figure collection');
      case 'illustrationCollection':
        return value.contains('illustration collection');
      case 'techStickerCollection':
        return value.contains('tech sticker collection');
      case 'buildAndBattle':
        return value.contains('build and battle') &&
            !value.contains('stadium');
      case 'buildAndBattleStadium':
        return value.contains('build and battle stadium');
      case 'collectionChest':
        return value.contains('collector chest') ||
            value.contains('collection chest');
      case 'battleDeck':
        return value.contains('battle deck') &&
            !value.contains('league battle deck');
      case 'leagueBattleDeck':
        return value.contains('league battle deck');
      case 'themeDeck':
        return value.contains('theme deck');
      case 'worldChampionshipDeck':
        return value.contains('world championship deck') ||
            value.contains('world championships deck');
      case 'battleAcademy':
        return value.contains('battle academy');
      case 'trainerToolkit':
        return value.contains('trainer toolkit') ||
            value.contains('trainers toolkit');
      case 'trainerKit':
        return value.contains('trainer kit') && !value.contains('toolkit');
      case 'posterCollection':
        return value.contains('poster collection');
      case 'binderCollection':
        return value.contains('binder collection');
      case 'firstPartnerPack':
        return value.contains('first partner pack');
      case 'surpriseBox':
        return value.contains('surprise box');
      case 'adventCalendar':
        return value.contains('holiday calendar') ||
            value.contains('advent calendar');
      default:
        return false;
    }
  }

  static String _productTypeLabel(String type, String edition) {
    if (type == 'eliteTrainerBox') {
      return edition == 'pokemonCenter'
          ? 'Pokémon Center Elite Trainer Box'
          : 'Standard Elite Trainer Box';
    }
    const labels = <String, String>{
      'boosterBox': 'Booster Box',
      'boosterBundle': 'Booster Bundle',
      'ultraPremiumCollection': 'Ultra-Premium Collection (UPC)',
      'boosterPack': 'Booster Pack',
      'sleevedBooster': 'Sleeved Booster Pack',
      'blisterPack': 'Blister Pack',
      'checklaneBlister': 'Checklane Blister',
      'threePackBlister': 'Three-Pack Blister',
      'tin': 'Tin',
      'miniTin': 'Mini Tin',
      'pokeBallTin': 'Poké Ball Tin',
      'stackingTin': 'Stacking Tin',
      'exBox': 'ex Box',
      'collectionBox': 'Collection Box',
      'premiumCollection': 'Premium Collection',
      'premiumTournamentCollection': 'Premium Tournament Collection',
      'specialCollection': 'Special Collection',
      'pinCollection': 'Pin Collection',
      'figureCollection': 'Figure Collection',
      'illustrationCollection': 'Illustration Collection',
      'firstPartnerIllustrationCollection': 'First Partner Illustration Collection',
      'techStickerCollection': 'Tech Sticker Collection',
      'buildAndBattle': 'Build & Battle Box',
      'buildAndBattleStadium': 'Build & Battle Stadium',
      'collectionChest': 'Collector Chest',
      'battleDeck': 'Battle Deck',
      'leagueBattleDeck': 'League Battle Deck',
      'themeDeck': 'Theme Deck',
      'worldChampionshipDeck': 'World Championship Deck',
      'battleAcademy': 'Battle Academy',
      'trainerToolkit': 'Trainer’s Toolkit',
      'trainerKit': 'Trainer Kit',
      'posterCollection': 'Poster Collection',
      'binderCollection': 'Binder Collection',
      'firstPartnerPack': 'First Partner Pack',
      'surpriseBox': 'Surprise Box',
      'adventCalendar': 'Holiday Calendar',
    };
    return labels[type] ?? 'Sealed product';
  }

  static Future<String> _approvedImage({
    required String productId,
    required String fallback,
  }) async {
    try {
      final document = await _firestore
          .collection('sealed_product_catalog')
          .doc('tcgplayer_$productId')
          .get()
          .timeout(const Duration(seconds: 4));
      final data = document.data();
      if (data?['approved'] == true) {
        final image = (data?['imageUrl'] ?? '').toString().trim();
        if (_isHttps(image)) return image;
      }
    } catch (_) {}
    return fallback;
  }

  static String catalogueDocumentId(String value) => value
      .replaceAll('|', '__')
      .replaceAll('/', '-')
      .replaceAll(RegExp(r'\s+'), '-');

  static bool _isHttps(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
