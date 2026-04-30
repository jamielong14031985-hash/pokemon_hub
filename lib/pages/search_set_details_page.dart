import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import '../models/tcg_set.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../utils/card_number_sorter.dart';
import '../utils/master_set_slot_helpers.dart';
import '../widgets/master_set_slot_tile.dart';
import '../widgets/set_info_chip.dart';
import '../widgets/set_logo_widgets.dart';
import 'set_card_details_page.dart';

class SearchSetDetailsPage extends StatefulWidget {
  const SearchSetDetailsPage({
    super.key,
    required this.set,
    this.initialCardsFuture,
  });

  final TcgSet set;
  final Future<List<TcgCard>>? initialCardsFuture;

  @override
  State<SearchSetDetailsPage> createState() => _SearchSetDetailsPageState();
}

class _SearchSetDetailsPageState extends State<SearchSetDetailsPage> {
  late Future<List<TcgCard>> _cardsFuture;
  final Map<String, CardOwnership> _ownershipByCardId = <String, CardOwnership>{};
  bool _loadedOwnership = false;
  bool _showMissingOnly = false;

  @override
  void initState() {
    super.initState();
    _cardsFuture = widget.initialCardsFuture ?? PokemonTcgService.fetchCardsBySet(widget.set.id);
    _loadOwnership();
  }

  Future<void> _loadOwnership() async {
    final loaded = await PokedexSyncService.loadCurrentUserSetOwnership(widget.set.id);
    _ownershipByCardId
      ..clear()
      ..addAll(loaded);

    if (mounted) {
      setState(() {
        _loadedOwnership = true;
      });
    }
  }

  Future<void> _saveOwnership() async {
    await LocalPokedexStore.saveSetOwnershipMap(widget.set.id, _ownershipByCardId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(widget.set.id);
  }

  CardOwnership _ownershipFor(TcgCard card) {
    return _ownershipByCardId[card.id] ?? const CardOwnership();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(widget.set.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF102754),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ResolvedSetLogo(
                      setId: widget.set.id,
                      setName: widget.set.name,
                      fallbackLogoUrl: widget.set.logoUrl,
                      height: 72,
                      fit: BoxFit.contain,
                      cacheWidth: 360,
                      cacheHeight: 144,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SetInfoChip(label: '${widget.set.total} cards'),
                      SetInfoChip(label: widget.set.series),
                      SetInfoChip(label: widget.set.releaseDate),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!_loadedOwnership)
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
                        'Loading your saved card status...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            FutureBuilder<List<TcgCard>>(
              future: _cardsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
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
                              'Loading set cards...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    color: const Color(0xFF5B1D28),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load set cards: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }

                final cards = (snapshot.data ?? const <TcgCard>[]).toList()
                  ..sort((a, b) => compareCardNumbers(a.number, b.number));
                final masterSetSlots = buildMasterSetSlots(cards);
                final ownedSlots = masterSetSlots
                    .where((slot) => slot.isOwned(_ownershipFor(slot.card)))
                    .length;
                final missingSlots = masterSetSlots.length - ownedSlots;
                final visibleSlots = _showMissingOnly
                    ? masterSetSlots
                        .where((slot) => !slot.isOwned(_ownershipFor(slot.card)))
                        .toList()
                    : masterSetSlots;

                if (cards.isEmpty) {
                  return Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFF102754),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'No cards found in this set.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _showMissingOnly
                            ? 'Showing $missingSlots missing slots from ${masterSetSlots.length} master set slots.'
                            : 'Showing ${masterSetSlots.length} master set slots from ${cards.length} printed cards • $missingSlots missing.',
                        style: const TextStyle(
                          color: Color(0xFFD8E3FB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF102754),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _showMissingOnly
                              ? const Color(0xFFF7DE77).withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
                            ),
                            child: Icon(
                              _showMissingOnly
                                  ? Icons.visibility_off_outlined
                                  : Icons.grid_view_rounded,
                              color: const Color(0xFFF7DE77),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _showMissingOnly ? 'Missing cards only' : 'Full set view',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$ownedSlots owned • $missingSlots missing',
                                  style: const TextStyle(
                                    color: Color(0xFFC8D4F0),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => setState(() {
                              _showMissingOnly = !_showMissingOnly;
                            }),
                            icon: Icon(
                              _showMissingOnly
                                  ? Icons.dashboard_outlined
                                  : Icons.filter_alt_rounded,
                              size: 18,
                            ),
                            label: Text(_showMissingOnly ? 'Show all' : 'Missing only'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (visibleSlots.isEmpty)
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: const Color(0xFF102754),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          _showMissingOnly
                              ? 'No missing cards in this view. Nice work!'
                              : 'No cards found in this set.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleSlots.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.71,
                      ),
                      itemBuilder: (context, index) {
                        final slot = visibleSlots[index];
                        final card = slot.card;
                        final ownership = _ownershipFor(card);

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onLongPress: () async {
                            setState(() {
                              _ownershipByCardId[card.id] = slot.toggleOwnership(ownership);
                            });
                            await _saveOwnership();
                          },
                          onTap: () async {
                            final updatedOwnership = await Navigator.of(context).push<CardOwnership>(
                              MaterialPageRoute(
                                builder: (_) => SetCardDetailsPage(
                                  card: card,
                                  ownership: ownership,
                                ),
                              ),
                            );
                            if (updatedOwnership != null) {
                              setState(() {
                                _ownershipByCardId[card.id] = updatedOwnership;
                              });
                              await _saveOwnership();
                            }
                          },
                          child: MasterSetSlotTile(
                            slot: slot,
                            ownership: ownership,
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 12),
          const Text(
            'Tap a card to open its details, or long-press a Normal, RH, or H slot to quickly toggle that exact master set slot.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}


