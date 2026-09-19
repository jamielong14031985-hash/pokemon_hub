class CardNumberParts {
  const CardNumberParts(this.number, this.raw);

  final int number;
  final String raw;
}

int compareCardNumbers(String a, String b) {
  final aParts = splitCardNumber(a);
  final bParts = splitCardNumber(b);

  if (aParts.number != bParts.number) {
    return aParts.number.compareTo(bParts.number);
  }

  return aParts.raw.compareTo(bParts.raw);
}

CardNumberParts splitCardNumber(String value) {
  final normalized = value.trim().toUpperCase();
  final match = RegExp(r'^(\d+)').firstMatch(normalized);
  if (match != null) {
    return CardNumberParts(
      int.tryParse(match.group(1) ?? '') ?? 999999,
      normalized,
    );
  }

  // The 30th Celebration master checklist has three groups outside the main
  // numeric set. Keep the Classic Collection together first, then the three
  // RGB Mew cards as one group, followed by the eight MEE Energy cards.
  final classicMatch = RegExp(r'^CC(\d+)$').firstMatch(normalized);
  if (classicMatch != null) {
    final number = int.tryParse(classicMatch.group(1) ?? '') ?? 0;
    return CardNumberParts(1000000 + number, normalized);
  }

  const rgbOrder = <String, int>{
    'B/RGB': 1,
    'G/RGB': 2,
    'R/RGB': 3,
  };
  final rgbNumber = rgbOrder[normalized];
  if (rgbNumber != null) {
    return CardNumberParts(2000000 + rgbNumber, normalized);
  }

  final energyMatch = RegExp(r'^MEE(\d+)$').firstMatch(normalized);
  if (energyMatch != null) {
    final number = int.tryParse(energyMatch.group(1) ?? '') ?? 0;
    return CardNumberParts(3000000 + number, normalized);
  }

  return CardNumberParts(999999, normalized);
}
