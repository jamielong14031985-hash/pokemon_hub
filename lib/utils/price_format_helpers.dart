import '../services/currency_settings.dart';

String formatCardPrice(
  double? price, {
  String fromCurrency = 'USD',
}) {
  return CurrencySettings.formatAmount(price, fromCurrency: fromCurrency);
}
