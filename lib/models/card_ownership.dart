import '../utils/card_condition_helpers.dart';

class CardOwnership {
  const CardOwnership({
    this.normal = false,
    this.reverseHolo = false,
    this.holo = false,
    this.copies = 0,
    this.condition = kDefaultCardCondition,
    this.gradingCompany = '',
    this.grade,
    this.conditionNotes = '',
  });

  final bool normal;
  final bool reverseHolo;
  final bool holo;
  final int copies;
  final String condition;
  final String gradingCompany;
  final double? grade;
  final String conditionNotes;

  int get effectiveCopies {
    if (copies > 0) return copies;
    if (normal || reverseHolo || holo) return 1;
    return 0;
  }

  int get ownedSlotCount {
    var count = 0;
    if (normal) count++;
    if (reverseHolo) count++;
    if (holo) count++;
    return count;
  }

  int get collectionCount {
    final slotCount = ownedSlotCount;
    return copies > slotCount ? copies : slotCount;
  }

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
    String? condition,
    String? gradingCompany,
    double? grade,
    bool clearGrade = false,
    String? conditionNotes,
  }) {
    return CardOwnership(
      normal: normal ?? this.normal,
      reverseHolo: reverseHolo ?? this.reverseHolo,
      holo: holo ?? this.holo,
      copies: copies ?? this.copies,
      condition: condition ?? this.condition,
      gradingCompany: gradingCompany ?? this.gradingCompany,
      grade: clearGrade ? null : (grade ?? this.grade),
      conditionNotes: conditionNotes ?? this.conditionNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'normal': normal,
        'reverseHolo': reverseHolo,
        'holo': holo,
        'copies': copies,
        if (normaliseCardCondition(condition) != kDefaultCardCondition)
          'condition': normaliseCardCondition(condition),
        if (gradingCompany.trim().isNotEmpty) 'gradingCompany': gradingCompany.trim(),
        if (grade != null && grade!.isFinite && grade! > 0) 'grade': grade,
        if (conditionNotes.trim().isNotEmpty) 'conditionNotes': conditionNotes.trim(),
      };

  factory CardOwnership.fromJson(Map<String, dynamic> json) {
    return CardOwnership(
      normal: json['normal'] == true,
      reverseHolo: json['reverseHolo'] == true,
      holo: json['holo'] == true,
      copies: (json['copies'] as num?)?.toInt() ?? 0,
      condition: normaliseCardCondition((json['condition'] ?? '').toString()),
      gradingCompany: (json['gradingCompany'] ?? json['gradeCompany'] ?? '').toString().trim(),
      grade: parseStoredCardGrade(json['grade']),
      conditionNotes: (json['conditionNotes'] ?? json['notes'] ?? '').toString().trim(),
    );
  }
}
