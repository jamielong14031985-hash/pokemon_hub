import 'tcg_card.dart';
import 'tcg_set.dart';

class CardSearchResult {
  const CardSearchResult({
    this.cards = const <TcgCard>[],
    this.sets = const <TcgSet>[],
    this.matchedSet,
  });

  final List<TcgCard> cards;
  final List<TcgSet> sets;
  final TcgSet? matchedSet;
}
