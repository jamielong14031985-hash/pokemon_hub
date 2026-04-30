DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

int calculateAgeYears(DateTime dateOfBirth, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final birthDate = dateOnly(dateOfBirth);
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age;
}

String formatDateOfBirth(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}
