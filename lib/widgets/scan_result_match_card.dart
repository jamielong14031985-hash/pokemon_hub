import 'package:flutter/material.dart';

import '../models/tcg_card.dart';
import '../services/currency_settings.dart';

class ScanResultMatchCard extends StatelessWidget {
  const ScanResultMatchCard({
    super.key,
    required this.card,
    required this.onTap,
    this.highlight = false,
    this.rank,
    this.confidenceLabel,
    this.actionLabel,
    this.onActionTap,
  });

  final TcgCard card;
  final VoidCallback onTap;
  final bool highlight;
  final int? rank;
  final String? confidenceLabel;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? const Color(0xFF16366E) : const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: highlight
            ? const BorderSide(color: Color(0xFFF7DE77), width: 1.2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Stack(
              children: [
                SizedBox(
                  width: 96,
                  height: 132,
                  child: card.imageUrl == null
                      ? const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.image_not_supported, color: Colors.white),
                        )
                      : Image.network(card.imageUrl!, fit: BoxFit.cover),
                ),
                if (rank != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: highlight
                            ? const Color(0xFFF7DE77)
                            : Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          color: highlight ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (confidenceLabel != null && confidenceLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFF7DE77).withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          confidenceLabel!,
                          style: const TextStyle(
                            color: Color(0xFFF7DE77),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      card.setName,
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
                    const SizedBox(height: 8),
                    Text(
                      'Current raw price: ${CurrencySettings.formatAmount(card.rawPrice, fromCurrency: card.rawPriceCurrency)}',
                      style: const TextStyle(
                        color: Color(0xFFF7DE77),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap for full details',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (onActionTap != null && actionLabel != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          onPressed: onActionTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF7DE77),
                            foregroundColor: Colors.black,
                          ),
                          child: Text(actionLabel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
