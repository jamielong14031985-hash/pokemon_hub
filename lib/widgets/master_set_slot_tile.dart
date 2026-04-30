import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../utils/master_set_slot_helpers.dart';
import 'binder_card_tile.dart';

class MasterSetSlotTile extends StatelessWidget {
  const MasterSetSlotTile({
    super.key,
    required this.slot,
    required this.ownership,
    this.greyOutWhenMissing = false,
  });

  final MasterSetCardSlot slot;
  final CardOwnership ownership;
  final bool greyOutWhenMissing;

  @override
  Widget build(BuildContext context) {
    final slotOwned = slot.isOwned(ownership);

    return Stack(
      fit: StackFit.expand,
      children: [
        BinderCardTile(
          card: slot.card,
          ownership: slot.tileOwnership(ownership),
          greyOutUnowned: greyOutWhenMissing,
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: slotOwned
                  ? const Color(0xFFF7DE77)
                  : Colors.black.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: slotOwned
                    ? const Color(0xFFF7DE77)
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              slot.shortLabel,
              style: TextStyle(
                color: slotOwned ? Colors.black : Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
