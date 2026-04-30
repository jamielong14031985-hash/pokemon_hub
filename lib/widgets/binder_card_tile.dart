import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
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

  @override
  Widget build(BuildContext context) {
    final shouldGreyOut = greyOutUnowned && !isOwned;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: shouldGreyOut ? 0.58 : 1,
      child: hasShine
          ? GlimmerBorder(
              borderRadius: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: shouldGreyOut
                          ? const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                      child: card.imageUrl == null
                          ? Container(
                              color: const Color(0xFF102754),
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(card.imageUrl!, fit: BoxFit.cover),
                                if (shouldGreyOut)
                                  Container(color: Colors.black.withValues(alpha: 0.18)),
                              ],
                            ),
                    ),
                    Positioned(
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
                    ),
                    if (ownership.effectiveCopies > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasShine ? const Color(0xFFF7DE77) : Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'x${ownership.effectiveCopies}',
                            style: TextStyle(
                              color: hasShine ? Colors.black : Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
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
                    ),
                  ],
                ),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: shouldGreyOut
                          ? const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                      child: card.imageUrl == null
                          ? Container(
                              color: const Color(0xFF102754),
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(card.imageUrl!, fit: BoxFit.cover),
                                if (shouldGreyOut)
                                  Container(color: Colors.black.withValues(alpha: 0.18)),
                              ],
                            ),
                    ),
                    Positioned(
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
                    ),
                    if (ownership.effectiveCopies > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'x${ownership.effectiveCopies}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
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
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
