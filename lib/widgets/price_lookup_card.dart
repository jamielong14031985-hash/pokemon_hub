import 'package:flutter/material.dart';

import '../models/tcg_card.dart';
import '../services/currency_settings.dart';

class PriceLookupCard extends StatelessWidget {
  const PriceLookupCard({
    super.key,
    required this.card,
    required this.onOpenRawSold,
    this.onRefreshPrice,
    this.refreshingPrice = false,
  });

  final TcgCard card;
  final VoidCallback onOpenRawSold;
  final VoidCallback? onRefreshPrice;
  final bool refreshingPrice;

  bool get _hasRawPrice => (card.marketPrice ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final rawPriceText = _hasRawPrice
        ? CurrencySettings.formatAmount(
            card.marketPrice,
            fromCurrency: card.marketPriceCurrency,
          )
        : refreshingPrice
            ? 'Checking latest raw price...'
            : 'No live raw price found yet';

    final sourceText = _hasRawPrice
        ? 'Source: ${card.marketPriceSource}'
        : onRefreshPrice != null
            ? 'PocketChase checked the Pokémon TCG API first. Use Refresh Raw Price to check JustTCG as the extra pricing source.'
            : 'PocketChase checked the Pokémon TCG API, but no raw price was available for this card yet.';

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
              sourceText,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            if (onRefreshPrice != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: refreshingPrice ? null : onRefreshPrice,
                  icon: refreshingPrice
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    refreshingPrice ? 'Checking JustTCG...' : 'Refresh Raw Price',
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
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
