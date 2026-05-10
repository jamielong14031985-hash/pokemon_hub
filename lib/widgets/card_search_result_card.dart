import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import 'card_image_with_fallback.dart';

class CardSearchResultCard extends StatefulWidget {
  const CardSearchResultCard({
    super.key,
    required this.card,
    required this.onOpenDetails,
  });

  final TcgCard card;
  final VoidCallback onOpenDetails;

  @override
  State<CardSearchResultCard> createState() => _CardSearchResultCardState();
}

class _CardSearchResultCardState extends State<CardSearchResultCard> {
  bool _saving = false;

  Future<void> _quickAddToPokedex() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final ownershipByCardId =
          await PokedexSyncService.loadCurrentUserSetOwnership(widget.card.setId);
      final existing = ownershipByCardId[widget.card.id] ?? const CardOwnership();

      ownershipByCardId[widget.card.id] = existing.copyWith(
        normal: true,
        copies: existing.effectiveCopies + 1,
      );

      await LocalPokedexStore.saveSetOwnershipMap(widget.card.setId, ownershipByCardId);
      await PokedexSyncService.syncCurrentSetForCurrentUser(widget.card.setId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${widget.card.name} to Set Pokédex '
            '(x${ownershipByCardId[widget.card.id]!.effectiveCopies} total)',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add this card right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: widget.onOpenDetails,
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 150,
                  child: CardImageWithFallback(
                    imageUrls: card.imageUrlCandidates,
                    fit: BoxFit.cover,
                    cacheWidth: 220,
                    cacheHeight: 300,
                    backgroundColor: Colors.black12,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 68, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Set: ${card.setName}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Number: ${card.number}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (card.rarity != null)
                          Text(
                            'Rarity: ${card.rarity}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        if (card.hp != null)
                          Text(
                            'HP: ${card.hp}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Tooltip(
              message: 'Quick add to Set Pokédex',
              child: Material(
                color: const Color(0xFFF7DE77),
                shape: const CircleBorder(),
                elevation: 1,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _saving ? null : _quickAddToPokedex,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Icon(
                              Icons.add_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
