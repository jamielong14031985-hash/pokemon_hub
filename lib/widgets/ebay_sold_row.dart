import 'package:flutter/material.dart';

import '../services/currency_settings.dart';

class EbaySoldRow extends StatelessWidget {
  const EbaySoldRow({
    super.key,
    required this.label,
    required this.price,
    required this.onTap,
    this.sourceCurrency = 'USD',
  });

  final String label;
  final double? price;
  final VoidCallback onTap;
  final String sourceCurrency;

  bool get _hasPrice => price != null && price!.isFinite && price! > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _hasPrice
                    ? CurrencySettings.formatAmount(price, fromCurrency: sourceCurrency)
                    : 'Check eBay',
                style: TextStyle(
                  color: _hasPrice ? Colors.white : const Color(0xFFF7DE77),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _hasPrice
                ? 'Open recent sold eBay results for this version.'
                : 'No live price found. Open recent sold eBay results for this version.',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open eBay Sold'),
            ),
          ),
        ],
      ),
    );
  }
}
