enum SealedProductEdition { standard, pokemonCenter }

class SealedProductIdentityService {
  SealedProductIdentityService._();

  static const Set<String> _searchNoise = <String>{
    'pokemon', 'pokémon', 'tcg', 'trading', 'card', 'cards', 'game', 'sealed',
    'new', 'brand', 'official', 'the', 'a', 'an', 'and', 'with', 'for', 'uk',
  };

  static const Set<String> _productWords = <String>{
    'elite', 'trainer', 'box', 'etb', 'booster', 'display', 'bundle', 'pack',
    'sleeved', 'blister', 'tin', 'mini', 'collection', 'premium', 'ultra',
    'special', 'build', 'battle', 'stadium', 'collector', 'chest', 'deck',
    'toolkit', 'poster', 'binder', 'holiday', 'advent', 'calendar', 'center',
    'centre', 'exclusive', 'pc', 'pcetb', 'checklane', 'stacking', 'ball',
    'league', 'championship', 'academy', 'tournament', 'illustration', 'sticker',
    'figure', 'pin', 'partner', 'surprise',
  };

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r"[^a-z0-9]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Set<String> _tokens(String value) =>
      normalize(value).split(' ').where((word) => word.isNotEmpty).toSet();

  static SealedProductEdition detectEdition(String title) {
    final value = normalize(title);
    final pokemonCenter = value.contains('pokemon center') ||
        value.contains('pokemon centre') ||
        value.contains('pokecenter') ||
        RegExp(r'\bpc\s*etb\b').hasMatch(value) ||
        value.contains('pokemon center exclusive');
    return pokemonCenter
        ? SealedProductEdition.pokemonCenter
        : SealedProductEdition.standard;
  }

  static String editionKey(SealedProductEdition edition) =>
      edition == SealedProductEdition.pokemonCenter
          ? 'pokemonCenter'
          : 'standard';

  static bool isSingleSealedProduct(String title) {
    final value = normalize(title);
    const rejectedPhrases = <String>[
      'single card', 'card only', 'promo card', 'code card', 'digital code',
      'empty box', 'box only', 'sleeves only', 'divider', 'opened', 'unsealed',
      'damaged box', 'case of', 'master case', 'display case', 'job lot',
      'mixed lot', 'assorted lot', 'bundle with', 'plus booster', 'and booster',
    ];
    if (rejectedPhrases.any(value.contains)) return false;
    if (RegExp(r'\b(?:2|3|4|5|6|8|10|12|24|36)\s*x\b').hasMatch(value) ||
        RegExp(r'\bx\s*(?:2|3|4|5|6|8|10|12|24|36)\b').hasMatch(value) ||
        RegExp(r'\b(?:lot|case)\s+(?:of\s+)?\d+\b').hasMatch(value)) {
      return false;
    }
    return true;
  }

  static bool matches({
    required String title,
    required String query,
    required String productType,
    required String etbVariant,
  }) {
    if (!isSingleSealedProduct(title) || !_matchesType(title, productType)) {
      return false;
    }

    if (productType == 'eliteTrainerBox') {
      final requestedEdition = etbVariant == 'pokemonCenter'
          ? SealedProductEdition.pokemonCenter
          : SealedProductEdition.standard;
      if (detectEdition(title) != requestedEdition) return false;
    }

    final wanted = _tokens(query)
        .where((token) =>
            !_searchNoise.contains(token) && !_productWords.contains(token))
        .toSet();
    if (wanted.isEmpty) return true;

    final found = _tokens(title);
    final matched = wanted.where(found.contains).length;
    // One-word set names must be exact. Longer names tolerate one omitted word,
    // which is common in marketplace abbreviations, but still require 75%.
    if (wanted.length == 1) return matched == 1;
    return matched >= wanted.length - 1 && matched / wanted.length >= 0.75;
  }

  static bool _matchesType(String title, String productType) {
    final value = normalize(title);
    bool has(String phrase) => value.contains(normalize(phrase));
    switch (productType) {
      case 'eliteTrainerBox':
        return has('elite trainer box') || RegExp(r'\betb\b').hasMatch(value) ||
            RegExp(r'\bpcetb\b').hasMatch(value);
      case 'boosterBox':
        return has('booster box') || has('booster display');
      case 'boosterBundle':
        return has('booster bundle');
      case 'ultraPremiumCollection':
        return has('ultra premium collection') ||
            RegExp(r'\bupc\b').hasMatch(value);
      case 'boosterPack':
        return has('booster pack') && !has('sleeved') && !has('blister');
      case 'sleevedBooster':
        return has('sleeved booster');
      case 'blisterPack':
        return has('blister') &&
            !has('checklane') &&
            !RegExp(r'\b(?:3|three) pack blister\b').hasMatch(value);
      case 'checklaneBlister':
        return has('checklane blister');
      case 'threePackBlister':
        return RegExp(r'\b(?:3|three) pack blister\b').hasMatch(value);
      case 'tin':
        return has('tin') &&
            !has('mini tin') &&
            !has('poke ball tin') &&
            !has('pokeball tin') &&
            !has('stacking tin');
      case 'miniTin':
        return has('mini tin');
      case 'pokeBallTin':
        return has('poke ball tin') || has('pokeball tin');
      case 'stackingTin':
        return has('stacking tin');
      case 'exBox':
        return RegExp(r'\bex box\b').hasMatch(value) && !has('bundle');
      case 'collectionBox':
        return has('collection box');
      case 'premiumCollection':
        return has('premium collection') && !has('ultra premium');
      case 'premiumTournamentCollection':
        return has('premium tournament collection');
      case 'specialCollection':
        return has('special collection');
      case 'pinCollection':
        return has('pin collection');
      case 'figureCollection':
        return has('figure collection');
      case 'illustrationCollection':
        return has('illustration collection');
      case 'techStickerCollection':
        return has('tech sticker collection');
      case 'buildAndBattle':
        return has('build and battle') && !has('stadium');
      case 'buildAndBattleStadium':
        return has('build and battle') && has('stadium');
      case 'collectionChest':
        return has('collector chest') || has('collection chest');
      case 'battleDeck':
        return has('battle deck') && !has('league battle deck');
      case 'leagueBattleDeck':
        return has('league battle deck');
      case 'themeDeck':
        return has('theme deck');
      case 'worldChampionshipDeck':
        return has('world championship deck') ||
            has('world championships deck');
      case 'battleAcademy':
        return has('battle academy');
      case 'trainerToolkit':
        return has('trainer toolkit') || has('trainers toolkit');
      case 'trainerKit':
        return has('trainer kit') && !has('toolkit');
      case 'posterCollection':
        return has('poster collection');
      case 'binderCollection':
        return has('binder collection');
      case 'firstPartnerPack':
        return has('first partner pack');
      case 'surpriseBox':
        return has('surprise box');
      case 'adventCalendar':
        return has('holiday calendar') || has('advent calendar');
      case 'all':
        return true;
      default:
        return has('sealed') || has('booster') || has('elite trainer box') ||
            has('collection') || has('tin');
    }
  }

  static String stableProductKey({
    required String query,
    required String productType,
    required String etbVariant,
  }) {
    final setKey = _tokens(query)
        .where((token) =>
            !_searchNoise.contains(token) && !_productWords.contains(token))
        .join('-');
    final edition = productType == 'eliteTrainerBox' ? etbVariant : 'standard';
    return '$setKey|$productType|$edition';
  }
}
