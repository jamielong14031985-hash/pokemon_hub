import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement_models.dart';
import '../models/profile_stats.dart';
import '../services/currency_settings.dart';
import 'achievement_badge_tile.dart';
import 'achievement_summary_pill.dart';

class AchievementBadges extends StatefulWidget {
  const AchievementBadges({
    super.key,
    required this.stats,
    this.visibilityToggleEnabled = true,
  });

  final ProfileStats stats;
  final bool visibilityToggleEnabled;

  @override
  State<AchievementBadges> createState() => _AchievementBadgesState();
}

class _AchievementBadgesState extends State<AchievementBadges> {
  static const String _showBadgesPrefsPrefix = 'show_achievement_badges_v1';

  bool _showAchievementBadges = true;

  @override
  void initState() {
    super.initState();
    _loadAchievementBadgeVisibility();
  }

  String get _showBadgesPrefsKey {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (uid != null && uid.isNotEmpty) {
      return '${_showBadgesPrefsPrefix}_$uid';
    }
    return _showBadgesPrefsPrefix;
  }

  Future<void> _loadAchievementBadgeVisibility() async {
    if (!widget.visibilityToggleEnabled) {
      if (!mounted) return;
      setState(() {
        _showAchievementBadges = true;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final showBadges = prefs.getBool(_showBadgesPrefsKey) ?? true;
    if (!mounted) return;
    setState(() {
      _showAchievementBadges = showBadges;
    });
  }

  Future<void> _setAchievementBadgeVisibility(bool value) async {
    if (!widget.visibilityToggleEnabled) return;

    setState(() {
      _showAchievementBadges = value;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showBadgesPrefsKey, value);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Achievement badges are visible again.'
              : 'Achievement badges are hidden.',
        ),
      ),
    );
  }

  AchievementBadgeData _rollingMilestoneBadge({
    required String title,
    required String category,
    required String baseDescription,
    required IconData icon,
    required Color accent,
    required num progress,
    required List<AchievementTier> tiers,
    String progressPrefix = '',
    String progressSuffix = '',
  }) {
    if (tiers.isEmpty) {
      return AchievementBadgeData(
        title: title,
        category: category,
        description: baseDescription,
        icon: icon,
        accent: accent,
        unlocked: false,
        complete: false,
        progress: 0,
        target: 1,
        statusLabel: '0/0 tiers',
        progressPrefix: progressPrefix,
        progressSuffix: progressSuffix,
        tiers: tiers,
      );
    }

    final safeProgress = progress < 0 ? 0 : progress;
    final completedTierIndex =
        tiers.lastIndexWhere((tier) => safeProgress >= tier.target);
    final completedTierCount = math.max(0, completedTierIndex + 1);
    final hasStarted = completedTierCount > 0;
    final isComplete = completedTierCount >= tiers.length;
    final nextTier = isComplete ? tiers.last : tiers[completedTierCount];
    final currentTier = hasStarted ? tiers[completedTierIndex] : null;

    final description = isComplete
        ? 'Completed: ${tiers.last.title}. $baseDescription'
        : currentTier == null
            ? 'Next: ${nextTier.title} at ${_formatAchievementTarget(nextTier.target, progressPrefix, progressSuffix)}. $baseDescription'
            : 'Earned: ${currentTier.title}. Next: ${nextTier.title} at ${_formatAchievementTarget(nextTier.target, progressPrefix, progressSuffix)}.';

    return AchievementBadgeData(
      title: title,
      category: category,
      description: description,
      icon: icon,
      accent: isComplete ? tiers.last.color : nextTier.color,
      unlocked: hasStarted,
      complete: isComplete,
      progress: isComplete ? nextTier.target : safeProgress,
      target: nextTier.target,
      statusLabel: isComplete ? 'Complete' : '$completedTierCount/${tiers.length} tiers',
      progressPrefix: progressPrefix,
      progressSuffix: progressSuffix,
      tiers: tiers,
    );
  }

  String _formatAchievementTarget(
    num value,
    String prefix,
    String suffix,
  ) {
    final formatted = value >= 100
        ? value.round().toString()
        : value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
    return '$prefix$formatted$suffix';
  }

  bool _isSpecialRarityLabel(String rarity) {
    final value = rarity.toLowerCase();
    return value.contains('special illustration') ||
        value.contains('illustration') ||
        value.contains('secret') ||
        value.contains('hyper') ||
        value.contains('rainbow') ||
        value.contains('gold') ||
        value.contains('ultra') ||
        value.contains('ace spec') ||
        value.contains('amazing') ||
        value.contains('radiant') ||
        value.contains('shiny') ||
        value.contains('trainer gallery') ||
        value.contains('gallery') ||
        value.contains('rare holo');
  }

  List<AchievementBadgeData> _buildBadges() {
    final uniqueRarities = widget.stats.rarityCopies.keys
        .where((rarity) => rarity.trim().isNotEmpty)
        .length;

    final specialPullCopies = widget.stats.rarityCopies.entries
        .where((entry) => _isSpecialRarityLabel(entry.key))
        .fold<int>(0, (runningTotal, entry) => runningTotal + entry.value);

    final duplicateCopies = math.max(
      0,
      widget.stats.totalCards - widget.stats.uniqueCards,
    );

    final topCardValue = CurrencySettings.convertAmountSync(
          widget.stats.mostExpensiveCard?.marketPrice,
          fromCurrency: widget.stats.mostExpensiveCard?.rawPriceCurrency ?? 'USD',
        ) ??
        0;

    final totalValue = widget.stats.totalEstimatedPrice;
    final currencySymbol = CurrencySettings.selectedCurrency.symbol;

    return <AchievementBadgeData>[
      _rollingMilestoneBadge(
        title: 'Collection Journey',
        category: 'Cards',
        baseDescription: 'This badge rolls forward as your total card count grows.',
        icon: Icons.catching_pokemon,
        accent: const Color(0xFFF7DE77),
        progress: widget.stats.totalCards,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'First Catch', target: 1, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Binder Starter', target: 10, color: Color(0xFFFFB36B)),
          AchievementTier(title: 'Set Builder', target: 50, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Master Collector', target: 100, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Vault Keeper', target: 250, color: Color(0xFF75E6A9)),
          AchievementTier(title: 'Legendary Hoard', target: 500, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Elite Collector', target: 1000, color: Color(0xFF64F4D4)),
          AchievementTier(title: 'Pokédex Titan', target: 2500, color: Color(0xFFFF7A7A)),
          AchievementTier(title: 'Museum Vault', target: 5000, color: Color(0xFF9BE15D)),
          AchievementTier(title: 'Lifetime Legend', target: 10000, color: Color(0xFFE7A6FF)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Unique Card Archive',
        category: 'Unique',
        baseDescription: 'This badge rolls forward as you add different cards.',
        icon: Icons.menu_book_outlined,
        accent: const Color(0xFFB8A3FF),
        progress: widget.stats.uniqueCards,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Page Filler', target: 25, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Card Catalogue', target: 100, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Archive Master', target: 200, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Dex Librarian', target: 500, color: Color(0xFF75E6A9)),
          AchievementTier(title: 'Set Historian', target: 1000, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Card Encyclopaedia', target: 2500, color: Color(0xFFFFB36B)),
          AchievementTier(title: 'Living Archive', target: 5000, color: Color(0xFF64F4D4)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Duplicate Power',
        category: 'Copies',
        baseDescription: 'Build stacks of duplicates for swaps, binders, and trade bait.',
        icon: Icons.copy_all_outlined,
        accent: const Color(0xFFFFB36B),
        progress: duplicateCopies,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Spare Copy', target: 5, color: Color(0xFFFFB36B)),
          AchievementTier(title: 'Trade Stack', target: 25, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Duplicate Drawer', target: 75, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Swap Stockpile', target: 150, color: Color(0xFF75E6A9)),
          AchievementTier(title: 'Bulk Box', target: 300, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Trade Empire', target: 750, color: Color(0xFFF7DE77)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Rarity Collector',
        category: 'Rarity',
        baseDescription: 'This badge rolls forward as you collect more rarity types.',
        icon: Icons.auto_awesome_outlined,
        accent: const Color(0xFF75E6A9),
        progress: uniqueRarities,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Rarity Starter', target: 3, color: Color(0xFF75E6A9)),
          AchievementTier(title: 'Rarity Hunter', target: 5, color: Color(0xFFFFB36B)),
          AchievementTier(title: 'Rarity Expert', target: 8, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Rarity Master', target: 10, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Rarity Scholar', target: 12, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Rarity Completionist', target: 15, color: Color(0xFFF7DE77)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Special Pulls',
        category: 'Rarity',
        baseDescription: 'Find rare, illustration, gold/rainbow, and gallery-style cards.',
        icon: Icons.verified_outlined,
        accent: const Color(0xFFFF8EC3),
        progress: specialPullCopies,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Rare Pull', target: 1, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Illustration Hunter', target: 5, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Gold Chase', target: 10, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Gallery Run', target: 25, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Shiny Vault', target: 50, color: Color(0xFF75E6A9)),
          AchievementTier(title: 'Secret Stash', target: 100, color: Color(0xFFFFB36B)),
          AchievementTier(title: 'Pull Legend', target: 250, color: Color(0xFF64F4D4)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Set Dedication',
        category: 'Sets',
        baseDescription: 'This badge rolls forward based on your biggest single-set collection.',
        icon: Icons.collections_bookmark_outlined,
        accent: const Color(0xFFFFB36B),
        progress: widget.stats.favouriteSetCopies,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Set Loyalist', target: 25, color: Color(0xFFFFB36B)),
          AchievementTier(title: 'Set Champion', target: 75, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Set Specialist', target: 150, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Set Master', target: 250, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Set Completionist', target: 500, color: Color(0xFF75E6A9)),
          AchievementTier(title: 'Set Dynasty', target: 1000, color: Color(0xFFE7A6FF)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Set Marathon',
        category: 'Sets',
        baseDescription: 'A long-term challenge for collectors who keep building one favourite set.',
        icon: Icons.route_outlined,
        accent: const Color(0xFF64F4D4),
        progress: widget.stats.favouriteSetCopies,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Half Binder', target: 60, color: Color(0xFF64F4D4)),
          AchievementTier(title: 'Deep Binder', target: 120, color: Color(0xFF75E6A9)),
          AchievementTier(title: 'Near Master', target: 220, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Master Run', target: 360, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Perfect Pursuit', target: 720, color: Color(0xFFE7A6FF)),
          AchievementTier(title: 'Completion Legend', target: 1200, color: Color(0xFFFF7A7A)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Top Card Chase',
        category: 'Value',
        baseDescription: 'This badge rolls forward based on your highest-value card.',
        icon: Icons.workspace_premium_outlined,
        accent: const Color(0xFF82D8FF),
        progress: topCardValue,
        progressPrefix: currencySymbol,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Showpiece', target: 25, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Treasure Card', target: 50, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Premium Pull', target: 100, color: Color(0xFFFFB36B)),
          AchievementTier(title: 'Chase Card', target: 250, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Holy Grail', target: 500, color: Color(0xFF75E6A9)),
          AchievementTier(title: 'Museum Piece', target: 1000, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Collector Crown', target: 2500, color: Color(0xFF64F4D4)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Collection Vault',
        category: 'Value',
        baseDescription: 'This badge rolls forward as your estimated collection value grows.',
        icon: Icons.savings_outlined,
        accent: const Color(0xFF75E6A9),
        progress: totalValue,
        progressPrefix: currencySymbol,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Value Vault', target: 100, color: Color(0xFF75E6A9)),
          AchievementTier(title: 'Premium Vault', target: 500, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Collector Fund', target: 1000, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Treasure Room', target: 2500, color: Color(0xFFFFB36B)),
          AchievementTier(title: 'Royal Vault', target: 5000, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Legend Vault', target: 10000, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Mythic Fortune', target: 25000, color: Color(0xFF64F4D4)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Value Marathon',
        category: 'Value',
        baseDescription: 'A very long value challenge for serious collection growth.',
        icon: Icons.diamond_outlined,
        accent: const Color(0xFFE7A6FF),
        progress: totalValue,
        progressPrefix: currencySymbol,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Collector Spark', target: 250, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Binder Treasure', target: 1000, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Premium Collection', target: 5000, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Elite Portfolio', target: 15000, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Mythic Portfolio', target: 50000, color: Color(0xFF64F4D4)),
          AchievementTier(title: 'Legendary Portfolio', target: 100000, color: Color(0xFFFF7A7A)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Top Shelf',
        category: 'Showcase',
        baseDescription: 'Build a showcase of priced cards.',
        icon: Icons.leaderboard_outlined,
        accent: const Color(0xFFFF8EC3),
        progress: widget.stats.topValueCards.length,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'Top Shelf', target: 5, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Premium Shelf', target: 10, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Display Case', target: 25, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Showroom', target: 50, color: Color(0xFF82D8FF)),
        ],
      ),
      _rollingMilestoneBadge(
        title: 'Showcase Builder',
        category: 'Showcase',
        baseDescription: 'Grow a stronger top-card display with more cards that have prices.',
        icon: Icons.view_carousel_outlined,
        accent: const Color(0xFFB8A3FF),
        progress: widget.stats.topValueCards.length,
        tiers: const <AchievementTier>[
          AchievementTier(title: 'First Display', target: 3, color: Color(0xFFB8A3FF)),
          AchievementTier(title: 'Mini Showcase', target: 8, color: Color(0xFF82D8FF)),
          AchievementTier(title: 'Collector Showcase', target: 15, color: Color(0xFFF7DE77)),
          AchievementTier(title: 'Premium Showcase', target: 30, color: Color(0xFFFF8EC3)),
          AchievementTier(title: 'Gallery Showcase', target: 60, color: Color(0xFF75E6A9)),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _buildBadges();
    final completedBadges = badges.where((badge) => badge.complete).toList();
    final inProgressBadges = badges.where((badge) => !badge.complete).toList()
      ..sort((a, b) => b.progressValue.compareTo(a.progressValue));
    final displayBadges = <AchievementBadgeData>[
      ...inProgressBadges,
      ...completedBadges,
    ];

    final completedCount = completedBadges.length;
    final startedCount = badges.where((badge) => badge.unlocked).length;
    final badgesVisible = !widget.visibilityToggleEnabled || _showAchievementBadges;
    final hiddenCount = badgesVisible ? 0 : badges.length;
    final badgeProgress = badges.isEmpty
        ? 0.0
        : (completedCount / badges.length).clamp(0.0, 1.0).toDouble();
    final nextBadge = inProgressBadges.isEmpty ? null : inProgressBadges.first;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF172F68),
            Color(0xFF102754),
            Color(0xFF071B43),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AchievementHeader(
              badgesVisible: badgesVisible,
              completedCount: completedCount,
              totalCount: badges.length,
              startedCount: startedCount,
            ),
            if (widget.visibilityToggleEnabled) ...[
              const SizedBox(height: 14),
              _VisibilityToggleCard(
                badgesVisible: badgesVisible,
                onChanged: _setAchievementBadgeVisibility,
              ),
            ],
            if (!badgesVisible) ...[
              const SizedBox(height: 14),
              _HiddenAchievementsCard(hiddenCount: hiddenCount),
            ] else ...[
              const SizedBox(height: 16),
              _NextAchievementCard(
                badgeProgress: badgeProgress,
                nextBadge: nextBadge,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AchievementSummaryPill(
                    icon: Icons.lock_open_rounded,
                    label: '$completedCount complete',
                    color: const Color(0xFF75E6A9),
                  ),
                  AchievementSummaryPill(
                    icon: Icons.flag_outlined,
                    label: '${badges.length - completedCount} active',
                    color: const Color(0xFFFFB36B),
                  ),
                  AchievementSummaryPill(
                    icon: Icons.style_outlined,
                    label: '${widget.stats.totalCards} cards tracked',
                    color: const Color(0xFF82D8FF),
                  ),
                  AchievementSummaryPill(
                    icon: Icons.visibility_outlined,
                    label: 'all visible',
                    color: const Color(0xFFB8A3FF),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 640
                          ? 2
                          : 1;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayBadges.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: columns == 1 ? 0.92 : 0.66,
                    ),
                    itemBuilder: (context, index) {
                      final badge = displayBadges[index];
                      return AchievementBadgeTile(data: badge);
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AchievementHeader extends StatelessWidget {
  const _AchievementHeader({
    required this.badgesVisible,
    required this.completedCount,
    required this.totalCount,
    required this.startedCount,
  });

  final bool badgesVisible;
  final int completedCount;
  final int totalCount;
  final int startedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7DE77), Color(0xFFFFB36B)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            badgesVisible
                ? Icons.emoji_events_rounded
                : Icons.visibility_off_outlined,
            color: const Color(0xFF08204F),
            size: 29,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Achievement badges',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                badgesVisible
                    ? '$completedCount/$totalCount complete • $startedCount started'
                    : '$completedCount/$totalCount complete • badges hidden',
                style: const TextStyle(
                  color: Color(0xFFC8D4F0),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisibilityToggleCard extends StatelessWidget {
  const _VisibilityToggleCard({
    required this.badgesVisible,
    required this.onChanged,
  });

  final bool badgesVisible;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = badgesVisible ? const Color(0xFFF7DE77) : const Color(0xFFC8D4F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: badgesVisible
              ? const Color(0xFFF7DE77).withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(
            badgesVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              badgesVisible
                  ? 'Slide off to hide all achievements'
                  : 'Slide on to see all achievements',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch.adaptive(
            value: badgesVisible,
            thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFF7DE77);
              }
              return const Color(0xFFC8D4F0);
            }),
            trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFF7DE77).withValues(alpha: 0.34);
              }
              return Colors.white.withValues(alpha: 0.14);
            }),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _HiddenAchievementsCard extends StatelessWidget {
  const _HiddenAchievementsCard({required this.hiddenCount});

  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Achievements are hidden',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$hiddenCount badges are hidden from your profile view. Use the switch above whenever you want to show the full badge wall again.',
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

class _NextAchievementCard extends StatelessWidget {
  const _NextAchievementCard({
    required this.badgeProgress,
    required this.nextBadge,
  });

  final double badgeProgress;
  final AchievementBadgeData? nextBadge;

  @override
  Widget build(BuildContext context) {
    final badge = nextBadge;
    final accent = badge?.accent ?? const Color(0xFFF7DE77);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (badge != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  child: Icon(badge.icon, color: accent, size: 19),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  badge == null ? 'Badge wall complete' : 'Next badge: ${badge.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  '${(badgeProgress * 100).round()}%',
                  style: const TextStyle(
                    color: Color(0xFFF7DE77),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: badgeProgress,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF7DE77)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge == null
                ? 'You have unlocked every badge available right now.'
                : '${badge.remainingLabel} • ${badge.description}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
