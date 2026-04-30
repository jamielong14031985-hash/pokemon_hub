import 'card_ownership.dart';

class SetCardDetailsResult {
  const SetCardDetailsResult({
    required this.cardId,
    required this.ownership,
    this.nextIndex,
  });

  final String cardId;
  final CardOwnership ownership;
  final int? nextIndex;
}
