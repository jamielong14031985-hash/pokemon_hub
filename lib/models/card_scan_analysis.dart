import 'tcg_card.dart';

class CardScanAnalysis {
  const CardScanAnalysis({
    required this.extractedText,
    required this.candidateNames,
    required this.candidateNumbers,
    required this.matches,
    required this.exactConfirmed,
  });

  final String extractedText;
  final List<String> candidateNames;
  final List<String> candidateNumbers;
  final List<TcgCard> matches;
  final bool exactConfirmed;

  TcgCard? get bestMatch => exactConfirmed && matches.isNotEmpty ? matches.first : null;
}
