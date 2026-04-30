import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/profile_stats.dart';
import '../utils/app_helpers.dart';
import 'profile_showcase_mini_stat.dart';

class FriendPokedexPreviewCard extends StatelessWidget {
  const FriendPokedexPreviewCard({
    super.key,
    required this.profile,
    required this.stats,
    required this.onOpenPokedex,
  });

  final AppUserProfile profile;
  final ProfileStats stats;
  final VoidCallback onOpenPokedex;

  double get _uniqueProgress {
    if (stats.totalCards <= 0) return 0;
    return (stats.uniqueCards / stats.totalCards).clamp(0.0, 1.0).toDouble();
  }

  String get _progressLabel {
    if (stats.totalCards <= 0) return 'No cards tracked yet';
    final percentage = (_uniqueProgress * 100).round();
    return '$percentage% unique cards';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = profile.displayName.trim().isEmpty
        ? 'Trainer'
        : profile.displayName.trim();

    return Card(
      color: const Color(0xFF102754),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF143163),
              Color(0xFF102754),
              Color(0xFF071B43),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PokedexHeader(
                title: friendPokedexLabel(displayName),
                totalCards: stats.totalCards,
                onOpenPokedex: onOpenPokedex,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ProfileShowcaseMiniStat(
                      label: 'Total cards',
                      value: '${stats.totalCards}',
                      icon: Icons.style_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ProfileShowcaseMiniStat(
                      label: 'Unique cards',
                      value: '${stats.uniqueCards}',
                      icon: Icons.auto_awesome_motion_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PokedexProgressPanel(
                progress: _uniqueProgress,
                progressLabel: _progressLabel,
                hasCards: stats.totalCards > 0,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenPokedex,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open full Pokédex'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C7A5B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PokedexHeader extends StatelessWidget {
  const _PokedexHeader({
    required this.title,
    required this.totalCards,
    required this.onOpenPokedex,
  });

  final String title;
  final int totalCards;
  final VoidCallback onOpenPokedex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF75E6A9).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFF75E6A9).withValues(alpha: 0.26),
            ),
          ),
          child: const Icon(
            Icons.collections_bookmark_outlined,
            color: Color(0xFF75E6A9),
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                totalCards == 0
                    ? 'No Pokédex cards tracked yet'
                    : '$totalCards tracked card${totalCards == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFFC8D4F0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Open Pokédex',
          onPressed: onOpenPokedex,
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _PokedexProgressPanel extends StatelessWidget {
  const _PokedexProgressPanel({
    required this.progress,
    required this.progressLabel,
    required this.hasCards,
  });

  final double progress;
  final String progressLabel;
  final bool hasCards;

  @override
  Widget build(BuildContext context) {
    final accent = hasCards ? const Color(0xFF75E6A9) : const Color(0xFFC8D4F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCards ? Icons.trending_up_rounded : Icons.info_outline_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progressLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.20),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            hasCards
                ? 'This compares unique cards against total tracked copies.'
                : 'Once this friend tracks cards, their Pokédex progress will appear here.',
            style: const TextStyle(
              color: Color(0xFFC8D4F0),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
