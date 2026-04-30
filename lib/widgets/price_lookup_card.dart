import 'package:flutter/material.dart';

import '../models/tcg_card.dart';
import '../services/currency_settings.dart';

class PriceLookupCard extends StatelessWidget {
  const PriceLookupCard({
    super.key,
    required this.card,
    required this.onOpenRawSold,
  });

  final TcgCard card;
  final VoidCallback onOpenRawSold;

  bool get _hasRawPrice => (card.rawPrice ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final rawPriceText = _hasRawPrice
        ? CurrencySettings.formatAmount(card.rawPrice, fromCurrency: card.rawPriceCurrency)
        : 'No live raw price found yet';

    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raw Price',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rawPriceText,
              style: TextStyle(
                color: _hasRawPrice ? Colors.white : const Color(0xFFF7DE77),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasRawPrice
                  ? 'This is the live raw market estimate currently available for this card.'
                  : 'Some cards do not have a live API price. Use the eBay sold search below on the details page for a quick price check.',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenRawSold,
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  _hasRawPrice
                      ? 'Open Raw Sold eBay Results'
                      : 'Check Raw Sold eBay Results',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
