import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/card_ownership.dart';
import '../models/set_card_details_result.dart';
import '../models/tcg_card.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../utils/card_number_sorter.dart';
import '../widgets/master_set_slot_tile.dart';
import '../widgets/collection_stat_card.dart';
import '../utils/master_set_slot_helpers.dart';
import 'set_card_details_page.dart';

class JapaneseSetsPage extends StatefulWidget {
  const JapaneseSetsPage({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<JapaneseSetsPage> createState() => _JapaneseSetsPageState();
}

class _JapaneseSetsPageState extends State<JapaneseSetsPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _fieldColor = Color(0xFF0E2A5E);

  final TextEditingController _searchController = TextEditingController();
  late Future<List<JapaneseTcgSet>> _futureSets;
  Timer? _searchDebounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _futureSets = JapaneseTcgDexService.fetchSets();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureSets = JapaneseTcgDexService.fetchSets(forceRefresh: true);
    });

    try {
      await _futureSets;
    } catch (_) {
      // The visible error card handles failures.
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchController.clear();
      _query = '';
    });
    FocusScope.of(context).unfocus();
  }

  List<JapaneseTcgSet> _filterSets(List<JapaneseTcgSet> sets) {
    return JapaneseTcgDexService.filterSetsForQuery(sets, _query);
  }

  Widget _buildSearchBox({
    required bool loading,
    required int totalCount,
    required int visibleCount,
    required Object? error,
  }) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _goldColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _goldColor.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(Icons.language_rounded, color: _goldColor),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Japanese Sets',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Browse Japanese Pokémon TCG sets and cards from TCGdex.',
                      style: TextStyle(
                        color: _softTextColor,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh Japanese sets',
                onPressed: loading ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded, color: _goldColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            cursorColor: _goldColor,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search Japanese sets, e.g. 151, Prismatic, Evolving',
              hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
              filled: true,
              fillColor: _fieldColor,
              prefixIcon: const Icon(Icons.search, color: _softTextColor),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _goldColor, width: 1.5),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 10),
          Text(
            loading
                ? 'Loading Japanese set data...'
                : error != null
                    ? 'Japanese set data could not be loaded.'
                    : hasQuery
                        ? '$visibleCount of $totalCount Japanese sets shown.'
                        : '$totalCount Japanese sets loaded. Tap a set to view cards.',
            style: const TextStyle(
              color: _softTextColor,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetCard(JapaneseTcgSet set) {
    return JapaneseSetSearchResultCard(set: set);
  }

  Widget _buildBody() {
    return FutureBuilder<List<JapaneseTcgSet>>(
      future: _futureSets,
      builder: (context, snapshot) {
        final allSets = snapshot.data ?? const <JapaneseTcgSet>[];
        final sets = _filterSets(allSets);

        final children = <Widget>[
          _buildSearchBox(
            loading: snapshot.connectionState == ConnectionState.waiting,
            totalCount: allSets.length,
            visibleCount: sets.length,
            error: snapshot.error,
          ),
          const SizedBox(height: 14),
        ];

        if (snapshot.connectionState == ConnectionState.waiting) {
          children.add(
            const Center(
              child: Padding(
                padding: EdgeInsets.all(26),
                child: CircularProgressIndicator(color: _goldColor),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            _InfoCard(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load Japanese sets',
              message: 'Check your internet connection and try again.',
              onRetry: _refresh,
            ),
          );
        } else if (sets.isEmpty) {
          children.add(
            _InfoCard(
              icon: Icons.search_off_rounded,
              title: 'No Japanese sets found',
              message: _query.isEmpty
                  ? 'No set data was returned.'
                  : 'Nothing matched “$_query”. Try a shorter search.',
              onRetry: _query.isEmpty ? _refresh : null,
            ),
          );
        } else {
          children.add(
            Text(
              '${sets.length} Japanese set${sets.length == 1 ? '' : 's'} found',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
          children.add(const SizedBox(height: 8));
          children.addAll(sets.map(_buildSetCard));
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: _goldColor,
          backgroundColor: _cardColor,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Container(
        color: _backgroundColor,
        child: _buildBody(),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Japanese Sets'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }
}


class JapaneseSetSearchResultCard extends StatelessWidget {
  const JapaneseSetSearchResultCard({
    super.key,
    required this.set,
  });

  final JapaneseTcgSet set;

  static const Color _cardColor = Color(0xFF102754);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  void _openSet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JapaneseSetDetailsPage(set: set),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (set.cardCount > 0) _SetBadge(label: '${set.cardCount} cards'),
      _SetBadge(label: 'Japanese'),
      if (set.releaseDate.trim().isNotEmpty) _SetBadge(label: set.releaseDate.trim()),
    ];

    return Card(
      margin: EdgeInsets.zero,
      color: _cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openSet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 112,
                child: Center(
                  child: _JapaneseSetPreviewImage(
                    set: set,
                    largeLogo: true,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (badges.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < badges.length; i++)
                          Padding(
                            padding: EdgeInsets.only(right: i == badges.length - 1 ? 0 : 8),
                            child: badges[i],
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Tap this set to open it and view all of the cards inside.',
                      style: TextStyle(
                        color: JapaneseSetSearchResultCard._softTextColor,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: JapaneseSetSearchResultCard._softTextColor,
                    size: 42,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JapaneseSetDetailsPage extends StatefulWidget {
  const JapaneseSetDetailsPage({
    super.key,
    required this.set,
  });

  final JapaneseTcgSet set;

  @override
  State<JapaneseSetDetailsPage> createState() => _JapaneseSetDetailsPageState();
}

class _JapaneseSetDetailsPageState extends State<JapaneseSetDetailsPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _goldColor = Color(0xFFF7DE77);

  late Future<JapaneseTcgSetDetails> _futureDetails;
  final Map<String, CardOwnership> _ownershipByCardId = <String, CardOwnership>{};
  final Set<String> _precachedImageUrls = <String>{};
  bool _loadedOwnership = false;

  String get _collectionSetId => 'jp_${widget.set.id.trim()}';

  @override
  void initState() {
    super.initState();
    _futureDetails = JapaneseTcgDexService.fetchSetDetails(widget.set.id);
    _loadOwnership();
  }

  Future<void> _loadOwnership() async {
    try {
      final ownership = await PokedexSyncService.loadCurrentUserSetOwnership(_collectionSetId);
      if (!mounted) return;
      setState(() {
        _ownershipByCardId
          ..clear()
          ..addAll(ownership);
        _loadedOwnership = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedOwnership = true;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loadedOwnership = false;
      _futureDetails = JapaneseTcgDexService.fetchSetDetails(
        widget.set.id,
        forceRefresh: true,
      );
    });

    try {
      await Future.wait<void>([
        _futureDetails.then<void>((_) {}),
        _loadOwnership(),
      ]);
    } catch (_) {
      // The visible error card handles failures.
    }
  }

  Future<void> _saveOwnership() async {
    await LocalPokedexStore.saveSetOwnershipMap(_collectionSetId, _ownershipByCardId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(_collectionSetId);
  }

  CardOwnership _ownershipFor(TcgCard card) {
    return _ownershipByCardId[card.id] ?? const CardOwnership();
  }

  Future<void> _updateOwnership(TcgCard card, CardOwnership ownership) async {
    setState(() {
      _ownershipByCardId[card.id] = ownership;
    });
    await _saveOwnership();
  }

  Future<void> _updateOwnershipForCardId(String cardId, CardOwnership ownership) async {
    setState(() {
      _ownershipByCardId[cardId] = ownership;
    });
    await _saveOwnership();
  }

  List<TcgCard> _cardsFromDetails(JapaneseTcgSetDetails details) {
    final cardsById = <String, TcgCard>{};
    for (final card in details.cards) {
      final tcgCard = card.toTcgCard(details);
      if (tcgCard.id.trim().isEmpty) continue;
      cardsById[tcgCard.id] = tcgCard;
    }

    final cards = cardsById.values.toList()
      ..sort((a, b) => compareCardNumbers(a.number, b.number));
    return cards;
  }

  void _precacheScrollableCardImages(List<TcgCard> cards) {
    final urlsToWarm = <String>[];
    for (final card in cards.take(24)) {
      final imageUrl = card.imageUrl?.trim();
      if (imageUrl == null || imageUrl.isEmpty) continue;
      if (_precachedImageUrls.add(imageUrl)) {
        urlsToWarm.add(imageUrl);
      }
    }

    if (urlsToWarm.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final imageUrl in urlsToWarm) {
        precacheImage(NetworkImage(imageUrl), context).catchError((_) {});
      }
    });
  }

  Route<dynamic> _buildCardDetailsRoute({
    required TcgCard card,
    required CardOwnership ownership,
    required List<TcgCard> navigationCards,
    required int currentIndex,
    required bool slideFromRight,
  }) {
    return PageRouteBuilder<dynamic>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SetCardDetailsPage(
          card: card,
          ownership: ownership,
          navigationCards: navigationCards,
          navigationIndex: currentIndex,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final beginOffset = Offset(slideFromRight ? 1 : -1, 0);

        return FadeTransition(
          opacity: Tween<double>(begin: 0.86, end: 1).animate(curvedAnimation),
          child: SlideTransition(
            position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openCardDetails({
    required List<TcgCard> cards,
    required TcgCard selectedCard,
  }) async {
    if (cards.isEmpty) return;

    var currentIndex = cards.indexWhere((card) => card.id == selectedCard.id);
    if (currentIndex < 0) currentIndex = 0;

    var previousIndex = currentIndex;

    while (mounted && currentIndex >= 0 && currentIndex < cards.length) {
      final card = cards[currentIndex];
      final slideFromRight = currentIndex >= previousIndex;
      if (!mounted) return;
      final result = await Navigator.of(context).push<dynamic>(
        _buildCardDetailsRoute(
          card: card,
          ownership: _ownershipFor(card),
          navigationCards: cards,
          currentIndex: currentIndex,
          slideFromRight: slideFromRight,
        ),
      );

      if (!mounted) return;

      if (result is SetCardDetailsResult) {
        await _updateOwnershipForCardId(result.cardId, result.ownership);

        final nextIndex = result.nextIndex;
        if (nextIndex != null && nextIndex >= 0 && nextIndex < cards.length) {
          previousIndex = currentIndex;
          currentIndex = nextIndex;
          continue;
        }
        break;
      }

      if (result is CardOwnership) {
        await _updateOwnership(card, result);
      }
      break;
    }
  }

  Widget _buildSetHero(JapaneseTcgSetDetails details, int cardCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 96,
            width: double.infinity,
            child: _JapaneseSetPreviewImage(
              set: details,
              details: details,
              largeLogo: true,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              _SetBadge(label: '$cardCount cards'),
              if (details.series.isNotEmpty) _SetBadge(label: details.series),
              if (details.releaseDate.isNotEmpty) _SetBadge(label: details.releaseDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnglishStyleCardsSummary({
    required int cardCount,
    required int ownedCount,
  }) {
    return Text(
      _loadedOwnership
          ? 'Showing $cardCount cards from this Japanese set\n• $ownedCount saved to your collection.'
          : 'Showing $cardCount cards from this Japanese set\n• Loading your collection...',
      style: const TextStyle(
        color: Color(0xFFC8D4F0),
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(widget.set.displayName),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<JapaneseTcgSetDetails>(
        future: _futureDetails,
        builder: (context, snapshot) {
          final details = snapshot.data ?? JapaneseTcgSetDetails.fromSet(widget.set);
          final cards = _cardsFromDetails(details);
          final cardCount = cards.isNotEmpty ? cards.length : details.cardCount;
          final ownedCount = cards
              .where((card) => _ownershipFor(card).effectiveCopies > 0)
              .length;

          if (snapshot.connectionState == ConnectionState.waiting && cards.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: _goldColor));
          }

          if (snapshot.hasError && cards.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: _goldColor,
              backgroundColor: _cardColor,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  _buildSetHero(details, cardCount),
                  const SizedBox(height: 14),
                  _InfoCard(
                    icon: Icons.wifi_off_rounded,
                    title: 'Could not load cards',
                    message: 'The set opened, but the card list could not be loaded.',
                    onRetry: _refresh,
                  ),
                ],
              ),
            );
          }

          _precacheScrollableCardImages(cards);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: _goldColor,
            backgroundColor: _cardColor,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 900
                    ? 5
                    : constraints.maxWidth >= 650
                        ? 4
                        : 3;

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            _buildSetHero(details, cardCount),
                            const SizedBox(height: 16),
                            _buildEnglishStyleCardsSummary(
                              cardCount: cardCount,
                              ownedCount: ownedCount,
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                    if (cards.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        sliver: SliverToBoxAdapter(
                          child: _InfoCard(
                            icon: Icons.collections_bookmark_outlined,
                            title: 'No cards shown yet',
                            message: 'TCGdex did not return cards for this Japanese set.',
                            onRetry: _refresh,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.76,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final card = cards[index];
                              return _JapaneseScrollableCardTile(
                                card: card,
                                ownership: _ownershipFor(card),
                                onTap: () => _openCardDetails(
                                  cards: cards,
                                  selectedCard: card,
                                ),
                              );
                            },
                            childCount: cards.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _JapaneseScrollableCardTile extends StatelessWidget {
  const _JapaneseScrollableCardTile({
    required this.card,
    required this.ownership,
    required this.onTap,
  });

  final TcgCard card;
  final CardOwnership ownership;
  final VoidCallback onTap;

  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _fieldColor = Color(0xFF0E2A5E);

  @override
  Widget build(BuildContext context) {
    final copies = ownership.effectiveCopies;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: _fieldColor,
                width: double.infinity,
                height: double.infinity,
                child: _TcgDexCandidateImage(
                  candidates: _cardImageCandidates(card.imageUrl ?? ''),
                  fallback: Icons.image_not_supported_outlined,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Text(
                  '#${card.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (copies > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _goldColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'x$copies',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class JapaneseSetPokedexPage extends StatefulWidget {
  const JapaneseSetPokedexPage({
    super.key,
    required this.set,
  });

  final JapaneseTcgSet set;

  @override
  State<JapaneseSetPokedexPage> createState() => _JapaneseSetPokedexPageState();
}

class _JapaneseSetPokedexPageState extends State<JapaneseSetPokedexPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  static const int _cardsPerPage = 9;
  static const ColorFilter _missingCardGreyFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  late Future<JapaneseTcgSetDetails> _futureDetails;
  late final PageController _pokedexPageController;
  final Map<String, CardOwnership> _ownershipByCardId = <String, CardOwnership>{};
  final Set<String> _precachedImageUrls = <String>{};
  bool _loadedOwnership = false;
  int _currentPage = 1;
  bool _showMissingOnly = false;

  String get _collectionSetId => 'jp_${widget.set.id.trim()}';

  @override
  void initState() {
    super.initState();
    _pokedexPageController = PageController();
    _futureDetails = JapaneseTcgDexService.fetchSetDetails(widget.set.id);
    _loadOwnership();
  }

  @override
  void dispose() {
    _pokedexPageController.dispose();
    super.dispose();
  }

  Future<void> _loadOwnership() async {
    try {
      final ownership = await PokedexSyncService.loadCurrentUserSetOwnership(_collectionSetId);
      if (!mounted) return;
      setState(() {
        _ownershipByCardId
          ..clear()
          ..addAll(ownership);
        _loadedOwnership = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedOwnership = true;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loadedOwnership = false;
      _futureDetails = JapaneseTcgDexService.fetchSetDetails(
        widget.set.id,
        forceRefresh: true,
      );
    });

    try {
      await Future.wait<void>([
        _futureDetails.then<void>((_) {}),
        _loadOwnership(),
      ]);
    } catch (_) {
      // The visible error card handles failures.
    }
  }

  Future<void> _saveOwnership() async {
    await LocalPokedexStore.saveSetOwnershipMap(_collectionSetId, _ownershipByCardId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(_collectionSetId);
  }

  CardOwnership _ownershipFor(TcgCard card) {
    return _ownershipByCardId[card.id] ?? const CardOwnership();
  }

  Future<void> _updateOwnership(TcgCard card, CardOwnership ownership) async {
    await _updateOwnershipForCardId(card.id, ownership);
  }

  Future<void> _updateOwnershipForCardId(String cardId, CardOwnership ownership) async {
    setState(() {
      _ownershipByCardId[cardId] = ownership;
    });
    await _saveOwnership();
  }

  List<TcgCard> _cardsFromDetails(JapaneseTcgSetDetails details) {
    final cardsById = <String, TcgCard>{};
    for (final card in details.cards) {
      final tcgCard = card.toTcgCard(details);
      if (tcgCard.id.trim().isEmpty) continue;
      cardsById[tcgCard.id] = tcgCard;
    }

    final cards = cardsById.values.toList()
      ..sort((a, b) => compareCardNumbers(a.number, b.number));
    return cards;
  }

  List<MasterSetCardSlot> _buildJapaneseMasterSetSlots(List<TcgCard> cards) {
    final slots = <MasterSetCardSlot>[];
    final seen = <String>{};

    // Japanese sets already list each printed card separately in TCGdex.
    // Do not create English-style Normal / Reverse Holo / Holo duplicate slots.
    for (final card in cards) {
      final key = card.id.trim().isNotEmpty
          ? card.id.trim().toLowerCase()
          : '${card.setId.trim().toLowerCase()}_${card.number.trim().toLowerCase()}_${card.name.trim().toLowerCase()}';
      if (seen.add(key)) {
        slots.add(
          MasterSetCardSlot(
            card: card,
            kind: MasterSetSlotKind.normal,
          ),
        );
      }
    }

    slots.sort((a, b) {
      final numberCompare = compareCardNumbers(a.card.number, b.card.number);
      if (numberCompare != 0) return numberCompare;

      return a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase());
    });

    return slots;
  }

  Widget _buildOwnedColourState({
    required bool isOwned,
    required Widget child,
  }) {
    if (isOwned) return child;

    return Opacity(
      opacity: 0.42,
      child: ColorFiltered(
        colorFilter: _missingCardGreyFilter,
        child: child,
      ),
    );
  }

  void _goToPokedexPage(int page, int totalPages) {
    final nextPage = page.clamp(1, totalPages).toInt();
    if (_currentPage != nextPage) {
      setState(() {
        _currentPage = nextPage;
      });
    }

    if (!_pokedexPageController.hasClients) return;
    _pokedexPageController.animateToPage(
      nextPage - 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _resetPokedexPage() {
    setState(() {
      _currentPage = 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pokedexPageController.hasClients) return;
      _pokedexPageController.jumpToPage(0);
    });
  }

  void _precacheVisiblePageImages({
    required List<MasterSetCardSlot> visibleSlots,
    required int currentPage,
    required int totalPages,
  }) {
    if (visibleSlots.isEmpty) return;

    final pagesToWarm = <int>{
      currentPage,
      if (currentPage < totalPages) currentPage + 1,
    };
    final urlsToWarm = <String>[];

    for (final page in pagesToWarm) {
      final pageStart = (page - 1) * _cardsPerPage;
      if (pageStart < 0 || pageStart >= visibleSlots.length) continue;

      final pageEnd = (pageStart + _cardsPerPage).clamp(0, visibleSlots.length).toInt();
      for (final slot in visibleSlots.sublist(pageStart, pageEnd)) {
        final imageUrl = slot.card.imageUrl?.trim();
        if (imageUrl == null || imageUrl.isEmpty) continue;
        if (_precachedImageUrls.add(imageUrl)) {
          urlsToWarm.add(imageUrl);
        }
      }
    }

    if (urlsToWarm.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final imageUrl in urlsToWarm) {
        precacheImage(NetworkImage(imageUrl), context).catchError((_) {});
      }
    });
  }

  Future<void> _showPagePicker({
    required int currentPage,
    required int totalPages,
  }) async {
    final pickedPage = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Jump to page',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: totalPages,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.25,
                    ),
                    itemBuilder: (context, index) {
                      final page = index + 1;
                      final selected = page == currentPage;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).pop(page),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? _goldColor : const Color(0xFF16366E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? _goldColor : _borderColor,
                            ),
                          ),
                          child: Text(
                            page.toString(),
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pickedPage == null || !mounted) return;
    _goToPokedexPage(pickedPage, totalPages);
  }

  Route<dynamic> _buildCardDetailsRoute({
    required TcgCard card,
    required CardOwnership ownership,
    required List<TcgCard> navigationCards,
    required List<MasterSetSlotKind> navigationSlotKinds,
    required int currentIndex,
    required bool slideFromRight,
  }) {
    return PageRouteBuilder<dynamic>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SetCardDetailsPage(
          card: card,
          ownership: ownership,
          initialSlotKind: navigationSlotKinds[currentIndex],
          navigationCards: navigationCards,
          navigationSlotKinds: navigationSlotKinds,
          navigationIndex: currentIndex,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final beginOffset = Offset(slideFromRight ? 1 : -1, 0);

        return FadeTransition(
          opacity: Tween<double>(begin: 0.86, end: 1).animate(curvedAnimation),
          child: SlideTransition(
            position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openCardDetailsFromSlot({
    required List<MasterSetCardSlot> visibleSlots,
    required MasterSetCardSlot slot,
  }) async {
    if (visibleSlots.isEmpty) return;

    final navigationCards = visibleSlots.map((slot) => slot.card).toList(growable: false);
    final navigationSlotKinds = visibleSlots.map((slot) => slot.kind).toList(growable: false);
    var currentIndex = visibleSlots.indexWhere(
      (item) => item.card.id == slot.card.id && item.kind == slot.kind,
    );
    if (currentIndex < 0) currentIndex = 0;

    var previousIndex = currentIndex;

    while (mounted && currentIndex >= 0 && currentIndex < navigationCards.length) {
      final card = navigationCards[currentIndex];
      final slideFromRight = currentIndex >= previousIndex;
      if (!mounted) return;
      final result = await Navigator.of(context).push<dynamic>(
        _buildCardDetailsRoute(
          card: card,
          ownership: _ownershipFor(card),
          navigationCards: navigationCards,
          navigationSlotKinds: navigationSlotKinds,
          currentIndex: currentIndex,
          slideFromRight: slideFromRight,
        ),
      );

      if (!mounted) return;

      if (result is SetCardDetailsResult) {
        await _updateOwnershipForCardId(result.cardId, result.ownership);

        final nextIndex = result.nextIndex;
        if (nextIndex != null && nextIndex >= 0 && nextIndex < navigationCards.length) {
          final totalPages = visibleSlots.isEmpty
              ? 1
              : ((visibleSlots.length - 1) ~/ _cardsPerPage) + 1;
          _goToPokedexPage((nextIndex ~/ _cardsPerPage) + 1, totalPages);
          previousIndex = currentIndex;
          currentIndex = nextIndex;
          continue;
        }
        break;
      }

      if (result is CardOwnership) {
        await _updateOwnership(card, result);
      }
      break;
    }
  }

  Widget _buildSetHero(JapaneseTcgSetDetails details) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2),
      child: SizedBox(
        height: 64,
        width: double.infinity,
        child: _JapaneseSetPreviewImage(
          set: details,
          details: details,
          largeLogo: true,
        ),
      ),
    );
  }

  Widget _buildViewControlCard({
    required int ownedCount,
    required int missingCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            !_loadedOwnership
                ? 'Cards loaded • loading your collection...'
                : _showMissingOnly
                    ? '$missingCount missing cards shown'
                    : '$missingCount missing • $ownedCount owned',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _softTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: FilledButton.tonalIcon(
            onPressed: _loadedOwnership
                ? () {
                    setState(() {
                      _showMissingOnly = !_showMissingOnly;
                    });
                    _resetPokedexPage();
                  }
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: Icon(
              _showMissingOnly ? Icons.dashboard_outlined : Icons.filter_alt_rounded,
              size: 16,
            ),
            label: Text(
              _showMissingOnly ? 'Show all' : 'Missing only',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _goldColor;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        toolbarHeight: 44,
        title: Text(widget.set.displayName),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<JapaneseTcgSetDetails>(
        future: _futureDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _goldColor));
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _InfoCard(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load cards',
                message: 'The set opened, but the card list could not be loaded.',
                onRetry: _refresh,
              ),
            );
          }

          final details = snapshot.data ?? JapaneseTcgSetDetails.fromSet(widget.set);
          final visibleCards = _cardsFromDetails(details);
          final allSlots = _buildJapaneseMasterSetSlots(visibleCards);
          final ownedCount = allSlots.where((slot) => slot.isOwned(_ownershipFor(slot.card))).length;
          final total = allSlots.length;
          final missingCount = total - ownedCount;
          final percent = total == 0 ? 0 : ((ownedCount / total) * 100).round();
          final visibleSlots = _showMissingOnly && _loadedOwnership
              ? allSlots.where((slot) => !slot.isOwned(_ownershipFor(slot.card))).toList()
              : allSlots;
          final totalPages = visibleSlots.isEmpty
              ? 1
              : ((visibleSlots.length - 1) ~/ _cardsPerPage) + 1;
          final safePage = _currentPage.clamp(1, totalPages).toInt();

          if (safePage != _currentPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _currentPage = safePage;
              });
              if (_pokedexPageController.hasClients) {
                _pokedexPageController.jumpToPage(safePage - 1);
              }
            });
          }

          _precacheVisiblePageImages(
            visibleSlots: visibleSlots,
            currentPage: safePage,
            totalPages: totalPages,
          );

          return SafeArea(
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSetHero(details),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CollectionStatCard(
                          label: 'Owned',
                          value: _loadedOwnership ? '$ownedCount/$total' : '...',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CollectionStatCard(
                          label: 'Complete',
                          value: _loadedOwnership ? '$percent%' : '...',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: total == 0 ? 0 : ownedCount / total,
                    minHeight: 5,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 8),
                  _buildViewControlCard(
                    ownedCount: ownedCount,
                    missingCount: missingCount,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: visibleSlots.isEmpty
                        ? Center(
                            child: Text(
                              _showMissingOnly
                                  ? 'No missing cards in this Japanese set. Nice work!'
                                  : 'No cards found in this Japanese set.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, gridConstraints) {
                              const columns = 3;
                              const rows = 3;
                              const spacing = 4.0;
                              const horizontalInset = 2.0;
                              const bottomInset = 6.0;

                              final usableWidth = gridConstraints.maxWidth - (horizontalInset * 2);
                              final usableHeight = gridConstraints.maxHeight - bottomInset;
                              final tileWidth = (usableWidth - (spacing * (columns - 1))) / columns;
                              final tileHeight = (usableHeight - (spacing * (rows - 1))) / rows;
                              final fittedAspectRatio = tileHeight <= 0
                                  ? 0.76
                                  : (tileWidth / tileHeight).clamp(0.72, 0.98).toDouble();

                              return PageView.builder(
                                controller: _pokedexPageController,
                                physics: const BouncingScrollPhysics(),
                                onPageChanged: (index) {
                                  final nextPage = index + 1;
                                  if (_currentPage != nextPage) {
                                    setState(() {
                                      _currentPage = nextPage;
                                    });
                                  }
                                },
                                itemCount: totalPages,
                                itemBuilder: (context, pageIndex) {
                                  final pageStart = pageIndex * _cardsPerPage;
                                  final pageEnd = (pageStart + _cardsPerPage)
                                      .clamp(0, visibleSlots.length)
                                      .toInt();
                                  final pageSlots = visibleSlots.sublist(pageStart, pageEnd);

                                  return AnimatedPadding(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.fromLTRB(
                                      horizontalInset,
                                      0,
                                      horizontalInset,
                                      bottomInset,
                                    ),
                                    child: GridView.builder(
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: pageSlots.length,
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: spacing,
                                        mainAxisSpacing: spacing,
                                        childAspectRatio: fittedAspectRatio,
                                      ),
                                      itemBuilder: (context, index) {
                                        final slot = pageSlots[index];
                                        final card = slot.card;
                                        final ownership = _ownershipFor(card);
                                        final isOwned = slot.isOwned(ownership);

                                        return AnimatedScale(
                                          duration: const Duration(milliseconds: 180),
                                          curve: Curves.easeOutCubic,
                                          scale: 1,
                                          child: GestureDetector(
                                            onLongPress: () async {
                                              await _updateOwnership(
                                                card,
                                                slot.toggleOwnership(ownership),
                                              );
                                            },
                                            onTap: () async {
                                              await _openCardDetailsFromSlot(
                                                visibleSlots: visibleSlots,
                                                slot: slot,
                                              );
                                            },
                                            child: _buildOwnedColourState(
                                              isOwned: isOwned,
                                              child: MasterSetSlotTile(
                                                slot: slot,
                                                ownership: ownership,
                                                greyOutWhenMissing: false,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: safePage > 1
                              ? () => _goToPokedexPage(safePage - 1, totalPages)
                              : null,
                          child: const Text('Previous'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: totalPages > 1
                            ? () => _showPagePicker(
                                  currentPage: safePage,
                                  totalPages: totalPages,
                                )
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$safePage / $totalPages',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: safePage < totalPages
                              ? () => _goToPokedexPage(safePage + 1, totalPages)
                              : null,
                          child: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


class _JapaneseSetPreviewImage extends StatelessWidget {
  const _JapaneseSetPreviewImage({
    required this.set,
    this.details,
    this.largeLogo = false,
  });

  final JapaneseTcgSet set;
  final JapaneseTcgSetDetails? details;
  final bool largeLogo;

  List<String> _candidates(JapaneseTcgSetDetails? currentDetails) {
    return <String>[
      ..._englishEquivalentLogoCandidates(set.id),
      ..._setAssetCandidates(set.logoUrl),
      ..._setAssetCandidates(set.symbolUrl),
      ..._fallbackSetAssetCandidates(set.id),
      if (currentDetails != null) ..._setAssetCandidates(currentDetails.logoUrl),
      if (currentDetails != null) ..._setAssetCandidates(currentDetails.symbolUrl),
      if (currentDetails != null) ..._cardPreviewCandidatesForSet(currentDetails),
      ..._fallbackFirstCardCandidates(set.id),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final existingDetails = details;
    if (existingDetails != null) {
      return _TcgDexCandidateImage(
        candidates: _candidates(existingDetails),
        fallback: Icons.style_outlined,
        fit: BoxFit.contain,
        padding: EdgeInsets.all(largeLogo ? 4 : 7),
      );
    }

    return FutureBuilder<JapaneseTcgSetDetails>(
      future: JapaneseTcgDexService.fetchSetDetails(set.id),
      builder: (context, snapshot) {
        return _TcgDexCandidateImage(
          candidates: _candidates(snapshot.data),
          fallback: Icons.style_outlined,
          fit: BoxFit.contain,
          padding: EdgeInsets.all(largeLogo ? 4 : 7),
        );
      },
    );
  }
}

class _TcgDexCandidateImage extends StatefulWidget {
  const _TcgDexCandidateImage({
    required this.candidates,
    required this.fallback,
    this.fit = BoxFit.contain,
    this.padding = EdgeInsets.zero,
  });

  final List<String> candidates;
  final IconData fallback;
  final BoxFit fit;
  final EdgeInsets padding;

  @override
  State<_TcgDexCandidateImage> createState() => _TcgDexCandidateImageState();
}

class _TcgDexCandidateImageState extends State<_TcgDexCandidateImage> {
  int _index = 0;

  List<String> get _cleanCandidates {
    final seen = <String>{};
    final results = <String>[];

    for (final candidate in widget.candidates) {
      final clean = candidate.trim();
      if (clean.isEmpty) continue;
      if (seen.add(clean)) results.add(clean);
    }

    return results;
  }

  @override
  void didUpdateWidget(covariant _TcgDexCandidateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidates.join('|') != widget.candidates.join('|')) {
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _cleanCandidates;

    if (candidates.isEmpty || _index >= candidates.length) {
      return Center(
        child: Icon(widget.fallback, color: const Color(0xFFF7DE77), size: 32),
      );
    }

    return Padding(
      padding: widget.padding,
      child: Image.network(
        candidates[_index],
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_index < candidates.length) {
              setState(() => _index += 1);
            }
          });

          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFF7DE77),
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFF7DE77),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SetBadge extends StatelessWidget {
  const _SetBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFC8D4F0),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF3F5C96)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFF7DE77), size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC8D4F0),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF3F5C96)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JapaneseSetSearchMatch {
  const _JapaneseSetSearchMatch({
    required this.set,
    required this.score,
  });

  final JapaneseTcgSet set;
  final int score;
}

class JapaneseTcgDexService {
  JapaneseTcgDexService._();

  static const String _host = 'api.tcgdex.net';
  static const String _language = 'ja';

  static List<JapaneseTcgSet>? _cachedSets;
  static Future<List<JapaneseTcgSet>>? _setsInFlight;
  static final Map<String, JapaneseTcgSetDetails> _detailsCache =
      <String, JapaneseTcgSetDetails>{};
  static final Map<String, Future<JapaneseTcgSetDetails>> _detailsInFlight =
      <String, Future<JapaneseTcgSetDetails>>{};

  static Future<List<JapaneseTcgSet>> fetchSets({bool forceRefresh = false}) async {
    final cached = _cachedSets;
    if (!forceRefresh && cached != null) {
      return List<JapaneseTcgSet>.from(cached);
    }

    final inFlight = _setsInFlight;
    if (!forceRefresh && inFlight != null) {
      return List<JapaneseTcgSet>.from(await inFlight);
    }

    final request = _fetchSetsFromApi();
    if (!forceRefresh) _setsInFlight = request;

    try {
      final sets = await request;
      _cachedSets = List<JapaneseTcgSet>.from(sets);
      return sets;
    } finally {
      if (!forceRefresh) _setsInFlight = null;
    }
  }

  static Future<List<JapaneseTcgSet>> searchSetsForQuery(String query) async {
    final sets = await fetchSets();
    return filterSetsForQuery(sets, query).take(50).toList();
  }

  static List<JapaneseTcgSet> filterSetsForQuery(
    List<JapaneseTcgSet> sets,
    String query,
  ) {
    final normalizedQuery = _normalizeSetSearch(query);
    if (normalizedQuery.isEmpty) return List<JapaneseTcgSet>.from(sets);

    final queryParts = normalizedQuery
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList();

    final scored = <_JapaneseSetSearchMatch>[];

    for (final set in sets) {
      final searchText = _normalizeSetSearch(
        '${set.id} ${set.name} ${set.series} ${set.releaseDate} '
        '${_englishAliasesForSet(set).join(' ')}',
      );

      if (!queryParts.every(searchText.contains)) continue;

      scored.add(
        _JapaneseSetSearchMatch(
          set: set,
          score: _scoreSetForQuery(set, normalizedQuery, queryParts),
        ),
      );
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      final dateCompare = b.set.releaseDate.compareTo(a.set.releaseDate);
      if (dateCompare != 0) return dateCompare;
      return a.set.displayName.compareTo(b.set.displayName);
    });

    return scored.map((match) => match.set).toList();
  }

  static int _scoreSetForQuery(
    JapaneseTcgSet set,
    String normalizedQuery,
    List<String> queryParts,
  ) {
    final id = _normalizeSetSearch(set.id);
    final name = _normalizeSetSearch(set.name);
    final displayName = _normalizeSetSearch(set.displayName);
    final aliases = _englishAliasesForSet(set)
        .map(_normalizeSetSearch)
        .where((alias) => alias.isNotEmpty)
        .toList();

    var score = 0;

    if (id == normalizedQuery) score += 1200;
    if (displayName == normalizedQuery || name == normalizedQuery) score += 1000;

    for (final alias in aliases) {
      if (alias == normalizedQuery) score += 950;
      if (alias.contains(normalizedQuery)) score += 500;
      if (normalizedQuery.contains(alias)) score += 300;
    }

    if (displayName.contains(normalizedQuery)) score += 500;
    if (name.contains(normalizedQuery)) score += 450;
    if (set.series.toLowerCase().contains(normalizedQuery)) score += 120;

    score += queryParts.length * 25;

    if (set.releaseDate.isNotEmpty) score += 10;
    if (set.cardCount > 0) score += 5;

    return score;
  }

  static List<String> _englishAliasesForSet(JapaneseTcgSet set) {
    final id = _normalizeSetSearch(set.id);
    final nameAndSeries = _normalizeSetSearch('${set.name} ${set.series}');
    final aliases = <String>[];

    void addAll(List<String>? values) {
      if (values == null) return;
      aliases.addAll(values);
    }

    addAll(_englishAliasesById[id]);

    for (final entry in _englishAliasesByName.entries) {
      if (nameAndSeries.contains(entry.key)) {
        aliases.addAll(entry.value);
      }
    }

    return aliases.toSet().toList();
  }

  static String _normalizeSetSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const Map<String, List<String>> _englishAliasesByName = <String, List<String>>{
    'terastal festival ex': <String>['prismatic evolutions'],
    'super electric breaker': <String>['surging sparks'],
    'paradise dragona': <String>['surging sparks'],
    'stellar miracle': <String>['stellar crown'],
    'night wanderer': <String>['shrouded fable'],
    'crimson haze': <String>['twilight masquerade'],
    'mask of change': <String>['twilight masquerade'],
    'wild force': <String>['temporal forces'],
    'cyber judge': <String>['temporal forces'],
    'shiny treasure ex': <String>['paldean fates'],
    'ancient roar': <String>['paradox rift'],
    'future flash': <String>['paradox rift'],
    'raging surf': <String>['paradox rift'],
    'ruler of the black flame': <String>['obsidian flames'],
    'pokemon card 151': <String>['scarlet and violet 151', 'pokemon 151', '151'],
    'snow hazard': <String>['paldea evolved'],
    'clay burst': <String>['paldea evolved'],
    'triplet beat': <String>['paldea evolved'],
    'scarlet ex': <String>['scarlet and violet base', 'scarlet and violet'],
    'violet ex': <String>['scarlet and violet base', 'scarlet and violet'],
    'vstar universe': <String>['crown zenith'],
    'paradigm trigger': <String>['silver tempest'],
    'incandescent arcana': <String>['silver tempest'],
    'lost abyss': <String>['lost origin'],
    'dark phantasma': <String>['lost origin'],
    'time gazer': <String>['astral radiance'],
    'space juggler': <String>['astral radiance'],
    'battle region': <String>['astral radiance'],
    'star birth': <String>['brilliant stars'],
    'vmax climax': <String>['brilliant stars'],
    'fusion arts': <String>['fusion strike'],
    'eevee heroes': <String>['evolving skies'],
    'blue sky stream': <String>['evolving skies'],
    'towering perfection': <String>['evolving skies'],
    'silver lance': <String>['chilling reign'],
    'jet black spirit': <String>['chilling reign'],
    'matchless fighters': <String>['chilling reign'],
    'single strike master': <String>['battle styles'],
    'rapid strike master': <String>['battle styles'],
    'shiny star v': <String>['shining fates'],
    'amazing volt tackle': <String>['vivid voltage'],
    'infinity zone': <String>['darkness ablaze'],
    'rebel clash': <String>['rebellion crash'],
  };

  static const Map<String, List<String>> _englishAliasesById = <String, List<String>>{
    'sv8a': <String>['prismatic evolutions', 'terastal festival ex'],
    'sv8': <String>['surging sparks', 'super electric breaker'],
    'sv7a': <String>['surging sparks', 'paradise dragona'],
    'sv7': <String>['stellar crown', 'stellar miracle'],
    'sv6a': <String>['shrouded fable', 'night wanderer'],
    'sv6': <String>['twilight masquerade', 'mask of change'],
    'sv5a': <String>['twilight masquerade', 'crimson haze'],
    'sv5k': <String>['temporal forces', 'wild force'],
    'sv5m': <String>['temporal forces', 'cyber judge'],
    'sv4a': <String>['paldean fates', 'shiny treasure ex'],
    'sv4k': <String>['paradox rift', 'ancient roar'],
    'sv4m': <String>['paradox rift', 'future flash'],
    'sv3a': <String>['paradox rift', 'raging surf'],
    'sv3': <String>['obsidian flames', 'ruler of the black flame'],
    'sv2a': <String>['scarlet and violet 151', 'pokemon 151', '151', 'pokemon card 151'],
    'sv2p': <String>['paldea evolved', 'snow hazard'],
    'sv2d': <String>['paldea evolved', 'clay burst'],
    'sv1a': <String>['paldea evolved', 'triplet beat'],
    'sv1s': <String>['scarlet and violet base', 'scarlet and violet', 'scarlet ex'],
    'sv1v': <String>['scarlet and violet base', 'scarlet and violet', 'violet ex'],
    's12a': <String>['crown zenith', 'vstar universe'],
    's12': <String>['silver tempest', 'paradigm trigger'],
    's11a': <String>['silver tempest', 'incandescent arcana'],
    's11': <String>['lost origin', 'lost abyss'],
    's10a': <String>['lost origin', 'dark phantasma'],
    's10d': <String>['astral radiance', 'time gazer'],
    's10p': <String>['astral radiance', 'space juggler'],
    's9a': <String>['astral radiance', 'battle region'],
    's9': <String>['brilliant stars', 'star birth'],
    's8b': <String>['brilliant stars', 'vmax climax'],
    's8': <String>['fusion strike', 'fusion arts'],
    's7r': <String>['evolving skies', 'blue sky stream'],
    's7d': <String>['evolving skies', 'towering perfection'],
    's6a': <String>['evolving skies', 'eevee heroes'],
    's6h': <String>['chilling reign', 'silver lance'],
    's6k': <String>['chilling reign', 'jet black spirit'],
    's5a': <String>['chilling reign', 'matchless fighters'],
    's5i': <String>['battle styles', 'single strike master'],
    's5r': <String>['battle styles', 'rapid strike master'],
    's4a': <String>['shining fates', 'shiny star v'],
    's4': <String>['vivid voltage', 'amazing volt tackle'],
    's3': <String>['darkness ablaze', 'infinity zone'],
    's2': <String>['rebel clash', 'rebellion crash'],
  };

  static Future<List<JapaneseTcgSet>> _fetchSetsFromApi() async {
    final uri = Uri.https(_host, '/v2/$_language/sets');
    final response = await http
        .get(uri, headers: const <String, String>{'accept': 'application/json'})
        .timeout(const Duration(seconds: 18));

    if (response.statusCode != 200) {
      throw Exception('TCGdex returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('TCGdex returned unexpected set data.');
    }

    final sets = decoded
        .whereType<Map>()
        .map((item) => JapaneseTcgSet.fromJson(Map<String, dynamic>.from(item)))
        .where((set) => set.id.isNotEmpty || set.name.isNotEmpty)
        .toList();

    sets.sort((a, b) {
      final dateCompare = b.releaseDate.compareTo(a.releaseDate);
      if (dateCompare != 0) return dateCompare;
      final idCompare = b.id.compareTo(a.id);
      if (idCompare != 0) return idCompare;
      return a.displayName.compareTo(b.displayName);
    });

    return sets;
  }

  static Future<JapaneseTcgSetDetails> fetchSetDetails(
    String setId, {
    bool forceRefresh = false,
  }) async {
    final cleanId = setId.trim();
    if (cleanId.isEmpty) throw Exception('Missing Japanese set ID.');

    if (!forceRefresh && _detailsCache.containsKey(cleanId)) {
      return _detailsCache[cleanId]!;
    }

    final inFlight = _detailsInFlight[cleanId];
    if (!forceRefresh && inFlight != null) return inFlight;

    final request = _fetchSetDetailsFromApi(cleanId);
    if (!forceRefresh) _detailsInFlight[cleanId] = request;

    try {
      final details = await request;
      _detailsCache[cleanId] = details;
      return details;
    } finally {
      if (!forceRefresh) _detailsInFlight.remove(cleanId);
    }
  }

  static Future<JapaneseTcgSetDetails> _fetchSetDetailsFromApi(String setId) async {
    final uri = Uri.https(_host, '/v2/$_language/sets/${Uri.encodeComponent(setId)}');
    final response = await http
        .get(uri, headers: const <String, String>{'accept': 'application/json'})
        .timeout(const Duration(seconds: 18));

    if (response.statusCode != 200) {
      throw Exception('TCGdex returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('TCGdex returned unexpected set detail data.');
    }

    return JapaneseTcgSetDetails.fromJson(Map<String, dynamic>.from(decoded));
  }
}

class JapaneseTcgSet {
  const JapaneseTcgSet({
    required this.id,
    required this.name,
    required this.series,
    required this.logoUrl,
    required this.symbolUrl,
    required this.releaseDate,
    required this.cardCount,
  });

  final String id;
  final String name;
  final String series;
  final String logoUrl;
  final String symbolUrl;
  final String releaseDate;
  final int cardCount;

  factory JapaneseTcgSet.fromJson(Map<String, dynamic> json) {
    final cardCount = _asMap(json['cardCount']);
    final serie = _asMap(json['serie'] ?? json['series']);

    return JapaneseTcgSet(
      id: _text(json['id']),
      name: _text(json['name']),
      series: _text(serie['name'] ?? json['series']),
      logoUrl: _text(json['logo']),
      symbolUrl: _text(json['symbol']),
      releaseDate: _text(json['releaseDate']),
      cardCount: _intValue(cardCount['official']) > 0
          ? _intValue(cardCount['official'])
          : _intValue(cardCount['total']),
    );
  }

  String get displayName => name.trim().isEmpty ? id : name.trim();
}

class JapaneseTcgSetDetails extends JapaneseTcgSet {
  const JapaneseTcgSetDetails({
    required super.id,
    required super.name,
    required super.series,
    required super.logoUrl,
    required super.symbolUrl,
    required super.releaseDate,
    required super.cardCount,
    required this.cards,
  });

  final List<JapaneseTcgCardBrief> cards;

  factory JapaneseTcgSetDetails.fromSet(JapaneseTcgSet set) {
    return JapaneseTcgSetDetails(
      id: set.id,
      name: set.name,
      series: set.series,
      logoUrl: set.logoUrl,
      symbolUrl: set.symbolUrl,
      releaseDate: set.releaseDate,
      cardCount: set.cardCount,
      cards: const <JapaneseTcgCardBrief>[],
    );
  }

  factory JapaneseTcgSetDetails.fromJson(Map<String, dynamic> json) {
    final base = JapaneseTcgSet.fromJson(json);
    final rawCards = json['cards'];
    final cards = rawCards is List
        ? rawCards
            .whereType<Map>()
            .map((item) => JapaneseTcgCardBrief.fromJson(Map<String, dynamic>.from(item)))
            .where((card) => card.id.isNotEmpty || card.name.isNotEmpty)
            .toList()
        : const <JapaneseTcgCardBrief>[];

    return JapaneseTcgSetDetails(
      id: base.id,
      name: base.name,
      series: base.series,
      logoUrl: base.logoUrl,
      symbolUrl: base.symbolUrl,
      releaseDate: base.releaseDate,
      cardCount: base.cardCount,
      cards: cards,
    );
  }
}

class JapaneseTcgCardBrief {
  const JapaneseTcgCardBrief({
    required this.id,
    required this.localId,
    required this.name,
    required this.image,
    required this.types,
  });

  final String id;
  final String localId;
  final String name;
  final String image;
  final List<String> types;

  factory JapaneseTcgCardBrief.fromJson(Map<String, dynamic> json) {
    return JapaneseTcgCardBrief(
      id: _text(json['id']),
      localId: _text(json['localId'] ?? json['number']),
      name: _text(json['name']),
      image: _text(json['image']),
      types: _stringList(json['types'] ?? json['type']),
    );
  }

  String get displayName => name.trim().isEmpty ? id : name.trim();

  TcgCard toTcgCard(JapaneseTcgSetDetails set) {
    final cleanSetId = set.id.trim();
    final cleanLocalId = localId.trim().isNotEmpty
        ? localId.trim()
        : _localIdFromCardId(id, cleanSetId);
    final displayNumber = cleanLocalId.isNotEmpty ? cleanLocalId : id.trim();
    final safeNumber = displayNumber
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final safeCardId = safeNumber.isEmpty ? id.trim() : safeNumber;
    final japaneseSetId = cleanSetId.isEmpty ? 'unknown' : cleanSetId;

    final imageCandidates = <String>[
      ..._cardImageCandidates(image),
      ..._cardImageCandidatesFromParts(
        setId: japaneseSetId,
        cardId: id,
        localId: cleanLocalId,
      ),
    ];

    final setLogoCandidates = <String>[
      ..._englishEquivalentLogoCandidates(japaneseSetId),
      ..._setAssetCandidates(set.logoUrl),
      ..._setAssetCandidates(set.symbolUrl),
      ..._fallbackSetAssetCandidates(japaneseSetId),
    ];

    return TcgCard(
      id: 'jp_${japaneseSetId}_$safeCardId',
      name: displayName,
      setId: 'jp_$japaneseSetId',
      setName: set.displayName,
      number: displayNumber.isEmpty ? 'Unknown' : displayNumber,
      rarity: null,
      hp: null,
      artist: null,
      flavorText: null,
      imageUrl: imageCandidates.isEmpty ? null : imageCandidates.first,
      largeImageUrl: imageCandidates.length > 1 ? imageCandidates[1] : null,
      setLogoUrl: setLogoCandidates.isEmpty ? null : setLogoCandidates.first,
      rawPrice: null,
      rawPriceCurrency: 'JPY',
      rawPriceBreakdown: const <String, double>{},
      gradedPrices: const <String, double>{},
      types: types,
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _text(Object? value) => value?.toString().trim() ?? '';

List<String> _stringList(Object? value) {
  String cleanOne(Object? item) {
    if (item is Map) {
      final map = Map<String, dynamic>.from(item);
      return _text(
        map['name'] ??
            map['id'] ??
            map['type'] ??
            map['slug'] ??
            map['label'],
      );
    }
    return _text(item);
  }

  if (value is List) {
    return value
        .map(cleanOne)
        .expand(_expandJapaneseTypeTokens)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
  final singleValues = _expandJapaneseTypeTokens(cleanOne(value));
  return singleValues.where((item) => item.isNotEmpty).toSet().toList(growable: false);
}

Iterable<String> _expandJapaneseTypeTokens(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return const <String>[];

  final lower = clean.toLowerCase();
  final mapped = <String>[clean];

  void add(String type) {
    if (!mapped.contains(type)) mapped.add(type);
  }

  if (lower.contains('grass') || clean.contains('草') || clean.contains('くさ') || clean.contains('リーフ')) add('Grass');
  if (lower.contains('fire') || clean.contains('炎') || clean.contains('ほのお')) add('Fire');
  if (lower.contains('water') || clean.contains('水') || clean.contains('みず')) add('Water');
  if (lower.contains('lightning') || lower.contains('electric') || clean.contains('雷') || clean.contains('電')) add('Lightning');
  if (lower.contains('psychic') || clean.contains('超') || clean.contains('エスパー')) add('Psychic');
  if (lower.contains('fighting') || clean.contains('闘') || clean.contains('かくとう')) add('Fighting');
  if (lower.contains('dark') || clean.contains('悪') || clean.contains('あく')) add('Darkness');
  if (lower.contains('metal') || lower.contains('steel') || clean.contains('鋼') || clean.contains('はがね')) add('Metal');
  if (lower.contains('fairy') || clean.contains('妖') || clean.contains('フェアリー')) add('Fairy');
  if (lower.contains('dragon') || clean.contains('竜') || clean.contains('ドラゴン')) add('Dragon');

  return mapped;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}

List<String> _englishEquivalentLogoCandidates(String japaneseSetId) {
  final cleanId = japaneseSetId.trim().toLowerCase();
  final englishSetId = _englishLogoSetIdByJapaneseId[cleanId];
  if (englishSetId == null || englishSetId.isEmpty) return const <String>[];

  final encodedId = Uri.encodeComponent(englishSetId);
  return <String>[
    'https://images.pokemontcg.io/$encodedId/logo.png',
    'https://images.pokemontcg.io/$encodedId/symbol.png',
  ];
}

const Map<String, String> _englishLogoSetIdByJapaneseId = <String, String>{
  'sv8a': 'sv8pt5',
  'sv8': 'sv8',
  'sv7a': 'sv8',
  'sv7': 'sv7',
  'sv6a': 'sv6pt5',
  'sv6': 'sv6',
  'sv5a': 'sv6',
  'sv5k': 'sv5',
  'sv5m': 'sv5',
  'sv4a': 'sv4pt5',
  'sv4k': 'sv4',
  'sv4m': 'sv4',
  'sv3a': 'sv4',
  'sv3': 'sv3',
  'sv2a': 'sv3pt5',
  'sv2p': 'sv2',
  'sv2d': 'sv2',
  'sv1a': 'sv2',
  'sv1s': 'sv1',
  'sv1v': 'sv1',
  's12a': 'swsh12pt5',
  's12': 'swsh12',
  's11a': 'swsh12',
  's11': 'swsh11',
  's10a': 'swsh11',
  's10d': 'swsh10',
  's10p': 'swsh10',
  's9a': 'swsh10',
  's9': 'swsh9',
  's8b': 'swsh9',
  's8': 'swsh8',
  's7r': 'swsh7',
  's7d': 'swsh7',
  's6a': 'swsh7',
  's6h': 'swsh6',
  's6k': 'swsh6',
  's5a': 'swsh6',
  's5i': 'swsh5',
  's5r': 'swsh5',
  's4a': 'swsh45',
  's4': 'swsh4',
  's3': 'swsh3',
  's2': 'swsh2',
};

List<String> _setAssetCandidates(String url) {
  final clean = _normaliseAssetUrl(url);
  if (clean.isEmpty) return const <String>[];

  if (_hasImageExtension(clean)) {
    return <String>[clean];
  }

  return <String>[
    '$clean.webp',
    '$clean.png',
    '$clean.jpg',
    '$clean.jpeg',
    clean,
  ];
}

List<String> _fallbackSetAssetCandidates(String setId) {
  final cleanId = setId.trim();
  if (cleanId.isEmpty) return const <String>[];

  final group = _setAssetGroup(cleanId);
  if (group.isEmpty) return const <String>[];

  final encodedId = Uri.encodeComponent(cleanId);
  final encodedGroup = Uri.encodeComponent(group);

  return <String>[
    'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/logo.webp',
    'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/logo.png',
    'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/logo.jpg',
    'https://assets.tcgdex.net/univ/$encodedGroup/$encodedId/symbol.webp',
    'https://assets.tcgdex.net/univ/$encodedGroup/$encodedId/symbol.png',
    'https://assets.tcgdex.net/univ/$encodedGroup/$encodedId/symbol.jpg',
  ];
}

List<String> _fallbackFirstCardCandidates(String setId) {
  final cleanId = setId.trim();
  if (cleanId.isEmpty) return const <String>[];

  final group = _setAssetGroup(cleanId);
  if (group.isEmpty) return const <String>[];

  final encodedId = Uri.encodeComponent(cleanId);
  final encodedGroup = Uri.encodeComponent(group);
  final localIds = <String>[
    '001',
    '1',
    '001a',
    '000',
  ];

  final candidates = <String>[];
  for (final localId in localIds) {
    final encodedLocalId = Uri.encodeComponent(localId);
    candidates.addAll(<String>[
      'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/$encodedLocalId/low.webp',
      'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/$encodedLocalId/low.png',
      'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/$encodedLocalId/high.webp',
      'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/$encodedLocalId/high.png',
      'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/$encodedLocalId/low.jpg',
      'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/$encodedLocalId/high.jpg',
    ]);
  }

  return candidates;
}

List<String> _cardPreviewCandidatesForSet(JapaneseTcgSetDetails details) {
  final candidates = <String>[];

  for (final card in details.cards.take(12)) {
    candidates.addAll(_cardImageCandidates(card.image));
    candidates.addAll(
      _cardImageCandidatesFromParts(
        setId: details.id,
        cardId: card.id,
        localId: card.localId,
      ),
    );
  }

  return candidates;
}

List<String> _cardImageCandidatesFromParts({
  required String setId,
  required String cardId,
  required String localId,
}) {
  final cleanSetId = setId.trim();
  if (cleanSetId.isEmpty) return const <String>[];

  final group = _setAssetGroup(cleanSetId);
  if (group.isEmpty) return const <String>[];

  final ids = <String>[
    localId.trim(),
    _localIdFromCardId(cardId, cleanSetId),
  ]
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  final candidates = <String>[];
  final encodedSetId = Uri.encodeComponent(cleanSetId);
  final encodedGroup = Uri.encodeComponent(group);

  for (final id in ids) {
    final encodedLocalId = Uri.encodeComponent(id);
    final base = 'https://assets.tcgdex.net/ja/$encodedGroup/$encodedSetId/$encodedLocalId';
    candidates.addAll(<String>[
      '$base/low.webp',
      '$base/low.png',
      '$base/high.webp',
      '$base/high.png',
      '$base/low.jpg',
      '$base/high.jpg',
      '$base.webp',
      '$base.png',
      '$base.jpg',
    ]);
  }

  return candidates;
}

String _localIdFromCardId(String cardId, String setId) {
  final cleanCardId = cardId.trim();
  final cleanSetId = setId.trim();
  if (cleanCardId.isEmpty || cleanSetId.isEmpty) return '';

  final prefix = '$cleanSetId-';
  if (cleanCardId.startsWith(prefix)) {
    return cleanCardId.substring(prefix.length).trim();
  }

  final parts = cleanCardId.split('-');
  return parts.isEmpty ? '' : parts.last.trim();
}


String _setAssetGroup(String setId) {
  final clean = setId.trim().toLowerCase();
  if (clean.isEmpty) return '';

  if (clean.startsWith('swsh')) return 'swsh';
  if (clean.startsWith('sv')) return 'sv';
  if (clean.startsWith('sm')) return 'sm';
  if (clean.startsWith('xy')) return 'xy';
  if (clean.startsWith('bw')) return 'bw';
  if (clean.startsWith('dp')) return 'dp';
  if (clean.startsWith('pl')) return 'pl';
  if (clean.startsWith('hgss')) return 'hgss';
  if (clean.startsWith('neo')) return 'neo';
  if (clean.startsWith('ex')) return 'ex';
  if (clean.startsWith('base')) return 'base';
  if (clean.startsWith('web')) return 'web';
  if (clean.startsWith('pcg')) return 'pcg';
  if (clean.startsWith('adv')) return 'adv';
  if (clean.startsWith('e')) return 'e';

  final match = RegExp(r'^[a-z]+').firstMatch(clean);
  return match?.group(0) ?? '';
}

List<String> _cardImageCandidates(String url) {
  final clean = _normaliseAssetUrl(url);
  if (clean.isEmpty) return const <String>[];

  if (_hasImageExtension(clean)) {
    return <String>[clean];
  }

  return <String>[
    '$clean/high.webp',
    '$clean/low.webp',
    '$clean/high.png',
    '$clean/low.png',
    '$clean/high.jpg',
    '$clean/low.jpg',
    '$clean.webp',
    '$clean.png',
    '$clean.jpg',
    '$clean.jpeg',
    clean,
  ];
}

String _normaliseAssetUrl(String url) {
  final clean = url.trim();
  if (clean.isEmpty) return '';
  if (clean.startsWith('https://') || clean.startsWith('http://')) return clean;
  if (clean.startsWith('//')) return 'https:$clean';
  if (clean.startsWith('/')) return 'https://assets.tcgdex.net$clean';
  return 'https://assets.tcgdex.net/$clean';
}

bool _hasImageExtension(String url) {
  final lower = url.toLowerCase().split('?').first;
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp');
}
