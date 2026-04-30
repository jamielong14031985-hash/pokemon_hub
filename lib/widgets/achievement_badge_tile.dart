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

  Color _textColor(bool active) {
    if (hidden) return Colors.white54;
    if (active) return Colors.white;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    final active = data.unlocked && !hidden;
    final accent = active ? data.accent : Colors.white38;
    final progressValue = data.progressValue.clamp(0.0, 1.0).toDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  data.accent.withValues(alpha: 0.18),
                  const Color(0xFF102754).withValues(alpha: 0.92),
                  const Color(0xFF071B43),
                ],
              )
            : null,
        color: active
            ? null
            : hidden
                ? Colors.white.withValues(alpha: 0.025)
                : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: active
              ? data.accent.withValues(alpha: 0.40)
              : Colors.white.withValues(alpha: hidden ? 0.07 : 0.09),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: data.accent.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
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
                _BadgeIcon(data: data, hidden: hidden, active: active),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      letterSpacing: 0.85,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _BadgeStatusChip(data: data, hidden: hidden, accent: accent),
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
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white60,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor(active),
                fontSize: 16,
                height: 1.08,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              data.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 11,
                height: 1.28,
              ),
            ),
            const SizedBox(height: 10),
            AchievementTierTrack(data: data, hidden: hidden),
            const Spacer(),
            _ProgressSummaryRow(data: data, hidden: hidden, accent: accent),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 7,
                backgroundColor: Colors.black.withValues(alpha: 0.20),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hidden
                  ? 'Hidden from wall'
                  : data.complete
                      ? 'Final tier reached'
                      : data.remainingLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.data,
    required this.hidden,
    required this.active,
  });

  final AchievementBadgeData data;
  final bool hidden;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final iconColor = active ? const Color(0xFF071B43) : Colors.white38;
    final icon = hidden
        ? Icons.visibility_off_outlined
        : data.unlocked
            ? data.icon
            : Icons.lock_outline_rounded;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  data.accent.withValues(alpha: 0.98),
                  data.accent.withValues(alpha: 0.50),
                ],
              )
            : null,
        color: active ? null : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: active
              ? data.accent.withValues(alpha: 0.44)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: data.accent.withValues(alpha: 0.20),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: iconColor, size: 26),
    );
  }
}

class _BadgeStatusChip extends StatelessWidget {
  const _BadgeStatusChip({
    required this.data,
    required this.hidden,
    required this.accent,
  });

  final AchievementBadgeData data;
  final bool hidden;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = hidden
        ? 'Hidden'
        : data.statusLabel ??
            (data.complete
                ? 'Complete'
                : data.unlocked
                    ? 'Started'
                    : '${(data.progressValue * 100).round()}%');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: data.unlocked && !hidden ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: data.unlocked && !hidden ? 0.32 : 0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProgressSummaryRow extends StatelessWidget {
  const _ProgressSummaryRow({
    required this.data,
    required this.hidden,
    required this.accent,
  });

  final AchievementBadgeData data;
  final bool hidden;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          hidden
              ? Icons.visibility_off_outlined
              : data.complete
                  ? Icons.check_circle_rounded
                  : data.unlocked
                      ? Icons.trending_up_rounded
                      : Icons.lock_outline_rounded,
          color: accent,
          size: 16,
        ),
        const SizedBox(width: 6),
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
              color: data.unlocked && !hidden ? data.accent : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
