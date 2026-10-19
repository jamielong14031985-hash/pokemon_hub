import 'package:flutter_test/flutter_test.dart';
import '../lib/models/tcg_card.dart';
import '../lib/utils/card_price_confidence.dart';

TcgCard makeCard({
  double? external,
  double? fallback,
  String method = 'provider_reference',
  String confidence = 'reference',
  int soldCount = 0,
  String currency = 'GBP',
}) => TcgCard(
  id: 'test-1',
  name: 'Test',
  setId: 'me55',
  setName: '30th Celebration',
  number: '1',
  types: const [],
  externalRawPrice: external,
  externalRawPriceCurrency: currency,
  externalRawPriceMethod: method,
  externalRawPriceConfidence: confidence,
  externalRawPriceSoldCount: soldCount,
  rawPrice: fallback,
  rawPriceCurrency: currency,
);

void main() {
  test('large JustTCG references are warned and not sales-supported', () {
    final card = makeCard(external: 2809.65);
    expect(CardPriceConfidence.isProviderReference(card), isTrue);
    expect(CardPriceConfidence.isHighValueWithoutSales(card), isTrue);
    expect(CardPriceConfidence.isSalesSupported(card), isFalse);
  });

  test('small reference still identified without high-value warning', () {
    final card = makeCard(external: 43.48);
    expect(CardPriceConfidence.isProviderReference(card), isTrue);
    expect(CardPriceConfidence.isHighValueWithoutSales(card), isFalse);
  });

  test('minimum three medium-confidence matched sales qualifies', () {
    final card = makeCard(external: 610, method: 'sold_median', confidence: 'medium', soldCount: 3);
    expect(CardPriceConfidence.isSalesSupported(card), isTrue);
    expect(CardPriceConfidence.isHighValueWithoutSales(card), isFalse);
  });

  test('two sales or low confidence never qualifies as sales-supported', () {
    final two = makeCard(external: 2000, method: 'sold_median', confidence: 'high', soldCount: 2);
    final low = makeCard(external: 2000, method: 'sold_median', confidence: 'low', soldCount: 30);
    expect(CardPriceConfidence.isSalesSupported(two), isFalse);
    expect(CardPriceConfidence.isSalesSupported(low), isFalse);
  });

  test('unclassified legacy raw prices are not treated as sold evidence', () {
    final legacy = makeCard(fallback: 2000);
    expect(CardPriceConfidence.isSalesSupported(legacy), isFalse);
    expect(CardPriceConfidence.isHighValueWithoutSales(legacy), isTrue);
  });

  test('missing prices do not produce high-value warnings', () {
    expect(CardPriceConfidence.isHighValueWithoutSales(makeCard()), isFalse);
  });
}
