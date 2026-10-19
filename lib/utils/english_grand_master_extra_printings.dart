// Curated English printings that are not represented by the three generic
// normal/reverse/holo flags returned by the card APIs.
//
// Ascended Heroes source: TCG Watchtower master-set checklist, generated
// 2026-10-07. The checklist totals 613 expansion printings before the six
// separately numbered MEP Black Star promos are merged by PokemonTcgService.

const int englishGrandMasterReverseHoloBit = 2;
const int englishGrandMasterPokeBallBit = 8;
const int englishGrandMasterEnergySymbolBit = 16;
const int englishGrandMasterDuskBallBit = 32;
const int englishGrandMasterLoveBallBit = 64;
const int englishGrandMasterFriendBallBit = 128;
const int englishGrandMasterQuickBallBit = 256;
const int englishGrandMasterTeamRocketBit = 512;

const Set<int> _ascendedHeroesReverseHolo = <int>{
  180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192,
  193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205,
  206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217,
};

const Set<int> _ascendedHeroesDuskBall = <int>{
  44, 45, 85, 86, 90, 91, 92, 98, 99, 102, 105, 106, 108, 118, 119,
  120, 123, 124, 128, 129, 130, 131, 132, 138, 144, 171,
};

const Set<int> _ascendedHeroesEnergySymbol = <int>{
  1, 2, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
  21, 23, 24, 25, 27, 28, 29, 30, 32, 33, 34, 35, 36, 37, 39, 40,
  41, 42, 44, 45, 46, 49, 50, 51, 52, 53, 54, 55, 56, 59, 60, 62,
  63, 64, 65, 66, 67, 69, 71, 72, 74, 75, 77, 78, 80, 81, 82, 83,
  85, 86, 87, 88, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100,
  101, 102, 103, 104, 105, 106, 108, 109, 110, 112, 115, 117, 118,
  119, 120, 122, 123, 124, 126, 127, 128, 129, 130, 131, 132, 133,
  134, 136, 138, 140, 141, 143, 144, 146, 147, 148, 150, 151, 153,
  154, 155, 156, 157, 158, 159, 161, 163, 165, 166, 168, 169, 170,
  171, 173, 174, 175, 176, 177, 178,
};

const Set<int> _ascendedHeroesFriendBall = <int>{
  8, 9, 16, 20, 21, 29, 30, 36, 37, 41, 42, 52, 53, 54, 55, 56,
  83, 112, 122, 153, 156, 157, 176,
};

const Set<int> _ascendedHeroesLoveBall = <int>{
  11, 12, 13, 14, 15, 39, 40, 46, 74, 75, 80, 81, 82, 87, 88,
  93, 94, 115, 117, 140, 150, 151, 165, 166, 178,
};

const Set<int> _ascendedHeroesPokeBall = <int>{
  1, 2, 4, 5, 6, 7, 23, 24, 32, 33, 49, 50, 51, 69, 71, 72, 95,
  96, 109, 110, 133, 136, 141, 143, 154, 155, 163, 168, 169, 170,
  173, 174, 175, 177,
};

const Set<int> _ascendedHeroesQuickBall = <int>{
  17, 25, 27, 28, 34, 35, 59, 60, 62, 63, 64, 65, 66, 67, 103,
  104, 134, 146, 147, 148, 158, 159,
};

const Set<int> _ascendedHeroesTeamRocket = <int>{
  18, 19, 77, 78, 97, 100, 101, 126, 127, 161,
};

bool _isAscendedHeroes(String setId, String setName) {
  final id = setId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  final name = setName.toLowerCase();
  return id == 'me25' ||
      id == 'me2pt5' ||
      id == 'me02pt5' ||
      id == 'asc' ||
      id == 'b2a' ||
      name.contains('ascended heroes');
}

bool englishGrandMasterHasCuratedExtraPrintings({
  required String setId,
  required String setName,
}) =>
    _isAscendedHeroes(setId, setName);

int? _printedNumber(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(0)!);
}

int englishGrandMasterExtraPrintingMask({
  required String setId,
  required String setName,
  required String cardNumber,
}) {
  if (!_isAscendedHeroes(setId, setName)) return 0;
  final number = _printedNumber(cardNumber);
  if (number == null || number < 1 || number > 217) return 0;

  var mask = 0;
  if (_ascendedHeroesReverseHolo.contains(number)) {
    mask |= englishGrandMasterReverseHoloBit;
  }
  if (_ascendedHeroesPokeBall.contains(number)) {
    mask |= englishGrandMasterPokeBallBit;
  }
  if (_ascendedHeroesEnergySymbol.contains(number)) {
    mask |= englishGrandMasterEnergySymbolBit;
  }
  if (_ascendedHeroesDuskBall.contains(number)) {
    mask |= englishGrandMasterDuskBallBit;
  }
  if (_ascendedHeroesLoveBall.contains(number)) {
    mask |= englishGrandMasterLoveBallBit;
  }
  if (_ascendedHeroesFriendBall.contains(number)) {
    mask |= englishGrandMasterFriendBallBit;
  }
  if (_ascendedHeroesQuickBall.contains(number)) {
    mask |= englishGrandMasterQuickBallBit;
  }
  if (_ascendedHeroesTeamRocket.contains(number)) {
    mask |= englishGrandMasterTeamRocketBit;
  }
  return mask;
}
