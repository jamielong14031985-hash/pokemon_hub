import 'dart:async';

import 'package:flutter/material.dart';

import '../models/card_search_result.dart';
import '../models/tcg_set.dart';
import '../pages/card_details_page.dart';
import '../pages/japanese_sets_page.dart';
import '../pages/sealed_product_price_page.dart';
import '../services/pokemon_tcg_service.dart';
import '../widgets/card_search_result_card.dart';
import '../widgets/cards_search_placeholder.dart';
import '../widgets/set_search_result_card.dart';

const Duration _kCardSearchDebounce = Duration(milliseconds: 450);
const int _kMinimumSearchCharacters = 2;

enum _CardSearchSection {
  cards,
  sets,
  sealed,
}

class _CombinedSetSearchResult {
  const _CombinedSetSearchResult({
    this.englishSets = const <TcgSet>[],
    this.japaneseSets = const <JapaneseTcgSet>[],
    this.englishError,
    this.japaneseError,
  });

  final List<TcgSet> englishSets;
  final List<JapaneseTcgSet> japaneseSets;
  final Object? englishError;
  final Object? japaneseError;

  int get totalCount => englishSets.length + japaneseSets.length;
  bool get hasResults => totalCount > 0;
  bool get hasAnyError => englishError != null || japaneseError != null;
}

class CardSearchPage extends StatefulWidget {
  const CardSearchPage({super.key});

  @override
  State<CardSearchPage> createState() => CardSearchPageState();
}

class CardSearchPageState extends State<CardSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _searchDebounce;
  late Future<CardSearchResult> _futureCardResults;
  late Future<_CombinedSetSearchResult> _futureSetResults;

  _CardSearchSection _selectedSection = _CardSearchSection.cards;
  String _lastSearchKey = '';

  @override
  void initState() {
    super.initState();
    _futureCardResults = Future.value(const CardSearchResult());
    _futureSetResults = Future.value(const _CombinedSetSearchResult());
    unawaited(PokemonTcgService.warmSetSearchCache());
    unawaited(JapaneseTcgDexService.fetchSets());
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

    if (cleanQuery.isEmpty || !_canSearch(cleanQuery)) {
      return const _CombinedSetSearchResult();
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
    _searchDebounce?.cancel();
    _search(force: true);
    FocusScope.of(context).unfocus();
  }

  void _clearSearch() {
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
    _searchDebounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _searchHintText {
    return switch (_selectedSection) {
      _CardSearchSection.cards => 'Search cards, e.g. Maractus JTG',
      _CardSearchSection.sets =>
        'Search English or Japanese sets, e.g. Prismatic Evolutions',
      _CardSearchSection.sealed => 'Search sealed products inside Sealed',
    };
  }

  String get _helperText {
    return switch (_selectedSection) {
      _CardSearchSection.cards =>
        'Search by name, collector number, or set code, like Maractus JTG or 4/102.',
      _CardSearchSection.sets =>
        'Set search now shows English sets and matching Japanese sets in the same place.',
      _CardSearchSection.sealed =>
        'Search booster boxes, booster bundles, ETBs and UPCs.',
    };
  }

  Widget _buildModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF7DE77) : const Color(0xFF16366E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFF7DE77) : const Color(0xFF3F5C96),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : const Color(0xFFE4ECFF),
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeChip(
            label: 'Cards',
            selected: _selectedSection == _CardSearchSection.cards,
            onTap: () => _setSearchSection(_CardSearchSection.cards),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModeChip(
            label: 'Sets',
            selected: _selectedSection == _CardSearchSection.sets,
            onTap: () => _setSearchSection(_CardSearchSection.sets),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModeChip(
            label: 'Sealed',
            selected: _selectedSection == _CardSearchSection.sealed,
            onTap: () => _setSearchSection(_CardSearchSection.sealed),
          ),
        ),
      ],
    );
  }

  Widget _buildEmbeddedSectionPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        color: const Color(0xFF102754),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _buildSectionSelector(),
        ),
      ),
    );
  }

  Widget _buildSearchTopCard() {
    return Card(
      color: const Color(0xFF102754),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearchImmediately(),
              decoration: InputDecoration(
                hintText: _searchHintText,
                hintStyle: const TextStyle(color: Color(0xFFB7C4E0)),
                filled: true,
                fillColor: const Color(0xFF0E2A5E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF3F5C96)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF3F5C96)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFF7DE77),
                    width: 1.5,
                  ),
                ),
                prefixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search, color: Colors.white),
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
            const SizedBox(height: 12),
            _buildSectionSelector(),
            const SizedBox(height: 10),
            Text(
              _helperText,
              style: const TextStyle(
                color: Color(0xFFAFC0E6),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
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
        detail:
            '${result.totalCount} sets found • ${result.englishSets.length} English • ${result.japaneseSets.length} Japanese',
      ),
    );
    children.add(const SizedBox(height: 8));

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
            const SizedBox(height: 14),
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
          const SizedBox(height: 14),
        ];

        if (query.isEmpty) {
          children.add(
            const _SearchInfoCard(
              icon: Icons.collections_bookmark_outlined,
              title: 'Search all sets',
              message: 'Search once to see English sets plus matching Japanese sets together.',
              accent: Color(0xFFF7DE77),
            ),
          );
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
