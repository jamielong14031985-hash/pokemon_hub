import 'dart:math' as math;

import '../services/community_image_services.dart';
import '../utils/card_condition_helpers.dart';
import 'card_ownership.dart';
import 'tcg_card.dart';

String _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

class CustomBinder {
  const CustomBinder({
    required this.id,
    required this.name,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.imageBase64,
  });

  final String id;
  final String name;
  final int createdAtMs;
  final int updatedAtMs;
  final String? imageBase64;

  bool get hasImage => imageBase64 != null && imageBase64!.trim().isNotEmpty;

  CustomBinder copyWith({
    String? name,
    int? createdAtMs,
    int? updatedAtMs,
    String? imageBase64,
    bool clearImage = false,
  }) {
    return CustomBinder(
      id: id,
      name: name ?? this.name,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      imageBase64: clearImage ? null : (imageBase64 ?? this.imageBase64),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        if (hasImage) 'imageRef': imageBase64!.trim(),
        if (hasImage && FirebaseImageStorageService.isRemoteRef(imageBase64)) 'imageUrl': imageBase64!.trim(),
        if (hasImage && !FirebaseImageStorageService.isRemoteRef(imageBase64)) 'imageBase64': imageBase64!.trim(),
      };

  factory CustomBinder.fromJson(Map<String, dynamic> json) {
    final rawImage = _firstNonEmptyString([
      json['imageRef'],
      json['imageUrl'],
      json['imageBase64'],
    ]);
    return CustomBinder(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Custom Binder').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      imageBase64: rawImage.isEmpty ? null : rawImage,
    );
  }
}

class CustomBinderCardEntry {
  const CustomBinderCardEntry({
    required this.cardId,
    required this.name,
    required this.setId,
    required this.setName,
    required this.number,
    required this.updatedAtMs,
    this.imageUrl,
    this.largeImageUrl,
    this.setLogoUrl,
    this.normal = true,
    this.reverseHolo = false,
    this.holo = false,
    this.copies = 1,
    this.condition = kDefaultCardCondition,
    this.gradingCompany = '',
    this.grade,
    this.conditionNotes = '',
  });

  final String cardId;
  final String name;
  final String setId;
  final String setName;
  final String number;
  final String? imageUrl;
  final String? largeImageUrl;
  final String? setLogoUrl;
  final bool normal;
  final bool reverseHolo;
  final bool holo;
  final int copies;
  final String condition;
  final String gradingCompany;
  final double? grade;
  final String conditionNotes;
  final int updatedAtMs;

  CardOwnership get ownership => CardOwnership(
        normal: normal,
        reverseHolo: reverseHolo,
        holo: holo,
        copies: copies,
        condition: condition,
        gradingCompany: gradingCompany,
        grade: grade,
        conditionNotes: conditionNotes,
      );

  TcgCard toSummaryCard() {
    return TcgCard(
      id: cardId,
      name: name,
      setId: setId,
      setName: setName,
      number: number,
      types: const <String>[],
      imageUrl: imageUrl,
      largeImageUrl: largeImageUrl,
      setLogoUrl: setLogoUrl,
    );
  }

  CustomBinderCardEntry copyWith({
    String? name,
    String? setId,
    String? setName,
    String? number,
    String? imageUrl,
    String? largeImageUrl,
    String? setLogoUrl,
    bool? normal,
    bool? reverseHolo,
    bool? holo,
    int? copies,
    String? condition,
    String? gradingCompany,
    double? grade,
    bool clearGrade = false,
    String? conditionNotes,
    int? updatedAtMs,
  }) {
    return CustomBinderCardEntry(
      cardId: cardId,
      name: name ?? this.name,
      setId: setId ?? this.setId,
      setName: setName ?? this.setName,
      number: number ?? this.number,
      imageUrl: imageUrl ?? this.imageUrl,
      largeImageUrl: largeImageUrl ?? this.largeImageUrl,
      setLogoUrl: setLogoUrl ?? this.setLogoUrl,
      normal: normal ?? this.normal,
      reverseHolo: reverseHolo ?? this.reverseHolo,
      holo: holo ?? this.holo,
      copies: copies ?? this.copies,
      condition: condition ?? this.condition,
      gradingCompany: gradingCompany ?? this.gradingCompany,
      grade: clearGrade ? null : (grade ?? this.grade),
      conditionNotes: conditionNotes ?? this.conditionNotes,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'name': name,
        'setId': setId,
        'setName': setName,
        'number': number,
        if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl!.trim(),
        if (largeImageUrl != null && largeImageUrl!.trim().isNotEmpty) 'largeImageUrl': largeImageUrl!.trim(),
        if (setLogoUrl != null && setLogoUrl!.trim().isNotEmpty) 'setLogoUrl': setLogoUrl!.trim(),
        'normal': normal,
        'reverseHolo': reverseHolo,
        'holo': holo,
        'copies': copies,
        if (normaliseCardCondition(condition) != kDefaultCardCondition)
          'condition': normaliseCardCondition(condition),
        if (gradingCompany.trim().isNotEmpty) 'gradingCompany': gradingCompany.trim(),
        if (grade != null && grade!.isFinite && grade! > 0) 'grade': grade,
        if (conditionNotes.trim().isNotEmpty) 'conditionNotes': conditionNotes.trim(),
        'updatedAtMs': updatedAtMs,
      };

  factory CustomBinderCardEntry.fromJson(Map<String, dynamic> json) {
    return CustomBinderCardEntry(
      cardId: (json['cardId'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Card').toString(),
      setId: (json['setId'] ?? '').toString(),
      setName: (json['setName'] ?? 'Unknown Set').toString(),
      number: (json['number'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (json['imageUrl'] ?? '').toString().trim(),
      largeImageUrl: (json['largeImageUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (json['largeImageUrl'] ?? '').toString().trim(),
      setLogoUrl: (json['setLogoUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (json['setLogoUrl'] ?? '').toString().trim(),
      normal: json['normal'] != false,
      reverseHolo: json['reverseHolo'] == true,
      holo: json['holo'] == true,
      copies: math.max(1, (json['copies'] as num?)?.toInt() ?? 1),
      condition: normaliseCardCondition((json['condition'] ?? '').toString()),
      gradingCompany: (json['gradingCompany'] ?? json['gradeCompany'] ?? '').toString().trim(),
      grade: parseStoredCardGrade(json['grade']),
      conditionNotes: (json['conditionNotes'] ?? json['notes'] ?? '').toString().trim(),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  factory CustomBinderCardEntry.fromCard(
    TcgCard card, {
    CardOwnership ownership = const CardOwnership(normal: true, copies: 1),
    int? updatedAtMs,
  }) {
    final safeOwnership = ownership.effectiveCopies > 0
        ? ownership
        : const CardOwnership(normal: true, copies: 1);
    return CustomBinderCardEntry(
      cardId: card.id,
      name: card.name,
      setId: card.setId,
      setName: card.setName,
      number: card.number,
      imageUrl: card.imageUrl,
      largeImageUrl: card.largeImageUrl,
      setLogoUrl: card.setLogoUrl,
      normal: safeOwnership.normal || (!safeOwnership.reverseHolo && !safeOwnership.holo),
      reverseHolo: safeOwnership.reverseHolo,
      holo: safeOwnership.holo,
      copies: math.max(1, safeOwnership.effectiveCopies),
      condition: safeOwnership.condition,
      gradingCompany: safeOwnership.gradingCompany,
      grade: safeOwnership.grade,
      conditionNotes: safeOwnership.conditionNotes,
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
