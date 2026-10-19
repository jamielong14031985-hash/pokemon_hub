import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/set_card_details_result.dart';
import '../models/tcg_card.dart';
import '../models/tcg_set.dart';
import '../pages/set_card_details_page.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../utils/card_number_sorter.dart';
import '../utils/master_set_slot_helpers.dart';
import 'set_logo_widgets.dart';

class SetSearchResultCard extends StatelessWidget {
  const SetSearchResultCard({
    super.key,
    required this.set,
  });

  final TcgSet set;

  static const Color _cardColor = Color(0xFF102754);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  void _openSet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SetSearchCardsPage(set: set),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCards = set.total;
    final badges = <Widget>[
      if (totalCards > 0) _SetBadge(label: '$totalCards cards'),
      if (set.series.trim().isNotEmpty) _SetBadge(label: set.series.trim()),
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
                  child: ResolvedSetLogo(
                    setId: set.id,
                    setName: set.name,
                    fallbackLogoUrl: set.logoUrl,
                    height: 94,
                    fit: BoxFit.contain,
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
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
                        color: SetSearchResultCard._softTextColor,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: SetSearchResultCard._softTextColor,
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
          color: SetSearchResultCard._softTextColor,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}


class SetSearchCardsPage extends StatefulWidget {
  const SetSearchCardsPage({
    super.key,
    required this.set,
  });

  final TcgSet set;

  @override
  State<SetSearchCardsPage> createState() => _SetSearchCardsPageState();
}

class _SetSearchCardsPageState extends State<SetSearchCardsPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  late Future<List<TcgCard>> _futureCards;
  final Map<String, CardOwnership> _ownershipByCardId = <String, CardOwnership>{};
  final Set<String> _precachedImageUrls = <String>{};
  bool _loadedOwnership = false;

  @override
  void initState() {
    super.initState();
    _futureCards = _loadCards();
    _loadOwnership();
  }

  Future<List<TcgCard>> _loadCards() async {
    final cards = await PokemonTcgService.fetchCardsBySet(widget.set.id);
    cards.sort((a, b) => compareCardNumbers(a.number, b.number));
    return cards;
  }

  Future<void> _loadOwnership() async {
    try {
      final loaded = await PokedexSyncService.loadCurrentUserSetOwnership(widget.set.id);
      _ownershipByCardId
        ..clear()
        ..addAll(loaded);
    } catch (_) {
      // The card list should still open even if collection sync fails.
    }

    if (!mounted) return;
    setState(() {
      _loadedOwnership = true;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loadedOwnership = false;
      _futureCards = _loadCards();
    });
    await Future.wait<void>([
      _futureCards.then((_) {}),
      _loadOwnership(),
    ]);
  }

  CardOwnership _ownershipFor(TcgCard card) {
    return _ownershipByCardId[card.id] ?? const CardOwnership();
  }

  int _savedCardCount(List<TcgCard> cards) {
    return cards.where((card) => _ownershipFor(card).effectiveCopies > 0).length;
  }

  void _precacheVisibleImages(List<TcgCard> cards) {
    if (!mounted) return;
    final urlsToWarm = <String>[];
    for (final card in cards.take(18)) {
      final imageUrl = (card.imageUrl ?? card.largeImageUrl ?? '').trim();
      if (imageUrl.isEmpty) continue;
      if (_precachedImageUrls.add(imageUrl)) {
        urlsToWarm.add(imageUrl);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final imageUrl in urlsToWarm) {
        precacheImage(NetworkImage(imageUrl), context).catchError((_) {});
      }
    });
  }


  // Open one persistent viewer. Previously every swipe popped this route,
  // exposed the set grid, then pushed another detail route.
  Future<void> _openCardDetails({
    required List<TcgCard> cards,
    required int index,
  }) async {
    if (index < 0 || index >= cards.length) return;

    var navigatedBetweenCards = false;
    final result = await Navigator.of(context).push<SetCardDetailsResult>(
      MaterialPageRoute<SetCardDetailsResult>(
        builder: (_) => _SearchSetSwipeViewer(
          cards: cards,
          initialIndex: index,
          ownershipFor: _ownershipFor,
          onCardLeft: (cardId, updatedOwnership) {
            // Keep edits in memory during swipes. Sync only once on exit.
            _ownershipByCardId[cardId] = updatedOwnership;
            navigatedBetweenCards = true;
          },
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      _ownershipByCardId[result.cardId] = result.ownership;
    }

    if (result != null || navigatedBetweenCards) {
      setState(() {});
      await LocalPokedexStore.saveSetOwnershipMap(
        widget.set.id,
        _ownershipByCardId,
      );
      await PokedexSyncService.syncCurrentSetForCurrentUser(widget.set.id);
    } else {
      await _loadOwnership();
    }
  }

  Widget _buildSetHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 112,
            width: double.infinity,
            child: Center(
              child: ResolvedSetLogo(
                setId: widget.set.id,
                setName: widget.set.name,
                fallbackLogoUrl: widget.set.logoUrl,
                height: 94,
                fit: BoxFit.contain,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _CenteredBadgeRow(
            badges: [
              if (widget.set.total > 0) _SetBadge(label: '${widget.set.total} cards'),
              if (widget.set.series.trim().isNotEmpty) _SetBadge(label: widget.set.series.trim()),
              if (widget.set.releaseDate.trim().isNotEmpty)
                _SetBadge(label: widget.set.releaseDate.trim()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardsSummary({
    required int cardCount,
    required int savedCount,
  }) {
    return Text(
      _loadedOwnership
          ? 'Showing $cardCount cards from this set\n• $savedCount saved to your collection.'
          : 'Showing $cardCount cards from this set\n• Loading your collection...',
      style: const TextStyle(
        color: _softTextColor,
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
        title: Text(widget.set.name),
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
      body: FutureBuilder<List<TcgCard>>(
        future: _futureCards,
        builder: (context, snapshot) {
          final cards = snapshot.data ?? const <TcgCard>[];

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
                  _buildSetHero(),
                  const SizedBox(height: 14),
                  _SetInfoCard(
                    icon: Icons.wifi_off_rounded,
                    title: 'Could not load cards',
                    message: 'The set opened, but the card list could not be loaded.',
                    onRetry: _refresh,
                  ),
                ],
              ),
            );
          }

          _precacheVisibleImages(cards);
          final savedCount = _savedCardCount(cards);

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
                            _buildSetHero(),
                            const SizedBox(height: 16),
                            _buildCardsSummary(
                              cardCount: cards.length,
                              savedCount: savedCount,
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
                          child: _SetInfoCard(
                            icon: Icons.collections_bookmark_outlined,
                            title: 'No cards shown yet',
                            message: 'No cards were returned for this set.',
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
                              return _SearchSetCardTile(
                                card: card,
                                ownership: _ownershipFor(card),
                                onTap: () => _openCardDetails(
                                  cards: cards,
                                  index: index,
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


// Keep the search-set card route mounted while swiping; the card detail widget
// changes in place so the set grid does not appear between cards.
class _SearchSetSwipeViewer extends StatefulWidget {
  const _SearchSetSwipeViewer({
    required this.cards,
    required this.initialIndex,
    required this.ownershipFor,
    required this.onCardLeft,
  });

  final List<TcgCard> cards;
  final int initialIndex;
  final CardOwnership Function(TcgCard card) ownershipFor;
  final void Function(String cardId, CardOwnership ownership) onCardLeft;

  @override
  State<_SearchSetSwipeViewer> createState() => _SearchSetSwipeViewerState();
}

class _SearchSetSwipeViewerState extends State<_SearchSetSwipeViewer> {
  late int _index;
  final Set<String> _preloadedImageUrls = <String>{};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _preloadNeighbours();
  }

  void _preloadNeighbours() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final index in <int>[_index - 1, _index + 1]) {
        if (index < 0 || index >= widget.cards.length) continue;
        final card = widget.cards[index];
        final url = (card.largeImageUrl ?? card.imageUrl ?? '').trim();
        if (url.isEmpty || !_preloadedImageUrls.add(url)) continue;
        precacheImage(NetworkImage(url), context).catchError((_) {});
      }
    });
  }

  void _onSwipeNavigate(int nextIndex, CardOwnership currentOwnership) {
    if (!mounted || nextIndex < 0 || nextIndex >= widget.cards.length) return;
    final currentCard = widget.cards[_index];
    widget.onCardLeft(currentCard.id, currentOwnership);
    setState(() => _index = nextIndex);
    _preloadNeighbours();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_index];
    return SetCardDetailsPage(
      key: ValueKey<String>('search-set-card-${card.id}-$_index'),
      card: card,
      ownership: widget.ownershipFor(card),
      navigationCards: widget.cards,
      navigationIndex: _index,
      initialSlotKind: MasterSetSlotKind.normal,
      onSwipeNavigate: _onSwipeNavigate,
    );
  }
}

class _SearchSetCardTile extends StatelessWidget {
  const _SearchSetCardTile({
    required this.card,
    required this.ownership,
    required this.onTap,
  });

  final TcgCard card;
  final CardOwnership ownership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copies = ownership.effectiveCopies;
    final imageUrl = (card.imageUrl ?? card.largeImageUrl ?? '').trim();

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
              child: imageUrl.isEmpty
                  ? Container(
                      color: const Color(0xFF0E2A5E),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFFF7DE77),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF0E2A5E),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFFF7DE77),
                        ),
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
                    color: const Color(0xFFF7DE77),
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

class _CenteredBadgeRow extends StatelessWidget {
  const _CenteredBadgeRow({required this.badges});

  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return SizedBox(
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
    );
  }
}

class _SetInfoCard extends StatelessWidget {
  const _SetInfoCard({
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.32),
              ),
            ),
            child: Icon(icon, color: const Color(0xFFF7DE77)),
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
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
