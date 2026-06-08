import '../utils/card_condition_helpers.dart';

class CardOwnership {
  const CardOwnership({
    this.normal = false,
    this.reverseHolo = false,
    this.holo = false,
    this.copies = 0,
    this.normalCopies = 0,
    this.reverseHoloCopies = 0,
    this.holoCopies = 0,
    this.condition = kDefaultCardCondition,
    this.gradingCompany = '',
    this.grade,
    this.conditionNotes = '',
  });

  /// Legacy booleans kept for backwards compatibility with older saved data.
  final bool normal;
  final bool reverseHolo;
  final bool holo;

  /// Legacy shared copy count kept for backwards compatibility.
  /// New code should use normalCopies/reverseHoloCopies/holoCopies.
  final int copies;

  /// Variant-specific duplicate counts.
  final int normalCopies;
  final int reverseHoloCopies;
  final int holoCopies;

  final String condition;
  final String gradingCompany;
  final double? grade;
  final String conditionNotes;

  bool get _hasVariantCopyCounts =>
      normalCopies > 0 || reverseHoloCopies > 0 || holoCopies > 0;

  int get normalCount {
    if (normalCopies > 0) return normalCopies;
    if (!normal) return 0;

    if (_hasVariantCopyCounts) return 1;

    final otherSlotsOwned = reverseHolo || holo;
    if (!otherSlotsOwned && copies > 0) return copies;

    return 1;
  }

  int get reverseHoloCount {
    if (reverseHoloCopies > 0) return reverseHoloCopies;
    if (!reverseHolo) return 0;

    if (_hasVariantCopyCounts) return 1;

    final otherSlotsOwned = normal || holo;
    if (!otherSlotsOwned && copies > 0) return copies;

    return 1;
  }

  int get holoCount {
    if (holoCopies > 0) return holoCopies;
    if (!holo) return 0;

    if (_hasVariantCopyCounts) return 1;

    final otherSlotsOwned = normal || reverseHolo;
    if (!otherSlotsOwned && copies > 0) return copies;

    return 1;
  }

  int get effectiveCopies => collectionCount;

  int get ownedSlotCount {
    var count = 0;
    if (normalCount > 0) count++;
    if (reverseHoloCount > 0) count++;
    if (holoCount > 0) count++;
    return count;
  }

  int get collectionCount => normalCount + reverseHoloCount + holoCount;

  bool get hasConditionDetails {
    return (condition.trim().isNotEmpty && condition.trim() != kDefaultCardCondition) ||
        gradingCompany.trim().isNotEmpty ||
        grade != null ||
        conditionNotes.trim().isNotEmpty;
  }

  String get conditionSummary {
    final parts = <String>[];
    final safeCondition = normaliseCardCondition(condition);
    if (safeCondition != kDefaultCardCondition) {
      parts.add(safeCondition);
    }

    final safeCompany = gradingCompany.trim();
    final gradeText = formatCardGrade(grade);
    if (safeCompany.isNotEmpty && gradeText.isNotEmpty) {
      parts.add('$safeCompany $gradeText');
    } else if (safeCompany.isNotEmpty) {
      parts.add('$safeCompany graded');
    } else if (gradeText.isNotEmpty) {
      parts.add('Grade $gradeText');
    }

    final notes = conditionNotes.trim();
    if (notes.isNotEmpty) {
      parts.add('Notes: $notes');
    }

    return parts.join(' • ');
  }

  CardOwnership copyWith({
    bool? normal,
    bool? reverseHolo,
    bool? holo,
    int? copies,
    int? normalCopies,
    int? reverseHoloCopies,
    int? holoCopies,
    String? condition,
    String? gradingCompany,
    double? grade,
    bool clearGrade = false,
    String? conditionNotes,
  }) {
    var nextNormalCopies = normalCopies ?? normalCount;
    var nextReverseHoloCopies = reverseHoloCopies ?? reverseHoloCount;
    var nextHoloCopies = holoCopies ?? holoCount;

    if (normal != null) {
      nextNormalCopies = normal ? (nextNormalCopies > 0 ? nextNormalCopies : 1) : 0;
    }
    if (reverseHolo != null) {
      nextReverseHoloCopies = reverseHolo
          ? (nextReverseHoloCopies > 0 ? nextReverseHoloCopies : 1)
          : 0;
    }
    if (holo != null) {
      nextHoloCopies = holo ? (nextHoloCopies > 0 ? nextHoloCopies : 1) : 0;
    }

    // Backwards compatibility for older screens that still pass only a shared
    // copies value. If only one variant is selected, apply that shared count to
    // that variant. If multiple variants are selected, keep each variant's own
    // count instead of duplicating the shared count across every slot.
    if (copies != null &&
        normalCopies == null &&
        reverseHoloCopies == null &&
        holoCopies == null) {
      final activeSlots = <String>[];
      if (nextNormalCopies > 0) activeSlots.add('normal');
      if (nextReverseHoloCopies > 0) activeSlots.add('reverseHolo');
      if (nextHoloCopies > 0) activeSlots.add('holo');

      final safeCopies = copies < 0 ? 0 : copies;
      if (safeCopies == 0) {
        nextNormalCopies = 0;
        nextReverseHoloCopies = 0;
        nextHoloCopies = 0;
      } else if (activeSlots.length <= 1) {
        if (activeSlots.isEmpty || activeSlots.first == 'normal') {
          nextNormalCopies = safeCopies;
          nextReverseHoloCopies = 0;
          nextHoloCopies = 0;
        } else if (activeSlots.first == 'reverseHolo') {
          nextNormalCopies = 0;
          nextReverseHoloCopies = safeCopies;
          nextHoloCopies = 0;
        } else {
          nextNormalCopies = 0;
          nextReverseHoloCopies = 0;
          nextHoloCopies = safeCopies;
        }
      }
    }

    final totalCopies = nextNormalCopies + nextReverseHoloCopies + nextHoloCopies;

    return CardOwnership(
      normal: nextNormalCopies > 0,
      reverseHolo: nextReverseHoloCopies > 0,
      holo: nextHoloCopies > 0,
      copies: totalCopies,
      normalCopies: nextNormalCopies,
      reverseHoloCopies: nextReverseHoloCopies,
      holoCopies: nextHoloCopies,
      condition: condition ?? this.condition,
      gradingCompany: gradingCompany ?? this.gradingCompany,
      grade: clearGrade ? null : (grade ?? this.grade),
      conditionNotes: conditionNotes ?? this.conditionNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'normal': normalCount > 0,
        'reverseHolo': reverseHoloCount > 0,
        'holo': holoCount > 0,
        'copies': collectionCount,
        'normalCopies': normalCount,
        'reverseHoloCopies': reverseHoloCount,
        'holoCopies': holoCount,
        if (normaliseCardCondition(condition) != kDefaultCardCondition)
          'condition': normaliseCardCondition(condition),
        if (gradingCompany.trim().isNotEmpty) 'gradingCompany': gradingCompany.trim(),
        if (grade != null && grade!.isFinite && grade! > 0) 'grade': grade,
        if (conditionNotes.trim().isNotEmpty) 'conditionNotes': conditionNotes.trim(),
      };

  factory CardOwnership.fromJson(Map<String, dynamic> json) {
    final parsedNormalCopies = (json['normalCopies'] as num?)?.toInt() ?? 0;
    final parsedReverseHoloCopies = (json['reverseHoloCopies'] as num?)?.toInt() ?? 0;
    final parsedHoloCopies = (json['holoCopies'] as num?)?.toInt() ?? 0;
    final hasNewVariantCounts = json.containsKey('normalCopies') ||
        json.containsKey('reverseHoloCopies') ||
        json.containsKey('holoCopies');

    if (hasNewVariantCounts) {
      return CardOwnership(
        normal: parsedNormalCopies > 0 || json['normal'] == true,
        reverseHolo: parsedReverseHoloCopies > 0 || json['reverseHolo'] == true,
        holo: parsedHoloCopies > 0 || json['holo'] == true,
        copies: (json['copies'] as num?)?.toInt() ??
            (parsedNormalCopies + parsedReverseHoloCopies + parsedHoloCopies),
        normalCopies: parsedNormalCopies,
        reverseHoloCopies: parsedReverseHoloCopies,
        holoCopies: parsedHoloCopies,
        condition: normaliseCardCondition((json['condition'] ?? '').toString()),
        gradingCompany: (json['gradingCompany'] ?? json['gradeCompany'] ?? '').toString().trim(),
        grade: parseStoredCardGrade(json['grade']),
        conditionNotes: (json['conditionNotes'] ?? json['notes'] ?? '').toString().trim(),
      );
    }

    final legacyNormal = json['normal'] == true;
    final legacyReverseHolo = json['reverseHolo'] == true;
    final legacyHolo = json['holo'] == true;
    final legacyCopies = (json['copies'] as num?)?.toInt() ?? 0;

    var normalCopies = 0;
    var reverseHoloCopies = 0;
    var holoCopies = 0;

    final activeCount = [legacyNormal, legacyReverseHolo, legacyHolo]
        .where((owned) => owned)
        .length;

    if (activeCount == 0 && legacyCopies > 0) {
      normalCopies = legacyCopies;
    } else if (activeCount == 1) {
      final count = legacyCopies > 0 ? legacyCopies : 1;
      if (legacyNormal) normalCopies = count;
      if (legacyReverseHolo) reverseHoloCopies = count;
      if (legacyHolo) holoCopies = count;
    } else {
      if (legacyNormal) normalCopies = 1;
      if (legacyReverseHolo) reverseHoloCopies = 1;
      if (legacyHolo) holoCopies = 1;
    }

    return CardOwnership(
      normal: normalCopies > 0,
      reverseHolo: reverseHoloCopies > 0,
      holo: holoCopies > 0,
      copies: normalCopies + reverseHoloCopies + holoCopies,
      normalCopies: normalCopies,
      reverseHoloCopies: reverseHoloCopies,
      holoCopies: holoCopies,
      condition: normaliseCardCondition((json['condition'] ?? '').toString()),
      gradingCompany: (json['gradingCompany'] ?? json['gradeCompany'] ?? '').toString().trim(),
      grade: parseStoredCardGrade(json['grade']),
      conditionNotes: (json['conditionNotes'] ?? json['notes'] ?? '').toString().trim(),
    );
  }
}
