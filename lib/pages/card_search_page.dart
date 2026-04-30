import 'dart:async';

import 'package:flutter/material.dart';

import '../models/card_search_mode.dart';
import '../models/card_search_result.dart';
import '../pages/card_details_page.dart';
import '../services/pokemon_tcg_service.dart';
import '../widgets/card_search_result_card.dart';
import '../widgets/cards_search_placeholder.dart';
import '../widgets/set_search_result_card.dart';

const Duration _kCardSearchDebounce = Duration(milliseconds: 220);

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
  }

  Future<CardSearchResult> _buildSearchFuture(String query) {
    if (query.isEmpty) {
      return Future.value(const CardSearchResult());
    }

    if (_searchMode == CardSearchMode.cards) {
      return PokemonTcgService.searchCardsOnlyResult(query);
    }

    return PokemonTcgService.searchSetsOnlyResult(query);
  }

  void _search() {
    final query = _controller.text.trim();
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
    if (value.trim().isEmpty) {
      _search();
      return;
    }
    _searchDebounce = Timer(_kCardSearchDebounce, _search);
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
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : const Color(0xFFE4ECFF),
              fontWeight: FontWeight.w800,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _searchMode == CardSearchMode.cards
                    ? 'Search cards, e.g. Pikachu'
                    : 'Search sets, e.g. Base Set',
                hintStyle: const TextStyle(color: Color(0xFFB7C4E0)),
                filled: true,
                fillColor: const Color(0xFF0E2A5E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
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
          ],
        ),
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

        if (snapshot.connectionState == ConnectionState.waiting && query.isNotEmpty) {
          children.add(
            const Card(
              color: Color(0xFF102754),
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Searching Pokémon TCG...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            Card(
              color: const Color(0xFF5B1D28),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Could not load results: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        } else if (query.isEmpty) {
          children.add(const CardsSearchPlaceholder());
        } else if (_searchMode == CardSearchMode.cards) {
          if (cards.isEmpty) {
            children.add(
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No cards found.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          } else {
            children.add(
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '${cards.length} card results',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
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
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No sets found.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          } else {
            children.add(
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '${sets.length} set results',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
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
