import '../utils/card_condition_helpers.dart';

class CardOwnership {
  const CardOwnership({
    this.normal = false,
    this.reverseHolo = false,
    this.holo = false,
    this.pokeBallReverse = false,
    this.masterBallReverse = false,
    this.copies = 0,
    this.normalCopies = 0,
    this.reverseHoloCopies = 0,
    this.holoCopies = 0,
    this.pokeBallReverseCopies = 0,
    this.masterBallReverseCopies = 0,
    this.extraVariantCopies = const <String, int>{},
    this.condition = kDefaultCardCondition,
    this.gradingCompany = '',
    this.grade,
    this.conditionNotes = '',
  });

  /// Legacy booleans kept for backwards compatibility with older saved data.
  final bool normal;
  final bool reverseHolo;
  final bool holo;

  /// Japanese master-set variants used by sets such as Japanese 151.
  final bool pokeBallReverse;
  final bool masterBallReverse;

  /// Legacy shared copy count kept for backwards compatibility.
  /// New code should use variant-specific copy fields.
  final int copies;

  /// Variant-specific duplicate counts.
  final int normalCopies;
  final int reverseHoloCopies;
  final int holoCopies;
  final int pokeBallReverseCopies;
  final int masterBallReverseCopies;

  /// Additional official English printings used by Grand Master Sets.
  /// Keys are stable variant ids (for example `firstEditionHolo`).
  /// Keeping these in a map lets new stamped/product variants be added without
  /// breaking collections saved by an older app version.
  final Map<String, int> extraVariantCopies;

  final String condition;
  final String gradingCompany;
  final double? grade;
  final String conditionNotes;

  bool get _hasVariantCopyCounts =>
      normalCopies > 0 ||
      reverseHoloCopies > 0 ||
      holoCopies > 0 ||
      pokeBallReverseCopies > 0 ||
      masterBallReverseCopies > 0;

  int get normalCount {
    if (normalCopies > 0) return normalCopies;
    if (!normal) return 0;

    if (_hasVariantCopyCounts) return 1;

    final otherSlotsOwned = reverseHolo || holo || pokeBallReverse || masterBallReverse;
    if (!otherSlotsOwned && copies > 0) return copies;

    return 1;
  }

  int get reverseHoloCount {
    if (reverseHoloCopies > 0) return reverseHoloCopies;
    if (!reverseHolo) return 0;

    if (_hasVariantCopyCounts) return 1;

    final otherSlotsOwned = normal || holo || pokeBallReverse || masterBallReverse;
    if (!otherSlotsOwned && copies > 0) return copies;

    return 1;
  }

  int get holoCount {
    if (holoCopies > 0) return holoCopies;
    if (!holo) return 0;

    if (_hasVariantCopyCounts) return 1;

    final otherSlotsOwned = normal || reverseHolo || pokeBallReverse || masterBallReverse;
    if (!otherSlotsOwned && copies > 0) return copies;

    return 1;
  }

  int get pokeBallReverseCount {
    if (pokeBallReverseCopies > 0) return pokeBallReverseCopies;
    if (!pokeBallReverse) return 0;

    if (_hasVariantCopyCounts) return 1;

    final otherSlotsOwned = normal || reverseHolo || holo || masterBallReverse;
    if (!otherSlotsOwned && copies > 0) return copies;

    return 1;
  }

  int get masterBallReverseCount {
    if (masterBallReverseCopies > 0) return masterBallReverseCopies;
    if (!masterBallReverse) return 0;

    if (_hasVariantCopyCounts) return 1;

    final otherSlotsOwned = normal || reverseHolo || holo || pokeBallReverse;
    if (!otherSlotsOwned && copies > 0) return copies;

    return 1;
  }

  int get effectiveCopies => collectionCount;

  int extraVariantCount(String variantId) {
    final value = extraVariantCopies[variantId] ?? 0;
    return value < 0 ? 0 : value;
  }

  int get ownedSlotCount {
    var count = 0;
    if (normalCount > 0) count++;
    if (reverseHoloCount > 0) count++;
    if (holoCount > 0) count++;
    if (pokeBallReverseCount > 0) count++;
    if (masterBallReverseCount > 0) count++;
    count += extraVariantCopies.values.where((value) => value > 0).length;
    return count;
  }

  int get collectionCount =>
      normalCount +
      reverseHoloCount +
      holoCount +
      pokeBallReverseCount +
      masterBallReverseCount +
      extraVariantCopies.values.fold<int>(0, (total, value) => total + (value > 0 ? value : 0));

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
    bool? pokeBallReverse,
    bool? masterBallReverse,
    int? copies,
    int? normalCopies,
    int? reverseHoloCopies,
    int? holoCopies,
    int? pokeBallReverseCopies,
    int? masterBallReverseCopies,
    Map<String, int>? extraVariantCopies,
    String? condition,
    String? gradingCompany,
    double? grade,
    bool clearGrade = false,
    String? conditionNotes,
  }) {
    var nextNormalCopies = normalCopies ?? normalCount;
    var nextReverseHoloCopies = reverseHoloCopies ?? reverseHoloCount;
    var nextHoloCopies = holoCopies ?? holoCount;
    var nextPokeBallReverseCopies = pokeBallReverseCopies ?? pokeBallReverseCount;
    var nextMasterBallReverseCopies = masterBallReverseCopies ?? masterBallReverseCount;

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
    if (pokeBallReverse != null) {
      nextPokeBallReverseCopies = pokeBallReverse
          ? (nextPokeBallReverseCopies > 0 ? nextPokeBallReverseCopies : 1)
          : 0;
    }
    if (masterBallReverse != null) {
      nextMasterBallReverseCopies = masterBallReverse
          ? (nextMasterBallReverseCopies > 0 ? nextMasterBallReverseCopies : 1)
          : 0;
    }

    // Backwards compatibility for older screens that still pass only a shared
    // copies value. If only one variant is selected, apply that shared count to
    // that variant. If multiple variants are selected, keep each variant's own
    // count instead of duplicating the shared count across every slot.
    if (copies != null &&
        normalCopies == null &&
        reverseHoloCopies == null &&
        holoCopies == null &&
        pokeBallReverseCopies == null &&
        masterBallReverseCopies == null) {
      final activeSlots = <String>[];
      if (nextNormalCopies > 0) activeSlots.add('normal');
      if (nextReverseHoloCopies > 0) activeSlots.add('reverseHolo');
      if (nextHoloCopies > 0) activeSlots.add('holo');
      if (nextPokeBallReverseCopies > 0) activeSlots.add('pokeBallReverse');
      if (nextMasterBallReverseCopies > 0) activeSlots.add('masterBallReverse');

      final safeCopies = copies < 0 ? 0 : copies;
      if (safeCopies == 0) {
        nextNormalCopies = 0;
        nextReverseHoloCopies = 0;
        nextHoloCopies = 0;
        nextPokeBallReverseCopies = 0;
        nextMasterBallReverseCopies = 0;
      } else if (activeSlots.length <= 1) {
        nextNormalCopies = 0;
        nextReverseHoloCopies = 0;
        nextHoloCopies = 0;
        nextPokeBallReverseCopies = 0;
        nextMasterBallReverseCopies = 0;

        final selectedSlot = activeSlots.isEmpty ? 'normal' : activeSlots.first;
        if (selectedSlot == 'normal') {
          nextNormalCopies = safeCopies;
        } else if (selectedSlot == 'reverseHolo') {
          nextReverseHoloCopies = safeCopies;
        } else if (selectedSlot == 'holo') {
          nextHoloCopies = safeCopies;
        } else if (selectedSlot == 'pokeBallReverse') {
          nextPokeBallReverseCopies = safeCopies;
        } else {
          nextMasterBallReverseCopies = safeCopies;
        }
      }
    }

    final nextExtraVariantCopies = Map<String, int>.unmodifiable(
      extraVariantCopies ?? this.extraVariantCopies,
    );
    final totalCopies = nextNormalCopies +
        nextReverseHoloCopies +
        nextHoloCopies +
        nextPokeBallReverseCopies +
        nextMasterBallReverseCopies +
        nextExtraVariantCopies.values.fold<int>(
          0,
          (total, value) => total + (value > 0 ? value : 0),
        );

    return CardOwnership(
      normal: nextNormalCopies > 0,
      reverseHolo: nextReverseHoloCopies > 0,
      holo: nextHoloCopies > 0,
      pokeBallReverse: nextPokeBallReverseCopies > 0,
      masterBallReverse: nextMasterBallReverseCopies > 0,
      copies: totalCopies,
      normalCopies: nextNormalCopies,
      reverseHoloCopies: nextReverseHoloCopies,
      holoCopies: nextHoloCopies,
      pokeBallReverseCopies: nextPokeBallReverseCopies,
      masterBallReverseCopies: nextMasterBallReverseCopies,
      extraVariantCopies: nextExtraVariantCopies,
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
        'pokeBallReverse': pokeBallReverseCount > 0,
        'masterBallReverse': masterBallReverseCount > 0,
        'copies': collectionCount,
        'normalCopies': normalCount,
        'reverseHoloCopies': reverseHoloCount,
        'holoCopies': holoCount,
        'pokeBallReverseCopies': pokeBallReverseCount,
        'masterBallReverseCopies': masterBallReverseCount,
        if (extraVariantCopies.isNotEmpty)
          'extraVariantCopies': <String, int>{
            for (final entry in extraVariantCopies.entries)
              if (entry.value > 0) entry.key: entry.value,
          },
        if (normaliseCardCondition(condition) != kDefaultCardCondition)
          'condition': normaliseCardCondition(condition),
        if (gradingCompany.trim().isNotEmpty) 'gradingCompany': gradingCompany.trim(),
        if (grade != null && grade!.isFinite && grade! > 0) 'grade': grade,
        if (conditionNotes.trim().isNotEmpty) 'conditionNotes': conditionNotes.trim(),
      };

  factory CardOwnership.fromJson(Map<String, dynamic> json) {
    final rawExtraVariants = json['extraVariantCopies'];
    final parsedExtraVariants = <String, int>{};
    if (rawExtraVariants is Map) {
      for (final entry in rawExtraVariants.entries) {
        final count = entry.value is num
            ? (entry.value as num).toInt()
            : int.tryParse(entry.value.toString()) ?? 0;
        if (entry.key.toString().trim().isNotEmpty && count > 0) {
          parsedExtraVariants[entry.key.toString()] = count;
        }
      }
    }
    final parsedNormalCopies = (json['normalCopies'] as num?)?.toInt() ?? 0;
    final parsedReverseHoloCopies = (json['reverseHoloCopies'] as num?)?.toInt() ?? 0;
    final parsedHoloCopies = (json['holoCopies'] as num?)?.toInt() ?? 0;
    final parsedPokeBallReverseCopies = (json['pokeBallReverseCopies'] as num?)?.toInt() ?? 0;
    final parsedMasterBallReverseCopies = (json['masterBallReverseCopies'] as num?)?.toInt() ?? 0;
    final hasNewVariantCounts = json.containsKey('normalCopies') ||
        json.containsKey('reverseHoloCopies') ||
        json.containsKey('holoCopies') ||
        json.containsKey('pokeBallReverseCopies') ||
        json.containsKey('masterBallReverseCopies');

    if (hasNewVariantCounts) {
      final totalCopies = parsedNormalCopies +
          parsedReverseHoloCopies +
          parsedHoloCopies +
          parsedPokeBallReverseCopies +
          parsedMasterBallReverseCopies;

      return CardOwnership(
        normal: parsedNormalCopies > 0 || json['normal'] == true,
        reverseHolo: parsedReverseHoloCopies > 0 || json['reverseHolo'] == true,
        holo: parsedHoloCopies > 0 || json['holo'] == true,
        pokeBallReverse: parsedPokeBallReverseCopies > 0 || json['pokeBallReverse'] == true,
        masterBallReverse: parsedMasterBallReverseCopies > 0 || json['masterBallReverse'] == true,
        copies: (json['copies'] as num?)?.toInt() ?? totalCopies,
        normalCopies: parsedNormalCopies,
        reverseHoloCopies: parsedReverseHoloCopies,
        holoCopies: parsedHoloCopies,
        pokeBallReverseCopies: parsedPokeBallReverseCopies,
        masterBallReverseCopies: parsedMasterBallReverseCopies,
        extraVariantCopies: Map<String, int>.unmodifiable(parsedExtraVariants),
        condition: normaliseCardCondition((json['condition'] ?? '').toString()),
        gradingCompany: (json['gradingCompany'] ?? json['gradeCompany'] ?? '').toString().trim(),
        grade: parseStoredCardGrade(json['grade']),
        conditionNotes: (json['conditionNotes'] ?? json['notes'] ?? '').toString().trim(),
      );
    }

    final legacyNormal = json['normal'] == true;
    final legacyReverseHolo = json['reverseHolo'] == true;
    final legacyHolo = json['holo'] == true;
    final legacyPokeBallReverse = json['pokeBallReverse'] == true;
    final legacyMasterBallReverse = json['masterBallReverse'] == true;
    final legacyCopies = (json['copies'] as num?)?.toInt() ?? 0;

    var normalCopies = 0;
    var reverseHoloCopies = 0;
    var holoCopies = 0;
    var pokeBallReverseCopies = 0;
    var masterBallReverseCopies = 0;

    final activeCount = [
      legacyNormal,
      legacyReverseHolo,
      legacyHolo,
      legacyPokeBallReverse,
      legacyMasterBallReverse,
    ].where((owned) => owned).length;

    if (activeCount == 0 && legacyCopies > 0) {
      normalCopies = legacyCopies;
    } else if (activeCount == 1) {
      final count = legacyCopies > 0 ? legacyCopies : 1;
      if (legacyNormal) normalCopies = count;
      if (legacyReverseHolo) reverseHoloCopies = count;
      if (legacyHolo) holoCopies = count;
      if (legacyPokeBallReverse) pokeBallReverseCopies = count;
      if (legacyMasterBallReverse) masterBallReverseCopies = count;
    } else {
      if (legacyNormal) normalCopies = 1;
      if (legacyReverseHolo) reverseHoloCopies = 1;
      if (legacyHolo) holoCopies = 1;
      if (legacyPokeBallReverse) pokeBallReverseCopies = 1;
      if (legacyMasterBallReverse) masterBallReverseCopies = 1;
    }

    return CardOwnership(
      normal: normalCopies > 0,
      reverseHolo: reverseHoloCopies > 0,
      holo: holoCopies > 0,
      pokeBallReverse: pokeBallReverseCopies > 0,
      masterBallReverse: masterBallReverseCopies > 0,
      copies: normalCopies +
          reverseHoloCopies +
          holoCopies +
          pokeBallReverseCopies +
          masterBallReverseCopies,
      normalCopies: normalCopies,
      reverseHoloCopies: reverseHoloCopies,
      holoCopies: holoCopies,
      pokeBallReverseCopies: pokeBallReverseCopies,
      masterBallReverseCopies: masterBallReverseCopies,
      extraVariantCopies: Map<String, int>.unmodifiable(parsedExtraVariants),
      condition: normaliseCardCondition((json['condition'] ?? '').toString()),
      gradingCompany: (json['gradingCompany'] ?? json['gradeCompany'] ?? '').toString().trim(),
      grade: parseStoredCardGrade(json['grade']),
      conditionNotes: (json['conditionNotes'] ?? json['notes'] ?? '').toString().trim(),
    );
  }
}
