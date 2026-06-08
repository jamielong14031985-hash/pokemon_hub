import 'card_ownership.dart';
import '../utils/master_set_slot_helpers.dart';

class SetCardDetailsResult {
  const SetCardDetailsResult({
    required this.cardId,
    required this.ownership,
    this.selectedSlotKind,
    this.nextIndex,
  });

  final String cardId;
  final CardOwnership ownership;
  final MasterSetSlotKind? selectedSlotKind;
  final int? nextIndex;
}
