import '../models/tcg_card.dart';
import '../services/currency_settings.dart';

/// Conservative classification for PocketChase's raw-card price displays.
///
/// "Sales-supported" means the feed reported at least three matched sales
/// and a medium/high-confidence sold median. PocketChase does not audit the
/// transactions independently; this is NOT a guaranteed realised sale price.
/// JustTCG market/reference prices are never classified as sales-supported.
class CardPriceConfidence {
  CardPriceConfidence._();

  // UI-only alert threshold, denominated in GBP and converted into the
  // viewer's chosen currency. Not a price cap or a valuation override.
  static const double highReferenceAlertGbp = 500.0;

  static bool isSalesSupported(TcgCard card) {
    if (!card.hasExternalRawPrice) return false;
    if (card.externalRawPriceMethod.trim().toLowerCase() != 'sold_median') {
      return false;
    }
    if (card.externalRawPriceSoldCount < 3) return false;
    final confidence = card.externalRawPriceConfidence.trim().toLowerCase();
    return confidence == 'high' || confidence == 'medium';
  }

  static bool isProviderReference(TcgCard card) {
    if (!card.hasExternalRawPrice) return false;
    return card.externalRawPriceMethod.trim().toLowerCase() == 'provider_reference' ||
        card.externalRawPriceConfidence.trim().toLowerCase() == 'reference';
  }

  static bool isHighValueWithoutSales(TcgCard card) {
    if (!card.hasLiveMarketPrice || isSalesSupported(card)) return false;
    final amount = CurrencySettings.convertAmountSync(
      card.marketPrice,
      fromCurrency: card.marketPriceCurrency,
    );
    final limit = CurrencySettings.convertAmountSync(
      highReferenceAlertGbp,
      fromCurrency: 'GBP',
    );
    return amount != null && limit != null && amount.isFinite &&
        limit.isFinite && amount >= limit;
  }
}
