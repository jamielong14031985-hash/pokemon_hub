import 'package:flutter/material.dart';

import '../services/currency_settings.dart';

String _formatProfilePercent(double value) {
  if (value >= 100) return '100%';
  if (value <= 0) return '0%';
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}%';
}

class RarityValueBar extends StatelessWidget {
  const RarityValueBar({
    super.key,
    required this.rarity,
    required this.copies,
    required this.value,
    required this.totalValue,
  });

  final String rarity;
  final int copies;
  final double value;
  final double totalValue;

  @override
  Widget build(BuildContext context) {
    final percent = totalValue <= 0 ? 0.0 : (value / totalValue).clamp(0.0, 1.0).toDouble();
    final percentText = _formatProfilePercent(percent * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rarity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "$percentText • $copies ${copies == 1 ? 'card' : 'cards'}",
              style: const TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth * percent;
            return Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: barWidth,
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF7DE77), Color(0xFFFFF4B0)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 5),
        Text(
          CurrencySettings.formatSelectedAmount(value),
          style: const TextStyle(
            color: Color(0xFFF7DE77),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
