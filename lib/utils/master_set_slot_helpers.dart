import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import 'card_number_sorter.dart';

enum MasterSetSlotKind {
  normal,
  reverseHolo,
  holo,
}

class MasterSetCardSlot {
  const MasterSetCardSlot({
    required this.card,
    required this.kind,
  });

  final TcgCard card;
  final MasterSetSlotKind kind;

  String get shortLabel {
    switch (kind) {
      case MasterSetSlotKind.normal:
        return 'N';
      case MasterSetSlotKind.reverseHolo:
        return 'RH';
      case MasterSetSlotKind.holo:
        return 'H';
    }
  }

  String get label {
    switch (kind) {
      case MasterSetSlotKind.normal:
        return 'Normal';
      case MasterSetSlotKind.reverseHolo:
        return 'Reverse Holo';
      case MasterSetSlotKind.holo:
        return 'Holo';
    }
  }

  int countFor(CardOwnership ownership) {
    switch (kind) {
      case MasterSetSlotKind.normal:
        return ownership.normalCount;
      case MasterSetSlotKind.reverseHolo:
        return ownership.reverseHoloCount;
      case MasterSetSlotKind.holo:
        return ownership.holoCount;
    }
  }

  bool isOwned(CardOwnership ownership) => countFor(ownership) > 0;

  CardOwnership tileOwnership(CardOwnership ownership) {
    final count = countFor(ownership);
    if (count <= 0) {
      return const CardOwnership();
    }

    switch (kind) {
      case MasterSetSlotKind.normal:
        return CardOwnership(
          normal: true,
          copies: count,
          normalCopies: count,
        );
      case MasterSetSlotKind.reverseHolo:
        return CardOwnership(
          reverseHolo: true,
          copies: count,
          reverseHoloCopies: count,
        );
      case MasterSetSlotKind.holo:
        return CardOwnership(
          holo: true,
          copies: count,
          holoCopies: count,
        );
    }
  }

  CardOwnership addOne(CardOwnership ownership) {
    switch (kind) {
      case MasterSetSlotKind.normal:
        return ownership.copyWith(
          normal: true,
          normalCopies: ownership.normalCount + 1,
        );
      case MasterSetSlotKind.reverseHolo:
        return ownership.copyWith(
          reverseHolo: true,
          reverseHoloCopies: ownership.reverseHoloCount + 1,
        );
      case MasterSetSlotKind.holo:
        return ownership.copyWith(
          holo: true,
          holoCopies: ownership.holoCount + 1,
        );
    }
  }

  CardOwnership removeOne(CardOwnership ownership) {
    switch (kind) {
      case MasterSetSlotKind.normal:
        return ownership.copyWith(
          normal: ownership.normalCount > 1,
          normalCopies: (ownership.normalCount - 1).clamp(0, 999999).toInt(),
        );
      case MasterSetSlotKind.reverseHolo:
        return ownership.copyWith(
          reverseHolo: ownership.reverseHoloCount > 1,
          reverseHoloCopies: (ownership.reverseHoloCount - 1).clamp(0, 999999).toInt(),
        );
      case MasterSetSlotKind.holo:
        return ownership.copyWith(
          holo: ownership.holoCount > 1,
          holoCopies: (ownership.holoCount - 1).clamp(0, 999999).toInt(),
        );
    }
  }

  CardOwnership toggleOwnership(CardOwnership ownership) {
    if (isOwned(ownership)) {
      switch (kind) {
        case MasterSetSlotKind.normal:
          return ownership.copyWith(normal: false, normalCopies: 0);
        case MasterSetSlotKind.reverseHolo:
          return ownership.copyWith(reverseHolo: false, reverseHoloCopies: 0);
        case MasterSetSlotKind.holo:
          return ownership.copyWith(holo: false, holoCopies: 0);
      }
    }

    return addOne(ownership);
  }
}

bool _hasRawPriceLabel(TcgCard card, String text) {
  final needle = text.toLowerCase();
  return card.rawPriceBreakdown.keys.any((label) => label.toLowerCase().contains(needle));
}

bool _isSpecialMasterSetRarity(TcgCard card) {
  final rarity = (card.rarity ?? '').toLowerCase();
  return rarity.contains('illustration') ||
      rarity.contains('ultra') ||
      rarity.contains('secret') ||
      rarity.contains('hyper') ||
      rarity.contains('rainbow') ||
      rarity.contains('radiant') ||
      rarity.contains('amazing rare') ||
      rarity.contains('ace spec') ||
      rarity.contains('double rare') ||
      rarity.contains('rare holo v') ||
      rarity.contains('rare holo vmax') ||
      rarity.contains('rare holo vstar') ||
      rarity.contains('rare holo gx') ||
      rarity.contains('rare holo ex') ||
      rarity.contains('rare prime') ||
      rarity.contains('rare prism') ||
      rarity.contains('rare break');
}

bool _isReverseHoloEligibleRarity(TcgCard card) {
  final rarity = (card.rarity ?? '').toLowerCase().trim();
  if (rarity.isEmpty || _isSpecialMasterSetRarity(card)) return false;
  if (rarity.contains('common') || rarity.contains('uncommon')) return true;
  if (rarity == 'rare' || rarity == 'rare holo' || rarity == 'rare holo lv.x') return true;
  if (rarity.contains('rare holo') &&
      !rarity.contains(' v') &&
      !rarity.contains('vmax') &&
      !rarity.contains('vstar') &&
      !rarity.contains(' ex') &&
      !rarity.contains(' gx')) {
    return true;
  }
  return false;
}

bool _isHoloMasterSetRarity(TcgCard card) {
  final rarity = (card.rarity ?? '').toLowerCase();
  return _isSpecialMasterSetRarity(card) || rarity.contains('holo');
}

List<MasterSetSlotKind> _availableMasterSetSlotKinds(TcgCard card) {
  final kinds = <MasterSetSlotKind>[];

  void add(MasterSetSlotKind kind) {
    if (!kinds.contains(kind)) {
      kinds.add(kind);
    }
  }

  final hasNormalPrice = _hasRawPriceLabel(card, 'normal market') ||
      _hasRawPriceLabel(card, '1st ed normal');
  final hasReversePrice = _hasRawPriceLabel(card, 'reverse holo');
  final hasHoloPrice = _hasRawPriceLabel(card, 'holofoil market') ||
      _hasRawPriceLabel(card, '1st ed holo') ||
      _hasRawPriceLabel(card, 'unlimited holo');

  final specialRarity = _isSpecialMasterSetRarity(card);
  final holoRarity = _isHoloMasterSetRarity(card);
  final reverseEligible = _isReverseHoloEligibleRarity(card);

  if (hasNormalPrice || (!hasHoloPrice && !specialRarity && !holoRarity)) {
    add(MasterSetSlotKind.normal);
  }

  if (hasReversePrice || reverseEligible) {
    add(MasterSetSlotKind.reverseHolo);
  }

  if (hasHoloPrice || holoRarity || specialRarity) {
    add(MasterSetSlotKind.holo);
  }

  if (kinds.isEmpty) {
    add(MasterSetSlotKind.normal);
  }

  kinds.sort((a, b) => a.index.compareTo(b.index));
  return kinds;
}

List<MasterSetCardSlot> buildMasterSetSlots(List<TcgCard> cards) {
  final slots = <MasterSetCardSlot>[];
  final seen = <String>{};

  for (final card in cards) {
    for (final kind in _availableMasterSetSlotKinds(card)) {
      final key = '${card.id}_${kind.name}';
      if (seen.add(key)) {
        slots.add(MasterSetCardSlot(card: card, kind: kind));
      }
    }
  }

  slots.sort((a, b) {
    final numberCompare = compareCardNumbers(a.card.number, b.card.number);
    if (numberCompare != 0) return numberCompare;

    final nameCompare = a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase());
    if (nameCompare != 0) return nameCompare;

    return a.kind.index.compareTo(b.kind.index);
  });

  return slots;
}
