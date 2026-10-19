import 'tcg_card.dart';

class ProfileStats {
  const ProfileStats({
    required this.totalCards,
    required this.uniqueCards,
    required this.totalEstimatedPrice,
    required this.mostExpensiveCard,
    required this.mostExpensiveCardCopies,
    required this.favouriteSetName,
    required this.favouriteSetCopies,
    required this.rarityCopies,
    required this.rarityValues,
    required this.topValueCards,
    this.pricedUniqueCards = 0,
    this.setsCollected = 0,
    this.lowConfidencePricedCards = 0,
    this.salesSupportedValue = 0,
    this.guideOnlyValue = 0,
    this.highValueUnverifiedCards = 0,
    this.salesSupportedUniqueCards = 0,
  });

  final int totalCards;
  final int uniqueCards;
  final double totalEstimatedPrice;
  final TcgCard? mostExpensiveCard;
  final int mostExpensiveCardCopies;
  final String? favouriteSetName;
  final int favouriteSetCopies;
  final Map<String, int> rarityCopies;
  final Map<String, double> rarityValues;
  final List<TcgCard> topValueCards;
  final int pricedUniqueCards;
  final int setsCollected;
  final int lowConfidencePricedCards;
  /// Subtotal with >=3 provider-reported sold comps and medium/high confidence.
  /// This is a partial, sales-supported estimate, not verified asset value.
  final double salesSupportedValue;
  /// Prices from reference providers or insufficient sale evidence.
  final double guideOnlyValue;
  final int highValueUnverifiedCards;
  final int salesSupportedUniqueCards;

  int get duplicateCards {
    final value = totalCards - uniqueCards;
    return value > 0 ? value : 0;
  }

  int get unpricedUniqueCards {
    final value = uniqueCards - pricedUniqueCards;
    return value > 0 ? value : 0;
  }
}
