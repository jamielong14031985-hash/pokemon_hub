import 'package:flutter/material.dart';

import '../models/achievement_models.dart';

class AchievementTierTrack extends StatelessWidget {
  const AchievementTierTrack({
    super.key,
    required this.data,
    required this.hidden,
  });

  final AchievementBadgeData data;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (data.tiers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: hidden ? Colors.white.withValues(alpha: 0.025) : Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.previousTierLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.nextTierLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: data.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < data.tiers.length; index++) ...[
                  AchievementTierChip(
                    tier: data.tiers[index],
                    complete: data.tierComplete(data.tiers[index]),
                    next: data.tierIsNext(data.tiers[index]),
                    targetLabel: data.tierTargetLabel(data.tiers[index]),
                    hidden: hidden,
                  ),
                  if (index != data.tiers.length - 1)
                    Container(
                      width: 14,
                      height: 2,
                      color: data.tierComplete(data.tiers[index])
                          ? data.tiers[index].color.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AchievementTierChip extends StatelessWidget {
  const AchievementTierChip({
    super.key,
    required this.tier,
    required this.complete,
    required this.next,
    required this.targetLabel,
    required this.hidden,
  });

  final AchievementTier tier;
  final bool complete;
  final bool next;
  final String targetLabel;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final color = hidden ? Colors.white38 : tier.color;
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: complete ? 0.20 : next ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withValues(alpha: complete || next ? 0.46 : 0.20),
          width: next ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: complete || next ? 0.95 : 0.28),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.65)),
                ),
                child: Icon(
                  complete
                      ? Icons.check_rounded
                      : next
                          ? Icons.flag_rounded
                          : Icons.lock_outline_rounded,
                  size: 13,
                  color: complete || next ? const Color(0xFF071B43) : Colors.white70,
                ),
              ),
              const Spacer(),
              Text(
                complete
                    ? 'Done'
                    : next
                        ? 'Next'
                        : 'Later',
                style: TextStyle(
                  color: complete || next ? color : Colors.white54,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            tier.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            targetLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
