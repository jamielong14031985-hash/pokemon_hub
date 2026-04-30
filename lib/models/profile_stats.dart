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
}
