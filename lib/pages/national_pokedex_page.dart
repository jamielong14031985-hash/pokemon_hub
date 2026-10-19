import 'dart:async';

import 'package:flutter/material.dart';

import '../models/national_pokedex_species.dart';
import '../services/national_pokedex_live_sync.dart';
import '../services/national_pokedex_service.dart';
import '../services/national_pokedex_featured_card_store.dart';
import '../services/national_pokedex_progress_cache.dart';

const _navy = Color(0xFF041B4A);
const _panel = Color(0xFF102754);
const _gold = Color(0xFFF7DE77);
const _muted = Color(0xFFBECDEB);

/// National Pokédex built automatically from cards the user actually owns.
/// The source of truth remains their existing set and custom binders.
class NationalPokedexPage extends StatefulWidget {
  const NationalPokedexPage({
    super.key,
    this.embedded = false,
    this.scrollHeader,
  });

  /// Display inside the Sets tab without a second app bar.
  final bool embedded;

  /// Optional Sets navigation, included inside this page's *single* scroll view.
  /// This lets the selector, progress summary, filters and card grid move together.
  final Widget? scrollHeader;

  @override
  State<NationalPokedexPage> createState() => _NationalPokedexPageState();
}

class _NationalPokedexPageState extends State<NationalPokedexPage> {
  List<NationalPokedexSpecies> _species = const [];
  Map<int, List<NationalOwnedCard>> _owned = const {};
  Map<int, String> _featuredCardIds = <int, String>{};
  int _generation = 0;
  int _page = 0;
  final PageController _gridPageController = PageController();
  bool _onlyOwned = false;
  bool _loadingCatalogue = true;
  String? _catalogueError;
  // Only recover missing artwork choices once per species during this view.
  final Map<int, Future<List<NationalOwnedCard>>> _choiceLookups = {};

  @override
  void initState() {
    super.initState();
    NationalPokedexLiveSync.revision.addListener(_onSavedProgressChanged);
    unawaited(_initialise());
  }

  @override
  void dispose() {
    NationalPokedexLiveSync.revision.removeListener(_onSavedProgressChanged);
    _gridPageController.dispose();
    super.dispose();
  }

  void _onSavedProgressChanged() {
    unawaited(_readLatestProgress());
  }

  Future<void> _readLatestProgress() async {
    try {
      final snapshot = await NationalPokedexProgressCache.load();
      if (!mounted || snapshot == null) return;
      setState(() {
        _owned = snapshot.result.cardsBySpecies;
        _choiceLookups.clear();
      });
    } catch (_) {
      // A temporary local-storage failure must not clear the visible grid.
    }
  }

  Future<void> _initialise() async {
    // Show saved discoveries *before* any optional background rescan. This
    // keeps previously found Pokémon visible across pages and app restarts.
    NationalPokedexProgressSnapshot? snapshot;
    try {
      final loaded = await Future.wait<Object?>([
        NationalPokedexFeaturedCardStore.load(),
        NationalPokedexProgressCache.load(),
      ]);
      if (!mounted) return;
      snapshot = loaded[1] as NationalPokedexProgressSnapshot?;
      setState(() {
        _featuredCardIds = loaded[0] as Map<int, String>;
        if (snapshot != null) {
          _owned = snapshot.result.cardsBySpecies;
        }
      });
    } catch (_) {
      // Storage being unavailable must not prevent the Pokédex from opening.
    }

    try {
      final species = await NationalPokedexService.loadSpecies();
      if (!mounted) return;
      setState(() {
        _species = species;
        _loadingCatalogue = false;
        _catalogueError = null;
      });

      // Ownership is reconciled in the background, with no user action.
      // Saved discoveries remain visible immediately while it runs. The
      // listener stays active after leaving the page, so future binder edits
      // also update the cache automatically.
      NationalPokedexLiveSync.start();
      NationalPokedexLiveSync.schedule();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCatalogue = false;
        _catalogueError =
            'Could not load National Pokédex. Check your connection and retry.';
      });
    }
  }

  List<NationalPokedexSpecies> get _selectedSpecies {
    Iterable<NationalPokedexSpecies> visible = _species;
    if (_generation > 0) {
      visible = visible.where((s) => s.generation == _generation);
    }
    if (_onlyOwned) {
      visible = visible.where((s) => _owned.containsKey(s.number));
    }
    return visible.toList(growable: false);
  }

  int get _generationOwned => _species
      .where((s) => (_generation == 0 || s.generation == _generation) &&
          _owned.containsKey(s.number)).length;

  int get _generationTotal => _species
      .where((s) => _generation == 0 || s.generation == _generation).length;

  // Keep the 3x3 grid and page indicator together when changing filters.
  void _resetGridPage() {
    _page = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _gridPageController.hasClients) {
        _gridPageController.jumpToPage(0);
      }
    });
  }

  void _selectGeneration(int next) {
    if (next == _generation) return;
    setState(() {
      _generation = next;
      _resetGridPage();
    });
  }

  void _goToGridPage(int targetPage, int pageCount) {
    final destination = targetPage.clamp(0, pageCount - 1).toInt();
    if (_gridPageController.hasClients) {
      _gridPageController.animateToPage(
        destination,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else if (_page != destination) {
      setState(() => _page = destination);
    }
  }

  NationalOwnedCard? _featuredFor(
      int speciesNumber, List<NationalOwnedCard> ownedCards) {
    return NationalPokedexFeaturedCardStore.selectedCard(
      ownedCards, _featuredCardIds[speciesNumber]);
  }

  Future<void> _chooseFeaturedCard(int speciesNumber, String? cardId) async {
    final previous = _featuredCardIds[speciesNumber];
    setState(() {
      if (cardId == null) {
        _featuredCardIds.remove(speciesNumber);
      } else {
        _featuredCardIds[speciesNumber] = cardId;
      }
    });
    try {
      await NationalPokedexFeaturedCardStore.save(
          Map<int, String>.from(_featuredCardIds));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          _featuredCardIds.remove(speciesNumber);
        } else {
          _featuredCardIds[speciesNumber] = previous;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save your chosen card. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _loadingCatalogue
        ? const Center(child: CircularProgressIndicator(color: _gold))
        : _catalogueError != null
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, color: _gold, size: 46),
                  const SizedBox(height: 14),
                  Text(_catalogueError!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () {
                    setState(() { _loadingCatalogue = true; _catalogueError = null; });
                    unawaited(_initialise());
                  }, child: const Text('Retry')),
                ]),
              ))
            : _buildContent();

    if (widget.embedded) {
      // The loaded page already includes scrollHeader as its first list item.
      // During loading and errors, keep the same header available for navigation.
      if (widget.scrollHeader == null ||
          (!_loadingCatalogue && _catalogueError == null)) {
        return content;
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          widget.scrollHeader!,
          SizedBox(height: 260, child: content),
        ],
      );
    }
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('National Pokédex'),
      ),
      body: content,
    );
  }

  /// Full-card artwork for discovered species, matching the 3x3 Set Pokédex
  /// binder tiles. Badges float over the picture rather than shrinking it.
  /// The currently selected owned printing controls the displayed artwork.
  Widget _buildOwnedCardSlot({
    required NationalPokedexSpecies species,
    required List<NationalOwnedCard> cards,
    required NationalOwnedCard? featured,
  }) {
    final url = featured?.imageUrl?.trim() ?? '';
    final multiple = cards.length > 1;
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSpecies(species, cards),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.75)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url.isNotEmpty)
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => _missingOwnedArtwork(
                      species.displayName),
                  )
                else
                  _missingOwnedArtwork(species.displayName),
                Positioned(
                  top: 6,
                  left: 6,
                  child: _cardSlotBadge(
                    species.labelNumber,
                    foreground: Colors.white,
                    background: Colors.black.withValues(alpha: .76),
                  ),
                ),
                // Do not display an invented quantity or holo badge: the
                // National Pokédex model knows which printings you own, not
                // their variant or per-printing copy totals.
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    width: 23,
                    height: 23,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold,
                    ),
                    child: const Icon(Icons.check_rounded,
                      size: 16, color: _navy),
                  ),
                ),
                if (multiple)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Tooltip(
                      message: 'Choose from ${cards.length} owned printings',
                      child: Container(
                        width: 26,
                        height: 23,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .76),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded,
                          size: 17, color: _gold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _missingOwnedArtwork(String title) {
    return Container(
      color: _panel,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style_outlined, size: 32, color: _gold),
          const SizedBox(height: 6),
          Text(title, textAlign: TextAlign.center,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white,
              fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Card image unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _cardSlotBadge(String label, {
    required Color foreground,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: background,
        borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(
        color: foreground, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  // Match Set Pokédex: nine cards per horizontally swipable page.
  // The inner grid cannot scroll vertically; the outer Sets page still can.
  Widget _buildGridPage(List<NationalPokedexSpecies> pageSpecies) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pageSpecies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: .76,
      ),
      itemBuilder: (context, index) {
        final species = pageSpecies[index];
        final myCards = _owned[species.number] ?? const <NationalOwnedCard>[];
        final owned = myCards.isNotEmpty;
        final featured = _featuredFor(species.number, myCards);
        // Owned Pokémon show their featured card exactly like a set
        // binder slot: full-bleed artwork and small overlay badges.
        // Missing Pokémon keep their familiar species silhouette.
        if (owned) {
          return _buildOwnedCardSlot(
            species: species,
            cards: myCards,
            featured: featured,
          );
        }
        return Material(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showSpecies(species, myCards),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(species.labelNumber,
                    style: const TextStyle(color: _muted,
                        fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                Expanded(child: Opacity(opacity: .45,
                  child: Image.network(species.artworkUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.catching_pokemon,
                      color: Colors.white38, size: 35)),
                )),
                Text(species.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted,
                      fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                const Icon(Icons.lock_outline,
                  color: Colors.white38, size: 14),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final visible = _selectedSpecies;
    final pageCount = visible.isEmpty ? 1 : (visible.length + 8) ~/ 9;
    final page = _page.clamp(0, pageCount - 1).toInt();
    if (page != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_page != page) setState(() => _page = page);
        if (_gridPageController.hasClients) {
          _gridPageController.jumpToPage(page);
        }
      });
    }
    final fraction = _generationTotal == 0 ? 0.0 : _generationOwned / _generationTotal;

    // Build the content as one non-scrolling group so the optional Sets
    // selector can live in this same scroll view (not above an Expanded list).
    final contentChildren = <Widget>[
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = _generation == index;
              return ChoiceChip(
                label: Text(index == 0 ? 'All Pokémon' : 'Gen $index'),
                selected: selected,
                onSelected: (_) => _selectGeneration(index),
                selectedColor: _gold,
                backgroundColor: _panel,
                side: BorderSide(color: selected ? _gold : Colors.white24),
                labelStyle: TextStyle(color: selected ? _navy : Colors.white,
                    fontWeight: FontWeight.w700),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_generation == 0 ? 'All generations' : 'Generation $_generation',
              style: const TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.bold)),
            Text('$_generationOwned of $_generationTotal discovered',
              style: const TextStyle(color: _muted, fontSize: 12.5)),
          ])),
          FilterChip(
            label: const Text('Owned only'),
            selected: _onlyOwned,
            onSelected: (value) => setState(() {
              _onlyOwned = value;
              _resetGridPage();
            }),
            labelStyle: TextStyle(color: _onlyOwned ? _navy : Colors.white),
            selectedColor: _gold, backgroundColor: _panel,
            showCheckmark: false,
          ),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: fraction, minHeight: 4,
          color: _gold, backgroundColor: Colors.white12),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'No Pokémon in this filter yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // One PageView contains a 3 x 3 grid. A bounded height lets
              // horizontal swipes work without trapping vertical page scroll.
              final tileWidth = (constraints.maxWidth - 18) / 3;
              final gridHeight = tileWidth / .76 * 3 + 18;
              return SizedBox(
                height: gridHeight,
                child: PageView.builder(
                  controller: _gridPageController,
                  physics: const BouncingScrollPhysics(),
                  allowImplicitScrolling: true,
                  itemCount: pageCount,
                  onPageChanged: (index) {
                    if (!mounted || _page == index) return;
                    setState(() => _page = index);
                  },
                  itemBuilder: (context, pageIndex) {
                    final pageSpecies = visible
                        .skip(pageIndex * 9)
                        .take(9)
                        .toList(growable: false);
                    return _buildGridPage(pageSpecies);
                  },
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(
            tooltip: 'Previous nine Pokémon',
            onPressed: page > 0
                ? () => _goToGridPage(page - 1, pageCount)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 18),
          Text('Page ${page + 1} of $pageCount',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
          const SizedBox(width: 18),
          IconButton.filledTonal(
            tooltip: 'Next nine Pokémon',
            onPressed: page < pageCount - 1
                ? () => _goToGridPage(page + 1, pageCount)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
        const SizedBox(height: 12),
        const Text('Pokémon species artwork is for Pokédex navigation. Owned cards are read from your existing set binders.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 11)),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.scrollHeader == null
          ? const EdgeInsets.fromLTRB(14, 12, 14, 24)
          : const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: widget.scrollHeader == null
          ? contentChildren
          : <Widget>[
              widget.scrollHeader!,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: contentChildren,
                ),
              ),
            ],
    );
  }

  /// The collector can choose their favourite *owned* printing. If the local
  /// Pokédex currently recognises just one, quietly search for other owned
  /// printings when the picker opens; no "Refresh" button is necessary.
  Future<List<NationalOwnedCard>> _discoverOwnedChoices(
    NationalPokedexSpecies species,
    List<NationalOwnedCard> current,
  ) async {
    try {
      final found = await NationalPokedexService.recheckSpeciesPrintings(
        species, current,
      );
      if (found.length <= current.length) return current;
      if (mounted) {
        setState(() {
          _owned = Map<int, List<NationalOwnedCard>>.from(_owned)
            ..[species.number] = found;
        });
      }
      // Persist recovered choices, without changing owned quantities.
      final signature = await NationalPokedexService.ownershipSignature();
      final saved = await NationalPokedexProgressCache.load();
      if (saved != null && saved.ownershipSignature == signature) {
        final updated = Map<int, List<NationalOwnedCard>>.from(
          saved.result.cardsBySpecies,
        )..[species.number] = found;
        await NationalPokedexProgressCache.save(
          signature,
          NationalPokedexResult(
            cardsBySpecies: updated,
            cardsPendingIdentification:
                saved.result.cardsPendingIdentification,
            cardsWithoutSpeciesMatch:
                saved.result.cardsWithoutSpeciesMatch,
          ),
        );
      } else {
        // An edit arrived during the search: the normal ownership watcher
        // will build a new snapshot from the latest collection.
        NationalPokedexLiveSync.schedule();
      }
      return found;
    } catch (_) {
      return current;
    }
  }

  void _showSpecies(NationalPokedexSpecies species, List<NationalOwnedCard> cards) {
    final future = cards.isNotEmpty && cards.length < 2
        ? _choiceLookups.putIfAbsent(
            species.number, () => _discoverOwnedChoices(species, cards))
        : Future<List<NationalOwnedCard>>.value(cards);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => FutureBuilder<List<NationalOwnedCard>>(
        future: future,
        initialData: cards,
        builder: (context, choiceSnapshot) {
          final choices = choiceSnapshot.data ?? cards;
          final selectedCard = _featuredFor(species.number, choices);
          final preferredId = _featuredCardIds[species.number];
          return SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Image.network(species.artworkUrl, height: 105,
                errorBuilder: (_, __, ___) => const Icon(Icons.catching_pokemon,
                  color: _gold, size: 70))),
              const SizedBox(height: 8),
              Text('${species.labelNumber} · ${species.displayName}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 23,
                  fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(choices.isEmpty
                ? 'Missing — add a matching Pokémon card to your collection.'
                : 'Discovered · ${choices.length} different owned card entries',
                textAlign: TextAlign.center,
                style: TextStyle(color: choices.isEmpty ? _muted : _gold)),
              if (choices.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Choose your Pokédex card',
                  style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Tap an owned card to display its artwork in your National Pokédex. Other cards stay in your collection.',
                  style: TextStyle(color: _muted, fontSize: 12.5)),
                const SizedBox(height: 14),
                // Automatic mode lets collectors remove a previously pinned
                // choice and return to whichever matching card comes first.
                Material(
                  color: const Color(0xFF0B2050),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_chooseFeaturedCard(species.number, null));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Icon(preferredId == null
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                          color: preferredId == null ? _gold : _muted),
                        const SizedBox(width: 12),
                        const Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Automatic selection',
                              style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold)),
                            Text('Show the first matching card I own',
                              style: TextStyle(color: _muted, fontSize: 12)),
                          ],
                        )),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                for (final card in choices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Material(
                      color: card.cardId == preferredId
                        ? const Color(0xFF173D76) : const Color(0xFF0B2050),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_chooseFeaturedCard(
                            species.number, card.cardId));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: card.cardId == preferredId
                                ? _gold : Colors.white12,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(children: [
                            SizedBox(
                              width: 61,
                              height: 85,
                              child: card.imageUrl?.isNotEmpty == true
                                ? Image.network(card.imageUrl!, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.style_outlined,
                                        color: _muted, size: 30))
                                : const Icon(Icons.style_outlined,
                                    color: _muted, size: 30),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(card.name,
                                  style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(card.setName, maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: _muted,
                                    fontSize: 12)),
                                if (selectedCard?.cardId == card.cardId) ...[
                                  const SizedBox(height: 6),
                                  const Text('Currently displayed',
                                    style: TextStyle(color: _gold,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold)),
                                ],
                              ],
                            )),
                            Icon(card.cardId == preferredId
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                              color: card.cardId == preferredId ? _gold : _muted),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
        },
      ),
    );
  }
}
