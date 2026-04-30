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

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.collections_bookmark_outlined, color: Color(0xFF75E6A9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    friendPokedexLabel(profile.displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenPokedex,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open full Pokédex'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C7A5B),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
