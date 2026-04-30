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

  bool isOwned(CardOwnership ownership) {
    switch (kind) {
      case MasterSetSlotKind.normal:
        return ownership.normal ||
            (ownership.effectiveCopies > 0 && !ownership.reverseHolo && !ownership.holo);
      case MasterSetSlotKind.reverseHolo:
        return ownership.reverseHolo;
      case MasterSetSlotKind.holo:
        return ownership.holo;
    }
  }

  CardOwnership tileOwnership(CardOwnership ownership) {
    if (!isOwned(ownership)) {
      return const CardOwnership();
    }

    switch (kind) {
      case MasterSetSlotKind.normal:
        return const CardOwnership(normal: true, copies: 1);
      case MasterSetSlotKind.reverseHolo:
        return const CardOwnership(reverseHolo: true, copies: 1);
      case MasterSetSlotKind.holo:
        return const CardOwnership(holo: true, copies: 1);
    }
  }

  CardOwnership toggleOwnership(CardOwnership ownership) {
    final nextOwned = !isOwned(ownership);
    var normal = ownership.normal;
    var reverseHolo = ownership.reverseHolo;
    var holo = ownership.holo;
    var copies = ownership.effectiveCopies;

    switch (kind) {
      case MasterSetSlotKind.normal:
        normal = nextOwned;
        break;
      case MasterSetSlotKind.reverseHolo:
        reverseHolo = nextOwned;
        break;
      case MasterSetSlotKind.holo:
        holo = nextOwned;
        break;
    }

    if (nextOwned && copies < 1) {
      copies = 1;
    }

    if (!normal && !reverseHolo && !holo) {
      copies = 0;
    }

    return ownership.copyWith(
      normal: normal,
      reverseHolo: reverseHolo,
      holo: holo,
      copies: copies,
    );
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

