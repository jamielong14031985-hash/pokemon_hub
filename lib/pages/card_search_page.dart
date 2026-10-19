import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_search_result.dart';
import '../models/tcg_set.dart';
import '../pages/card_details_page.dart';
import '../pages/japanese_sets_page.dart';
import '../pages/sealed_product_price_page.dart';
import '../pages/first_partner_promo_cards_page.dart';
import '../services/pokemon_tcg_service.dart';
import '../widgets/card_search_result_card.dart';
import '../widgets/cards_search_placeholder.dart';
import '../widgets/set_search_result_card.dart';
import '../widgets/set_logo_widgets.dart';

const Duration _kCardSearchDebounce = Duration(milliseconds: 450);
const int _kMinimumSearchCharacters = 2;
const int _kMaximumRecentSearches = 8;
const Duration _kRecentSearchSaveDelay = Duration(milliseconds: 1500);

enum _CardSearchSection {
  cards,
  sets,
  sealed,
}

/// Special sealed-product releases are searchable alongside regular TCG sets,
/// but they open the user's sealed collection, not a card binder.
class _FirstPartnerSeriesSearchResult {
  const _FirstPartnerSeriesSearchResult(this.series, this.region);

  final int series;
  final String region;

  String get imagePath => 'assets/images/first_partner_series_$series.png';
  String get subtitle => 'Series $series — $region';
}

const List<_FirstPartnerSeriesSearchResult> _kFirstPartnerSeries = [
  _FirstPartnerSeriesSearchResult(1, 'Kanto'),
  _FirstPartnerSeriesSearchResult(2, 'Johto'),
  _FirstPartnerSeriesSearchResult(3, 'Hoenn'),
];

List<_FirstPartnerSeriesSearchResult> _firstPartnerSearchMatches(String query) {
  final normalized = query.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Start showing all three results when the user types "first". Support
  // longer variants such as "first partner series 2" and "first partner 2026".
  if (!normalized.startsWith('first')) return const [];
  // Never present the 2026 releases for a different requested year.
  if (RegExp(r'\b20\d{2}\b').allMatches(normalized)
      .any((m) => m.group(0) != '2026')) {
    return const [];
  }

  final match = RegExp(r'\bseries\s*([123])\b').firstMatch(normalized);
  if (match == null) return _kFirstPartnerSeries;
  final series = int.tryParse(match.group(1) ?? '');
  return _kFirstPartnerSeries.where((entry) => entry.series == series).toList();
}

class _CombinedSetSearchResult {
  const _CombinedSetSearchResult({
    this.englishSets = const <TcgSet>[],
    this.japaneseSets = const <JapaneseTcgSet>[],
    this.firstPartnerSeries = const <_FirstPartnerSeriesSearchResult>[],
    this.englishError,
    this.japaneseError,
  });

  final List<TcgSet> englishSets;
  final List<JapaneseTcgSet> japaneseSets;
  final List<_FirstPartnerSeriesSearchResult> firstPartnerSeries;
  final Object? englishError;
  final Object? japaneseError;

  int get totalCount =>
      englishSets.length + japaneseSets.length + firstPartnerSeries.length;
  bool get hasResults => totalCount > 0;
  bool get hasAnyError => englishError != null || japaneseError != null;
}

/// A resolved catalogue entry for a recent set search. Keep the original
/// search text separate so tapping a logo still repeats that exact query.
class _RecentSetLogoMatch {
  const _RecentSetLogoMatch.english(this.englishSet) : japaneseSet = null;
  const _RecentSetLogoMatch.japanese(this.japaneseSet) : englishSet = null;

  final TcgSet? englishSet;
  final JapaneseTcgSet? japaneseSet;
}

class CardSearchPage extends StatefulWidget {
  const CardSearchPage({super.key, this.selectForDeal = false});

  /// Same full search experience, but tapping a card returns it to Trade Builder.
  /// Normal card browsing is unchanged when this is false.
  final bool selectForDeal;

  @override
  State<CardSearchPage> createState() => CardSearchPageState();
}

class CardSearchPageState extends State<CardSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _searchDebounce;
  Timer? _recentSearchDebounce;
  List<String> _recentCardSearches = <String>[];
  List<String> _recentSetSearches = <String>[];
  // Resolved from the same set catalogues as the regular search results.
  // Never guess set-logo asset names or use unrelated search images.
  Map<String, _RecentSetLogoMatch> _recentSetLogos =
      <String, _RecentSetLogoMatch>{};
  List<TcgSet> _recentEnglishCatalogue = <TcgSet>[];
  List<JapaneseTcgSet> _recentJapaneseCatalogue = <JapaneseTcgSet>[];
  bool _recentCataloguesLoaded = false;
  bool _loadingRecentCatalogues = false;
  late Future<CardSearchResult> _futureCardResults;
  late Future<_CombinedSetSearchResult> _futureSetResults;

  _CardSearchSection _selectedSection = _CardSearchSection.cards;
  String _lastSearchKey = '';

  @override
  void initState() {
    super.initState();
    _futureCardResults = Future.value(const CardSearchResult());
    _futureSetResults = Future.value(const _CombinedSetSearchResult());
    unawaited(_loadRecentSearches());
    unawaited(PokemonTcgService.warmSetSearchCache());
    unawaited(JapaneseTcgDexService.fetchSets());
  }

  // Recent searches are local to this device and account. Card and set
  // searches have separate lists so the two tabs stay useful.
  String _recentKey(_CardSearchSection section) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'device';
    return 'pocketchase_recent_searches_v1_${uid}_${section.name}';
  }

  List<String> _recentFor(_CardSearchSection section) =>
      section == _CardSearchSection.cards
          ? _recentCardSearches
          : _recentSetSearches;

  void _setRecentFor(_CardSearchSection section, List<String> values) {
    if (section == _CardSearchSection.cards) {
      _recentCardSearches = values;
    } else if (section == _CardSearchSection.sets) {
      _recentSetSearches = values;
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cards = prefs.getStringList(_recentKey(_CardSearchSection.cards))
          ?? <String>[];
      final sets = prefs.getStringList(_recentKey(_CardSearchSection.sets))
          ?? <String>[];
      if (!mounted) return;
      setState(() {
        _recentCardSearches = cards.take(_kMaximumRecentSearches).toList();
        _recentSetSearches = sets.take(_kMaximumRecentSearches).toList();
      });
      if (sets.isNotEmpty) unawaited(_loadRecentSetCatalogues());
    } catch (_) {
      // A storage failure must never stop a normal card or set search.
    }
  }

  /// Loads catalogue metadata once, using the same caches as set search.
  /// Missing/offline logos simply fall back to the original text chips.
  Future<void> _loadRecentSetCatalogues() async {
    if (_recentCataloguesLoaded || _loadingRecentCatalogues) return;
    _loadingRecentCatalogues = true;
    try {
      final results = await Future.wait<Object>([
        PokemonTcgService.fetchSets()
            .then<Object>((sets) => sets)
            .catchError((_) => <TcgSet>[]),
        JapaneseTcgDexService.fetchSets()
            .then<Object>((sets) => sets)
            .catchError((_) => <JapaneseTcgSet>[]),
      ]);
      if (!mounted) return;
      _recentEnglishCatalogue = List<TcgSet>.from(results[0] as List);
      _recentJapaneseCatalogue = List<JapaneseTcgSet>.from(results[1] as List);
      // Retry next time if both sources were temporarily unavailable.
      _recentCataloguesLoaded = _recentEnglishCatalogue.isNotEmpty ||
          _recentJapaneseCatalogue.isNotEmpty;
      setState(_rebuildRecentSetLogoMatches);
    } catch (_) {
      // No logo should ever block searching.
    } finally {
      _loadingRecentCatalogues = false;
    }
  }

  static String _normaliseRecentSet(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static int _recentSetMatchScore({
    required String query,
    required String name,
    required String id,
  }) {
    final q = _normaliseRecentSet(query);
    final n = _normaliseRecentSet(name);
    final code = _normaliseRecentSet(id);
    if (q.length < 2 || n.isEmpty) return -1;
    if (const <String>{'english', 'japanese', 'sets', 'all sets'}
        .contains(q)) {
      return -1;
    }
    if (n == q) return 1100;
    if (code == q) return 1000;
    if (n.startsWith('$q ')) return 850 - (n.length - q.length);
    if (n.contains(' $q ') || n.endsWith(' $q')) {
      return 730 - (n.length - q.length);
    }
    if (n.contains(q)) return 650 - (n.length - q.length);
    // Multiword queries must match all words, in any order.
    final words = q.split(' ');
    if (words.length > 1 && words.every((word) => n.contains(word))) {
      return 500 - (n.length - q.length).abs();
    }
    return -1;
  }

  _RecentSetLogoMatch? _bestRecentSetLogo(String query) {
    var topScore = -1;
    _RecentSetLogoMatch? best;
    for (final set in _recentEnglishCatalogue) {
      final score = _recentSetMatchScore(
        query: query, name: set.name, id: set.id,
      );
      if (score > topScore) {
        topScore = score;
        best = _RecentSetLogoMatch.english(set);
      }
    }
    for (final set in _recentJapaneseCatalogue) {
      final score = _recentSetMatchScore(
        query: query, name: set.displayName, id: set.id,
      );
      if (score > topScore) {
        topScore = score;
        best = _RecentSetLogoMatch.japanese(set);
      }
    }
    return topScore >= 0 ? best : null;
  }

  void _rebuildRecentSetLogoMatches() {
    final matches = <String, _RecentSetLogoMatch>{};
    for (final query in _recentSetSearches) {
      final match = _bestRecentSetLogo(query);
      if (match != null) matches[query] = match;
    }
    _recentSetLogos = matches;
  }

  Future<void> _saveRecentList(
    _CardSearchSection section,
    List<String> searches,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey(section), searches);
    } catch (_) {
      // Search remains available if local storage is unavailable.
    }
  }

  Future<void> _rememberSearch(
    String value,
    _CardSearchSection section,
  ) async {
    if (!mounted || section == _CardSearchSection.sealed) return;
    final query = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.isEmpty || !_canSearch(query)) return;
    final searches = List<String>.from(_recentFor(section))
      ..removeWhere((saved) => saved.toLowerCase() == query.toLowerCase())
      ..insert(0, query);
    if (searches.length > _kMaximumRecentSearches) {
      searches.removeRange(_kMaximumRecentSearches, searches.length);
    }
    setState(() {
      _setRecentFor(section, searches);
      if (section == _CardSearchSection.sets) _rebuildRecentSetLogoMatches();
    });
    if (section == _CardSearchSection.sets) {
      unawaited(_loadRecentSetCatalogues());
    }
    await _saveRecentList(section, searches);
  }

  void _scheduleRecentSearch(String value) {
    _recentSearchDebounce?.cancel();
    final query = value.trim();
    if (!_canSearch(query) || query.isEmpty ||
        _selectedSection == _CardSearchSection.sealed) {
      return;
    }
    final section = _selectedSection;
    // Wait until the user stops typing to avoid saving partial words.
    _recentSearchDebounce = Timer(_kRecentSearchSaveDelay, () {
      if (!mounted || _selectedSection != section ||
          _controller.text.trim() != query) {
        return;
      }
      unawaited(_rememberSearch(query, section));
    });
  }

  void _useRecentSearch(String query) {
    _recentSearchDebounce?.cancel();
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _runSearchImmediately();
  }

  void _removeRecentSearch(String query) {
    final section = _selectedSection;
    if (section == _CardSearchSection.sealed) return;
    final remaining = _recentFor(section)
        .where((saved) => saved != query).toList();
    setState(() {
      _setRecentFor(section, remaining);
      if (section == _CardSearchSection.sets) _rebuildRecentSetLogoMatches();
    });
    unawaited(_saveRecentList(section, remaining));
  }

  void _clearRecentSearches() {
    final section = _selectedSection;
    if (section == _CardSearchSection.sealed) return;
    _recentSearchDebounce?.cancel();
    setState(() {
      _setRecentFor(section, <String>[]);
      if (section == _CardSearchSection.sets) _recentSetLogos.clear();
    });
    unawaited(_saveRecentList(section, <String>[]));
  }

  Widget _buildRecentSetLogoTile(
    String query,
    _RecentSetLogoMatch match,
  ) {
    return SizedBox(
      width: 104,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _useRecentSearch(query),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 8, 14, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _RecentSetLogoImage(match: match),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -2,
            right: 0,
            child: Material(
              color: const Color(0xCC17376E),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _removeRecentSearch(query),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: Color(0xFFF0F5FF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    final queries = _recentFor(_selectedSection);
    if (queries.isEmpty || _selectedSection == _CardSearchSection.sealed) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded,
                color: Color(0xFFF7DE77), size: 17),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Recent searches',
                style: TextStyle(
                  color: Color(0xFFD7E1F6),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: _clearRecentSearches,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(color: Color(0xFFF7DE77), fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _selectedSection == _CardSearchSection.sets ? 52 : 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: queries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final query = queries[index];
              final setLogo = _selectedSection == _CardSearchSection.sets
                  ? _recentSetLogos[query]
                  : null;
              if (setLogo != null) {
                return _buildRecentSetLogoTile(query, setLogo);
              }
              return Center(
                child: InputChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: const Color(0xFF17376E),
                side: const BorderSide(color: Color(0xFF47649A)),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                deleteIcon: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: Color(0xFFD2DBF0),
                ),
                onPressed: () => _useRecentSearch(query),
                onDeleted: () => _removeRecentSearch(query),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _canSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;

    final collectorNumberSearch =
        RegExp(r'^\s*[A-Za-z0-9]+\s*/\s*\d+\s*$').hasMatch(trimmed);

    return collectorNumberSearch || trimmed.length >= _kMinimumSearchCharacters;
  }

  Future<CardSearchResult> _buildCardSearchFuture(String query) {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty || !_canSearch(cleanQuery)) {
      return Future.value(const CardSearchResult());
    }

    return PokemonTcgService.searchCardsOnlyResult(cleanQuery);
  }

  Future<_CombinedSetSearchResult> _buildCombinedSetSearchFuture(
    String query,
  ) async {
    final cleanQuery = query.trim();
    final languageQuery = cleanQuery
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanQuery.isEmpty || !_canSearch(cleanQuery)) {
      return const _CombinedSetSearchResult();
    }

    // First Partner is a defined promo checklist within MEP Black Star Promos.
    // Present the three series locally without a slow catalogue round trip.
    final firstPartnerMatches = _firstPartnerSearchMatches(cleanQuery);
    if (firstPartnerMatches.isNotEmpty) {
      return _CombinedSetSearchResult(firstPartnerSeries: firstPartnerMatches);
    }

    final showAllEnglish = languageQuery == 'english' ||
        languageQuery == 'english set' ||
        languageQuery == 'english sets';
    final showAllJapanese = languageQuery == 'japanese' ||
        languageQuery == 'japanese set' ||
        languageQuery == 'japanese sets' ||
        languageQuery == 'japan';

    if (showAllEnglish) {
      return _CombinedSetSearchResult(
        englishSets: await PokemonTcgService.fetchSets(),
      );
    }

    if (showAllJapanese) {
      return _CombinedSetSearchResult(
        // Refresh here so an empty catalogue cached by an earlier app build
        // cannot make the explicit "Japanese" search appear empty.
        japaneseSets: await JapaneseTcgDexService.fetchSets(forceRefresh: true),
      );
    }

    var englishSets = <TcgSet>[];
    var japaneseSets = <JapaneseTcgSet>[];
    Object? englishError;
    Object? japaneseError;

    await Future.wait<void>([
      (() async {
        try {
          englishSets = await PokemonTcgService.searchSetsOnly(cleanQuery);
        } catch (error) {
          englishError = error;
        }
      })(),
      (() async {
        try {
          japaneseSets = await JapaneseTcgDexService.searchSetsForQuery(cleanQuery);
        } catch (error) {
          japaneseError = error;
        }
      })(),
    ]);

    if (englishSets.isEmpty && japaneseSets.isEmpty &&
        englishError != null && japaneseError != null) {
      throw Exception('Could not load English or Japanese set results.');
    }

    return _CombinedSetSearchResult(
      englishSets: englishSets,
      japaneseSets: japaneseSets,
      englishError: englishError,
      japaneseError: japaneseError,
    );
  }

  void _search({bool force = false}) {
    if (_selectedSection == _CardSearchSection.sealed) return;

    final query = _controller.text.trim();

    if (!force && !_canSearch(query)) {
      final searchKey = '${_selectedSection.name}::$query::too_short';
      if (searchKey == _lastSearchKey) return;
      _lastSearchKey = searchKey;

      setState(() {
        _futureCardResults = Future.value(const CardSearchResult());
        _futureSetResults = Future.value(const _CombinedSetSearchResult());
      });
      return;
    }

    final searchKey = '${_selectedSection.name}::$query';
    if (searchKey == _lastSearchKey) return;
    _lastSearchKey = searchKey;

    setState(() {
      if (_selectedSection == _CardSearchSection.cards) {
        _futureCardResults = _buildCardSearchFuture(query);
      } else {
        _futureSetResults = _buildCombinedSetSearchFuture(query);
      }
    });

    if (query.isNotEmpty) {
      scrollToTop(animated: false);
    }
  }

  void _onSearchChanged(String value) {
    if (_selectedSection == _CardSearchSection.sealed) return;
    _scheduleRecentSearch(value);

    if (_selectedSection == _CardSearchSection.sets &&
        value.trim().toLowerCase().startsWith('first')) {
      _searchDebounce?.cancel();
      _search(force: true);
      return;
    }

    _searchDebounce?.cancel();

    final query = value.trim();

    if (query.isEmpty || !_canSearch(query)) {
      _search();
      return;
    }

    if (mounted) {
      setState(() {});
    }

    _searchDebounce = Timer(_kCardSearchDebounce, _search);
  }

  void _runSearchImmediately() {
    _recentSearchDebounce?.cancel();
    unawaited(_rememberSearch(_controller.text, _selectedSection));
    _searchDebounce?.cancel();
    _search(force: true);
    FocusScope.of(context).unfocus();
  }

  void _clearSearch() {
    _recentSearchDebounce?.cancel();
    _searchDebounce?.cancel();

    setState(() {
      _controller.clear();
      _lastSearchKey = '';
      _futureCardResults = Future.value(const CardSearchResult());
      _futureSetResults = Future.value(const _CombinedSetSearchResult());
    });

    scrollToTop(animated: false);
    FocusScope.of(context).unfocus();
  }

  void _setSearchSection(_CardSearchSection section) {
    if (_selectedSection == section) return;

    _recentSearchDebounce?.cancel();
    _searchDebounce?.cancel();

    setState(() {
      _selectedSection = section;
      _controller.clear();
      _lastSearchKey = '';
      _futureCardResults = Future.value(const CardSearchResult());
      _futureSetResults = Future.value(const _CombinedSetSearchResult());
    });

    FocusScope.of(context).unfocus();
    if (section != _CardSearchSection.sealed) {
      scrollToTop(animated: false);
    }
  }

  void scrollToTop({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    if (animated) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _recentSearchDebounce?.cancel();
    _searchDebounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _searchHintText {
    return switch (_selectedSection) {
      _CardSearchSection.cards => 'Search cards, e.g. Maractus JTG',
      _CardSearchSection.sets =>
        'Type English, Japanese, or a set name',
      _CardSearchSection.sealed => 'Search sealed products inside Sealed',
    };
  }

  /// Illustrated search tabs inspired by the Sets collection navigation.
  /// Only the presentation changes; all search, history and trade selection
  /// behaviour still flows through _setSearchSection.
  // Visual tabs use the artwork from the approved PocketChase mock-up.
  // Navigation, saved searches and Deal Builder selection still use the
  // original _setSearchSection logic; only the presentation changes here.
  // Compact 104dp tab height: keeps the original art and tappable area
  // without dominating the search screen.
  Widget _buildModeTab({
    required String label,
    required String asset,
    required _CardSearchSection section,
  }) {
    const ink = Color(0xFF0B224A);
    const highlight = Color(0xFFFFDE56);
    final selected = _selectedSection == section;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label search tab',
        child: Tooltip(
          message: 'Search $label',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _setSearchSection(section),
              borderRadius: BorderRadius.circular(19),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 104,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: selected
                        ? const [
                            Color(0xFFFFF3A0),
                            Color(0xFFFFDE57),
                            Color(0xFFF8C93E),
                          ]
                        : const [
                            Color(0xFF18518F),
                            Color(0xFF0D3266),
                            Color(0xFF061D49),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFF2A9)
                        : const Color(0xFF468AC4),
                    width: selected ? 1.9 : 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? highlight.withValues(alpha: 0.42)
                          : const Color(0xFF2D8EDF).withValues(alpha: 0.19),
                      blurRadius: selected ? 14 : 9,
                      spreadRadius: selected ? 0.8 : 0,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 7,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: -12,
                      right: -8,
                      child: IgnorePointer(
                        child: Icon(
                          Icons.catching_pokemon,
                          size: 56,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.15)
                              : const Color(0xFFB3DAFF).withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 62,
                          width: double.infinity,
                          child: Image.asset(
                            asset,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              section == _CardSearchSection.cards
                                  ? Icons.style_rounded
                                  : section == _CardSearchSection.sets
                                      ? Icons.menu_book_rounded
                                      : Icons.inventory_2_rounded,
                              color: selected ? ink : const Color(0xFFFFDE56),
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? ink : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 3,
                          width: selected ? 23 : 16,
                          decoration: BoxDecoration(
                            color: selected
                                ? ink
                                : const Color(0xFFA9D0F5),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _buildModeTab(
            label: 'Cards',
            asset: 'assets/images/pc_search_cards.png',
            section: _CardSearchSection.cards,
          ),
          const SizedBox(width: 8),
          _buildModeTab(
            label: 'Sets',
            asset: 'assets/images/pc_search_sets.png',
            section: _CardSearchSection.sets,
          ),
          const SizedBox(width: 8),
          _buildModeTab(
            label: 'Sealed',
            asset: 'assets/images/pc_search_sealed.png',
            section: _CardSearchSection.sealed,
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedSectionPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _buildSectionSelector(),
    );
  }

  Widget _buildSearchTopCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keep the Cards, Sets and Sealed tabs above the search field,
        // matching their position on the Sealed page.
        _buildSectionSelector(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0C2B5E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF3A71AD), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearchImmediately(),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              hintText: _searchHintText,
              hintMaxLines: 1,
              hintStyle: const TextStyle(
                color: Color(0xFFB7C4E0),
                fontSize: 14,
              ),
              filled: true,
              fillColor: const Color(0xFF0B2D66),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: Color(0xFF416FAF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: Color(0xFF416FAF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: Color(0xFFFFDE56), width: 1.5),
              ),
              prefixIcon: IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search, color: Colors.white, size: 22),
                onPressed: _runSearchImmediately,
              ),
              suffixIcon: _controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: _clearSearch,
                    ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_controller.text.trim().isEmpty &&
            _selectedSection != _CardSearchSection.sealed &&
            _recentFor(_selectedSection).isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF102754),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: _buildRecentSearches(),
          ),
        ],
      ],
    );
  }

  Widget _buildShortSearchMessage() {
    return const _SearchInfoCard(
      icon: Icons.keyboard_alt_outlined,
      title: 'Keep typing',
      message: 'Type at least 2 characters to search, or use a collector number like 4/102 or a set code like JTG.',
      accent: Color(0xFFF7DE77),
    );
  }

  Widget _buildLoadingMessage(String query) {
    final label = _selectedSection == _CardSearchSection.cards
        ? 'cards'
        : 'English and Japanese sets';

    return _SearchLoadingCard(
      title: 'Searching $label...',
      message: 'Looking for “$query” in the Pokémon TCG database.',
    );
  }

  Widget _buildErrorMessage(Object? error) {
    return const _SearchInfoCard(
      icon: Icons.wifi_off_rounded,
      title: 'Could not load results',
      message: 'Check your connection and try again. If it keeps happening, the card database may be busy.',
      accent: Color(0xFFE85D5D),
      danger: true,
    );
  }

  Widget _buildNoResultsMessage({
    required String query,
    required bool searchingCards,
  }) {
    return _NoResultsCard(
      query: query,
      searchingCards: searchingCards,
      onClear: _clearSearch,
    );
  }

  Widget _buildResultsHeader({
    required int count,
    required bool cards,
    required String query,
    String? detail,
  }) {
    final label = cards ? 'card' : 'set';
    final plural = count == 1 ? label : '${label}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              detail ?? '$count $plural found',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFF7DE77),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetSourceHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF7DE77).withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.28),
              ),
            ),
            child: Icon(icon, color: const Color(0xFFF7DE77), size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstPartnerSearchCard(_FirstPartnerSeriesSearchResult entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF102754),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => FirstPartnerPromoCardsPage(seriesNumber: entry.series),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: [
            SizedBox(
              width: 110,
              height: 80,
              child: Image.asset(
                entry.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Text('Series ${entry.series}',
                    style: const TextStyle(color: Color(0xFFF7DE77),
                      fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('First Partner Collection 2026',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(entry.subtitle,
                    style: const TextStyle(color: Color(0xFFF7DE77),
                      fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('View 9 promotional cards',
                    style: TextStyle(color: Color(0xFFC8D4F0), fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFF7DE77), size: 28),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildSetResults({
    required _CombinedSetSearchResult result,
    required String query,
  }) {
    final children = <Widget>[];

    if (!result.hasResults) {
      children.add(_buildNoResultsMessage(query: query, searchingCards: false));
      return children;
    }

    children.add(
      _buildResultsHeader(
        count: result.totalCount,
        cards: false,
        query: query,
        detail: result.firstPartnerSeries.isNotEmpty
            ? '${result.firstPartnerSeries.length} First Partner card collections found'
            : '${result.totalCount} sets found • ${result.englishSets.length} English • ${result.japaneseSets.length} Japanese',
      ),
    );
    children.add(const SizedBox(height: 8));

    if (result.firstPartnerSeries.isNotEmpty) {
      children.add(_buildSetSourceHeader(
        title: 'First Partner promo card collections',
        subtitle: '9 cards per series • MEP Black Star Promos',
        icon: Icons.collections_bookmark_outlined,
      ));
      children.addAll(result.firstPartnerSeries.map(_buildFirstPartnerSearchCard));
    }

    if (result.englishSets.isNotEmpty) {
      children.add(
        _buildSetSourceHeader(
          title: 'English sets',
          subtitle: 'International Pokémon TCG set results',
          icon: Icons.collections_bookmark_outlined,
        ),
      );
      children.addAll(
        result.englishSets.map(
          (set) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SetSearchResultCard(set: set),
          ),
        ),
      );
    }

    if (result.japaneseSets.isNotEmpty) {
      children.add(
        _buildSetSourceHeader(
          title: 'Japanese sets',
          subtitle: 'Matching Japanese releases and related set equivalents',
          icon: Icons.language_rounded,
        ),
      );
      children.addAll(
        result.japaneseSets.map(
          (set) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: JapaneseSetSearchResultCard(set: set),
          ),
        ),
      );
    }

    if (result.hasAnyError) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: _SearchInfoCard(
            icon: Icons.info_outline_rounded,
            title: 'Some set results may be missing',
            message: 'One set source did not respond, so only the results that loaded are shown.',
            accent: Color(0xFFF7DE77),
          ),
        ),
      );
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSection == _CardSearchSection.sealed) {
      return Column(
        children: [
          _buildEmbeddedSectionPicker(),
          const Expanded(child: SealedProductPricePage(embedded: true)),
        ],
      );
    }

    if (_selectedSection == _CardSearchSection.cards) {
      return FutureBuilder<CardSearchResult>(
        future: _futureCardResults,
        builder: (context, snapshot) {
          final query = _controller.text.trim();
          final result = snapshot.data ?? const CardSearchResult();
          final cards = result.cards;

          final children = <Widget>[
            _buildSearchTopCard(),
            const SizedBox(height: 10),
          ];

          if (query.isEmpty) {
            children.add(const CardsSearchPlaceholder());
          } else if (!_canSearch(query)) {
            children.add(_buildShortSearchMessage());
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            children.add(_buildLoadingMessage(query));
          } else if (snapshot.hasError) {
            children.add(_buildErrorMessage(snapshot.error));
          } else if (cards.isEmpty) {
            children.add(
              _buildNoResultsMessage(
                query: query,
                searchingCards: true,
              ),
            );
          } else {
            children.add(
              _buildResultsHeader(
                count: cards.length,
                cards: true,
                query: query,
              ),
            );
            children.add(const SizedBox(height: 8));
            children.addAll(
              cards.map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardSearchResultCard(
                    card: card,
                    onOpenDetails: () {
                      if (widget.selectForDeal) {
                        Navigator.of(context).pop(card);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CardDetailsPage(card: card),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          }

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: children,
          );
        },
      );
    }

    return FutureBuilder<_CombinedSetSearchResult>(
      future: _futureSetResults,
      builder: (context, snapshot) {
        final query = _controller.text.trim();
        final result = snapshot.data ?? const _CombinedSetSearchResult();

        final children = <Widget>[
          _buildSearchTopCard(),
          const SizedBox(height: 10),
        ];

        if (query.isEmpty) {
          children.add(const CardsSearchPlaceholder.sets());
        } else if (!_canSearch(query)) {
          children.add(_buildShortSearchMessage());
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          children.add(_buildLoadingMessage(query));
        } else if (snapshot.hasError) {
          children.add(_buildErrorMessage(snapshot.error));
        } else {
          children.addAll(_buildSetResults(result: result, query: query));
        }

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: children,
        );
      },
    );
  }
}

/// Uses the same resolver as the set-result tiles; never substitutes
/// arbitrary internet imagery when a logo is missing.
class _RecentSetLogoImage extends StatelessWidget {
  const _RecentSetLogoImage({required this.match});

  final _RecentSetLogoMatch match;

  @override
  Widget build(BuildContext context) {
    final english = match.englishSet;
    if (english != null) {
      return ResolvedSetLogo(
        setId: english.id,
        setName: english.name,
        fallbackLogoUrl: english.logoUrl,
        height: 32,
        fit: BoxFit.contain,
        textStyle: const TextStyle(
          color: Color(0xFFE7F0FF),
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      );
    }

    final japanese = match.japaneseSet!;
    final raw = japanese.logoUrl.trim();
    if (raw.isEmpty) return _textFallback(japanese.displayName);
    var url = raw;
    if (raw.startsWith('//')) {
      url = 'https:$raw';
    } else if (raw.startsWith('/')) {
      url = 'https://assets.tcgdex.net$raw';
    } else if (!raw.startsWith('https://') && !raw.startsWith('http://')) {
      url = 'https://assets.tcgdex.net/$raw';
    }
    if (!RegExp(r'\.(png|webp|jpe?g)(\?|$)', caseSensitive: false)
        .hasMatch(url)) {
      url = '$url.webp';
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _textFallback(japanese.displayName),
    );
  }

  Widget _textFallback(String label) => Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE7F0FF),
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
      );
}

class _SearchLoadingCard extends StatelessWidget {
  const _SearchLoadingCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.26),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF7DE77)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFC8D4F0),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchInfoCard extends StatelessWidget {
  const _SearchInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: danger ? const Color(0xFF5B1D28) : const Color(0xFF102754),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFE4ECFF),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsCard extends StatelessWidget {
  const _NoResultsCard({
    required this.query,
    required this.searchingCards,
    required this.onClear,
  });

  final String query;
  final bool searchingCards;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final title = searchingCards ? 'No cards found' : 'No sets found';
    final message = searchingCards
        ? 'Try a shorter card name, remove extra words, or search by collector number like 4/102.'
        : 'Try a shorter set name, for example “Base”, “151”, “Obsidian”, “Evolving”, or “Prismatic”.';

    return Card(
      color: const Color(0xFF102754),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.26),
                ),
              ),
              child: Icon(
                searchingCards
                    ? Icons.search_off_rounded
                    : Icons.collections_bookmark_outlined,
                color: const Color(0xFFF7DE77),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nothing matched “$query”.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Clear search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF3F5C96)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
