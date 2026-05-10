// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_element_parameter, unreachable_switch_default, unnecessary_import

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/card_scan_analysis.dart';
import '../models/card_search_result.dart';
import '../models/collector_number_query.dart';
import '../models/scan_line_hint.dart';
import '../models/tcg_card.dart';
import '../models/tcg_set.dart';
import '../utils/card_number_sorter.dart';

const int _kFastCardSearchPageSize = 100;
const int _kFastCardSearchMaxPages = 2;
const int _kFastSetSearchMaxPages = 2;

class _ParsedCardSearchQuery {
  const _ParsedCardSearchQuery({
    required this.originalQuery,
    required this.cardQuery,
    required this.cardTerms,
    required this.matchedSets,
  });

  final String originalQuery;
  final String cardQuery;
  final List<String> cardTerms;
  final List<TcgSet> matchedSets;

  bool get hasSetHints => matchedSets.isNotEmpty;

  Set<String> get matchedSetIds => matchedSets
      .map((set) => set.id.trim().toLowerCase())
      .where((id) => id.isNotEmpty)
      .toSet();
}

class PokemonTcgService {
  static const String _baseUrl = 'https://api.pokemontcg.io/v2';
  static final Map<String, List<TcgCard>> _cardSearchCache = <String, List<TcgCard>>{};
  static final Map<String, Future<List<TcgCard>>> _cardSearchInFlight =
      <String, Future<List<TcgCard>>>{};
  static final Map<String, List<TcgSet>> _setSearchCache = <String, List<TcgSet>>{};
  static final Map<String, Future<List<TcgSet>>> _setSearchInFlight =
      <String, Future<List<TcgSet>>>{};
  static final Map<String, List<TcgCard>> _setCardsCache = <String, List<TcgCard>>{};
  static final Map<String, Future<List<TcgCard>>> _setCardsInFlight =
      <String, Future<List<TcgCard>>>{};
  static final Map<String, TcgCard> _cardByIdCache = <String, TcgCard>{};
  static final Map<String, Future<TcgCard>> _cardByIdInFlight = <String, Future<TcgCard>>{};
  static final Map<String, TcgSet> _setByIdCache = <String, TcgSet>{};
  static final Map<String, Future<TcgSet?>> _setByIdInFlight =
      <String, Future<TcgSet?>>{};

  static List<TcgSet>? _allSetsCache;
  static Future<List<TcgSet>>? _allSetsInFlight;


  static const Duration _apiDiskCacheFreshFor = Duration(days: 14);
  static const Duration _apiDiskCacheStaleFor = Duration(days: 90);
  static Directory? _apiDiskCacheDirectory;

  static Future<Directory> _getApiDiskCacheDirectory() async {
    final cachedDirectory = _apiDiskCacheDirectory;
    if (cachedDirectory != null) return cachedDirectory;

    final baseDirectory = await getApplicationSupportDirectory();
    final directory = Directory('${baseDirectory.path}/pokemon_tcg_api_cache');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _apiDiskCacheDirectory = directory;
    return directory;
  }

  static String _apiCacheFileName(Uri uri) {
    final value = uri.toString();
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '${hash.toRadixString(16).padLeft(8, '0')}.json';
  }

  static Future<Map<String, dynamic>?> _readApiJsonFromDisk(
    Uri uri, {
    required Duration maxAge,
  }) async {
    try {
      final directory = await _getApiDiskCacheDirectory();
      final file = File('${directory.path}/${_apiCacheFileName(uri)}');
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final cachedAtMs = (decoded['cachedAtMs'] as num?)?.toInt() ?? 0;
      if (cachedAtMs <= 0) return null;

      final age = DateTime.now().millisecondsSinceEpoch - cachedAtMs;
      if (age > maxAge.inMilliseconds) return null;

      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {
      // Ignore broken cache files and use the network instead.
    }

    return null;
  }

  static Future<void> _writeApiJsonToDisk(
    Uri uri,
    Map<String, dynamic> data,
  ) async {
    try {
      final directory = await _getApiDiskCacheDirectory();
      final file = File('${directory.path}/${_apiCacheFileName(uri)}');
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'cachedAtMs': DateTime.now().millisecondsSinceEpoch,
          'url': uri.toString(),
          'data': data,
        }),
        flush: false,
      );
    } catch (_) {
      // Disk cache is only a speed boost. Never block the app if it fails.
    }
  }

  static Future<Map<String, dynamic>> _getJsonMapWithDiskCache(
    Uri uri, {
    Duration freshFor = _apiDiskCacheFreshFor,
  }) async {
    final freshCachedData = await _readApiJsonFromDisk(uri, maxAge: freshFor);
    if (freshCachedData != null) {
      return freshCachedData;
    }

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _writeApiJsonToDisk(uri, data);
      return data;
    } catch (_) {
      final staleCachedData = await _readApiJsonFromDisk(
        uri,
        maxAge: _apiDiskCacheStaleFor,
      );
      if (staleCachedData != null) {
        return staleCachedData;
      }
      rethrow;
    }
  }

  static Future<CardSearchResult> searchCardsAndSets(String query) async {
    final results = await Future.wait<dynamic>([
      searchCardsOnly(query),
      searchSetsOnly(query),
    ]);
    final cards = results[0] as List<TcgCard>;
    final sets = results[1] as List<TcgSet>;
    return CardSearchResult(
      cards: cards,
      sets: sets,
      matchedSet: sets.isEmpty ? null : sets.first,
    );
  }

  static Future<List<TcgCard>> _fetchAllCardsForSearch(String cardSearch) async {
    const pageSize = 250;
    final cardsById = <String, TcgCard>{};
    var page = 1;

    while (true) {
      final cardsUri = Uri.parse(
        '$_baseUrl/cards?q=$cardSearch&pageSize=$pageSize&page=$page&orderBy=name,set.releaseDate,number',
      );
      final cardsData = await _getJsonMapWithDiskCache(cardsUri);
      final cardsItems = (cardsData['data'] as List<dynamic>? ?? []);

      if (cardsItems.isEmpty) {
        break;
      }

      for (final item in cardsItems) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }

      if (cardsItems.length < pageSize || page >= 40) {
        break;
      }

      page++;
    }

    final cards = cardsById.values.toList()
      ..sort((a, b) {
        final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (nameCompare != 0) return nameCompare;

        final setCompare = a.setName.toLowerCase().compareTo(b.setName.toLowerCase());
        if (setCompare != 0) return setCompare;

        return compareCardNumbers(a.number, b.number);
      });

    return cards;
  }

  static CollectorNumberQuery? _tryParseCollectorNumberQuery(String value) {
    final match = RegExp(r'^\s*([A-Za-z0-9]+)\s*/\s*(\d+)\s*$').firstMatch(value);
    if (match == null) return null;

    final cardNumber = match.group(1)?.trim() ?? '';
    final printedTotal = int.tryParse(match.group(2)?.trim() ?? '');
    if (cardNumber.isEmpty || printedTotal == null || printedTotal <= 0) {
      return null;
    }

    return CollectorNumberQuery(
      cardNumber: cardNumber,
      printedTotal: printedTotal,
    );
  }

  static Future<List<TcgCard>> _searchExactCollectorNumber(
    CollectorNumberQuery query,
  ) async {
    final normalizedRequestedNumber = _normalizeCollectorCardNumber(query.cardNumber);
    if (normalizedRequestedNumber.isEmpty) return const <TcgCard>[];

    final numberSearch = 'number:${_escapeTcgQueryValue(query.cardNumber)}';
    final cardsById = <String, TcgCard>{};
    var page = 1;

    while (true) {
      final uri = Uri.parse(
        '$_baseUrl/cards?q=$numberSearch&pageSize=250&page=$page&orderBy=-set.releaseDate,number',
      );
      final data = await _getJsonMapWithDiskCache(uri);
      final items = (data['data'] as List<dynamic>? ?? const []);
      if (items.isEmpty) break;

      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;

        final rawNumber = (item['number'] ?? '').toString();
        if (_normalizeCollectorCardNumber(rawNumber) != normalizedRequestedNumber) {
          continue;
        }

        final set = (item['set'] as Map<String, dynamic>? ?? const <String, dynamic>{});
        final printedTotal = _readIntValue(set['printedTotal']);
        final total = _readIntValue(set['total']);
        if (printedTotal != query.printedTotal && total != query.printedTotal) {
          continue;
        }

        final card = TcgCard.fromJson(item);
        cardsById.putIfAbsent(card.id, () => card);
      }

      if (items.length < 250 || page >= 20) {
        break;
      }
      page++;
    }

    final cards = cardsById.values.toList()
      ..sort((a, b) {
        final setCompare = a.setName.toLowerCase().compareTo(b.setName.toLowerCase());
        if (setCompare != 0) return setCompare;
        return compareCardNumbers(a.number, b.number);
      });

    return cards;
  }

  static int? _readIntValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim());
  }

  static String _normalizeCollectorCardNumber(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    if (cleaned.isEmpty) return '';

    final numeric = int.tryParse(cleaned);
    if (numeric != null) {
      return numeric.toString();
    }

    return cleaned.replaceFirstMapped(
      RegExp(r'^([a-z]+)0+(\d+)$'),
      (match) => '${match.group(1)}${int.tryParse(match.group(2) ?? '') ?? match.group(2)}',
    );
  }


  static Future<CardSearchResult> searchCardsOnlyResult(String query) async {
    final cards = await searchCardsOnly(query);
    return CardSearchResult(cards: cards);
  }

  static Future<CardSearchResult> searchSetsOnlyResult(String query) async {
    final sets = await searchSetsOnly(query);
    return CardSearchResult(sets: sets, matchedSet: sets.isEmpty ? null : sets.first);
  }

  static Future<List<TcgCard>> searchCardsOnly(String query) async {
    final cleanQuery = query.trim();
    final cacheKey = _normalizeApiSearchKey(cleanQuery);
    if (cacheKey.isEmpty) return const <TcgCard>[];

    final cachedCards = _cardSearchCache[cacheKey];
    if (cachedCards != null) {
      return List<TcgCard>.from(cachedCards);
    }

    final inFlightRequest = _cardSearchInFlight[cacheKey];
    if (inFlightRequest != null) {
      final cards = await inFlightRequest;
      return List<TcgCard>.from(cards);
    }

    final request = _searchCardsOnlyFromApi(cleanQuery);
    _cardSearchInFlight[cacheKey] = request;

    try {
      final cards = await request;
      _cardSearchCache[cacheKey] = List<TcgCard>.from(cards);
      return List<TcgCard>.from(cards);
    } finally {
      _cardSearchInFlight.remove(cacheKey);
    }
  }

  static Future<List<TcgCard>> _searchCardsOnlyFromApi(String cleanQuery) async {
    final exactCollectorNumber = _tryParseCollectorNumberQuery(cleanQuery);
    if (exactCollectorNumber != null) {
      return _searchExactCollectorNumber(exactCollectorNumber);
    }

    final parsedSearch = await _parseCardSearchQuery(cleanQuery);

    if (parsedSearch.hasSetHints) {
      final setFilteredCards = await _searchCardsOnlyFromParsedSetSearch(parsedSearch);
      if (setFilteredCards.isNotEmpty) {
        return setFilteredCards;
      }
    }

    final terms = parsedSearch.cardTerms.isNotEmpty
        ? parsedSearch.cardTerms
        : cleanQuery
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
    if (terms.isEmpty) return const <TcgCard>[];

    final cards = await _fetchCardSearchMatchesForNameTerms(terms);
    cards.sort(
      (a, b) => parsedSearch.hasSetHints
          ? _compareCardSearchResultsForParsedQuery(a, b, parsedSearch)
          : _compareCardSearchResults(a, b, cleanQuery),
    );
    return cards;
  }

  static Future<List<TcgCard>> _fetchCardSearchMatchesForNameTerms(
    List<String> terms,
  ) async {
    final usefulTerms = terms
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();
    if (usefulTerms.isEmpty) return const <TcgCard>[];

    final escapedTerms = usefulTerms.map(_escapeTcgQueryValue).toList();
    final cardSearch = escapedTerms.map((term) => 'name:*$term*').join(' AND ');
    final cardsById = <String, TcgCard>{};
    var page = 1;

    while (true) {
      final uri = Uri.parse(
        '$_baseUrl/cards?q=$cardSearch&pageSize=$_kFastCardSearchPageSize&page=$page&orderBy=name,number,set.releaseDate',
      );
      final data = await _getJsonMapWithDiskCache(uri);
      final items = (data['data'] as List<dynamic>? ?? const []);
      if (items.isEmpty) break;

      for (final item in items) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }

      if (items.length < _kFastCardSearchPageSize || page >= _kFastCardSearchMaxPages) {
        break;
      }
      page++;
    }

    return cardsById.values.toList();
  }

  static Future<List<TcgCard>> _searchCardsOnlyFromParsedSetSearch(
    _ParsedCardSearchQuery parsedSearch,
  ) async {
    final cardsById = <String, TcgCard>{};

    final collectorNumber = _tryParseCollectorNumberQuery(parsedSearch.cardQuery);

    for (final set in parsedSearch.matchedSets.take(4)) {
      final setId = set.id.trim();
      if (setId.isEmpty) continue;

      try {
        final cardsInSet = await fetchCardsBySet(setId);
        for (final card in cardsInSet) {
          if (!_doesCardMatchParsedCardSearch(
            card: card,
            parsedSearch: parsedSearch,
            collectorNumber: collectorNumber,
          )) {
            continue;
          }

          cardsById.putIfAbsent(card.id, () => card);
        }
      } catch (_) {
        // Keep searching from the public cards endpoint if a full-set load fails.
      }
    }

    if (parsedSearch.cardTerms.isNotEmpty) {
      try {
        final apiCards = await _fetchCardSearchMatchesForNameTerms(parsedSearch.cardTerms);
        for (final card in apiCards) {
          if (_cardBelongsToAnyParsedSet(card, parsedSearch)) {
            cardsById.putIfAbsent(card.id, () => card);
          }
        }
      } catch (_) {
        // Set results above are normally enough for a set-code search.
      }
    }

    final cards = cardsById.values.toList()
      ..sort((a, b) => _compareCardSearchResultsForParsedQuery(a, b, parsedSearch));

    return cards.take(160).toList();
  }

  static bool _doesCardMatchParsedCardSearch({
    required TcgCard card,
    required _ParsedCardSearchQuery parsedSearch,
    required CollectorNumberQuery? collectorNumber,
  }) {
    if (!_cardBelongsToAnyParsedSet(card, parsedSearch)) {
      return false;
    }

    if (collectorNumber != null) {
      return _normalizeCollectorCardNumber(card.number) ==
          _normalizeCollectorCardNumber(collectorNumber.cardNumber);
    }

    if (parsedSearch.cardTerms.isEmpty) {
      return true;
    }

    final normalizedName = _normalizeSearchMatchText(card.name);
    final normalizedCardQuery = _normalizeSearchMatchText(parsedSearch.cardQuery);
    if (normalizedName.isEmpty || normalizedCardQuery.isEmpty) return false;

    if (normalizedName == normalizedCardQuery) return true;
    if (normalizedName.contains(normalizedCardQuery)) return true;

    final nameWords = normalizedName.split(' ').where((word) => word.isNotEmpty).toList();

    return parsedSearch.cardTerms.every((term) {
      final normalizedTerm = _normalizeSearchMatchText(term);
      if (normalizedTerm.isEmpty) return true;

      return nameWords.any((word) => word == normalizedTerm || word.startsWith(normalizedTerm)) ||
          normalizedName.contains(normalizedTerm);
    });
  }

  static bool _cardBelongsToAnyParsedSet(
    TcgCard card,
    _ParsedCardSearchQuery parsedSearch,
  ) {
    if (!parsedSearch.hasSetHints) return true;

    final cardSetId = card.setId.trim().toLowerCase();
    if (cardSetId.isNotEmpty && parsedSearch.matchedSetIds.contains(cardSetId)) {
      return true;
    }

    final cardSetName = _normalizeSearchMatchText(card.setName);
    if (cardSetName.isEmpty) return false;

    return parsedSearch.matchedSets.any(
      (set) => cardSetName == _normalizeSearchMatchText(set.name),
    );
  }

  static Future<_ParsedCardSearchQuery> _parseCardSearchQuery(String cleanQuery) async {
    final rawParts = cleanQuery
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    _ParsedCardSearchQuery fallback() => _ParsedCardSearchQuery(
          originalQuery: cleanQuery,
          cardQuery: cleanQuery,
          cardTerms: rawParts,
          matchedSets: const <TcgSet>[],
        );

    if (rawParts.length < 2) {
      return fallback();
    }

    List<TcgSet> allSets;
    try {
      allSets = await fetchSets();
    } catch (_) {
      return fallback();
    }

    final usedIndexes = <int>{};
    final matchedSetsById = <String, TcgSet>{};

    void addMatches(List<TcgSet> sets) {
      for (final set in sets) {
        final id = set.id.trim();
        if (id.isEmpty) continue;
        matchedSetsById.putIfAbsent(id, () => set);
      }
    }

    final maxPhraseLength = math.min(5, rawParts.length);
    for (var phraseLength = maxPhraseLength; phraseLength >= 2; phraseLength--) {
      for (var start = 0; start + phraseLength <= rawParts.length; start++) {
        final indexes = [for (var i = start; i < start + phraseLength; i++) i];
        if (indexes.any(usedIndexes.contains)) continue;

        final phrase = rawParts.sublist(start, start + phraseLength).join(' ');
        final matches = _findSetMatchesForSearchAlias(
          phrase,
          allSets,
          allowLooseNameMatch: true,
        );

        if (matches.isEmpty) continue;

        usedIndexes.addAll(indexes);
        addMatches(matches);
      }
    }

    for (var index = 0; index < rawParts.length; index++) {
      if (usedIndexes.contains(index)) continue;

      final matches = _findSetMatchesForSearchAlias(
        rawParts[index],
        allSets,
        allowLooseNameMatch: false,
      );

      if (matches.isEmpty) continue;

      usedIndexes.add(index);
      addMatches(matches);
    }

    final cardTerms = <String>[
      for (var index = 0; index < rawParts.length; index++)
        if (!usedIndexes.contains(index)) rawParts[index],
    ];

    if (matchedSetsById.isEmpty) {
      return fallback();
    }

    return _ParsedCardSearchQuery(
      originalQuery: cleanQuery,
      cardQuery: cardTerms.join(' ').trim(),
      cardTerms: cardTerms,
      matchedSets: matchedSetsById.values.toList(),
    );
  }

  static const Map<String, List<String>> _cardSearchSetAliasNames = <String, List<String>>{
    'jtg': <String>['journey together'],
    'journeytogether': <String>['journey together'],
    'prz': <String>['prismatic evolutions'],
    'pre': <String>['prismatic evolutions'],
    'ssp': <String>['surging sparks'],
    'scr': <String>['stellar crown'],
    'sfa': <String>['shrouded fable'],
    'twm': <String>['twilight masquerade'],
    'tei': <String>['temporal forces'],
    'par': <String>['paradox rift'],
    'obf': <String>['obsidian flames'],
    'pal': <String>['paldea evolved'],
    'svi': <String>['scarlet violet'],
    'sv1': <String>['scarlet violet'],
    'svp': <String>['scarlet violet black star promos', 'scarlet violet promo'],
    'svpblackstar': <String>['scarlet violet black star promos'],
    'mev': <String>['151'],
    '151': <String>['151'],
    'dri': <String>['destined rivals'],
    'destinedrivals': <String>['destined rivals'],
    'meg': <String>['mega evolution'],
    'mega': <String>['mega evolution'],
  };

  static List<TcgSet> _findSetMatchesForSearchAlias(
    String alias,
    List<TcgSet> allSets, {
    required bool allowLooseNameMatch,
  }) {
    final normalizedAlias = _normalizeSearchMatchText(alias);
    final compactAlias = _compactSearchMatchText(alias);
    if (normalizedAlias.isEmpty || compactAlias.isEmpty) return const <TcgSet>[];

    final explicitNames = _cardSearchSetAliasNames[compactAlias] ??
        _cardSearchSetAliasNames[normalizedAlias.replaceAll(' ', '')] ??
        const <String>[];
    final normalizedExplicitNames = explicitNames
        .map(_normalizeSearchMatchText)
        .where((name) => name.isNotEmpty)
        .toList();

    final scored = <MapEntry<TcgSet, int>>[];

    for (final set in allSets) {
      final normalizedSetId = _normalizeSearchMatchText(set.id);
      final compactSetId = _compactSearchMatchText(set.id);
      final normalizedSetName = _normalizeSearchMatchText(set.name);
      final compactSetName = _compactSearchMatchText(set.name);
      final initials = _setNameInitials(set.name);

      var score = 0;

      if (compactSetId == compactAlias) score = math.max(score, 920);
      if (compactSetName == compactAlias) score = math.max(score, 900);

      for (final explicitName in normalizedExplicitNames) {
        if (normalizedSetName == explicitName) {
          score = math.max(score, 1000);
        } else if (normalizedSetName.contains(explicitName)) {
          score = math.max(score, 940);
        }
      }

      if (compactAlias.length >= 2 && compactAlias.length <= 6 && initials == compactAlias) {
        score = math.max(score, 760);
      }

      if (allowLooseNameMatch) {
        if (normalizedSetName == normalizedAlias) {
          score = math.max(score, 880);
        } else if (normalizedAlias.length >= 4 && normalizedSetName.startsWith(normalizedAlias)) {
          score = math.max(score, 700);
        } else if (normalizedAlias.length >= 4 && normalizedSetName.contains(normalizedAlias)) {
          score = math.max(score, 640);
        }
      }

      if (score > 0) {
        scored.add(MapEntry(set, score));
      }
    }

    scored.sort((a, b) {
      final scoreCompare = b.value.compareTo(a.value);
      if (scoreCompare != 0) return scoreCompare;

      final dateA = _tryParseReleaseDate(a.key.releaseDate);
      final dateB = _tryParseReleaseDate(b.key.releaseDate);
      if (dateA != null && dateB != null) return dateB.compareTo(dateA);
      if (dateA != null) return -1;
      if (dateB != null) return 1;

      return a.key.name.compareTo(b.key.name);
    });

    return scored.take(5).map((entry) => entry.key).toList();
  }

  static String _compactSearchMatchText(String value) {
    return _normalizeSearchMatchText(value).replaceAll(' ', '');
  }

  static String _setNameInitials(String value) {
    final ignoredWords = <String>{'and', 'the', 'of', 'a', 'an'};
    return _normalizeSearchMatchText(value)
        .split(' ')
        .where((word) => word.isNotEmpty && !ignoredWords.contains(word))
        .map((word) => word[0])
        .join();
  }

  static int _compareCardSearchResultsForParsedQuery(
    TcgCard a,
    TcgCard b,
    _ParsedCardSearchQuery parsedSearch,
  ) {
    final scoreA = _scoreCardSearchResultForParsedQuery(a, parsedSearch);
    final scoreB = _scoreCardSearchResultForParsedQuery(b, parsedSearch);
    if (scoreA != scoreB) {
      return scoreB.compareTo(scoreA);
    }

    final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameCompare != 0) return nameCompare;

    final setCompare = a.setName.toLowerCase().compareTo(b.setName.toLowerCase());
    if (setCompare != 0) return setCompare;

    return compareCardNumbers(a.number, b.number);
  }

  static int _scoreCardSearchResultForParsedQuery(
    TcgCard card,
    _ParsedCardSearchQuery parsedSearch,
  ) {
    var score = parsedSearch.cardQuery.isEmpty
        ? 80
        : _scoreCardSearchResult(card, parsedSearch.cardQuery);

    if (_cardBelongsToAnyParsedSet(card, parsedSearch)) {
      score += 1200;
    }

    final normalizedCardQuery = _normalizeSearchMatchText(parsedSearch.cardQuery);
    final normalizedName = _normalizeSearchMatchText(card.name);
    if (normalizedCardQuery.isNotEmpty && normalizedName == normalizedCardQuery) {
      score += 400;
    }

    return score;
  }

  static Future<List<TcgSet>> searchSetsOnly(String query) async {
    final cleanQuery = query.trim();
    final cacheKey = _normalizeApiSearchKey(cleanQuery);
    if (cacheKey.isEmpty) return const <TcgSet>[];

    final cachedSets = _setSearchCache[cacheKey];
    if (cachedSets != null) {
      return List<TcgSet>.from(cachedSets);
    }

    final inFlightRequest = _setSearchInFlight[cacheKey];
    if (inFlightRequest != null) {
      final sets = await inFlightRequest;
      return List<TcgSet>.from(sets);
    }

    final request = _searchSetsOnlyFromApi(cleanQuery);
    _setSearchInFlight[cacheKey] = request;

    try {
      final sets = await request;
      _setSearchCache[cacheKey] = List<TcgSet>.from(sets);
      return List<TcgSet>.from(sets);
    } finally {
      _setSearchInFlight.remove(cacheKey);
    }
  }

  static Future<List<TcgSet>> _searchSetsOnlyFromApi(String cleanQuery) async {
    if (_tryParseCollectorNumberQuery(cleanQuery) != null) {
      return const <TcgSet>[];
    }

    final normalizedQuery = _normalizeSearchMatchText(cleanQuery);
    final queryWords = normalizedQuery
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    if (normalizedQuery.isEmpty || queryWords.isEmpty) {
      return const <TcgSet>[];
    }

    final allSets = await fetchSets();

    final sets = allSets
        .where(
          (set) => _doesLocalSetMatch(
            set: set,
            normalizedQuery: normalizedQuery,
            queryWords: queryWords,
          ),
        )
        .toList()
      ..sort((a, b) => _compareSetSearchResults(a, b, cleanQuery));

    final prefixMatches = sets
        .where((set) => _matchesSetPrefixSearch(set, cleanQuery))
        .toList();

    if (prefixMatches.isNotEmpty) {
      return prefixMatches.take(80).toList();
    }

    return sets.take(80).toList();
  }

  static bool _doesLocalSetMatch({
    required TcgSet set,
    required String normalizedQuery,
    required List<String> queryWords,
  }) {
    final normalizedName = _normalizeSearchMatchText(set.name);
    final normalizedId = _normalizeSearchMatchText(set.id);

    if (normalizedName.isEmpty) return false;

    if (normalizedName == normalizedQuery) return true;
    if (normalizedName.startsWith(normalizedQuery)) return true;
    if (normalizedName.contains(normalizedQuery)) return true;

    return queryWords.every(
      (word) => normalizedName.contains(word) || normalizedId.contains(word),
    );
  }

  static String _escapeTcgQueryValue(String value) {
    return value
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"');
  }

  static String _normalizeApiSearchKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _compareCardSearchResults(TcgCard a, TcgCard b, String query) {
    final scoreA = _scoreCardSearchResult(a, query);
    final scoreB = _scoreCardSearchResult(b, query);
    if (scoreA != scoreB) {
      return scoreB.compareTo(scoreA);
    }

    final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameCompare != 0) return nameCompare;

    final setCompare = a.setName.toLowerCase().compareTo(b.setName.toLowerCase());
    if (setCompare != 0) return setCompare;

    return compareCardNumbers(a.number, b.number);
  }

  static int _scoreCardSearchResult(TcgCard card, String query) {
    final normalizedQuery = _normalizeSearchMatchText(query);
    final normalizedName = _normalizeSearchMatchText(card.name);
    if (normalizedQuery.isEmpty || normalizedName.isEmpty) return 0;

    if (normalizedName == normalizedQuery) return 700;
    if (normalizedName.startsWith(normalizedQuery)) return 620;
    if (normalizedName.contains(normalizedQuery)) return 500;

    final queryWords = normalizedQuery.split(' ').where((word) => word.isNotEmpty).toList();
    final nameWords = normalizedName.split(' ').where((word) => word.isNotEmpty).toList();
    var score = 0;
    for (final word in queryWords) {
      if (nameWords.any((nameWord) => nameWord == word)) {
        score += 130;
      } else if (nameWords.any((nameWord) => nameWord.startsWith(word))) {
        score += 100;
      } else if (normalizedName.contains(word)) {
        score += 45;
      }
    }

    if (_normalizeSearchMatchText(card.setName).contains(normalizedQuery)) {
      score += 10;
    }

    return score;
  }

  static int _compareSetSearchResults(TcgSet a, TcgSet b, String query) {
    final scoreA = _scoreSetSearchResult(a, query);
    final scoreB = _scoreSetSearchResult(b, query);
    if (scoreA != scoreB) {
      return scoreB.compareTo(scoreA);
    }

    final dateA = _tryParseReleaseDate(a.releaseDate);
    final dateB = _tryParseReleaseDate(b.releaseDate);
    if (dateA != null && dateB != null) {
      final dateCompare = dateA.compareTo(dateB);
      if (dateCompare != 0) return dateCompare;
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static int _scoreSetSearchResult(TcgSet set, String query) {
    final normalizedQuery = _normalizeSearchMatchText(query);
    final normalizedName = _normalizeSearchMatchText(set.name);
    if (normalizedQuery.isEmpty || normalizedName.isEmpty) return 0;

    if (normalizedName == normalizedQuery) return 500;
    if (normalizedName.startsWith(normalizedQuery)) return 460;
    if (_matchesSetPrefixSearch(set, query)) return 430;
    if (normalizedName.contains(normalizedQuery)) return 320;

    final queryWords = normalizedQuery.split(' ').where((word) => word.isNotEmpty).toList();
    final nameWords = normalizedName.split(' ').where((word) => word.isNotEmpty).toList();
    var score = 0;
    for (final word in queryWords) {
      if (normalizedName == word) {
        score += 120;
      } else if (normalizedName.startsWith(word)) {
        score += 95;
      } else if (nameWords.any((nameWord) => nameWord.startsWith(word))) {
        score += 80;
      } else if (normalizedName.contains(word)) {
        score += 35;
      }
    }

    return score;
  }

  static bool _matchesSetPrefixSearch(TcgSet set, String query) {
    final normalizedQuery = _normalizeSearchMatchText(query);
    final normalizedName = _normalizeSearchMatchText(set.name);
    if (normalizedQuery.isEmpty || normalizedName.isEmpty) return false;

    final queryWords = normalizedQuery.split(' ').where((word) => word.isNotEmpty).toList();
    final nameWords = normalizedName.split(' ').where((word) => word.isNotEmpty).toList();
    if (queryWords.isEmpty || nameWords.isEmpty) return false;

    return queryWords.every(
      (queryWord) => nameWords.any((nameWord) => nameWord.startsWith(queryWord)),
    );
  }

  static String _normalizeSearchMatchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static DateTime? _tryParseReleaseDate(String value) {
    try {
      return DateTime.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  static Future<List<TcgCard>> searchCards(String query) async {
    return searchCardsOnly(query);
  }

  static Future<CardScanAnalysis> scanCardFromImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String? croppedImagePath;
    String? bottomLeftCropPath;
    String bottomLeftOcrText = '';

    try {
      croppedImagePath = await _createScannerCrop(imagePath);

      final primaryPath = croppedImagePath ?? imagePath;
      final primaryRecognizedText = await recognizer.processImage(
        InputImage.fromFilePath(primaryPath),
      );
      var primaryAnalysis = await analyzeRecognizedScan(primaryRecognizedText);

      bottomLeftCropPath = await _createBottomLeftScannerCrop(primaryPath);
      if (bottomLeftCropPath != null) {
        final bottomLeftRecognizedText = await recognizer.processImage(
          InputImage.fromFilePath(bottomLeftCropPath),
        );
        bottomLeftOcrText = bottomLeftRecognizedText.text;
        primaryAnalysis = await _refineAnalysisWithBottomLeftText(
          analysis: primaryAnalysis,
          bottomLeftText: bottomLeftOcrText,
        );
      }

      if (croppedImagePath == null) {
        return primaryAnalysis;
      }

      if (_scanAnalysisConfidence(primaryAnalysis) >= 80) {
        return primaryAnalysis;
      }

      final fallbackRecognizedText = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      var fallbackAnalysis = await analyzeRecognizedScan(fallbackRecognizedText);
      if (bottomLeftOcrText.trim().isNotEmpty) {
        fallbackAnalysis = await _refineAnalysisWithBottomLeftText(
          analysis: fallbackAnalysis,
          bottomLeftText: bottomLeftOcrText,
        );
      }

      return _preferScanAnalysis(primaryAnalysis, fallbackAnalysis);
    } finally {
      await recognizer.close();
      for (final tempPath in <String?>[croppedImagePath, bottomLeftCropPath]) {
        if (tempPath == null) continue;
        try {
          final file = File(tempPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }

  static Future<String?> _createScannerCrop(String imagePath) async {
    try {
      final sourceBytes = await File(imagePath).readAsBytes();
      final decodedImage = img.decodeImage(sourceBytes);
      if (decodedImage == null) return null;

      final oriented = img.bakeOrientation(decodedImage);
      final imageWidth = oriented.width;
      final imageHeight = oriented.height;
      if (imageWidth < 200 || imageHeight < 200) {
        return null;
      }

      const cardAspectRatio = 63 / 88;
      var cropWidth = (imageWidth * 0.78).round();
      var cropHeight = (cropWidth / cardAspectRatio).round();

      final maxHeight = (imageHeight * 0.86).round();
      if (cropHeight > maxHeight) {
        cropHeight = maxHeight;
        cropWidth = (cropHeight * cardAspectRatio).round();
      }

      final maxWidth = (imageWidth * 0.88).round();
      if (cropWidth > maxWidth) {
        cropWidth = maxWidth;
        cropHeight = (cropWidth / cardAspectRatio).round();
      }

      cropWidth = cropWidth.clamp(120, imageWidth).toInt();
      cropHeight = cropHeight.clamp(160, imageHeight).toInt();

      final cropX = ((imageWidth - cropWidth) / 2).round().clamp(0, imageWidth - cropWidth).toInt();
      final cropY = ((imageHeight - cropHeight) / 2).round().clamp(0, imageHeight - cropHeight).toInt();

      var cropped = img.copyCrop(
        oriented,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      if (cropped.width > 1400) {
        cropped = img.copyResize(cropped, width: 1400);
      }

      final tempDir = await getTemporaryDirectory();
      final croppedPath =
          '${tempDir.path}/scan_crop_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final croppedBytes = img.encodeJpg(cropped, quality: 92);
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(croppedBytes, flush: true);
      return croppedFile.path;
    } catch (_) {
      return null;
    }
  }


  static Future<String?> _createBottomLeftScannerCrop(String imagePath) async {
    try {
      final sourceBytes = await File(imagePath).readAsBytes();
      final decodedImage = img.decodeImage(sourceBytes);
      if (decodedImage == null) return null;

      final oriented = img.bakeOrientation(decodedImage);
      final imageWidth = oriented.width;
      final imageHeight = oriented.height;
      if (imageWidth < 160 || imageHeight < 220) {
        return null;
      }

      final cropWidth = (imageWidth * 0.58).round().clamp(120, imageWidth).toInt();
      final cropHeight = (imageHeight * 0.24).round().clamp(90, imageHeight).toInt();
      final cropX = (imageWidth * 0.02).round().clamp(0, imageWidth - cropWidth).toInt();
      final bottomPadding = (imageHeight * 0.03).round();
      final cropY = (imageHeight - cropHeight - bottomPadding)
          .clamp(0, imageHeight - cropHeight)
          .toInt();

      var cropped = img.copyCrop(
        oriented,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      if (cropped.width < 1000) {
        cropped = img.copyResize(cropped, width: 1000);
      }

      cropped = img.adjustColor(
        cropped,
        contrast: 1.15,
        saturation: 0.92,
        brightness: 1.03,
      );

      final tempDir = await getTemporaryDirectory();
      final croppedPath =
          '${tempDir.path}/scan_bottom_left_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final croppedBytes = img.encodeJpg(cropped, quality: 96);
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(croppedBytes, flush: true);
      return croppedFile.path;
    } catch (_) {
      return null;
    }
  }

  static Future<CardScanAnalysis> _refineAnalysisWithBottomLeftText({
    required CardScanAnalysis analysis,
    required String bottomLeftText,
  }) async {
    final cleanedBottomLeftText = bottomLeftText.trim();
    if (cleanedBottomLeftText.isEmpty) {
      return analysis;
    }

    final bottomLeftNumbers = _mergeUniqueStrings(
      _extractScanNumberCandidates(cleanedBottomLeftText),
    );
    final mergedCandidateNumbers = _mergeUniqueStrings(<String>[
      ...bottomLeftNumbers,
      ...analysis.candidateNumbers,
    ]);

    final combinedExtractedText =
        '${analysis.extractedText}\n\nBottom-left focus:\n$cleanedBottomLeftText';

    if (bottomLeftNumbers.isEmpty) {
      return CardScanAnalysis(
        extractedText: combinedExtractedText,
        candidateNames: analysis.candidateNames,
        candidateNumbers: mergedCandidateNumbers,
        matches: analysis.matches,
        exactConfirmed: analysis.exactConfirmed,
      );
    }

    final combinedNormalizedText = _normalizeScanText(
      '${analysis.extractedText} $cleanedBottomLeftText',
    );
    final combinedNormalizedOcrText = _normalizeOcrTextForMatching(
      '${analysis.extractedText} $cleanedBottomLeftText',
    );

    final bottomLeftSetCandidates = _mergeUniqueStrings(<String>[
      ..._extractScanSetCandidates(cleanedBottomLeftText),
      ..._extractScanSetCandidates(analysis.extractedText),
    ]);

    final likelySets = await _findLikelySets(
      setCandidates: bottomLeftSetCandidates,
      candidateNames: analysis.candidateNames,
      phraseCandidates: _extractScanPhraseCandidates(cleanedBottomLeftText),
      normalizedText: combinedNormalizedText,
      normalizedOcrText: combinedNormalizedOcrText,
    );
    final likelySetIds = likelySets.map((set) => set.id).toSet();

    final exactMatchesById = <String, TcgCard>{};

    for (final card in analysis.matches) {
      final normalizedCardNumber = _normalizeCardNumberHint(card.number);
      if (bottomLeftNumbers.any(
        (number) => _normalizeCardNumberHint(number) == normalizedCardNumber,
      )) {
        exactMatchesById.putIfAbsent(card.id, () => card);
      }
    }

    for (final set in likelySets.take(4)) {
      for (final bottomLeftNumber in bottomLeftNumbers.take(5)) {
        try {
          final exactCards = await _fetchCardsBySetAndNumber(
            set.id,
            bottomLeftNumber,
          );
          for (final card in exactCards) {
            exactMatchesById.putIfAbsent(card.id, () => card);
          }
        } catch (_) {}
      }
    }

    final prioritizedMatches = exactMatchesById.values.toList()
      ..sort((a, b) {
        final scoreA = _scoreScannedCard(
              card: a,
              normalizedText: combinedNormalizedText,
              normalizedOcrText: combinedNormalizedOcrText,
              candidateNames: analysis.candidateNames,
              candidateNumbers: mergedCandidateNumbers,
              phraseCandidates: _extractScanPhraseCandidates(cleanedBottomLeftText),
              setCandidates: bottomLeftSetCandidates,
              likelySetIds: likelySetIds,
            ) +
            _scoreBottomLeftExactMatch(
              card: a,
              bottomLeftNumbers: bottomLeftNumbers,
              likelySetIds: likelySetIds,
            );
        final scoreB = _scoreScannedCard(
              card: b,
              normalizedText: combinedNormalizedText,
              normalizedOcrText: combinedNormalizedOcrText,
              candidateNames: analysis.candidateNames,
              candidateNumbers: mergedCandidateNumbers,
              phraseCandidates: _extractScanPhraseCandidates(cleanedBottomLeftText),
              setCandidates: bottomLeftSetCandidates,
              likelySetIds: likelySetIds,
            ) +
            _scoreBottomLeftExactMatch(
              card: b,
              bottomLeftNumbers: bottomLeftNumbers,
              likelySetIds: likelySetIds,
            );
        return scoreB.compareTo(scoreA);
      });

    final mergedMatches = <TcgCard>[
      ...prioritizedMatches,
      ...analysis.matches.where((card) => !exactMatchesById.containsKey(card.id)),
    ];

    return CardScanAnalysis(
      extractedText: combinedExtractedText,
      candidateNames: analysis.candidateNames,
      candidateNumbers: mergedCandidateNumbers,
      matches: mergedMatches.take(8).toList(),
      exactConfirmed: exactMatchesById.isNotEmpty || analysis.exactConfirmed,
    );
  }

  static int _scoreBottomLeftExactMatch({
    required TcgCard card,
    required List<String> bottomLeftNumbers,
    required Set<String> likelySetIds,
  }) {
    final normalizedCardNumber = _normalizeCardNumberHint(card.number);
    final hasNumberMatch = bottomLeftNumbers.any(
      (number) => _normalizeCardNumberHint(number) == normalizedCardNumber,
    );
    if (!hasNumberMatch) return 0;
    if (likelySetIds.contains(card.setId)) return 520;
    return 320;
  }

  static int _scanAnalysisConfidence(CardScanAnalysis analysis) {
    var score = 0;
    if (analysis.bestMatch != null) score += 60;
    score += math.min(analysis.matches.length, 4) * 10;
    score += math.min(analysis.candidateNumbers.length, 3) * 15;
    score += math.min(analysis.candidateNames.length, 3) * 8;
    score += math.min((analysis.extractedText.length / 60).floor(), 10);
    return score;
  }

  static CardScanAnalysis _preferScanAnalysis(
    CardScanAnalysis primary,
    CardScanAnalysis fallback,
  ) {
    final primaryScore = _scanAnalysisConfidence(primary);
    final fallbackScore = _scanAnalysisConfidence(fallback);
    if (primaryScore == fallbackScore) {
      return primary.matches.length >= fallback.matches.length ? primary : fallback;
    }
    return primaryScore >= fallbackScore ? primary : fallback;
  }

  static Future<CardScanAnalysis> analyzeRecognizedScan(RecognizedText recognizedText) async {
    final rawText = recognizedText.text.trim();
    final normalizedText = _normalizeScanText(rawText);
    final normalizedOcrText = _normalizeOcrTextForMatching(rawText);
    final lineHints = _extractScanLineHints(recognizedText);

    final spatialNameCandidates = _extractSpatialNameCandidates(lineHints);
    final spatialNumberCandidates = _extractSpatialNumberCandidates(lineHints);
    final spatialSetCandidates = _extractSpatialSetCandidates(lineHints);

    final candidateNames = _mergeUniqueStrings(<String>[
      ...spatialNameCandidates,
      ..._extractScanNameCandidates(rawText),
    ]);
    final candidateNumbers = _mergeUniqueStrings(<String>[
      ...spatialNumberCandidates,
      ..._extractScanNumberCandidates(rawText),
    ]);
    final setCandidates = _mergeUniqueStrings(<String>[
      ...spatialSetCandidates,
      ..._extractScanSetCandidates(rawText),
    ]);
    final phraseCandidates = _extractScanPhraseCandidates(rawText);

    final queryCandidates = <String>{};

    void addQueryCandidate(String candidate) {
      final query = _buildScanQuery(candidate);
      if (query.isNotEmpty) {
        queryCandidates.add(query);
      }
    }

    for (final candidate in <String>[
      ...spatialNameCandidates,
      ...candidateNames,
      ...phraseCandidates,
    ].take(16)) {
      addQueryCandidate(candidate);
    }

    if (queryCandidates.isEmpty && normalizedText.isNotEmpty) {
      final fallbackWords = normalizedText
          .split(' ')
          .where((word) => word.length > 2 && !_scanStopWords.contains(word))
          .take(5)
          .join(' ');
      if (fallbackWords.isNotEmpty) {
        queryCandidates.add(fallbackWords);
      }
    }

    final likelySets = await _findLikelySets(
      setCandidates: setCandidates,
      candidateNames: candidateNames,
      phraseCandidates: phraseCandidates,
      normalizedText: normalizedText,
      normalizedOcrText: normalizedOcrText,
    );
    final likelySetIds = likelySets.map((set) => set.id).toSet();

    final matchesById = <String, TcgCard>{};

    for (final set in likelySets.take(3)) {
      for (final numberHint in candidateNumbers.take(3)) {
        try {
          final exactSetNumberCards = await _fetchCardsBySetAndNumber(set.id, numberHint);
          for (final card in exactSetNumberCards) {
            matchesById.putIfAbsent(card.id, () => card);
          }
        } catch (_) {}
      }

      for (final nameHint in candidateNames.take(4)) {
        try {
          final exactNameCards = await _searchCardsForExactNameCandidate(
            nameHint,
            setId: set.id,
            numberHint: candidateNumbers.isEmpty ? null : candidateNumbers.first,
          );
          for (final card in exactNameCards) {
            matchesById.putIfAbsent(card.id, () => card);
          }
        } catch (_) {}
      }

      try {
        final setCards = await _topCardsFromLikelySet(
          setId: set.id,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          candidateNames: candidateNames,
          candidateNumbers: candidateNumbers,
          phraseCandidates: phraseCandidates,
          setCandidates: setCandidates,
          likelySetIds: likelySetIds,
        );
        for (final card in setCards) {
          matchesById.putIfAbsent(card.id, () => card);
        }
      } catch (_) {}

      if (matchesById.length >= 16) {
        break;
      }
    }

    for (final nameHint in candidateNames.take(5)) {
      try {
        final exactNameCards = await _searchCardsForExactNameCandidate(
          nameHint,
          numberHint: candidateNumbers.isEmpty ? null : candidateNumbers.first,
        );
        for (final card in exactNameCards) {
          matchesById.putIfAbsent(card.id, () => card);
        }
      } catch (_) {}

      if (matchesById.length >= 22) {
        break;
      }
    }

    for (final numberHint in candidateNumbers.take(5)) {
      try {
        final cards = await _searchCardsByNumberHint(numberHint);
        for (final card in cards) {
          matchesById.putIfAbsent(card.id, () => card);
        }
      } catch (_) {}

      if (matchesById.length >= 24) {
        break;
      }
    }

    final numberSearchHints = candidateNumbers.isEmpty
        ? <String?>[null]
        : <String?>[...candidateNumbers.take(3), null];

    for (final numberHint in numberSearchHints) {
      for (final query in queryCandidates.take(10)) {
        try {
          final cards = await _searchCardsForScanCandidate(
            query,
            numberHint: numberHint,
          );
          for (final card in cards) {
            matchesById.putIfAbsent(card.id, () => card);
          }
        } catch (_) {}

        if (matchesById.length >= 32) {
          break;
        }
      }
      if (matchesById.length >= 32) {
        break;
      }
    }

    final matches = matchesById.values.toList()
      ..sort((a, b) {
        final scoreA = _scoreScannedCard(
          card: a,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          candidateNames: candidateNames,
          candidateNumbers: candidateNumbers,
          phraseCandidates: phraseCandidates,
          setCandidates: setCandidates,
          likelySetIds: likelySetIds,
        );
        final scoreB = _scoreScannedCard(
          card: b,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          candidateNames: candidateNames,
          candidateNumbers: candidateNumbers,
          phraseCandidates: phraseCandidates,
          setCandidates: setCandidates,
          likelySetIds: likelySetIds,
        );
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }
        return a.name.compareTo(b.name);
      });

    return CardScanAnalysis(
      extractedText: rawText,
      candidateNames: candidateNames,
      candidateNumbers: candidateNumbers,
      matches: matches.take(8).toList(),
      exactConfirmed: false,
    );
  }

  static List<String> _mergeUniqueStrings(List<String> values) {
    final results = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        results.add(trimmed);
      }
    }
    return results;
  }

  static List<ScanLineHint> _extractScanLineHints(RecognizedText recognizedText) {
    final rawLines = <ScanLineHint>[];
    final bounds = <Rect>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        final box = line.boundingBox;
        if (text.isEmpty || box.width <= 0 || box.height <= 0) continue;
        bounds.add(box);
      }
    }

    if (bounds.isEmpty) {
      return _buildFallbackLineHints(recognizedText.text);
    }

    final minLeft = bounds.map((box) => box.left).reduce(math.min);
    final minTop = bounds.map((box) => box.top).reduce(math.min);
    final maxRight = bounds.map((box) => box.right).reduce(math.max);
    final maxBottom = bounds.map((box) => box.bottom).reduce(math.max);
    final totalWidth = math.max(1.0, maxRight - minLeft);
    final totalHeight = math.max(1.0, maxBottom - minTop);

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        final box = line.boundingBox;
        if (text.isEmpty || box.width <= 0 || box.height <= 0) continue;
        rawLines.add(
          ScanLineHint(
            text: text,
            topFraction: ((box.top - minTop) / totalHeight).clamp(0.0, 1.0),
            leftFraction: ((box.left - minLeft) / totalWidth).clamp(0.0, 1.0),
            widthFraction: (box.width / totalWidth).clamp(0.0, 1.0),
            heightFraction: (box.height / totalHeight).clamp(0.0, 1.0),
          ),
        );
      }
    }

    rawLines.sort((a, b) {
      final topCompare = a.topFraction.compareTo(b.topFraction);
      if (topCompare != 0) return topCompare;
      return a.leftFraction.compareTo(b.leftFraction);
    });

    return rawLines;
  }

  static List<ScanLineHint> _buildFallbackLineHints(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const <ScanLineHint>[];

    return List<ScanLineHint>.generate(lines.length, (index) {
      final fraction = index / math.max(1, lines.length);
      return ScanLineHint(
        text: lines[index],
        topFraction: fraction,
        leftFraction: 0.1,
        widthFraction: 0.8,
        heightFraction: 1 / math.max(1, lines.length),
      );
    });
  }

  static bool _looksLikeCardNameLine(String line) {
    final cleaned = line
        .replaceAll(RegExp(r'\b\d{2,4}\s*HP\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length < 2 || cleaned.length > 32) return false;
    if (RegExp(r'^\d+[\d/ ]*$').hasMatch(cleaned)) return false;

    final normalized = _normalizeScanText(cleaned);
    if (normalized.isEmpty) return false;

    const blocked = <String>[
      'ability',
      'basic pokemon',
      'flip a coin',
      'pokemon power',
      'search your deck',
      'this attack',
      'weakness',
      'resistance',
      'retreat cost',
      'trainer',
      'supporter',
      'stadium',
    ];
    if (blocked.any(normalized.contains)) return false;

    final meaningfulWords = normalized
        .split(' ')
        .where((word) => word.length > 1 && !_scanStopWords.contains(word))
        .toList();
    return meaningfulWords.isNotEmpty;
  }

  static List<String> _extractSpatialNameCandidates(List<ScanLineHint> lineHints) {
    final results = <String>[];
    final seen = <String>{};

    final topLines = lineHints
        .where((line) => line.topFraction <= 0.40 && _looksLikeCardNameLine(line.text))
        .toList()
      ..sort((a, b) {
        final topCompare = a.topFraction.compareTo(b.topFraction);
        if (topCompare != 0) return topCompare;
        return b.widthFraction.compareTo(a.widthFraction);
      });

    for (final line in topLines.take(6)) {
      final cleaned = line.text
          .replaceAll(RegExp(r'\b\d{2,4}\s*HP\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final key = _normalizeScanText(cleaned);
      if (cleaned.isEmpty || !seen.add(key)) continue;
      results.add(cleaned);
    }

    return results;
  }

  static List<String> _extractSpatialNumberCandidates(List<ScanLineHint> lineHints) {
    final results = <String>[];
    final seen = <String>{};

    final bottomLines = lineHints
        .where((line) => line.topFraction >= 0.58)
        .toList()
      ..sort((a, b) {
        final topCompare = b.topFraction.compareTo(a.topFraction);
        if (topCompare != 0) return topCompare;
        return a.leftFraction.compareTo(b.leftFraction);
      });

    for (final line in bottomLines.take(8)) {
      final text = line.text;

      final slashMatches = RegExp(
        r'\b([A-Za-z]{0,5}[\s-]*[0-9OQDSIBLZG]{1,4}[A-Za-z]?)\s*/\s*[0-9OQDSIBLZG]{1,4}\b',
        caseSensitive: false,
      ).allMatches(text);
      for (final match in slashMatches) {
        _appendCardNumberHint(results, seen, match.group(1) ?? '');
      }

      final prefixedMatches = RegExp(
        r'\b(?:TG|GG|SWSH|SVP|SM|XY|BW|SV|PROMO)[\s-]*[0-9OQDSIBLZG]{1,4}[A-Za-z]?\b',
        caseSensitive: false,
      ).allMatches(text);
      for (final match in prefixedMatches) {
        _appendCardNumberHint(results, seen, match.group(0) ?? '');
      }
    }

    return results;
  }

  static List<String> _extractSpatialSetCandidates(List<ScanLineHint> lineHints) {
    final results = <String>[];
    final seen = <String>{};

    final candidateLines = lineHints
        .where((line) => line.topFraction >= 0.42 && line.topFraction <= 0.95)
        .toList()
      ..sort((a, b) {
        final widthCompare = b.widthFraction.compareTo(a.widthFraction);
        if (widthCompare != 0) return widthCompare;
        return b.topFraction.compareTo(a.topFraction);
      });

    for (final line in candidateLines.take(10)) {
      final cleaned = line.text
          .replaceAll(RegExp(r'[^A-Za-z0-9\s-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final normalized = _normalizeScanText(cleaned);
      if (cleaned.length < 4 || cleaned.length > 28) continue;
      if (normalized.contains('pokemon') || normalized.contains('trainer')) continue;
      if (normalized.contains('weakness') || normalized.contains('resistance')) continue;
      if (normalized.split(' ').where((word) => word.length > 2 && !_scanStopWords.contains(word)).isEmpty) {
        continue;
      }
      if (seen.add(normalized)) {
        results.add(cleaned);
      }
      if (results.length >= 6) break;
    }

    return results;
  }

  static Future<List<TcgSet>> _findLikelySets({
    required List<String> setCandidates,
    required List<String> candidateNames,
    required List<String> phraseCandidates,
    required String normalizedText,
    required String normalizedOcrText,
  }) async {
    final setById = <String, TcgSet>{};

    for (final candidate in <String>[
      ...setCandidates,
      ...phraseCandidates,
      ...candidateNames,
    ].take(10)) {
      try {
        final sets = await _searchSetsForScanCandidate(candidate);
        for (final set in sets) {
          setById.putIfAbsent(set.id, () => set);
        }
      } catch (_) {}
      if (setById.length >= 12) {
        break;
      }
    }

    final sets = setById.values.toList()
      ..sort((a, b) {
        final scoreA = _scoreScannedSet(
          set: a,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          setCandidates: setCandidates,
        );
        final scoreB = _scoreScannedSet(
          set: b,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          setCandidates: setCandidates,
        );
        return scoreB.compareTo(scoreA);
      });

    return sets.take(3).toList();
  }

  static Future<List<TcgSet>> _searchSetsForScanCandidate(String candidate) async {
    final normalizedCandidate = _buildScanQuery(candidate);
    if (normalizedCandidate.isEmpty) return const <TcgSet>[];

    final terms = normalizedCandidate.split(' ').where((term) => term.isNotEmpty).toList();
    if (terms.isEmpty) return const <TcgSet>[];

    final query = terms.map((term) => 'name:*$term*').join(' AND ');
    final uri = Uri.https('api.pokemontcg.io', '/v2/sets', {
      'q': query,
      'pageSize': '8',
      'orderBy': '-releaseDate',
    });

    final data = await _getJsonMapWithDiskCache(uri);
    final items = (data['data'] as List<dynamic>? ?? const []);
    return items.map((item) => TcgSet.fromJson(item as Map<String, dynamic>)).toList();
  }

  static Future<List<TcgCard>> _topCardsFromLikelySet({
    required String setId,
    required String normalizedText,
    required String normalizedOcrText,
    required List<String> candidateNames,
    required List<String> candidateNumbers,
    required List<String> phraseCandidates,
    required List<String> setCandidates,
    required Set<String> likelySetIds,
  }) async {
    final cards = await fetchCardsBySet(setId);
    final scored = cards
        .map((card) => MapEntry(
              card,
              _scoreScannedCard(
                card: card,
                normalizedText: normalizedText,
                normalizedOcrText: normalizedOcrText,
                candidateNames: candidateNames,
                candidateNumbers: candidateNumbers,
                phraseCandidates: phraseCandidates,
                setCandidates: setCandidates,
                likelySetIds: likelySetIds,
              ),
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final threshold = candidateNumbers.isNotEmpty ? 120 : 150;
    final filtered = scored.where((entry) => entry.value >= threshold).take(8).map((entry) => entry.key).toList();

    if (filtered.isNotEmpty) {
      return filtered;
    }

    return scored.take(4).map((entry) => entry.key).toList();
  }

  static Future<List<TcgCard>> _fetchCardsBySetAndNumber(String setId, String numberHint) async {
    final cleaned = _normalizeCardNumberHint(numberHint);
    if (cleaned.isEmpty) return const <TcgCard>[];

    final variants = <String>{cleaned};
    final plainDigitsMatch = RegExp(r'^0*(\d+[A-Z]?)$').firstMatch(cleaned);
    if (plainDigitsMatch != null) {
      variants.add(plainDigitsMatch.group(1)!);
    }

    final cardsById = <String, TcgCard>{};
    for (final variant in variants.take(4)) {
      final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
        'q': 'set.id:$setId AND number:$variant',
        'pageSize': '40',
      });

      final data = await _getJsonMapWithDiskCache(uri);
      final items = (data['data'] as List<dynamic>? ?? const []);
      for (final item in items) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }
    }

    return cardsById.values.toList();
  }

  static Future<List<TcgCard>> _searchCardsForExactNameCandidate(
    String candidate, {
    String? setId,
    String? numberHint,
  }) async {
    final normalizedCandidate = _buildScanQuery(candidate);
    if (normalizedCandidate.isEmpty) return const <TcgCard>[];

    final escaped = normalizedCandidate.replaceAll('"', '');
    final queryParts = <String>['name:"$escaped"'];
    if (setId != null && setId.trim().isNotEmpty) {
      queryParts.add('set.id:$setId');
    }
    if (numberHint != null && numberHint.trim().isNotEmpty) {
      queryParts.add('number:${_normalizeCardNumberHint(numberHint)}');
    }

    final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
      'q': queryParts.join(' AND '),
      'pageSize': '30',
      'orderBy': 'set.releaseDate,name',
    });

    final data = await _getJsonMapWithDiskCache(uri);
    final items = (data['data'] as List<dynamic>? ?? const []);
    return items.map((item) => TcgCard.fromJson(item as Map<String, dynamic>)).toList();
  }

  static Future<List<TcgCard>> _searchCardsByNumberHint(String numberHint) async {
    final cleaned = _normalizeCardNumberHint(numberHint);
    if (cleaned.isEmpty) return const <TcgCard>[];

    final variants = <String>{cleaned};
    final plainDigitsMatch = RegExp(r'^0*(\d+[A-Z]?)$').firstMatch(cleaned);
    if (plainDigitsMatch != null) {
      variants.add(plainDigitsMatch.group(1)!);
    }

    final prefixedMatch = RegExp(r'^([A-Z]+)0*(\d+[A-Z]?)$').firstMatch(cleaned);
    if (prefixedMatch != null) {
      variants.add('${prefixedMatch.group(1)}${prefixedMatch.group(2)}');
    }

    final cardsById = <String, TcgCard>{};

    for (final variant in variants.take(4)) {
      final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
        'q': 'number:$variant',
        'pageSize': '120',
      });

      final data = await _getJsonMapWithDiskCache(uri);
      final items = (data['data'] as List<dynamic>? ?? const []);
      for (final item in items) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }
    }

    return cardsById.values.toList();
  }

  static Future<List<TcgCard>> _searchCardsForScanCandidate(
    String candidate, {
    String? numberHint,
  }) async {
    final normalizedCandidate = _buildScanQuery(candidate);
    if (normalizedCandidate.isEmpty) return const <TcgCard>[];

    final terms = normalizedCandidate
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const <TcgCard>[];

    final nameClause = terms
        .map((term) => '(name:*$term* OR set.name:*$term*)')
        .join(' AND ');

    final queryParts = <String>[nameClause];
    if (numberHint != null && numberHint.trim().isNotEmpty) {
      queryParts.add('number:${_normalizeCardNumberHint(numberHint.trim())}');
    }

    final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
      'q': queryParts.join(' AND '),
      'pageSize': '50',
      'orderBy': 'set.releaseDate,name',
    });

    final data = await _getJsonMapWithDiskCache(uri);
    final items = (data['data'] as List<dynamic>? ?? const []);
    return items.map((item) => TcgCard.fromJson(item as Map<String, dynamic>)).toList();
  }

  static void _appendCardNumberHint(
    List<String> results,
    Set<String> seen,
    String rawValue,
  ) {
    final cleaned = _normalizeCardNumberHint(rawValue);
    if (cleaned.isEmpty) return;

    final variants = <String>{cleaned};
    final plainDigits = RegExp(r'^0*(\d+[A-Z]?)$').firstMatch(cleaned)?.group(1);
    if (plainDigits != null && plainDigits.isNotEmpty) {
      variants.add(plainDigits);
    }

    final prefixed = RegExp(r'^([A-Z]+)0*(\d+[A-Z]?)$').firstMatch(cleaned);
    if (prefixed != null) {
      variants.add('${prefixed.group(1)}${prefixed.group(2)}');
    }

    for (final variant in variants) {
      if (seen.add(variant)) {
        results.add(variant);
      }
    }
  }

  static const Set<String> _scanStopWords = <String>{
    'a',
    'an',
    'and',
    'attack',
    'basic',
    'bench',
    'card',
    'choose',
    'coin',
    'damage',
    'discard',
    'during',
    'energy',
    'evolves',
    'flip',
    'from',
    'hand',
    'has',
    'hp',
    'if',
    'in',
    'of',
    'on',
    'opponent',
    'pokemon',
    'power',
    'put',
    'retreat',
    'rule',
    'search',
    'stage',
    'switch',
    'take',
    'the',
    'this',
    'to',
    'trainer',
    'turn',
    'weakness',
    'your',
  };

  static String _normalizeScanText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeOcrTextForMatching(String value) {
    return _normalizeScanText(value)
        .replaceAll('0', 'o')
        .replaceAll('1', 'l')
        .replaceAll('5', 's')
        .replaceAll('8', 'b');
  }

  static String _normalizeOcrWord(String value) {
    return _normalizeOcrTextForMatching(value).replaceAll(' ', '');
  }

  static String _normalizeCardNumberHint(String value) {
    final upper = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (upper.isEmpty) return '';

    final chars = upper.split('');
    for (var i = 0; i < chars.length; i++) {
      final previous = i > 0 ? chars[i - 1] : '';
      final next = i + 1 < chars.length ? chars[i + 1] : '';
      final nearDigit = RegExp(r'\d').hasMatch(previous) || RegExp(r'\d').hasMatch(next);
      switch (chars[i]) {
        case 'O':
        case 'Q':
        case 'D':
          if (nearDigit) chars[i] = '0';
          break;
        case 'I':
        case 'L':
          if (nearDigit) chars[i] = '1';
          break;
        case 'Z':
          if (nearDigit) chars[i] = '2';
          break;
        case 'S':
          if (nearDigit) chars[i] = '5';
          break;
        case 'B':
          if (nearDigit) chars[i] = '8';
          break;
        case 'G':
          if (nearDigit) chars[i] = '6';
          break;
      }
    }
    return chars.join();
  }

  static List<String> _extractScanNameCandidates(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final results = <String>[];
    final seen = <String>{};

    for (var line in lines) {
      line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      line = line.replaceAll(RegExp(r'\b\d{2,4}\s*HP\b', caseSensitive: false), '').trim();

      if (!_looksLikeCardNameLine(line)) continue;

      final normalized = _normalizeScanText(line);
      if (seen.add(normalized)) {
        results.add(line);
      }

      if (results.length >= 8) break;
    }

    return results;
  }

  static List<String> _extractScanSetCandidates(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final results = <String>[];
    final seen = <String>{};

    for (var line in lines) {
      line = line
          .replaceAll(RegExp(r'[^A-Za-z0-9\s-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (line.length < 4 || line.length > 28) continue;
      final normalized = _normalizeScanText(line);
      if (normalized.contains('pokemon') || normalized.contains('weakness')) continue;
      if (normalized.split(' ').where((word) => word.length > 2 && !_scanStopWords.contains(word)).isEmpty) continue;
      if (seen.add(normalized)) {
        results.add(line);
      }
      if (results.length >= 6) break;
    }

    return results;
  }

  static List<String> _extractScanNumberCandidates(String text) {
    final results = <String>[];
    final seen = <String>{};

    final slashMatches = RegExp(
      r'\b([A-Za-z]{0,5}[\s-]*[0-9OQDSIBLZG]{1,4}[A-Za-z]?)\s*/\s*[0-9OQDSIBLZG]{1,4}\b',
      caseSensitive: false,
    ).allMatches(text);

    for (final match in slashMatches) {
      _appendCardNumberHint(results, seen, match.group(1) ?? '');
    }

    final prefixedMatches = RegExp(
      r'\b(?:TG|GG|SWSH|SVP|SM|XY|BW|SV|PROMO)[\s-]*[0-9OQDSIBLZG]{1,4}[A-Za-z]?\b',
      caseSensitive: false,
    ).allMatches(text);

    for (final match in prefixedMatches) {
      _appendCardNumberHint(results, seen, match.group(0) ?? '');
    }

    return results;
  }

  static List<String> _extractScanPhraseCandidates(String text) {
    final results = <String>[];
    final seen = <String>{};

    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(10)
        .toList();

    for (var line in lines) {
      line = line
          .replaceAll(RegExp(r'\b\d{2,4}\s*HP\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9\s-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (line.isEmpty) continue;

      final words = _normalizeScanText(line)
          .split(' ')
          .where((word) => word.length > 2 && !_scanStopWords.contains(word))
          .toList();

      if (words.isEmpty) continue;

      for (final length in const [3, 2, 1]) {
        if (words.length < length) continue;
        for (var index = 0; index <= words.length - length; index++) {
          final phrase = words.sublist(index, index + length).join(' ');
          if (phrase.length < 3) continue;
          if (seen.add(phrase)) {
            results.add(phrase);
          }
          if (results.length >= 16) {
            return results;
          }
        }
      }
    }

    return results;
  }

  static String _buildScanQuery(String candidate) {
    final normalized = _normalizeScanText(candidate);
    if (normalized.isEmpty) return '';

    final filtered = normalized
        .split(' ')
        .where((word) => word.length > 1 && !_scanStopWords.contains(word))
        .take(5)
        .join(' ');

    return filtered;
  }

  static int _scoreScannedSet({
    required TcgSet set,
    required String normalizedText,
    required String normalizedOcrText,
    required List<String> setCandidates,
  }) {
    var score = 0;
    final normalizedSetName = _normalizeScanText(set.name);
    final fuzzySetName = _normalizeOcrTextForMatching(set.name);

    if (normalizedText.contains(normalizedSetName)) {
      score += 180;
    }
    if (normalizedOcrText.contains(fuzzySetName)) {
      score += 180;
    }

    for (final candidate in setCandidates.take(8)) {
      final normalizedCandidate = _normalizeScanText(candidate);
      final fuzzyCandidate = _normalizeOcrTextForMatching(candidate);
      if (normalizedCandidate.isEmpty) continue;
      if (normalizedCandidate == normalizedSetName || fuzzyCandidate == fuzzySetName) {
        score += 160;
        continue;
      }
      final similarity = _stringSimilarity(fuzzyCandidate, fuzzySetName);
      if (similarity >= 0.90) {
        score += 120;
      } else if (similarity >= 0.82) {
        score += 72;
      } else if (similarity >= 0.72) {
        score += 32;
      }
    }

    return score;
  }

  static int _scoreScannedCard({
    required TcgCard card,
    required String normalizedText,
    required String normalizedOcrText,
    required List<String> candidateNames,
    required List<String> candidateNumbers,
    required List<String> phraseCandidates,
    required List<String> setCandidates,
    required Set<String> likelySetIds,
  }) {
    var score = 0;
    final cardName = _normalizeScanText(card.name);
    final fuzzyCardName = _normalizeOcrTextForMatching(card.name);
    final setName = _normalizeScanText(card.setName);
    final fuzzySetName = _normalizeOcrTextForMatching(card.setName);
    final cardNumber = _normalizeCardNumberHint(card.number);

    if (normalizedText.contains(cardName)) {
      score += 210;
    }
    if (normalizedOcrText.contains(fuzzyCardName)) {
      score += 210;
    }
    if (normalizedText.contains(setName) || normalizedOcrText.contains(fuzzySetName)) {
      score += 44;
    }
    if (likelySetIds.contains(card.setId)) {
      score += 90;
    }
    if (candidateNumbers.any((candidate) => candidate == cardNumber)) {
      score += 260;
    } else if (candidateNumbers.isNotEmpty) {
      score -= 28;
    }

    final cardNameWords = cardName.split(' ').where((word) => word.length > 2).toList();
    score += _tokenCoverageScore(cardNameWords, normalizedText, normalizedOcrText);

    final setNameWords = setName
        .split(' ')
        .where((word) => word.length > 2 && !_scanStopWords.contains(word))
        .toList();
    score += (_tokenCoverageScore(setNameWords, normalizedText, normalizedOcrText) * 0.30).round();

    for (final candidate in setCandidates.take(6)) {
      final similarity = _stringSimilarity(
        _normalizeOcrTextForMatching(candidate),
        fuzzySetName,
      );
      if (similarity >= 0.90) {
        score += 85;
      } else if (similarity >= 0.80) {
        score += 42;
      }
    }

    for (final candidate in <String>[
      ...candidateNames,
      ...phraseCandidates,
    ].take(16)) {
      final normalizedCandidate = _normalizeScanText(candidate);
      final fuzzyCandidate = _normalizeOcrTextForMatching(candidate);
      if (normalizedCandidate.isEmpty || fuzzyCandidate.isEmpty) continue;

      if (normalizedCandidate == cardName || fuzzyCandidate == fuzzyCardName) {
        score += 200;
        continue;
      }

      if (cardName.startsWith(normalizedCandidate) || fuzzyCardName.startsWith(fuzzyCandidate)) {
        score += 130;
        continue;
      }

      if (cardName.contains(normalizedCandidate) || normalizedCandidate.contains(cardName)) {
        score += 100;
      }

      final similarity = _stringSimilarity(fuzzyCandidate, fuzzyCardName);
      if (similarity >= 0.93) {
        score += 170;
      } else if (similarity >= 0.86) {
        score += 120;
      } else if (similarity >= 0.78) {
        score += 72;
      } else if (similarity >= 0.68) {
        score += 28;
      }
    }

    if (card.hp != null && normalizedText.contains(card.hp!.toLowerCase())) {
      score += 16;
    }
    if (card.rarity != null && normalizedText.contains(_normalizeScanText(card.rarity!))) {
      score += 8;
    }

    return score;
  }

  static int _tokenCoverageScore(
    List<String> words,
    String normalizedText,
    String normalizedOcrText,
  ) {
    if (words.isEmpty) return 0;

    var hits = 0;
    for (final word in words) {
      final cleanWord = _normalizeScanText(word);
      final ocrWord = _normalizeOcrWord(word);
      if (cleanWord.isEmpty) continue;
      if (normalizedText.contains(cleanWord) || normalizedOcrText.contains(ocrWord)) {
        hits++;
      }
    }

    return ((hits / words.length) * 100).round();
  }

  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final substitutionCost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(
            current[j - 1] + 1,
            previous[j] + 1,
          ),
          previous[j - 1] + substitutionCost,
        );
      }
      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }

  static double _stringSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final distance = _levenshteinDistance(a, b);
    return 1 - (distance / math.max(a.length, b.length));
  }

  static Future<List<TcgSet>> fetchSets({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedSets = _allSetsCache;
      if (cachedSets != null) {
        return List<TcgSet>.from(cachedSets);
      }

      final inFlightRequest = _allSetsInFlight;
      if (inFlightRequest != null) {
        final sets = await inFlightRequest;
        return List<TcgSet>.from(sets);
      }
    }

    final request = _fetchAllSetsFromApi();

    if (!forceRefresh) {
      _allSetsInFlight = request;
    }

    try {
      final sets = await request;
      _allSetsCache = List<TcgSet>.from(sets);
      return List<TcgSet>.from(sets);
    } finally {
      if (!forceRefresh) {
        _allSetsInFlight = null;
      }
    }
  }

  static Future<void> warmSetSearchCache() async {
    try {
      await fetchSets();
    } catch (_) {
      // Ignore preloading errors. The normal search error UI will handle it later.
    }
  }

  static bool hasCachedCardsForSet(String setId) {
    return _setCardsCache.containsKey(setId);
  }

  static Future<void> warmCardsBySetCache(String setId) async {
    if (setId.trim().isEmpty || hasCachedCardsForSet(setId)) return;

    try {
      await fetchCardsBySet(setId);
    } catch (_) {
      // Ignore warm-up errors. The normal set page error UI will handle failures.
    }
  }

  static Future<List<TcgSet>> _fetchAllSetsFromApi() async {
    final allSets = <TcgSet>[];
    int page = 1;

    while (true) {
      final uri = Uri.parse(
        '$_baseUrl/sets?pageSize=250&page=$page&orderBy=-releaseDate',
      );
      final data = await _getJsonMapWithDiskCache(uri);
      final items = (data['data'] as List<dynamic>? ?? []);

      if (items.isEmpty) {
        break;
      }

      allSets.addAll(
        items.map((item) => TcgSet.fromJson(item as Map<String, dynamic>)),
      );

      if (items.length < 250) {
        break;
      }

      page++;
    }

    return allSets;
  }

  static Future<List<TcgCard>> fetchCardsBySet(String setId) async {
    final cachedCards = _setCardsCache[setId];
    if (cachedCards != null) {
      return List<TcgCard>.from(cachedCards);
    }

    final inFlightRequest = _setCardsInFlight[setId];
    if (inFlightRequest != null) {
      final cards = await inFlightRequest;
      return List<TcgCard>.from(cards);
    }

    final request = _fetchAndCacheCardsBySet(setId);
    _setCardsInFlight[setId] = request;

    try {
      final cards = await request;
      return List<TcgCard>.from(cards);
    } finally {
      _setCardsInFlight.remove(setId);
    }
  }

  static Future<List<TcgCard>> _fetchAndCacheCardsBySet(String setId) async {
    final cardsByKey = <String, TcgCard>{};

    final setRequest = _fetchSetById(setId);
    final primaryCardsRequest = _fetchCardsForSetQuery(
      'set.id:$setId',
      orderBy: 'number',
      maxPages: 4,
    );

    void addCards(Iterable<TcgCard> cards) {
      for (final card in cards) {
        if (card.id.trim().isEmpty && card.number.trim().isEmpty) continue;
        final key = card.id.trim().isNotEmpty ? card.id.trim() : _buildSetCardDedupKey(card);
        final existing = cardsByKey[key];
        if (existing == null || _preferCardForSetView(card, existing)) {
          cardsByKey[key] = card;
        }
      }
    }

    // Fast first pass: official set id. This is normally enough for the full set,
    // including illustration rares, ultra rares, and secret rares. Run it in
    // parallel with the set metadata request so the page opens sooner.
    final set = await setRequest;
    addCards(await primaryCardsRequest);

    final expectedTotal = set?.total ?? 0;
    final setNameFromApi = set?.name.trim() ?? '';
    final setNameFromCards = cardsByKey.values
        .map((card) => card.setName.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    final setName = setNameFromApi.isNotEmpty ? setNameFromApi : setNameFromCards;

    // Only do the slower exact-name fallback if the set id result looks incomplete.
    // This keeps Master Sets fast while still rescuing special cards when needed.
    final needsFallbackByName =
        setName.isNotEmpty && (expectedTotal <= 0 || cardsByKey.length < expectedTotal);

    if (needsFallbackByName) {
      addCards(
        (await _fetchCardsForSetQuery(
          'set.name:"${_escapeTcgQueryValue(setName)}"',
          orderBy: 'number',
          maxPages: 4,
        )).where(
          (card) => _cardBelongsToRequestedSet(
            card: card,
            setId: setId,
            setName: setName,
          ),
        ),
      );
    }

    // Rare fallback is now deliberately small and only runs when the set still
    // looks incomplete. The previous version checked too many rarity searches and
    // made Master Sets feel slow.
    if (setName.isNotEmpty && expectedTotal > 0 && cardsByKey.length < expectedTotal) {
      final remainingGap = expectedTotal - cardsByKey.length;
      if (remainingGap <= 120) {
        final rarityCards = await Future.wait(
          _fastMasterSetRarityQueries.map(
            (rarityQuery) => _fetchCardsForSetQuery(
              'set.name:"${_escapeTcgQueryValue(setName)}" $rarityQuery',
              orderBy: 'number',
              maxPages: 2,
            ),
          ),
        );

        for (final batch in rarityCards) {
          addCards(
            batch.where(
              (card) => _cardBelongsToRequestedSet(
                card: card,
                setId: setId,
                setName: setName,
              ),
            ),
          );
        }
      }
    }

    // Final rescue: only fill a small number of missing numbers. If a set is
    // missing dozens of cards, individual lookups are too slow and usually means
    // the online database has not added those cards yet.
    await _fillMissingSetNumbers(
      cardsByKey: cardsByKey,
      setId: setId,
      setName: setName,
      expectedTotal: expectedTotal,
    );

    final allCards = cardsByKey.values.toList()
      ..sort((a, b) => compareCardNumbers(a.number, b.number));

    _setCardsCache[setId] = List<TcgCard>.from(allCards);
    return allCards;
  }

  static const List<String> _fastMasterSetRarityQueries = <String>[
    'rarity:"Illustration Rare"',
    'rarity:"Special Illustration Rare"',
    'rarity:"Ultra Rare"',
    'rarity:"Hyper Rare"',
    'rarity:"Rare Secret"',
    'rarity:"Secret Rare"',
  ];

  static Future<TcgSet?> _fetchSetById(String setId) async {
    final normalizedSetId = setId.trim();
    if (normalizedSetId.isEmpty) return null;

    final cached = _setByIdCache[normalizedSetId];
    if (cached != null) return cached;

    final inFlight = _setByIdInFlight[normalizedSetId];
    if (inFlight != null) return inFlight;

    final request = () async {
      final uri = Uri.https('api.pokemontcg.io', '/v2/sets/$normalizedSetId');
      Map<String, dynamic> data;
      try {
        data = await _getJsonMapWithDiskCache(uri);
      } catch (_) {
        return null;
      }

      final set = TcgSet.fromJson(data['data'] as Map<String, dynamic>);
      _setByIdCache[normalizedSetId] = set;
      return set;
    }();

    _setByIdInFlight[normalizedSetId] = request;
    try {
      return await request;
    } finally {
      _setByIdInFlight.remove(normalizedSetId);
    }
  }

  static Future<String?> resolveSetLogoUrl({
    required String setId,
    required String setName,
    String? fallbackLogoUrl,
  }) async {
    final normalizedSetId = setId.trim();
    final fallback = fallbackLogoUrl?.trim();

    if (normalizedSetId.isEmpty) {
      return (fallback != null && fallback.isNotEmpty) ? fallback : null;
    }

    final set = await _fetchSetById(normalizedSetId);
    final resolved = set?.logoUrl?.trim();
    final resolvedSetName = (set?.name.trim().isNotEmpty ?? false) ? set!.name.trim() : setName.trim();

    final isGenericPromoLogo = _isGenericPromoLogoForSet(
      setId: normalizedSetId,
      setName: resolvedSetName,
      logoUrl: resolved ?? fallback,
    );

    if (isGenericPromoLogo) {
      final originalLogo = await _resolveOriginalLogoForPromoSet(
        setId: normalizedSetId,
        setName: resolvedSetName,
      );

      if (originalLogo != null && originalLogo.trim().isNotEmpty) {
        return originalLogo.trim();
      }

      // Do not return the generic PROMO / Black Star badge if we could not
      // resolve a proper base-set logo. The UI will show a plain text fallback
      // instead of the wrong promo sign.
      return null;
    }

    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }

    return (fallback != null && fallback.isNotEmpty) ? fallback : null;
  }

  static bool _isGenericPromoLogoForSet({
    required String setId,
    required String setName,
    String? logoUrl,
  }) {
    final id = setId.toLowerCase().trim();
    final name = setName.toLowerCase().trim();
    final url = logoUrl?.toLowerCase().trim() ?? '';

    return name.contains('promo') ||
        name.contains('black star') ||
        id.endsWith('p') ||
        id.contains('promo') ||
        id.startsWith('svp') ||
        id.startsWith('swshp') ||
        id.startsWith('smp') ||
        id.startsWith('xyp') ||
        id.startsWith('bwp') ||
        id.startsWith('dpp') ||
        url.contains('/promo') ||
        url.contains('promo') ||
        url.contains('blackstar') ||
        url.contains('black-star');
  }

  static String? _knownOriginalSetIdForPromoSet({
    required String setId,
    required String setName,
  }) {
    final id = setId.toLowerCase().trim();
    final name = setName.toLowerCase().trim();

    // These promo sets use generic Black Star / Promo artwork in the API.
    // For the Master Sets page, show the matching original era/base-set logo.
    if (id.startsWith('svp') || name.contains('scarlet') && name.contains('violet')) {
      return 'sv1';
    }
    if (id.startsWith('swshp') || name.contains('sword') && name.contains('shield')) {
      return 'swsh1';
    }
    if (id.startsWith('smp') || name.contains('sun') && name.contains('moon')) {
      return 'sm1';
    }
    if (id.startsWith('xyp') || RegExp(r'\bxy\b').hasMatch(name)) {
      return 'xy1';
    }
    if (id.startsWith('bwp') || name.contains('black') && name.contains('white')) {
      return 'bw1';
    }
    if (id.startsWith('dpp') || name.contains('diamond') && name.contains('pearl')) {
      return 'dp1';
    }

    return null;
  }

  static String _baseSetNameFromPromoSetName(String setName) {
    return setName
        .replaceAll('&', ' ')
        .replaceAll(RegExp(r'\bblack\s+star\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bpromos?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bpromo\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<String?> _resolveOriginalLogoForPromoSet({
    required String setId,
    required String setName,
  }) async {
    final knownBaseSetId = _knownOriginalSetIdForPromoSet(
      setId: setId,
      setName: setName,
    );

    if (knownBaseSetId != null) {
      final knownBaseSet = await _fetchSetById(knownBaseSetId);
      final knownLogo = knownBaseSet?.logoUrl?.trim();
      if (knownLogo != null && knownLogo.isNotEmpty) {
        return knownLogo;
      }
    }

    final baseSetName = _baseSetNameFromPromoSetName(setName);
    if (baseSetName.isEmpty || baseSetName.toLowerCase() == setName.toLowerCase()) {
      return null;
    }

    final searchNames = <String>[
      baseSetName,
      setName
          .replaceAll(RegExp(r'\bblack\s+star\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\bpromos?\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\bpromo\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    ]
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim())
        .toSet()
        .toList();

    final candidatesById = <String, TcgSet>{};
    for (final searchName in searchNames) {
      try {
        final results = await searchSetsOnly(searchName);
        for (final set in results) {
          candidatesById.putIfAbsent(set.id, () => set);
        }
      } catch (_) {
        // Keep trying any other search names.
      }
    }

    final candidates = candidatesById.values.toList();
    if (candidates.isEmpty) return null;

    final baseNormalized = _normalizeSearchMatchText(baseSetName);

    bool isGoodCandidate(TcgSet candidate) {
      final candidateLogo = candidate.logoUrl?.trim();
      if (candidateLogo == null || candidateLogo.isEmpty) return false;
      if (candidate.id.toLowerCase() == setId.toLowerCase()) return false;

      return !_isGenericPromoLogoForSet(
        setId: candidate.id,
        setName: candidate.name,
        logoUrl: candidate.logoUrl,
      );
    }

    TcgSet? exactMatch;
    for (final candidate in candidates) {
      if (!isGoodCandidate(candidate)) continue;
      if (_normalizeSearchMatchText(candidate.name) == baseNormalized) {
        exactMatch = candidate;
        break;
      }
    }

    if (exactMatch != null) return exactMatch.logoUrl;

    TcgSet? containsMatch;
    for (final candidate in candidates) {
      if (!isGoodCandidate(candidate)) continue;
      final candidateName = _normalizeSearchMatchText(candidate.name);
      if (candidateName.startsWith(baseNormalized) ||
          candidateName.contains(baseNormalized) ||
          baseNormalized.contains(candidateName)) {
        containsMatch = candidate;
        break;
      }
    }

    if (containsMatch != null) return containsMatch.logoUrl;

    for (final candidate in candidates) {
      if (isGoodCandidate(candidate)) {
        return candidate.logoUrl;
      }
    }

    return null;
  }


  static Future<List<TcgCard>> _fetchCardsForSetQuery(
    String query, {
    String orderBy = 'number',
    int maxPages = 4,
  }) async {
    const pageSize = 250;
    final cardsById = <String, TcgCard>{};
    var page = 1;

    while (true) {
      final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
        'q': query,
        'pageSize': '$pageSize',
        'page': '$page',
        'orderBy': orderBy,
      });

      final data = await _getJsonMapWithDiskCache(uri);
      final items = (data['data'] as List<dynamic>? ?? const []);
      if (items.isEmpty) break;

      for (final item in items) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }

      if (items.length < pageSize || page >= maxPages) {
        break;
      }

      page++;
    }

    return cardsById.values.toList();
  }

  static bool _cardBelongsToRequestedSet({
    required TcgCard card,
    required String setId,
    required String setName,
  }) {
    if (card.setId.trim() == setId.trim()) return true;

    final requested = _normalizeSetNameForFullSetSearch(setName);
    final actual = _normalizeSetNameForFullSetSearch(card.setName);
    if (requested.isEmpty || actual.isEmpty) return false;

    return actual == requested;
  }

  static String _normalizeSetNameForFullSetSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _firstCardNumberAsInt(String value) {
    final match = RegExp(r'^0*(\d+)').firstMatch(value.trim());
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  static Future<void> _fillMissingSetNumbers({
    required Map<String, TcgCard> cardsByKey,
    required String setId,
    required String setName,
    required int expectedTotal,
  }) async {
    if (expectedTotal <= 0 || expectedTotal > 600) return;

    final existingNumbers = <int>{
      for (final card in cardsByKey.values)
        if (_cardBelongsToRequestedSet(card: card, setId: setId, setName: setName))
          _firstCardNumberAsInt(card.number),
    }..remove(0);

    final missingNumbers = <int>[
      for (var number = 1; number <= expectedTotal; number++)
        if (!existingNumbers.contains(number)) number,
    ];

    if (missingNumbers.isEmpty) return;

    // Keep this small for speed. Large gaps are usually because the public card
    // database has not added the newest cards yet, and checking every number
    // individually makes the page very slow.
    final numbersToFetch = missingNumbers.take(18).toList();

    void addCards(Iterable<TcgCard> cards) {
      for (final card in cards) {
        if (!_cardBelongsToRequestedSet(card: card, setId: setId, setName: setName)) {
          continue;
        }

        final key = card.id.trim().isNotEmpty ? card.id.trim() : _buildSetCardDedupKey(card);
        final existing = cardsByKey[key];
        if (existing == null || _preferCardForSetView(card, existing)) {
          cardsByKey[key] = card;
        }
      }
    }

    final results = await Future.wait(
      numbersToFetch.map((number) => _fetchCardsForMissingSetNumber(
            setId: setId,
            setName: setName,
            number: number,
          )),
    );

    for (final cards in results) {
      addCards(cards);
    }
  }

  static Future<List<TcgCard>> _fetchCardsForMissingSetNumber({
    required String setId,
    required String setName,
    required int number,
  }) async {
    final cardsById = <String, TcgCard>{};

    Future<void> fetch(String query) async {
      final cards = await _fetchCardsForSetQuery(
        query,
        orderBy: 'number',
        maxPages: 1,
      );
      for (final card in cards) {
        cardsById.putIfAbsent(card.id, () => card);
      }
    }

    await fetch('set.id:$setId AND number:$number');

    if (setName.trim().isNotEmpty) {
      await fetch('set.name:"${_escapeTcgQueryValue(setName)}" AND number:$number');
      await fetch('set.name:"${_escapeTcgQueryValue(setName)}" AND number:${number.toString().padLeft(3, '0')}');
    }

    return cardsById.values.toList();
  }

  static String _buildSetCardDedupKey(TcgCard card) {
    final normalizedName = card.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    final normalizedNumber = card.number
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '');

    return '${card.setId}__${normalizedNumber}__$normalizedName';
  }

  static bool _isSpecialMasterSetRarity(TcgCard card) {
    final rarity = (card.rarity ?? '').toLowerCase();
    return rarity.contains('illustration') ||
        rarity.contains('ultra') ||
        rarity.contains('secret') ||
        rarity.contains('hyper') ||
        rarity.contains('rainbow') ||
        rarity.contains('radiant') ||
        rarity.contains('amazing rare') ||
        rarity.contains('ace spec') ||
        rarity.contains('double rare') ||
        rarity.contains('rare holo v') ||
        rarity.contains('rare holo vmax') ||
        rarity.contains('rare holo vstar') ||
        rarity.contains('rare holo gx') ||
        rarity.contains('rare holo ex') ||
        rarity.contains('rare prime') ||
        rarity.contains('rare prism') ||
        rarity.contains('rare break');
  }

  static bool _preferCardForSetView(TcgCard candidate, TcgCard existing) {
    int score(TcgCard card) {
      var value = 0;
      if (card.largeImageUrl != null && card.largeImageUrl!.isNotEmpty) value += 4;
      if (card.imageUrl != null && card.imageUrl!.isNotEmpty) value += 2;
      if (card.rawPrice != null && card.rawPrice! > 0) value += 1;
      if ((card.rarity ?? '').trim().isNotEmpty) value += 1;
      if (_isSpecialMasterSetRarity(card)) value += 3;
      return value;
    }

    return score(candidate) > score(existing);
  }

  static Future<TcgCard> fetchCardById(String cardId) async {
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Missing card id');
    }

    final cached = _cardByIdCache[normalizedId];
    if (cached != null) {
      return cached;
    }

    final existingFuture = _cardByIdInFlight[normalizedId];
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = () async {
      final uri = Uri.parse('$_baseUrl/cards/$normalizedId');
      final data = await _getJsonMapWithDiskCache(uri);
      final card = TcgCard.fromJson(data['data'] as Map<String, dynamic>);
      _cardByIdCache[normalizedId] = card;
      return card;
    }();

    _cardByIdInFlight[normalizedId] = future;
    try {
      return await future;
    } finally {
      _cardByIdInFlight.remove(normalizedId);
    }
  }
}
