import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import 'card_image_with_fallback.dart';
import 'set_logo_widgets.dart';

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
                Container(
                  width: 118,
                  constraints: const BoxConstraints(minHeight: 176),
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFF0A1D43),
                  child: Center(
                    child: CardImageWithFallback(
                      imageUrls: card.imageUrlCandidates,
                      fit: BoxFit.contain,
                      cacheWidth: 240,
                      cacheHeight: 340,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 44, 18, 20),
                    child: Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ResolvedSetLogo(
                          setId: card.setId,
                          setName: card.setName,
                          fallbackLogoUrl: card.setLogoUrl,
                          height: 50,
                          fit: BoxFit.contain,
                          cacheWidth: 240,
                          cacheHeight: 100,
                          textStyle: const TextStyle(
                            color: Color(0xFFE3E9F8),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
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
                    width: 34,
                    height: 34,
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
                              size: 22,
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
