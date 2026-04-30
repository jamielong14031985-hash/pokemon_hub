import 'package:flutter/material.dart';

import '../models/tcg_card.dart';
import 'ebay_sold_row.dart';

class GradedPricesCard extends StatelessWidget {
  const GradedPricesCard({
    super.key,
    required this.card,
    required this.gradedPrices,
    required this.onOpenSoldSearch,
  });

  final TcgCard card;
  final Map<String, double> gradedPrices;
  final ValueChanged<String> onOpenSoldSearch;

  @override
  Widget build(BuildContext context) {
    final preferredLabels = <String>[
      'PSA 10',
      'BGS 10',
      'CGC 10',
      'SGC 10',
      'ACE 10',
      'GEM 10',
    ];

    final labelsToShow = <String>{
      ...preferredLabels,
      ...gradedPrices.keys,
    }.toList();

    final hasAnyLiveGradedPrice = gradedPrices.values.any((price) => price > 0);

    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Graded Price Checks',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAnyLiveGradedPrice
                  ? 'Live graded prices are shown where available. You can also open recent sold eBay results for each grade below.'
                  : 'No live graded prices were found for this card right now. Use the buttons below to check recent sold eBay results from this details page.',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            ...labelsToShow.map(
              (label) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EbaySoldRow(
                  label: label,
                  price: gradedPrices[label],
                  onTap: () => onOpenSoldSearch(label),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
