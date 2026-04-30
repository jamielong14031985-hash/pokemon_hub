import 'dart:math' as math;

import 'package:flutter/material.dart';

class AchievementTier {
  const AchievementTier({
    required this.title,
    required this.target,
    this.color = const Color(0xFFF7DE77),
  });

  final String title;
  final num target;
  final Color color;
}

class AchievementBadgeData {
  const AchievementBadgeData({
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.accent,
    required this.unlocked,
    bool? complete,
    required this.progress,
    required this.target,
    this.statusLabel,
    this.progressPrefix = '',
    this.progressSuffix = '',
    this.tiers = const <AchievementTier>[],
  }) : complete = complete ?? unlocked;

  final String title;
  final String category;
  final String description;
  final IconData icon;
  final Color accent;
  final bool unlocked;
  final bool complete;
  final num progress;
  final num target;
  final String? statusLabel;
  final String progressPrefix;
  final String progressSuffix;
  final List<AchievementTier> tiers;

  double get progressValue {
    if (target <= 0) return unlocked ? 1 : 0;
    final value = progress / target;
    if (value.isNaN || value.isInfinite) return 0;
    return value.clamp(0, 1).toDouble();
  }

  String get progressLabel {
    final cappedProgress = progress > target ? target : progress;
    return '${_formatValue(cappedProgress)} / ${_formatValue(target)}';
  }

  String get remainingLabel {
    final remaining = target - progress;
    if (remaining <= 0) return 'Unlocked';
    return '${_formatValue(remaining)} to go';
  }

  int get completedTierCount {
    if (tiers.isEmpty) return unlocked ? 1 : 0;
    return tiers.where((tier) => progress >= tier.target).length;
  }

  AchievementTier? get previousTier {
    if (tiers.isEmpty || completedTierCount <= 0) return null;
    final index = math.min(completedTierCount - 1, tiers.length - 1).toInt();
    return tiers[index];
  }

  AchievementTier? get nextTier {
    if (tiers.isEmpty || completedTierCount >= tiers.length) return null;
    return tiers[completedTierCount];
  }

  String get previousTierLabel {
    final tier = previousTier;
    if (tier == null) return 'Previous: none yet';
    return 'Previous: ${tier.title}';
  }

  String get nextTierLabel {
    final tier = nextTier;
    if (tier == null) return 'Next: all tiers done';
    return 'Next: ${tier.title} at ${_formatValue(tier.target)}';
  }

  bool tierComplete(AchievementTier tier) => progress >= tier.target;

  bool tierIsNext(AchievementTier tier) => nextTier == tier;

  String tierTargetLabel(AchievementTier tier) => _formatValue(tier.target);

  String _formatValue(num value) {
    final rounded = value >= 100
        ? value.round().toString()
        : value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
    return '$progressPrefix$rounded$progressSuffix';
  }
}
