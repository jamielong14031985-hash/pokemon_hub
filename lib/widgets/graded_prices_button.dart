import 'package:flutter/material.dart';

import '../models/tcg_card.dart';

class GradedPricesButton extends StatelessWidget {
  const GradedPricesButton({
    super.key,
    required this.card,
    required this.onOpenGradedPrices,
  });

  final TcgCard card;
  final VoidCallback onOpenGradedPrices;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Graded Prices',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Raw price stays on this page. Tap below to view graded price checks separately.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenGradedPrices,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('View Graded Prices'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
