class ScanLineHint {
  const ScanLineHint({
    required this.text,
    required this.topFraction,
    required this.leftFraction,
    required this.widthFraction,
    required this.heightFraction,
  });

  final String text;
  final double topFraction;
  final double leftFraction;
  final double widthFraction;
  final double heightFraction;
}
