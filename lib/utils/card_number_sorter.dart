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
  final match = RegExp(r'^(\d+)').firstMatch(value);
  if (match != null) {
    return CardNumberParts(
      int.tryParse(match.group(1) ?? '') ?? 999999,
      value,
    );
  }

  return CardNumberParts(999999, value);
}
