import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tcg_card.dart';
import '../services/currency_settings.dart';

enum SealedProductType {
  boosterBox,
  eliteTrainerBox,
  boosterBundle,
  ultraPremiumCollection,
  boosterPack,
  sleevedBooster,
  blisterPack,
  checklaneBlister,
  threePackBlister,
  tin,
  miniTin,
  pokeBallTin,
  stackingTin,
  exBox,
  collectionBox,
  premiumCollection,
  premiumTournamentCollection,
  specialCollection,
  pinCollection,
  figureCollection,
  illustrationCollection,
  firstPartnerIllustrationCollection,
  techStickerCollection,
  buildAndBattle,
  buildAndBattleStadium,
  collectionChest,
  battleDeck,
  leagueBattleDeck,
  themeDeck,
  worldChampionshipDeck,
  battleAcademy,
  trainerToolkit,
  trainerKit,
  posterCollection,
  binderCollection,
  firstPartnerPack,
  surpriseBox,
  adventCalendar,
}

extension SealedProductTypeDetails on SealedProductType {
  String get label {
    switch (this) {
      case SealedProductType.boosterBox:
        return 'Booster Box';
      case SealedProductType.eliteTrainerBox:
        return 'Elite Trainer Box';
      case SealedProductType.boosterBundle:
        return 'Booster Bundle';
      case SealedProductType.ultraPremiumCollection:
        return 'Ultra-Premium Collection (UPC)';
      case SealedProductType.boosterPack:
        return 'Booster Pack';
      case SealedProductType.sleevedBooster:
        return 'Sleeved Booster Pack';
      case SealedProductType.blisterPack:
        return 'Blister Pack';
      case SealedProductType.checklaneBlister:
        return 'Checklane Blister';
      case SealedProductType.threePackBlister:
        return 'Three-Pack Blister';
      case SealedProductType.tin:
        return 'Tin';
      case SealedProductType.miniTin:
        return 'Mini Tin';
      case SealedProductType.pokeBallTin:
        return 'Poké Ball Tin';
      case SealedProductType.stackingTin:
        return 'Stacking Tin';
      case SealedProductType.exBox:
        return 'ex Box';
      case SealedProductType.collectionBox:
        return 'Collection Box';
      case SealedProductType.premiumCollection:
        return 'Premium Collection';
      case SealedProductType.premiumTournamentCollection:
        return 'Premium Tournament Collection';
      case SealedProductType.specialCollection:
        return 'Special Collection';
      case SealedProductType.pinCollection:
        return 'Pin Collection';
      case SealedProductType.figureCollection:
        return 'Figure Collection';
      case SealedProductType.illustrationCollection:
        return 'Illustration Collection';
      case SealedProductType.firstPartnerIllustrationCollection:
        return 'First Partner Illustration Collection (2026)';
      case SealedProductType.techStickerCollection:
        return 'Tech Sticker Collection';
      case SealedProductType.buildAndBattle:
        return 'Build & Battle Box';
      case SealedProductType.buildAndBattleStadium:
        return 'Build & Battle Stadium';
      case SealedProductType.collectionChest:
        return 'Collector Chest';
      case SealedProductType.battleDeck:
        return 'Battle Deck';
      case SealedProductType.leagueBattleDeck:
        return 'League Battle Deck';
      case SealedProductType.themeDeck:
        return 'Theme Deck';
      case SealedProductType.worldChampionshipDeck:
        return 'World Championship Deck';
      case SealedProductType.battleAcademy:
        return 'Battle Academy';
      case SealedProductType.trainerToolkit:
        return 'Trainer’s Toolkit';
      case SealedProductType.trainerKit:
        return 'Trainer Kit';
      case SealedProductType.posterCollection:
        return 'Poster Collection';
      case SealedProductType.binderCollection:
        return 'Binder Collection';
      case SealedProductType.firstPartnerPack:
        return 'First Partner Pack';
      case SealedProductType.surpriseBox:
        return 'Surprise Box';
      case SealedProductType.adventCalendar:
        return 'Holiday Calendar';
    }
  }

  String get shortLabel {
    switch (this) {
      case SealedProductType.boosterBox:
        return 'Booster Box';
      case SealedProductType.eliteTrainerBox:
        return 'ETB';
      case SealedProductType.boosterBundle:
        return 'Booster Bundle';
      case SealedProductType.ultraPremiumCollection:
        return 'UPC';
      default:
        return label;
    }
  }

  String get searchPhrase {
    switch (this) {
      case SealedProductType.boosterBox:
        return 'booster box';
      case SealedProductType.eliteTrainerBox:
        return 'elite trainer box';
      case SealedProductType.boosterBundle:
        return 'booster bundle';
      case SealedProductType.ultraPremiumCollection:
        return 'ultra premium collection';
      case SealedProductType.boosterPack:
        return 'booster pack';
      case SealedProductType.sleevedBooster:
        return 'sleeved booster pack';
      case SealedProductType.blisterPack:
        return 'blister pack';
      case SealedProductType.checklaneBlister:
        return 'checklane blister';
      case SealedProductType.threePackBlister:
        return 'three pack blister';
      case SealedProductType.tin:
        return 'pokemon tin';
      case SealedProductType.miniTin:
        return 'mini tin';
      case SealedProductType.pokeBallTin:
        return 'poke ball tin';
      case SealedProductType.stackingTin:
        return 'stacking tin';
      case SealedProductType.exBox:
        return 'ex box';
      case SealedProductType.collectionBox:
        return 'collection box';
      case SealedProductType.premiumCollection:
        return 'premium collection';
      case SealedProductType.premiumTournamentCollection:
        return 'premium tournament collection';
      case SealedProductType.specialCollection:
        return 'special collection';
      case SealedProductType.pinCollection:
        return 'pin collection';
      case SealedProductType.figureCollection:
        return 'figure collection';
      case SealedProductType.illustrationCollection:
        return 'illustration collection';
      case SealedProductType.firstPartnerIllustrationCollection:
        return 'first partner illustration collection';
      case SealedProductType.techStickerCollection:
        return 'tech sticker collection';
      case SealedProductType.buildAndBattle:
        return 'build battle box';
      case SealedProductType.buildAndBattleStadium:
        return 'build battle stadium';
      case SealedProductType.collectionChest:
        return 'collector chest';
      case SealedProductType.battleDeck:
        return 'battle deck';
      case SealedProductType.leagueBattleDeck:
        return 'league battle deck';
      case SealedProductType.themeDeck:
        return 'theme deck';
      case SealedProductType.worldChampionshipDeck:
        return 'world championship deck';
      case SealedProductType.battleAcademy:
        return 'battle academy';
      case SealedProductType.trainerToolkit:
        return 'trainer toolkit';
      case SealedProductType.trainerKit:
        return 'trainer kit';
      case SealedProductType.posterCollection:
        return 'poster collection';
      case SealedProductType.binderCollection:
        return 'binder collection';
      case SealedProductType.firstPartnerPack:
        return 'first partner pack';
      case SealedProductType.surpriseBox:
        return 'surprise box';
      case SealedProductType.adventCalendar:
        return 'holiday calendar';
    }
  }
}

Uri _buildRegionalEbaySoldUri({
  required String query,
  String? marketplaceCode,
}) {
  final normalizedMarketplaceCode = CurrencySettings.normalizeMarketplaceCode(
    marketplaceCode,
    currencyCode: CurrencySettings.selectedCode,
  );
  final marketplace =
      CurrencySettings.supportedMarketplaces[normalizedMarketplaceCode] ??
          CurrencySettings.selectedMarketplace;

  return Uri.https(
    marketplace.ebayHost,
    '/sch/i.html',
    <String, String>{
      '_nkw': query.trim().isEmpty ? 'pokemon sealed product' : query.trim(),
      '_sacat': '0',
      'LH_Sold': '1',
      'LH_Complete': '1',
    },
  );
}

// The 30th Celebration binder combines main-set, Classic Collection, RGB,
// Energy and promo cards. A binder slot (e.g. CC018) is NOT necessarily the
// printed card number (Gengar Prime is 94/102). eBay searches must not use
// binder slots as if they were physical collector numbers.
bool _isThirtyCelebrationCard(TcgCard card) {
  final setId = card.setId.trim().toLowerCase();
  final setName = card.setName.trim().toLowerCase();
  final id = card.id.trim().toLowerCase();
  return setName.contains('30th celebration') ||
      setName.contains('30th anniversary') ||
      <String>{'30th', '30th-c', 'me55', 'me55c'}.contains(setId) ||
      id.startsWith('me55-') ||
      id.startsWith('me55c-') ||
      id.startsWith('30th-');
}

String _quotedEbayTerm(String value) {
  final cleaned = value.replaceAll('"', '').trim();
  return cleaned.isEmpty ? '' : '"$cleaned"';
}

String _thirtySoldQuery(TcgCard card) {
  final name = card.name.trim();
  final number = card.number.trim().toUpperCase();
  final id = card.id.trim().toLowerCase();
  final rarity = (card.rarity ?? '').toLowerCase();
  final rgb = RegExp(r'^([RGB])/RGB$').firstMatch(number);

  // RGB cards have unique printed numbers: B/RGB, G/RGB and R/RGB.
  // Never substitute the unrelated Mew 065/128 or an RGB colour.
  if (name.toLowerCase() == 'mew' && rgb != null) {
    final rgbNumber = '${rgb.group(1)!}/RGB';
    return 'Mew ${_quotedEbayTerm(rgbNumber)} 30th Pokemon card';
  }

  if (number.startsWith('CC') || id.startsWith('me55c-')) {
    // Prefer the original catalogue source ID. Classic binder slots are
    // ordering positions, not printed collector numbers.
    final source = RegExp(r'^me55c[-_:]0*(\d+m?)$', caseSensitive: false)
        .firstMatch(id);
    final sourceNumber = source?.group(1)?.toLowerCase() ?? '';
    const printedNumbers = <String, String>{
      '4': '4/102', // Charizard
      '94': '94/102', // Gengar Prime
      '106m': '106/160', // M Gardevoir EX
    };
    final printed = printedNumbers[sourceNumber] ?? sourceNumber;
    // Keep type variants identifiable if the provider uses a suffix not
    // included in the PocketChase display title.
    final displayName = name.toLowerCase() == 'gengar' ? 'Gengar Prime' : name;
    return <String>[
      displayName,
      if (printed.isNotEmpty) _quotedEbayTerm(printed),
      '30th',
      if (printed.isEmpty) 'Classic Collection',
      'Pokemon card',
    ].join(' ');
  }

  if (number.startsWith('MEP')) {
    // The Pokémon Center stamp must stay distinct from the ordinary promo.
    final promoNumber = RegExp(r'^MEP0*(\d+)').firstMatch(number)?.group(1);
    final pokemonCenter = number.endsWith('PC') ||
        name.toLowerCase().contains('pokemon center') ||
        name.toLowerCase().contains('pokémon center') ||
        rarity.contains('pokemon center') ||
        rarity.contains('pokémon center');
    final cleanName = name.replaceAll(
      RegExp(r'\s*\[(?:Pok[eé]mon Center)\]', caseSensitive: false),
      '',
    ).trim();
    return <String>[
      cleanName,
      if (promoNumber != null) 'MEP$promoNumber',
      '30th',
      if (pokemonCenter) 'Pokemon Center stamped',
      'Pokemon card',
    ].join(' ');
  }

  if (number.startsWith('MEE')) {
    final energyNumber = RegExp(r'^MEE0*(\d+)').firstMatch(number)?.group(1);
    return <String>[
      name,
      if (energyNumber != null) 'MEE$energyNumber',
      '30th',
      'Pokemon energy card',
    ].join(' ');
  }

  // The main 30th Celebration set uses /128 on the printed cards, including
  // secret cards such as Mewtwo ex 151/128 and Pikachu ex 150/128.
  final printed = RegExp(r'^\d{1,3}$').hasMatch(number)
      ? '$number/128'
      : number;
  return <String>[
    name,
    if (printed.isNotEmpty) _quotedEbayTerm(printed),
    '30th',
    if (rarity.contains('stamped')) 'stamped',
    'Pokemon card',
  ].join(' ');
}

// Keep individual-card searches focused on a single genuine card. eBay
// supports -word and -"exact phrase" exclusion operators in the search box.
// Do NOT exclude "Collection" or "Pack": those words can appear on valid
// individual card listings, especially the 30th Celebration cards.
List<String> _cardSoldSearchExclusions({
  required bool rawCard,
  required bool englishThirtyCelebration,
}) {
  return <String>[
    '-bundle',
    '-lot',
    '-playset',
    '-"set of"',
    '-"complete set"',
    '-proxy',
    '-reprint',
    '-replica',
    if (rawCard) ...<String>['-PSA', '-BGS', '-CGC', '-graded', '-slab'],
    // This combined 30th Celebration catalogue is the English-language
    // release. Do not use these filters for unrelated or Japanese sets.
    if (englishThirtyCelebration) ...<String>[
      '-Japanese',
      '-JPN',
      '-Korean',
      '-Chinese',
    ],
  ];
}

Uri buildEbaySoldSearchUri({
  required TcgCard card,
  String? gradeLabel,
  String? marketplaceCode,
}) {
  // Prefer a distinct printed-number/variant query for the combined 30th
  // Celebration binder. All other sets retain their existing behaviour.
  final parts = _isThirtyCelebrationCard(card)
      ? <String>[
          _thirtySoldQuery(card),
          if (gradeLabel != null && gradeLabel.trim().isNotEmpty)
            gradeLabel.trim(),
        ]
      : <String>[
          card.name,
          card.setName,
          card.number,
          if (gradeLabel != null && gradeLabel.trim().isNotEmpty)
            gradeLabel.trim(),
          'pokemon card',
        ];

  final isThirtyCelebration = _isThirtyCelebrationCard(card);
  // No grade label means the Price snapshot's raw/ungraded Sold button.
  // Graded-price searches must retain PSA/BGS/CGC listings.
  final isRawSearch = gradeLabel == null || gradeLabel.trim().isEmpty;
  final searchWords = <String>[
    ...parts.where((part) => part.trim().isNotEmpty),
    if (isThirtyCelebration) 'English',
    ..._cardSoldSearchExclusions(
      rawCard: isRawSearch,
      englishThirtyCelebration: isThirtyCelebration,
    ),
  ];
  return _buildRegionalEbaySoldUri(
    query: searchWords.join(' '),
    marketplaceCode: marketplaceCode,
  );
}

Uri buildEbaySealedSoldSearchUri({
  required String setName,
  required SealedProductType productType,
  String? marketplaceCode,
}) {
  final cleanSetName = setName.trim();
  final parts = <String>[
    'pokemon',
    if (cleanSetName.isNotEmpty) cleanSetName,
    productType.searchPhrase,
    'sealed',
  ];

  return _buildRegionalEbaySoldUri(
    query: parts.join(' '),
    marketplaceCode: marketplaceCode,
  );
}

Future<void> openEbaySoldSearch({
  required BuildContext context,
  required TcgCard card,
  String? gradeLabel,
  String? marketplaceCode,
}) async {
  final uri = buildEbaySoldSearchUri(
    card: card,
    gradeLabel: gradeLabel,
    marketplaceCode: marketplaceCode,
  );
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open ${CurrencySettings.selectedMarketplace.label} sold prices.',
        ),
      ),
    );
  }
}

Future<void> openEbaySealedSoldSearch({
  required BuildContext context,
  required String setName,
  required SealedProductType productType,
  String? marketplaceCode,
}) async {
  final uri = buildEbaySealedSoldSearchUri(
    setName: setName,
    productType: productType,
    marketplaceCode: marketplaceCode,
  );
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open ${CurrencySettings.selectedMarketplace.label} sold prices.',
        ),
      ),
    );
  }
}
