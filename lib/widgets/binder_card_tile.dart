import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import 'card_image_with_fallback.dart';
import 'glimmer_border.dart';
import 'variant_pill.dart';

class BinderCardTile extends StatelessWidget {
  const BinderCardTile({
    super.key,
    required this.card,
    required this.ownership,
    this.greyOutUnowned = false,
  });

  final TcgCard card;
  final CardOwnership ownership;
  final bool greyOutUnowned;

  bool get isOwned =>
      ownership.effectiveCopies > 0 ||
      ownership.normal ||
      ownership.reverseHolo ||
      ownership.holo;

  bool get hasShine => ownership.effectiveCopies > 1;

  ColorFilter _greyOutFilter(bool shouldGreyOut) {
    // Always show the real artwork in full colour. The inactive ownership pills
    // still make it clear when a card is missing.
    return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
  }

  Widget _buildCardArtwork({required bool shouldGreyOut}) {
    return ColorFiltered(
      colorFilter: _greyOutFilter(shouldGreyOut),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CardImageWithFallback(
            imageUrls: card.imageUrlCandidates,
            fit: BoxFit.cover,
            backgroundColor: const Color(0xFF102754),
          ),
        ],
      ),
    );
  }

  Widget _buildCardNumberBadge() {
    return Positioned(
      top: 6,
      left: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '#${card.number}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildCopyBadge({required bool shiny}) {
    if (ownership.effectiveCopies <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: shiny
              ? const Color(0xFFF7DE77)
              : Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'x${ownership.effectiveCopies}',
          style: TextStyle(
            color: shiny ? Colors.black : Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildVariantPills() {
    return Positioned(
      right: 6,
      bottom: 6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VariantPill(label: 'N', active: ownership.normal),
          const SizedBox(width: 3),
          VariantPill(label: 'RH', active: ownership.reverseHolo),
          const SizedBox(width: 3),
          VariantPill(label: 'H', active: ownership.holo),
        ],
      ),
    );
  }

  Widget _buildTileContent({required bool shouldGreyOut, required bool shiny}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCardArtwork(shouldGreyOut: shouldGreyOut),
          _buildCardNumberBadge(),
          _buildCopyBadge(shiny: shiny),
          _buildVariantPills(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shouldGreyOut = greyOutUnowned && !isOwned;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: 1,
      child: hasShine
          ? GlimmerBorder(
              borderRadius: 14,
              child: _buildTileContent(
                shouldGreyOut: shouldGreyOut,
                shiny: true,
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB(45, 0, 0, 0),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: _buildTileContent(
                shouldGreyOut: shouldGreyOut,
                shiny: false,
              ),
            ),
    );
  }
}
