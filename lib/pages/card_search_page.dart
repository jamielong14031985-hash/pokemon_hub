import 'dart:async';

import 'package:flutter/material.dart';

import '../models/card_search_mode.dart';
import '../models/card_search_result.dart';
import '../pages/card_details_page.dart';
import '../services/pokemon_tcg_service.dart';
import '../widgets/card_search_result_card.dart';
import '../widgets/cards_search_placeholder.dart';
import '../widgets/set_search_result_card.dart';

const Duration _kCardSearchDebounce = Duration(milliseconds: 450);
const int _kMinimumSearchCharacters = 2;

class CardSearchPage extends StatefulWidget {
  const CardSearchPage({super.key});

  @override
  State<CardSearchPage> createState() => CardSearchPageState();
}

class CardSearchPageState extends State<CardSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _searchDebounce;
  late Future<CardSearchResult> _futureResults;

  CardSearchMode _searchMode = CardSearchMode.cards;
  String _lastSearchKey = '';

  @override
  void initState() {
    super.initState();
    _futureResults = Future.value(const CardSearchResult());
    unawaited(PokemonTcgService.warmSetSearchCache());
  }

  bool _canSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;

    final collectorNumberSearch =
        RegExp(r'^\s*[A-Za-z0-9]+\s*/\s*\d+\s*$').hasMatch(trimmed);

    return collectorNumberSearch || trimmed.length >= _kMinimumSearchCharacters;
  }

  Future<CardSearchResult> _buildSearchFuture(String query) {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty || !_canSearch(cleanQuery)) {
      return Future.value(const CardSearchResult());
    }

    if (_searchMode == CardSearchMode.cards) {
      return PokemonTcgService.searchCardsOnlyResult(cleanQuery);
    }

    return PokemonTcgService.searchSetsOnlyResult(cleanQuery);
  }

  void _search({bool force = false}) {
    final query = _controller.text.trim();

    if (!force && !_canSearch(query)) {
      final searchKey = '${_searchMode.name}::$query::too_short';
      if (searchKey == _lastSearchKey) return;
      _lastSearchKey = searchKey;

      setState(() {
        _futureResults = Future.value(const CardSearchResult());
      });
      return;
    }

    final searchKey = '${_searchMode.name}::$query';
    if (searchKey == _lastSearchKey) return;
    _lastSearchKey = searchKey;

    setState(() {
      _futureResults = _buildSearchFuture(query);
    });

    if (query.isNotEmpty) {
      scrollToTop(animated: false);
    }
  }

  void _onSearchChanged(String value) {
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
      _futureResults = Future.value(const CardSearchResult());
    });

    scrollToTop(animated: false);
    FocusScope.of(context).unfocus();
  }

  void _setSearchMode(CardSearchMode mode) {
    if (_searchMode == mode) return;

    _searchDebounce?.cancel();

    setState(() {
      _searchMode = mode;
      _controller.clear();
      _lastSearchKey = '';
      _futureResults = Future.value(const CardSearchResult());
    });

    FocusScope.of(context).unfocus();
    scrollToTop(animated: false);
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
                hintText: _searchMode == CardSearchMode.cards
                    ? 'Search cards, e.g. Pikachu'
                    : 'Search sets, e.g. Base Set',
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
            Row(
              children: [
                Expanded(
                  child: _buildModeChip(
                    label: 'Cards',
                    selected: _searchMode == CardSearchMode.cards,
                    onTap: () => _setSearchMode(CardSearchMode.cards),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildModeChip(
                    label: 'Sets',
                    selected: _searchMode == CardSearchMode.sets,
                    onTap: () => _setSearchMode(CardSearchMode.sets),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _searchMode == CardSearchMode.cards
                  ? 'Search by card name or collector number, like 4/102.'
                  : 'Set search is cached after first load, so repeat searches should feel quicker.',
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
      message: 'Type at least 2 characters to search, or use a collector number like 4/102.',
      accent: Color(0xFFF7DE77),
    );
  }

  Widget _buildLoadingMessage(String query) {
    final label = _searchMode == CardSearchMode.cards ? 'cards' : 'sets';

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
  }) {
    final label = cards ? 'card' : 'set';
    final plural = count == 1 ? label : '${label}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count $plural found',
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CardSearchResult>(
      future: _futureResults,
      builder: (context, snapshot) {
        final query = _controller.text.trim();
        final result = snapshot.data ?? const CardSearchResult();
        final cards = result.cards;
        final sets = result.sets;

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
        } else if (_searchMode == CardSearchMode.cards) {
          if (cards.isEmpty) {
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
                        MaterialPageRoute(
                          builder: (_) => CardDetailsPage(card: card),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          }
        } else {
          if (sets.isEmpty) {
            children.add(
              _buildNoResultsMessage(
                query: query,
                searchingCards: false,
              ),
            );
          } else {
            children.add(
              _buildResultsHeader(
                count: sets.length,
                cards: false,
                query: query,
              ),
            );
            children.add(const SizedBox(height: 8));

            children.addAll(
              sets.map(
                (set) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SetSearchResultCard(set: set),
                ),
              ),
            );
          }
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
        : 'Try a shorter set name, for example “Base”, “151”, “Obsidian”, or “Evolving”.';

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
