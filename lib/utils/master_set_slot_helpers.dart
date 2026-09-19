import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import 'card_number_sorter.dart';
import 'english_grand_master_catalog.dart';

enum MasterSetSlotKind {
  normal,
  reverseHolo,
  holo,
  pokeBallReverse,
  masterBallReverse,
  firstEditionNormal,
  firstEditionHolo,
  unlimitedNormal,
  unlimitedHolo,
  shadowlessNormal,
  shadowlessHolo,
  cosmosHolo,
  crackedIceHolo,
  setStamped,
  prereleaseStamped,
  staffStamped,
  leagueStamped,
  productExclusive,
}

extension MasterSetSlotKindDetails on MasterSetSlotKind {
  String get storageId => name;

  String get displayLabel {
    switch (this) {
      case MasterSetSlotKind.normal: return 'Normal';
      case MasterSetSlotKind.reverseHolo: return 'Reverse Holo';
      case MasterSetSlotKind.holo: return 'Holo';
      case MasterSetSlotKind.pokeBallReverse: return 'Poke Ball Reverse';
      case MasterSetSlotKind.masterBallReverse: return 'Master Ball Reverse';
      case MasterSetSlotKind.firstEditionNormal: return '1st Edition Normal';
      case MasterSetSlotKind.firstEditionHolo: return '1st Edition Holo';
      case MasterSetSlotKind.unlimitedNormal: return 'Unlimited Normal';
      case MasterSetSlotKind.unlimitedHolo: return 'Unlimited Holo';
      case MasterSetSlotKind.shadowlessNormal: return 'Shadowless Normal';
      case MasterSetSlotKind.shadowlessHolo: return 'Shadowless Holo';
      case MasterSetSlotKind.cosmosHolo: return 'Cosmos Holo';
      case MasterSetSlotKind.crackedIceHolo: return 'Cracked Ice Holo';
      case MasterSetSlotKind.setStamped: return 'Set Stamped';
      case MasterSetSlotKind.prereleaseStamped: return 'Prerelease Stamped';
      case MasterSetSlotKind.staffStamped: return 'Staff Stamped';
      case MasterSetSlotKind.leagueStamped: return 'League Stamped';
      case MasterSetSlotKind.productExclusive: return 'Product Exclusive';
    }
  }

  String get compactLabel {
    switch (this) {
      case MasterSetSlotKind.normal: return 'N';
      case MasterSetSlotKind.reverseHolo: return 'RH';
      case MasterSetSlotKind.holo: return 'H';
      case MasterSetSlotKind.pokeBallReverse: return 'PB';
      case MasterSetSlotKind.masterBallReverse: return 'MB';
      case MasterSetSlotKind.firstEditionNormal: return '1E';
      case MasterSetSlotKind.firstEditionHolo: return '1E H';
      case MasterSetSlotKind.unlimitedNormal: return 'UL';
      case MasterSetSlotKind.unlimitedHolo: return 'UL H';
      case MasterSetSlotKind.shadowlessNormal: return 'SL';
      case MasterSetSlotKind.shadowlessHolo: return 'SL H';
      case MasterSetSlotKind.cosmosHolo: return 'COS';
      case MasterSetSlotKind.crackedIceHolo: return 'CI';
      case MasterSetSlotKind.setStamped: return 'STAMP';
      case MasterSetSlotKind.prereleaseStamped: return 'PRE';
      case MasterSetSlotKind.staffStamped: return 'STAFF';
      case MasterSetSlotKind.leagueStamped: return 'LEAGUE';
      case MasterSetSlotKind.productExclusive: return 'EXCL';
    }
  }

  bool get isLegacyStoredVariant => index <= MasterSetSlotKind.masterBallReverse.index;
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
        if (isSinglePrintSetCard(card)) return 'H';
        return _printedRarityLabel(card);
      case MasterSetSlotKind.reverseHolo:
        return 'RH';
      case MasterSetSlotKind.holo:
        final special = _specialRarityLabel(card);
        return special.isNotEmpty ? special : 'H';
      case MasterSetSlotKind.pokeBallReverse:
        return 'PB';
      case MasterSetSlotKind.masterBallReverse:
        return 'MB';
      default:
        return kind.compactLabel;
    }
  }

  String get label {
    switch (kind) {
      case MasterSetSlotKind.normal:
        if (isSinglePrintSetCard(card)) return 'Holo';
        final rarity = (card.rarity ?? '').trim();
        return rarity.isEmpty ? 'Normal' : rarity;
      case MasterSetSlotKind.reverseHolo:
        return 'Reverse Holo';
      case MasterSetSlotKind.holo:
        return 'Holo';
      case MasterSetSlotKind.pokeBallReverse:
        return 'Poke Ball Reverse';
      case MasterSetSlotKind.masterBallReverse:
        return 'Master Ball Reverse';
      default:
        return kind.displayLabel;
    }
  }

  int countFor(CardOwnership ownership) {
    if (isSinglePrintSetCard(card)) {
      return ownership.collectionCount;
    }

    switch (kind) {
      case MasterSetSlotKind.normal:
        return ownership.normalCount;
      case MasterSetSlotKind.reverseHolo:
        return ownership.reverseHoloCount;
      case MasterSetSlotKind.holo:
        return ownership.holoCount;
      case MasterSetSlotKind.pokeBallReverse:
        return ownership.pokeBallReverseCount;
      case MasterSetSlotKind.masterBallReverse:
        return ownership.masterBallReverseCount;
      default:
        return ownership.extraVariantCount(kind.storageId);
    }
  }

  bool isOwned(CardOwnership ownership) => countFor(ownership) > 0;

  CardOwnership tileOwnership(CardOwnership ownership) {
    final count = countFor(ownership);
    if (count <= 0) return const CardOwnership();

    if (isSinglePrintSetCard(card)) {
      return CardOwnership(
        normal: true,
        copies: count,
        normalCopies: count,
      );
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
      case MasterSetSlotKind.pokeBallReverse:
        return CardOwnership(
          pokeBallReverse: true,
          copies: count,
          pokeBallReverseCopies: count,
        );
      case MasterSetSlotKind.masterBallReverse:
        return CardOwnership(
          masterBallReverse: true,
          copies: count,
          masterBallReverseCopies: count,
        );
      default:
        return CardOwnership(
          copies: count,
          extraVariantCopies: <String, int>{kind.storageId: count},
        );
    }
  }

  CardOwnership addOne(CardOwnership ownership) {
    if (isSinglePrintSetCard(card)) {
      return ownership.copyWith(
        normal: true,
        reverseHolo: false,
        holo: false,
        pokeBallReverse: false,
        masterBallReverse: false,
        normalCopies: ownership.collectionCount + 1,
        reverseHoloCopies: 0,
        holoCopies: 0,
        pokeBallReverseCopies: 0,
        masterBallReverseCopies: 0,
      );
    }

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
      case MasterSetSlotKind.pokeBallReverse:
        return ownership.copyWith(
          pokeBallReverse: true,
          pokeBallReverseCopies: ownership.pokeBallReverseCount + 1,
        );
      case MasterSetSlotKind.masterBallReverse:
        return ownership.copyWith(
          masterBallReverse: true,
          masterBallReverseCopies: ownership.masterBallReverseCount + 1,
        );
      default:
        final variants = Map<String, int>.from(ownership.extraVariantCopies);
        variants[kind.storageId] = ownership.extraVariantCount(kind.storageId) + 1;
        return ownership.copyWith(extraVariantCopies: variants);
    }
  }

  CardOwnership removeOne(CardOwnership ownership) {
    if (isSinglePrintSetCard(card)) {
      final nextCount = (ownership.collectionCount - 1).clamp(0, 999999).toInt();
      return ownership.copyWith(
        normal: nextCount > 0,
        reverseHolo: false,
        holo: false,
        pokeBallReverse: false,
        masterBallReverse: false,
        normalCopies: nextCount,
        reverseHoloCopies: 0,
        holoCopies: 0,
        pokeBallReverseCopies: 0,
        masterBallReverseCopies: 0,
      );
    }

    switch (kind) {
      case MasterSetSlotKind.normal:
        return ownership.copyWith(
          normal: ownership.normalCount > 1,
          normalCopies: (ownership.normalCount - 1).clamp(0, 999999).toInt(),
        );
      case MasterSetSlotKind.reverseHolo:
        return ownership.copyWith(
          reverseHolo: ownership.reverseHoloCount > 1,
          reverseHoloCopies:
              (ownership.reverseHoloCount - 1).clamp(0, 999999).toInt(),
        );
      case MasterSetSlotKind.holo:
        return ownership.copyWith(
          holo: ownership.holoCount > 1,
          holoCopies: (ownership.holoCount - 1).clamp(0, 999999).toInt(),
        );
      case MasterSetSlotKind.pokeBallReverse:
        return ownership.copyWith(
          pokeBallReverse: ownership.pokeBallReverseCount > 1,
          pokeBallReverseCopies:
              (ownership.pokeBallReverseCount - 1).clamp(0, 999999).toInt(),
        );
      case MasterSetSlotKind.masterBallReverse:
        return ownership.copyWith(
          masterBallReverse: ownership.masterBallReverseCount > 1,
          masterBallReverseCopies:
              (ownership.masterBallReverseCount - 1).clamp(0, 999999).toInt(),
        );
      default:
        final variants = Map<String, int>.from(ownership.extraVariantCopies);
        final next = (ownership.extraVariantCount(kind.storageId) - 1)
            .clamp(0, 999999)
            .toInt();
        if (next > 0) {
          variants[kind.storageId] = next;
        } else {
          variants.remove(kind.storageId);
        }
        return ownership.copyWith(extraVariantCopies: variants);
    }
  }

  CardOwnership toggleOwnership(CardOwnership ownership) {
    if (isSinglePrintSetCard(card) && isOwned(ownership)) {
      return ownership.copyWith(
        normal: false,
        reverseHolo: false,
        holo: false,
        pokeBallReverse: false,
        masterBallReverse: false,
        normalCopies: 0,
        reverseHoloCopies: 0,
        holoCopies: 0,
        pokeBallReverseCopies: 0,
        masterBallReverseCopies: 0,
      );
    }

    if (isOwned(ownership)) {
      switch (kind) {
        case MasterSetSlotKind.normal:
          return ownership.copyWith(normal: false, normalCopies: 0);
        case MasterSetSlotKind.reverseHolo:
          return ownership.copyWith(
            reverseHolo: false,
            reverseHoloCopies: 0,
          );
        case MasterSetSlotKind.holo:
          return ownership.copyWith(holo: false, holoCopies: 0);
        case MasterSetSlotKind.pokeBallReverse:
          return ownership.copyWith(
            pokeBallReverse: false,
            pokeBallReverseCopies: 0,
          );
        case MasterSetSlotKind.masterBallReverse:
          return ownership.copyWith(
            masterBallReverse: false,
            masterBallReverseCopies: 0,
          );
        default:
          final variants = Map<String, int>.from(ownership.extraVariantCopies)
            ..remove(kind.storageId);
          return ownership.copyWith(extraVariantCopies: variants);
      }
    }

    return addOne(ownership);
  }
}

bool isSinglePrintSetCard(TcgCard card) {
  final setId = card.setId.toLowerCase().trim();
  final setName = card.setName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return setId == '30th' ||
      setId == '30th-c' ||
      setName == '30th celebration' ||
      setName == '30th classic collection' ||
      setName.contains('30th anniversary');
}

bool _isJapaneseCard(TcgCard card) {
  return card.id.toLowerCase().startsWith('jp_') ||
      card.setId.toLowerCase().startsWith('jp_');
}

String _printedRarityLabel(TcgCard card) {
  final raw = (card.rarity ?? '').trim();
  if (raw.isEmpty) return '';

  final compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  const directCodes = <String>{
    'C', 'U', 'R', 'RR', 'AR', 'SR', 'SAR', 'UR', 'HR',
    'CHR', 'CSR', 'SSR', 'S', 'K', 'A', 'PR', 'BWR', 'MHR'
  };
  if (directCodes.contains(compact)) return compact;

  final rarity = raw.toLowerCase();
  final japanese = _isJapaneseCard(card);

  if (rarity.contains('special illustration rare') ||
      rarity.contains('special art rare')) {
    return japanese ? 'SAR' : 'SIR';
  }
  if (rarity.contains('illustration rare')) return japanese ? 'AR' : 'IR';
  if (rarity.contains('double rare')) return japanese ? 'RR' : 'DR';
  if (rarity.contains('ultra rare') || rarity.contains('rare ultra')) {
    return 'UR';
  }
  if (rarity.contains('hyper rare')) return 'HR';
  if (rarity.contains('secret rare') || rarity.contains('rare secret')) {
    return 'SR';
  }
  if (rarity.contains('ace spec')) return 'ACE';
  if (rarity.contains('uncommon')) return 'U';
  if (rarity.contains('common')) return 'C';
  if (rarity.contains('rare')) return 'R';

  return '';
}

String _specialRarityLabel(TcgCard card) {
  final rarity = (card.rarity ?? '').toLowerCase();
  if (!_isSpecialMasterSetRarity(card)) return '';
  if (rarity == 'rare holo' || rarity == 'holo rare') return '';
  return _printedRarityLabel(card);
}

bool _hasRawPriceLabel(TcgCard card, String text) {
  final needle = text.toLowerCase();
  return card.rawPriceBreakdown.keys.any(
    (label) => label.toLowerCase().contains(needle),
  );
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
  if (rarity == 'rare' || rarity == 'rare holo' || rarity == 'rare holo lv.x') {
    return true;
  }
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

class _MasterSetVariantProfile {
  const _MasterSetVariantProfile({
    required this.hasExactData,
    required this.supportsNormal,
    required this.supportsReverseHolo,
    required this.supportsHolo,
    required this.supportsBallPatternVariants,
  });

  final bool hasExactData;
  final bool supportsNormal;
  final bool supportsReverseHolo;
  final bool supportsHolo;
  final bool supportsBallPatternVariants;

  factory _MasterSetVariantProfile.fromCards(List<TcgCard> cards) {
    final hasExactData = cards.any(
      (card) =>
          card.hasNormalVariant != null ||
          card.hasReverseHoloVariant != null ||
          card.hasHoloVariant != null,
    );

    final setText = cards
        .map((card) => '${card.setId} ${card.setName}'.toLowerCase())
        .join(' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    final supportsBallPatternVariants =
        setText.contains('prismatic evolutions') ||
        setText.contains('black bolt') ||
        setText.contains('white flare') ||
        setText.contains('sv8pt5') ||
        setText.contains('sv08 5');

    return _MasterSetVariantProfile(
      hasExactData: hasExactData,
      supportsNormal: cards.any((card) => card.hasNormalVariant == true),
      supportsReverseHolo:
          cards.any((card) => card.hasReverseHoloVariant == true),
      supportsHolo: cards.any((card) => card.hasHoloVariant == true),
      supportsBallPatternVariants: supportsBallPatternVariants,
    );
  }
}

List<MasterSetSlotKind> _availableMasterSetSlotKinds(
  TcgCard card,
  _MasterSetVariantProfile profile,
) {
  if (isSinglePrintSetCard(card)) {
    return const <MasterSetSlotKind>[MasterSetSlotKind.normal];
  }

  final catalogueMask = englishGrandMasterVariantMask(
    card.setId,
    card.number,
    card.name,
  );
  if (!_isJapaneseCard(card) && catalogueMask != null) {
    final catalogueKinds = <MasterSetSlotKind>[];
    void addCatalogueKind(int bit, MasterSetSlotKind kind) {
      if ((catalogueMask & bit) != 0) catalogueKinds.add(kind);
    }

    addCatalogueKind(1, MasterSetSlotKind.normal);
    addCatalogueKind(2, MasterSetSlotKind.reverseHolo);
    addCatalogueKind(4, MasterSetSlotKind.holo);
    addCatalogueKind(8, MasterSetSlotKind.firstEditionNormal);
    addCatalogueKind(16, MasterSetSlotKind.firstEditionHolo);
    addCatalogueKind(32, MasterSetSlotKind.unlimitedNormal);
    addCatalogueKind(64, MasterSetSlotKind.unlimitedHolo);
    addCatalogueKind(128, MasterSetSlotKind.shadowlessNormal);
    addCatalogueKind(256, MasterSetSlotKind.shadowlessHolo);
    if (catalogueKinds.isNotEmpty) return catalogueKinds;
  }

  final kinds = <MasterSetSlotKind>[];

  void add(MasterSetSlotKind kind) {
    if (!kinds.contains(kind)) kinds.add(kind);
  }

  void addEnglishGrandMasterPrintings() {
    if (_isJapaneseCard(card)) return;

    if (_hasRawPriceLabel(card, '1st ed normal')) {
      add(MasterSetSlotKind.firstEditionNormal);
    }
    if (_hasRawPriceLabel(card, '1st ed holo')) {
      add(MasterSetSlotKind.firstEditionHolo);
    }
    if (_hasRawPriceLabel(card, 'unlimited normal')) {
      add(MasterSetSlotKind.unlimitedNormal);
    }
    if (_hasRawPriceLabel(card, 'unlimited holo')) {
      add(MasterSetSlotKind.unlimitedHolo);
    }

    final setId = card.setId.toLowerCase().trim();
    final setName = card.setName.toLowerCase();
    final cardText = '${card.id} ${card.name}'.toLowerCase();
    if (setId == 'base1' || setName == 'base set') {
      add(_isHoloMasterSetRarity(card)
          ? MasterSetSlotKind.shadowlessHolo
          : MasterSetSlotKind.shadowlessNormal);
    }

    // These are only added when the source identifies the official printing.
    // They are not inferred for every card in the expansion.
    if (cardText.contains('prerelease')) {
      add(MasterSetSlotKind.prereleaseStamped);
    }
    if (cardText.contains('staff')) {
      add(MasterSetSlotKind.staffStamped);
    }
    if (cardText.contains('league')) {
      add(MasterSetSlotKind.leagueStamped);
    }
    if (cardText.contains('cosmos holo')) {
      add(MasterSetSlotKind.cosmosHolo);
    }
    if (cardText.contains('cracked ice')) {
      add(MasterSetSlotKind.crackedIceHolo);
    }
    if (cardText.contains('stamped')) {
      add(MasterSetSlotKind.setStamped);
    }
  }

  if (profile.hasExactData) {
    final specialRarity = _isSpecialMasterSetRarity(card);
    final holoRarity = _isHoloMasterSetRarity(card);
    final reverseEligible = _isReverseHoloEligibleRarity(card);

    if (card.hasNormalVariant == true ||
        (profile.supportsNormal && !specialRarity && !holoRarity)) {
      add(MasterSetSlotKind.normal);
    }
    if (card.hasReverseHoloVariant == true ||
        (profile.supportsReverseHolo && reverseEligible)) {
      add(MasterSetSlotKind.reverseHolo);
    }
    if (card.hasHoloVariant == true ||
        (profile.supportsHolo && (holoRarity || specialRarity))) {
      add(MasterSetSlotKind.holo);
    }
    if (profile.supportsBallPatternVariants && reverseEligible) {
      add(MasterSetSlotKind.pokeBallReverse);
      add(MasterSetSlotKind.masterBallReverse);
    }
    addEnglishGrandMasterPrintings();
    if (kinds.isEmpty) add(MasterSetSlotKind.normal);
    return kinds;
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

  addEnglishGrandMasterPrintings();

  if (kinds.isEmpty) add(MasterSetSlotKind.normal);

  kinds.sort((a, b) => a.index.compareTo(b.index));
  return kinds;
}

List<MasterSetCardSlot> buildMasterSetSlots(List<TcgCard> cards) {
  final slots = <MasterSetCardSlot>[];
  final seen = <String>{};
  final variantProfile = _MasterSetVariantProfile.fromCards(cards);

  for (final card in cards) {
    for (final kind in _availableMasterSetSlotKinds(card, variantProfile)) {
      final key = '${card.id}_${kind.name}';
      if (seen.add(key)) {
        slots.add(MasterSetCardSlot(card: card, kind: kind));
      }
    }
  }

  slots.sort((a, b) {
    final numberCompare = compareCardNumbers(a.card.number, b.card.number);
    if (numberCompare != 0) return numberCompare;

    final nameCompare =
        a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase());
    if (nameCompare != 0) return nameCompare;

    return a.kind.index.compareTo(b.kind.index);
  });

  return slots;
}
