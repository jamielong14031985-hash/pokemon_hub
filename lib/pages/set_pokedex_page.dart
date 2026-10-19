import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/set_card_details_result.dart';
import '../models/tcg_card.dart';
import '../models/tcg_set.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../utils/card_number_sorter.dart';
import '../utils/master_set_slot_helpers.dart';
import '../widgets/collection_stat_card.dart';
import '../widgets/master_set_slot_tile.dart';
import '../widgets/set_logo_widgets.dart';
import 'first_partner_promo_cards_page.dart';
import 'set_card_details_page.dart';
import 'thirty_celebration_price_audit_page.dart';

class SetPokedexPage extends StatefulWidget {
  const SetPokedexPage({super.key, required this.set});

  final TcgSet set;

  @override
  State<SetPokedexPage> createState() => _SetPokedexPageState();
}

class _SetPokedexPageState extends State<SetPokedexPage> {
  late Future<List<TcgCard>> _futureCards;
  late final PageController _pokedexPageController;
  final Map<String, CardOwnership> _ownershipByCardId = <String, CardOwnership>{};
  bool _loadedOwned = false;
  List<TcgCard> _allCards = <TcgCard>[];
  final Set<String> _precachedImageUrls = <String>{};
  int _currentPage = 1;
  bool _showMissingOnly = false;
  static const int _cardsPerPage = 9;

  static const ColorFilter _missingCardGreyFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();
    _pokedexPageController = PageController();
    _futureCards = _loadCards();
    _loadOwnership();
  }

  @override
  void dispose() {
    _pokedexPageController.dispose();
    super.dispose();
  }

  Future<List<TcgCard>> _loadCards() async {
    if (widget.set.id.trim().toLowerCase() == 'mep') {
      // This is the First Partner Series Collection 2026 binder, not the
      // unfiltered MEP promo catalogue. Only the 27 designated promo cards
      // belong in this specific view. Combining full remote MEP results
      // and historical saved IDs created duplicates such as 037-bulbasaur.
      // This does not delete or rewrite anyone's saved collection data.
      final cards = FirstPartnerPromoCardsPage.knownMepPromoCards().toList()
        ..sort((a, b) => compareCardNumbers(a.number, b.number));
      _allCards = cards;
      return cards;
    }

    final cards = await PokemonTcgService.fetchCardsBySet(widget.set.id);
    cards.sort((a, b) => compareCardNumbers(a.number, b.number));
    _allCards = cards;
    return cards;
  }

  Future<void> _loadOwnership() async {
    try {
      final loaded = await PokedexSyncService.loadCurrentUserSetOwnership(widget.set.id);
      _ownershipByCardId
        ..clear()
        ..addAll(loaded);
    } catch (_) {
      // Cards should still open quickly even if ownership sync is slow or fails.
    }

    if (mounted) {
      setState(() {
        _loadedOwned = true;
      });
    }
  }

  Future<void> _saveOwnership() async {
    await LocalPokedexStore.saveSetOwnershipMap(widget.set.id, _ownershipByCardId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(widget.set.id);
  }

  CardOwnership _ownershipFor(TcgCard card) {
    final canonical = _ownershipByCardId[card.id] ?? const CardOwnership();
    if (widget.set.id.trim().toLowerCase() != 'mep') return canonical;

    // An older provider sometimes appended the card name to the ID:
    //   mep-037-bulbasaur versus mep-037.
    // Read that *same-name* record as an ownership alias, so two actual
    // Bulbasaur copies show on one checklist card. Never match merely on
    // promo number: mep-037-ns-zekrom is not a Bulbasaur card.
    final slug = card.name.trim().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final alias = _ownershipByCardId['${card.id}-$slug'];
    if (alias != null && alias.collectionCount > canonical.collectionCount) {
      return alias;
    }
    return canonical;
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

  Widget _buildOwnedColourState({
    required bool isOwned,
    required Widget child,
  }) {
    if (isOwned) {
      return child;
    }

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

      final pageEnd = (pageStart + _cardsPerPage)
          .clamp(0, visibleSlots.length)
          .toInt();

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

  Route<dynamic> _buildCardDetailsRoute({
    required MasterSetCardSlot slot,
    required List<MasterSetCardSlot> visibleSlots,
    required int currentIndex,
    required bool slideFromRight,
  }) {
    return PageRouteBuilder<dynamic>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _BinderCardSwipeViewer(
          slots: visibleSlots,
          initialIndex: currentIndex,
          ownershipFor: _ownershipFor,
          onCardLeft: (cardId, updated) {
            // Keep unsaved edits when changing cards. Persist as one batch
            // when the viewer finally closes, not on every horizontal swipe.
            _ownershipByCardId[cardId] = updated;
          },
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
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _quickAddSlot(MasterSetCardSlot slot) async {
    final ownership = _ownershipFor(slot.card);
    await _updateOwnership(slot.card, slot.addOne(ownership));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${slot.label} added to Set Pokédex')),
    );
  }

  Future<void> _openCardDetailsFromSlot({
    required List<MasterSetCardSlot> visibleSlots,
    required MasterSetCardSlot slot,
  }) async {
    if (visibleSlots.isEmpty) return;

    var currentIndex = visibleSlots.indexWhere(
      (candidate) => candidate.card.id == slot.card.id && candidate.kind == slot.kind,
    );
    if (currentIndex < 0) currentIndex = 0;

    // One route for the whole browsing session. Swipes inside the viewer do
    // not return to this binder or trigger a database sync between cards.
    final result = await Navigator.of(context).push<dynamic>(
      _buildCardDetailsRoute(
        slot: visibleSlots[currentIndex],
        visibleSlots: visibleSlots,
        currentIndex: currentIndex,
        slideFromRight: true,
      ),
    );
    if (!mounted) return;

    if (result is SetCardDetailsResult) {
      _ownershipByCardId[result.cardId] = result.ownership;
    } else if (result is CardOwnership) {
      _ownershipByCardId[visibleSlots[currentIndex].card.id] = result;
    }

    setState(() {});
    await _saveOwnership();
  }

  List<TcgCard> get _filteredCards {
    final list = _allCards.toList();
    list.sort((a, b) => compareCardNumbers(a.number, b.number));
    return list;
  }

  Future<void> _showPagePicker({
    required int currentPage,
    required int totalPages,
  }) async {
    final pickedPage = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF102754),
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
                            color: selected ? const Color(0xFFF7DE77) : const Color(0xFF16366E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? const Color(0xFFF7DE77) : const Color(0xFF3F5C96),
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

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFF7DE77);

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        toolbarHeight: 44,
        title: const Text(''),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        actions: <Widget>[
          if (widget.set.id.trim().toLowerCase() == '30th')
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const ThirtyCelebrationPriceAuditPage(),
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined, color: Color(0xFFF7DE77)),
              label: const Text('Price audit',
                  style: TextStyle(color: Color(0xFFF7DE77))),
            ),
        ],
      ),
      body: FutureBuilder<List<TcgCard>>(
        future: _futureCards,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load cards: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final visibleCards = _filteredCards;
          final allSlots = buildMasterSetSlots(visibleCards);
          final ownedCount = allSlots
              .where((slot) => slot.isOwned(_ownershipFor(slot.card)))
              .length;
          final total = allSlots.length;
          final missingCount = total - ownedCount;
          final visibleSlots = _showMissingOnly
              ? allSlots
                  .where((slot) => !slot.isOwned(_ownershipFor(slot.card)))
                  .toList()
              : allSlots;
          final percent = total == 0 ? 0 : ((ownedCount / total) * 100).round();
          final cardsPerPage = _cardsPerPage;
          final totalPages = visibleSlots.isEmpty ? 1 : ((visibleSlots.length - 1) ~/ cardsPerPage) + 1;
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
                children: [
                  Transform.translate(
                    // Use the same header position for First Partner and
                    // other set pages (including 30th Celebration).
                    offset: const Offset(0, 6),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, right: 2),
                      child: Column(
                        children: [
                          widget.set.id.trim().toLowerCase() == 'mep'
                              ? SizedBox(
                                  height: 64,
                                  child: Center(
                                    // Keep the full logo within the same
                                    // 64 logical-pixel slot as normal set logos.
                                    // Do not paint it outside its bounds.
                                    child: Image.asset(
                                      'assets/images/first_partner_series_collection_logo.png',
                                      height: 64,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Text(
                                        'First Partner Series Collection 2026',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : ResolvedSetLogo(
                                  setId: widget.set.id,
                                  setName: widget.set.name,
                                  fallbackLogoUrl: widget.set.logoUrl,
                                  height: 64,
                                  fit: BoxFit.contain,
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: CollectionStatCard(
                                  label: 'Owned',
                                  value: _loadedOwned ? '$ownedCount/$total' : '...',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CollectionStatCard(
                                  label: 'Complete',
                                  value: _loadedOwned ? '$percent%' : '...',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: total == 0 ? 0 : ownedCount / total,
                            minHeight: 5,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  !_loadedOwned
                                      ? 'Cards loaded • loading your collection...'
                                      : _showMissingOnly
                                          ? '$missingCount missing slots shown'
                                          : '$missingCount missing • $ownedCount owned',
                                  style: const TextStyle(
                                    color: Color(0xFFC8D4F0),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 34,
                                child: FilledButton.tonalIcon(
                                  onPressed: _loadedOwned
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
                                    _showMissingOnly
                                        ? Icons.dashboard_outlined
                                        : Icons.filter_alt_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _showMissingOnly ? 'Show all' : 'Missing only',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: visibleSlots.isEmpty
                        ? Center(
                            child: Text(
                              _showMissingOnly
                                  ? 'No missing cards in this set. Nice work!'
                                  : 'No cards found in this set.',
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        : PageView.builder(
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
                              final pageStart = pageIndex * cardsPerPage;
                              final pageEnd = (pageStart + cardsPerPage)
                                  .clamp(0, visibleSlots.length)
                                  .toInt();
                              final pageSlots = visibleSlots.sublist(pageStart, pageEnd);

                              return AnimatedPadding(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: GridView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  itemCount: pageSlots.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                    childAspectRatio: 0.76,
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
                                          if (isOwned) {
                                            await _openCardDetailsFromSlot(
                                              visibleSlots: visibleSlots,
                                              slot: slot,
                                            );
                                            return;
                                          }
                                          await _quickAddSlot(slot);
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

// Keep one card-detail route open while moving between binder cards.
// This avoids flashing the binder and rebuilding its entire navigation stack
// on every swipe. Only the selected card widget is replaced.
class _BinderCardSwipeViewer extends StatefulWidget {
  const _BinderCardSwipeViewer({
    required this.slots,
    required this.initialIndex,
    required this.ownershipFor,
    required this.onCardLeft,
  });

  final List<MasterSetCardSlot> slots;
  final int initialIndex;
  final CardOwnership Function(TcgCard card) ownershipFor;
  final void Function(String cardId, CardOwnership ownership) onCardLeft;

  @override
  State<_BinderCardSwipeViewer> createState() => _BinderCardSwipeViewerState();
}

class _BinderCardSwipeViewerState extends State<_BinderCardSwipeViewer> {
  late int _index;
  late final List<TcgCard> _cards;
  late final List<MasterSetSlotKind> _kinds;
  final Set<String> _warming = <String>{};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _cards = widget.slots.map((slot) => slot.card).toList(growable: false);
    _kinds = widget.slots.map((slot) => slot.kind).toList(growable: false);
    _warmNeighbourImages();
  }

  // Cache only adjacent card images. Network requests are asynchronous, and
  // the user never needs to wait for an image to start the next swipe.
  void _warmNeighbourImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final nearby in <int>[_index - 1, _index + 1]) {
        if (nearby < 0 || nearby >= widget.slots.length) continue;
        final card = widget.slots[nearby].card;
        final url = (card.largeImageUrl ?? card.imageUrl ?? '').trim();
        if (url.isEmpty || !_warming.add(url)) continue;
        precacheImage(NetworkImage(url), context).catchError((_) {});
      }
    });
  }

  void _goTo(int nextIndex, CardOwnership currentOwnership) {
    if (!mounted || nextIndex < 0 || nextIndex >= widget.slots.length) return;
    final currentSlot = widget.slots[_index];
    widget.onCardLeft(currentSlot.card.id, currentOwnership);
    setState(() => _index = nextIndex);
    _warmNeighbourImages();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slots[_index];
    return SetCardDetailsPage(
      key: ValueKey<String>('binder-slot-$_index-${slot.card.id}'),
      card: slot.card,
      ownership: widget.ownershipFor(slot.card),
      initialSlotKind: slot.kind,
      navigationCards: _cards,
      navigationSlotKinds: _kinds,
      navigationIndex: _index,
      onSwipeNavigate: _goTo,
    );
  }
}
