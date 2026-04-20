import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class VisionExtraction {
  const VisionExtraction({
    required this.pokemonName,
    required this.cardName,
    required this.collectorNumber,
    required this.printedTotal,
    required this.setCode,
    required this.setName,
    required this.hp,
    required this.supertype,
    required this.subtypes,
    required this.attacks,
    required this.abilities,
    required this.rulesText,
    required this.rarityHint,
    required this.exactCardConfidence,
    required this.notes,
  });

  final String? pokemonName;
  final String? cardName;
  final String? collectorNumber;
  final String? printedTotal;
  final String? setCode;
  final String? setName;
  final int? hp;
  final String? supertype;
  final List<String> subtypes;
  final List<String> attacks;
  final List<String> abilities;
  final List<String> rulesText;
  final String? rarityHint;
  final double exactCardConfidence;
  final List<String> notes;

  factory VisionExtraction.fromJson(Map<String, dynamic> json) {
    List<String> toList(dynamic value) => (value as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return VisionExtraction(
      pokemonName: json['pokemon_name']?.toString(),
      cardName: json['card_name']?.toString(),
      collectorNumber: json['collector_number']?.toString(),
      printedTotal: json['printed_total']?.toString(),
      setCode: json['set_code']?.toString(),
      setName: json['set_name']?.toString(),
      hp: (json['hp'] as num?)?.toInt(),
      supertype: json['supertype']?.toString(),
      subtypes: toList(json['subtypes']),
      attacks: toList(json['attacks']),
      abilities: toList(json['abilities']),
      rulesText: toList(json['rules_text']),
      rarityHint: json['rarity_hint']?.toString(),
      exactCardConfidence: (json['exact_card_confidence'] as num?)?.toDouble() ?? 0,
      notes: toList(json['notes']),
    );
  }
}

class VisionResolvedCard {
  const VisionResolvedCard({
    required this.id,
    required this.name,
    required this.number,
    required this.setId,
    required this.setName,
    required this.imageUrl,
    required this.largeImageUrl,
    required this.score,
    required this.supertype,
    required this.hp,
  });

  final String id;
  final String name;
  final String number;
  final String setId;
  final String setName;
  final String? imageUrl;
  final String? largeImageUrl;
  final int score;
  final String? supertype;
  final String? hp;

  factory VisionResolvedCard.fromJson(Map<String, dynamic> json) {
    final card = json['card'] is Map
        ? Map<String, dynamic>.from(json['card'] as Map)
        : Map<String, dynamic>.from(json);
    final set = Map<String, dynamic>.from(card['set'] as Map? ?? const {});
    final images = Map<String, dynamic>.from(card['images'] as Map? ?? const {});

    return VisionResolvedCard(
      id: card['id']?.toString() ?? '',
      name: card['name']?.toString() ?? 'Unknown card',
      number: card['number']?.toString() ?? '',
      setId: set['id']?.toString() ?? '',
      setName: set['name']?.toString() ?? '',
      imageUrl: images['small']?.toString(),
      largeImageUrl: images['large']?.toString(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      supertype: card['supertype']?.toString(),
      hp: card['hp']?.toString(),
    );
  }
}

class VisionDebugData {
  const VisionDebugData({
    required this.initialBestMatch,
    required this.initialPossibleMatches,
  });

  final VisionResolvedCard? initialBestMatch;
  final List<VisionResolvedCard> initialPossibleMatches;

  factory VisionDebugData.fromJson(Map<String, dynamic> json) {
    final best = json['initialBestMatch'];
    final matches = (json['initialPossibleMatches'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => VisionResolvedCard.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return VisionDebugData(
      initialBestMatch: best is Map<String, dynamic>
          ? VisionResolvedCard.fromJson(best)
          : best is Map
              ? VisionResolvedCard.fromJson(Map<String, dynamic>.from(best))
              : null,
      initialPossibleMatches: matches,
    );
  }
}

class VisionScanResponse {
  const VisionScanResponse({
    required this.extraction,
    required this.exactConfirmed,
    required this.bestMatch,
    required this.possibleMatches,
    required this.candidateSetIds,
    required this.debug,
  });

  final VisionExtraction extraction;
  final bool exactConfirmed;
  final VisionResolvedCard? bestMatch;
  final List<VisionResolvedCard> possibleMatches;
  final List<String> candidateSetIds;
  final VisionDebugData debug;

  factory VisionScanResponse.fromJson(Map<String, dynamic> json) {
    final best = json['bestMatch'];
    final matches = (json['possibleMatches'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => VisionResolvedCard.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final candidateSetIds = (json['candidateSetIds'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return VisionScanResponse(
      extraction: VisionExtraction.fromJson(
        Map<String, dynamic>.from(json['extraction'] as Map? ?? const {}),
      ),
      exactConfirmed: json['exactConfirmed'] == true,
      bestMatch: best is Map<String, dynamic>
          ? VisionResolvedCard.fromJson(best)
          : best is Map
              ? VisionResolvedCard.fromJson(Map<String, dynamic>.from(best))
              : null,
      possibleMatches: matches,
      candidateSetIds: candidateSetIds,
      debug: VisionDebugData.fromJson(
        Map<String, dynamic>.from(json['debug'] as Map? ?? const {}),
      ),
    );
  }
}

class PokemonHubVisionClient {
  const PokemonHubVisionClient({
    required this.endpoint,
    this.timeout = const Duration(seconds: 45),
  });

  final String endpoint;
  final Duration timeout;

  Future<VisionScanResponse> scanImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image not found: $imagePath');
    }

    final bytes = await file.readAsBytes();
    final body = {
      'imageBase64': base64Encode(bytes),
      'mimeType': _mimeTypeForPath(imagePath),
    };

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Vision scan failed: HTTP ${response.statusCode} ${response.body}');
    }

    return VisionScanResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
