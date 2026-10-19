/// Identifies a Pokémon expansion only when its actual name is in the title.
/// Avoid assigning character-themed collections to a set without evidence.
class SealedExpansionMatcher {
  SealedExpansionMatcher._();

  // Order matters: the longest/most specific release name must match first.
  // Unknown sets remain unassigned until the user selects one manually.
  static const List<String> _knownExpansions = <String>[
    // Confirmed sealed set names from the collector's existing products.
    // These were previously displayed together as 'Unassigned set'.
    '30th Celebration',
    'Chaos Rising',
    'Delta Reign',
    'Pitch Black',
    'Ascended Heroes',
    'Prismatic Evolutions',
    'Surging Sparks',
    'Shrouded Fable',
    'Twilight Masquerade',
    'Temporal Forces',
    'Paldean Fates',
    'Paradox Rift',
    'Obsidian Flames',
    'Paldea Evolved',
    'Destined Rivals',
    'Journey Together',
    'Black Bolt',
    'White Flare',
    'Phantasmal Flames',
    'Mega Evolution',
    'Crown Zenith',
    'Silver Tempest',
    'Lost Origin',
    'Astral Radiance',
    'Brilliant Stars',
    'Fusion Strike',
    'Celebrations',
    'Evolving Skies',
    'Chilling Reign',
    'Battle Styles',
    'Shining Fates',
    'Vivid Voltage',
    "Champion's Path",
    'Darkness Ablaze',
    'Rebel Clash',
    'Cosmic Eclipse',
    'Hidden Fates',
    'Unified Minds',
    'Unbroken Bonds',
    'Lost Thunder',
    'Dragon Majesty',
    'Celestial Storm',
    'Forbidden Light',
    'Ultra Prism',
    'Crimson Invasion',
    'Shining Legends',
    'Burning Shadows',
    'Guardians Rising',
    'Evolutions',
    'Steam Siege',
    'Fates Collide',
    'Generations',
    'BREAKpoint',
    'BREAKthrough',
    'Ancient Origins',
    'Roaring Skies',
    'Double Crisis',
    'Primal Clash',
    'Phantom Forces',
    'Furious Fists',
    'Flashfire',
    '151',
  ];

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Product names sometimes omit their expansion altogether. Use a strictly
  // product-specific allowlist for verified cases, NEVER a broad rule such as
  // every 'Poster Collection' belonging to Ascended Heroes.
  //
  // This particular Mega Gardevoir premium poster box is an Ascended Heroes
  // product. Other poster collections remain independent.
  static const Map<String, String> _verifiedProductExpansions =
      <String, String>{
    'premium poster collection mega gardevoir': 'Ascended Heroes',
  };

  static String? fromVerifiedProductTitle(String title) {
    final normalized = _normalize(title);
    final unbranded = normalized.replaceFirst(
      RegExp(r'^(?:pokemon tcg |pokemon |tcg )'),
      '',
    );
    return _verifiedProductExpansions[normalized] ??
        _verifiedProductExpansions[unbranded];
  }

  static String? fromProductTitle(String title) {
    final verified = fromVerifiedProductTitle(title);
    if (verified != null) return verified;
    // The 2026 releases are three products within a separate product line,
    // not part of an ordinary booster expansion or the 2021 jumbo packs.
    if (isFirstPartnerIllustrationTitle(title)) {
      return firstPartnerCollectionGroup;
    }
    final searchable = ' ${_normalize(title)} ';
    for (final expansion in _knownExpansions) {
      if (searchable.contains(' ${_normalize(expansion)} ')) {
        return expansion;
      }
    }
    return null;
  }

  static const String firstPartnerCollectionGroup =
      'First Partner Collection 2026';

  static bool isFirstPartnerIllustrationTitle(String title) {
    final value = _normalize(title);
    // Reject cases, code cards and promotional singles: only unopened
    // individual illustration collection boxes should be grouped here.
    if (value.contains('code card') ||
        value.contains(' case ') ||
        value.endsWith(' case') ||
        value.contains('promo card')) {
      return false;
    }
    return RegExp(r'\bfirst partner illustration collection\b').hasMatch(value) &&
        RegExp(r'\bseries [123]\b').hasMatch(value);
  }

  static int? firstPartnerSeriesNumber(String title) {
    final value = _normalize(title);
    final match = RegExp(r'\bseries ([123])\b').firstMatch(value);
    return int.tryParse(match?.group(1) ?? '');
  }

  static String? firstPartnerPrimaryRegion(String title) {
    switch (firstPartnerSeriesNumber(title)) {
      case 1:
        return 'Kanto';
      case 2:
        return 'Johto';
      case 3:
        return 'Hoenn';
      default:
        return null;
    }
  }

  static String? firstPartnerRegionGroup(String title) {
    switch (firstPartnerSeriesNumber(title)) {
      case 1:
        return 'Kanto / Sinnoh / Alola';
      case 2:
        return 'Johto / Unova / Galar';
      case 3:
        return 'Hoenn / Kalos / Paldea';
      default:
        return null;
    }
  }

  static String? firstPartnerSeriesLabel(String title) {
    final series = firstPartnerSeriesNumber(title);
    final primary = firstPartnerPrimaryRegion(title);
    if (series == null || primary == null) return null;
    return 'Series $series — $primary';
  }

  static bool isFirstPartnerCatalogueGroup(String name) {
    final value = _normalize(name);
    return value.contains('first partner') &&
        (value.contains('collection 2026') ||
            value.contains('illustration collection'));
  }

  static String fromCatalogueGroup(String groupName) {
    if (isFirstPartnerCatalogueGroup(groupName)) {
      return firstPartnerCollectionGroup;
    }
    final known = fromProductTitle(groupName);
    if (known != null) return known;
    // For new catalogue items, retain the catalogue's explicit group name.
    // This is stronger evidence than trying to guess from product artwork.
    return groupName.trim();
  }
}
