import 'package:flutter/material.dart';

import '../models/tcg_card.dart';
import '../services/currency_settings.dart';
import '../utils/card_price_confidence.dart';

class PriceLookupCard extends StatelessWidget {
  const PriceLookupCard({
    super.key,
    required this.card,
    required this.onOpenRawSold,
    this.onOpenGradedPrices,
    this.onRefreshPrice,
    this.refreshingPrice = false,
  });

  final TcgCard card;
  final VoidCallback onOpenRawSold;
  final VoidCallback? onOpenGradedPrices;
  final VoidCallback? onRefreshPrice;
  final bool refreshingPrice;

  static const Color _panel = Color(0xFF102E66);
  static const Color _panelSoft = Color(0xFF173872);
  static const Color _gold = Color(0xFFF7DE77);

  bool get _hasRawPrice => (card.marketPrice ?? 0) > 0;

  String get _confidenceLabel {
    switch (card.externalRawPriceConfidence.toLowerCase()) {
      case 'high':
        return 'HIGH CONFIDENCE';
      case 'medium':
        return 'MEDIUM CONFIDENCE';
      case 'low':
        return 'LOW CONFIDENCE';
      case 'reference':
        return 'REFERENCE';
      default:
        return _hasRawPrice ? 'ESTIMATE' : '';
    }
  }

  Color get _confidenceColor {
    switch (card.externalRawPriceConfidence.toLowerCase()) {
      case 'high':
        return const Color(0xFF7DE8B1);
      case 'medium':
        return _gold;
      case 'low':
      case 'reference':
        return const Color(0xFFFFB36B);
      default:
        return Colors.white70;
    }
  }

  String _rangeLabel() {
    final low = card.externalRawPriceLow;
    final high = card.externalRawPriceHigh;
    if (low == null || high == null || low <= 0 || high <= 0) return '';
    final lowText = CurrencySettings.formatAmount(
      low,
      fromCurrency: card.externalRawPriceCurrency,
    );
    final highText = CurrencySettings.formatAmount(
      high,
      fromCurrency: card.externalRawPriceCurrency,
    );
    final sales = card.externalRawPriceSoldCount;
    return '$lowText–$highText${sales > 0 ? ' from $sales matched sales' : ''}';
  }

  String _updatedLabel() {
    final milliseconds = card.externalRawPriceUpdatedAtMs;
    if (milliseconds == null || milliseconds <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Updated just now';
    if (difference.inMinutes < 60) return 'Updated ${difference.inMinutes}m ago';
    if (difference.inHours < 24) return 'Updated ${difference.inHours}h ago';
    return 'Updated ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final rawPriceText = _hasRawPrice
        ? CurrencySettings.formatAmount(
            card.marketPrice,
            fromCurrency: card.marketPriceCurrency,
          )
        : refreshingPrice
            ? 'Checking…'
            : 'Not available';
    final updatedLabel = _updatedLabel();
    final rangeLabel = _rangeLabel();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.show_chart_rounded, color: _gold, size: 20),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price snapshot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Raw card • ungraded',
                      style: TextStyle(color: Colors.white60, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (_hasRawPrice && _confidenceLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _confidenceColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _confidenceLabel,
                    style: TextStyle(
                      color: _confidenceColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _panelSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CardPriceConfidence.isSalesSupported(card)
                      ? 'SOLD-PRICE ESTIMATE'
                      : 'INDICATIVE PRICE GUIDE',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        rawPriceText,
                        style: TextStyle(
                          color: _hasRawPrice ? _gold : Colors.white70,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    if (refreshingPrice)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _hasRawPrice
                      ? '${card.marketPriceSource}${updatedLabel.isEmpty ? '' : ' • $updatedLabel'}'
                      : 'Refresh to check the latest available market data.',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
                if (rangeLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Matched range $rangeLabel',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_hasRawPrice && CardPriceConfidence.isHighValueWithoutSales(card)) ...[
            const SizedBox(height: 9),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB36B), size: 18),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'High-value price guide only. No qualifying sold-price evidence is attached to this value. It is excluded from the sales-supported collection subtotal.',
                    style: TextStyle(color: Color(0xFFFFD4A4), fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ] else if (_hasRawPrice && CardPriceConfidence.isProviderReference(card)) ...[
            const SizedBox(height: 8),
            const Text(
              'Provider reference only — not a confirmed completed-sale price.',
              style: TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ] else if (_hasRawPrice && !CardPriceConfidence.isSalesSupported(card)) ...[
            const SizedBox(height: 8),
            const Text(
              'Price guide has insufficient sold-price evidence to qualify for the sales-supported subtotal.',
              style: TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PriceAction(
                  icon: Icons.sync_rounded,
                  label: refreshingPrice ? 'Checking' : 'Update',
                  onTap: refreshingPrice ? null : onRefreshPrice,
                  highlighted: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriceAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'Sold',
                  onTap: onOpenRawSold,
                ),
              ),
              if (onOpenGradedPrices != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _PriceAction(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Graded',
                    onTap: onOpenGradedPrices,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline_rounded, color: Colors.white38, size: 13),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Market values are guides, not guaranteed sale prices. Sold opens recent ${CurrencySettings.selectedMarketplace.label} results.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceAction extends StatelessWidget {
  const _PriceAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? PriceLookupCard._gold
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: highlighted ? const Color(0xFF111111) : Colors.white,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlighted ? const Color(0xFF111111) : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
