import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Printed metadata read from the physical card itself.
///
/// This service intentionally uses the LATIN text recognizer only.
/// Japanese Pokémon cards still print useful identifiers such as:
///
///   SM12a
///   083/173
///
/// using Latin letters and numbers. That lets PocketChase identify a
/// Japanese printing without loading the optional Japanese ML Kit model.
class CardPrintedIdentity {
  const CardPrintedIdentity({
    required this.rawText,
    required this.japaneseSetCode,
    required this.collectorNumber,
    required this.printedTotal,
  });

  final String rawText;
  final String? japaneseSetCode;
  final String? collectorNumber;
  final String? printedTotal;

  bool get isJapanesePrinting =>
      (japaneseSetCode ?? '').trim().isNotEmpty;
}

class CardScanLanguageService {
  CardScanLanguageService();

  final TextRecognizer _latinRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<CardPrintedIdentity> analyseCardImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Card image does not exist: $imagePath');
    }

    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _latinRecognizer.processImage(inputImage);
    final rawText = result.text.trim();

    return CardPrintedIdentity(
      rawText: rawText,
      japaneseSetCode: _extractJapaneseSetCode(rawText),
      collectorNumber: _extractCollectorNumber(rawText),
      printedTotal: _extractPrintedTotal(rawText),
    );
  }

  String _cleanForMatching(String value) {
    return value
        .replaceAll('／', '/')
        .replaceAll('‐', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  String? _extractJapaneseSetCode(String text) {
    final cleaned = _cleanForMatching(text);

    // Japanese Pokémon set codes are commonly printed directly on the card.
    // Examples:
    // SM12a, SM9b, S12a, S8a, SV2a, SV5K, SV5M, SV9, SV10,
    // S-P, SM-P, SV-P, XY-P.
    //
    // English expansion abbreviations such as UNB, PAL and MEW do not match
    // these patterns.
    final patterns = <RegExp>[
      RegExp(
        r'(?<![A-Za-z0-9])'
        r'(SV-P|S-P|SM-P|XY-P|BW-P)'
        r'(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      RegExp(
        r'(?<![A-Za-z0-9])'
        r'(SM\d{1,2}[A-Za-z])'
        r'(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      RegExp(
        r'(?<![A-Za-z0-9])'
        r'(SV\d{1,2}[A-Za-z]?)'
        r'(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      RegExp(
        r'(?<![A-Za-z0-9])'
        r'(S\d{1,2}[A-Za-z]?)'
        r'(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      RegExp(
        r'(?<![A-Za-z0-9])'
        r'(XY\d{1,2}[A-Za-z])'
        r'(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      RegExp(
        r'(?<![A-Za-z0-9])'
        r'(BW\d{1,2}[A-Za-z])'
        r'(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      RegExp(
        r'(?<![A-Za-z0-9])'
        r'(DPT?\d{1,2}[A-Za-z]?)'
        r'(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return _normaliseSetCode(value);
      }
    }

    return null;
  }

  RegExpMatch? _collectorFractionMatch(String text) {
    final cleaned = _cleanForMatching(text);

    // Match normal collector numbering such as:
    // 083/173
    // 120/214
    // 224/173
    //
    // Keep this intentionally conservative so HP/attack numbers do not become
    // collector numbers.
    return RegExp(
      r'(?<!\d)(\d{1,3})\s*/\s*(\d{1,3})(?!\d)',
    ).firstMatch(cleaned);
  }

  String? _extractCollectorNumber(String text) {
    final match = _collectorFractionMatch(text);
    final value = match?.group(1);
    if (value == null || value.trim().isEmpty) return null;

    final parsed = int.tryParse(value);
    if (parsed == null) return value.trim();

    // Preserve three-digit card formatting where useful. The Japanese lookup
    // also tries unpadded values, so both 083 and 83 resolve safely.
    return parsed.toString().padLeft(3, '0');
  }

  String? _extractPrintedTotal(String text) {
    final match = _collectorFractionMatch(text);
    final value = match?.group(2);
    if (value == null || value.trim().isEmpty) return null;

    final parsed = int.tryParse(value);
    if (parsed == null) return value.trim();
    return parsed.toString().padLeft(3, '0');
  }

  String _normaliseSetCode(String value) {
    final compact = value
        .trim()
        .replaceAll(' ', '')
        .replaceAll('‐', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-');

    // TCGdex set/card IDs are handled case-insensitively by the scanner and
    // are normalised to lower case before API requests.
    return compact;
  }

  Future<void> dispose() async {
    await _latinRecognizer.close();
  }
}
