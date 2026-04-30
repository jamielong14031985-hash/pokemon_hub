const String kDefaultCardCondition = 'Not set';

const List<String> kCardConditionOptions = <String>[
  kDefaultCardCondition,
  'Near Mint',
  'Excellent',
  'Good',
  'Lightly Played',
  'Played',
  'Poor',
  'Damaged',
];

const List<String> kGradingCompanyOptions = <String>[
  '',
  'PSA',
  'CGC',
  'BGS',
  'SGC',
  'ACE',
  'Other',
];

String normaliseCardCondition(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return kDefaultCardCondition;
  for (final option in kCardConditionOptions) {
    if (option.toLowerCase() == trimmed.toLowerCase()) {
      return option;
    }
  }
  return trimmed;
}

String formatCardGrade(double? grade) {
  if (grade == null || !grade.isFinite || grade <= 0) return '';
  if (grade == grade.roundToDouble()) {
    return grade.toInt().toString();
  }
  return grade.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}

double? parseStoredCardGrade(dynamic rawGrade) {
  if (rawGrade == null) return null;
  if (rawGrade is num) {
    final value = rawGrade.toDouble();
    return value.isFinite && value > 0 ? value : null;
  }
  final value = double.tryParse(rawGrade.toString().trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}
