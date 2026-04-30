import 'package:flutter/material.dart';

import '../models/achievement_models.dart';
import 'achievement_tier_widgets.dart';

class AchievementBadgeTile extends StatelessWidget {
  const AchievementBadgeTile({
    super.key,
    required this.data,
    this.hidden = false,
    this.onHide,
    this.onUnhide,
  });

  final AchievementBadgeData data;
  final bool hidden;
  final VoidCallback? onHide;
  final VoidCallback? onUnhide;

  @override
  Widget build(BuildContext context) {
    final accent = data.unlocked ? data.accent : Colors.white38;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hidden
            ? Colors.white.withValues(alpha: 0.025)
            : data.unlocked
                ? data.accent.withValues(alpha: 0.105)
                : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hidden
              ? Colors.white.withValues(alpha: 0.07)
              : data.unlocked
                  ? data.accent.withValues(alpha: 0.36)
                  : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: data.unlocked && !hidden
            ? [
                BoxShadow(
                  color: data.accent.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Opacity(
        opacity: hidden ? 0.70 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: data.unlocked && !hidden
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [data.accent.withValues(alpha: 0.95), data.accent.withValues(alpha: 0.42)],
                          )
                        : null,
                    color: data.unlocked && !hidden ? null : Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: accent.withValues(alpha: data.unlocked && !hidden ? 0.40 : 0.18)),
                  ),
                  child: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : data.unlocked
                            ? data.icon
                            : Icons.lock_outline_rounded,
                    color: data.unlocked && !hidden ? const Color(0xFF071B43) : Colors.white38,
                    size: 25,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: data.unlocked && !hidden ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: data.unlocked && !hidden ? 0.30 : 0.12)),
                  ),
                  child: Text(
                    hidden
                        ? 'Hidden'
                        : data.statusLabel ??
                            (data.complete
                                ? 'Complete'
                                : data.unlocked
                                    ? 'Started'
                                    : '${(data.progressValue * 100).round()}%'),
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onHide != null || onUnhide != null) ...[
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: hidden ? 'Show achievement' : 'Hide achievement',
                      onPressed: hidden ? onUnhide : onHide,
                      icon: Icon(
                        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white60,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 11),
            Text(
              data.category.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: data.unlocked ? Colors.white : Colors.white70,
                fontSize: 14,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 11,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 9),
            AchievementTierTrack(data: data, hidden: hidden),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hidden
                        ? 'Hidden from wall'
                        : data.complete
                            ? 'Complete'
                            : data.progressLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: data.unlocked ? data.accent : Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (data.complete && !hidden)
                  Icon(Icons.check_circle_rounded, color: data.accent, size: 16),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: data.progressValue,
                minHeight: 6,
                backgroundColor: Colors.black.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
