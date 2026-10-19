import '../models/national_pokedex_species.dart';

/// Conservatively maps one-card Pokémon titles to one National Pokédex species.
/// Trainer cards and multi-Pokémon TAG TEAM/LEGEND titles do not count.
class NationalPokedexNameMatcher {
  const NationalPokedexNameMatcher();

  static String key(String input) => input
      .toLowerCase()
      .replaceAll('♀', 'f')
      .replaceAll('♂', 'm')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('’', '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static const _nonSpeciesNames = <String>{
    'energy', 'basicenergy', 'switch', 'ultraball', 'pokegear', 'pokedex',
  };

  int? match(String cardName, Map<String, int> speciesByKey) {
    var name = cardName.trim();
    if (name.isEmpty ||
        RegExp(r'\s+(?:&|and)\s+', caseSensitive: false).hasMatch(name)) {
      return null;
    }

    // Trainer's Pokémon and special printings still represent one species.
    // Examples: Lance's Charizard V, Dark Charizard, M Charizard-EX.
    name = name.replaceFirst(RegExp(r"^.+[’']s\s+"), '');
    name = name.replaceFirst(RegExp(
      r'^(?:Alolan|Galarian|Hisuian|Paldean|Mega|Primal|Dark|Light|Radiant|Shining|Origin Forme|Therian Forme|Incarnate Forme|Ice Rider|Shadow Rider)\s+',
      caseSensitive: false,
    ), '');
    name = name.replaceFirst(RegExp(r'^M\s+(?=[A-Z])'), '');

    // Use separators found on older cards as well as modern EX/ex, GX, VMAX.
    // Avoid fuzzy substring matching: a species must be the entire base name.
    name = name.replaceFirst(RegExp(
      r'(?:\s+|[-–])(?:ex|gx|vmax|vstar|v-union|v|lv\.?x|break|prime|sp|star|δ|delta species)(?:\s+.*)?$',
      caseSensitive: false,
    ), '');
    // Mega Charizard X ex / Mega Charizard Y ex.
    name = name.replaceFirst(RegExp(r'\s+[XY]$', caseSensitive: false), '');
    name = name.replaceFirst(RegExp(
      r'\s*\((?:delta species|holo|reverse holo|promo)\)$',
      caseSensitive: false,
    ), '');
    final normalized = key(name);
    if (normalized.isEmpty || _nonSpeciesNames.contains(normalized)) return null;
    return speciesByKey[normalized];
  }

  static Map<String, int> index(Iterable<NationalPokedexSpecies> species) => {
    for (final entry in species) key(entry.displayName): entry.number,
    for (final entry in species) key(entry.slug): entry.number,
  };
}
