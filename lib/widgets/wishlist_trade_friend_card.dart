import 'package:flutter/material.dart';

import '../models/friend_trade_match_models.dart';
import '../models/wishlist_entry.dart';
import '../services/currency_settings.dart';
import 'community_meta_chip.dart';
import 'friend_trade_match_widgets.dart';

class WishlistTradeFriendCard extends StatelessWidget {
  const WishlistTradeFriendCard({
    super.key,
    required this.overview,
    required this.showLikelySpareOnly,
    required this.canMessage,
    required this.onTapEntry,
    required this.onOpenDetails,
    required this.onMessage,
  });

  final FriendTradeMatchOverview overview;
  final bool showLikelySpareOnly;
  final bool canMessage;
  final Future<void> Function(WishlistEntry entry) onTapEntry;
  final VoidCallback onOpenDetails;
  final VoidCallback onMessage;

  List<FriendTradeMatchEntry> _filter(List<FriendTradeMatchEntry> items) {
    if (!showLikelySpareOnly) return items;
    return items.where((item) => item.hasLikelySpare).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theyHave = _filter(overview.snapshot.friendHasForYou);
    final youHave = _filter(overview.snapshot.youHaveForFriend);
    final visibleTop = overview.topEntries(likelySpareOnly: showLikelySpareOnly);

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overview.friend.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${overview.totalMatches} total match${overview.totalMatches == 1 ? '' : 'es'}',
                        style: const TextStyle(color: Color(0xFFC8D4F0)),
                      ),
                    ],
                  ),
                ),
                if (overview.likelySpareMatches > 0)
                  const CommunityMetaChip(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Likely spares',
                    color: Color(0xFF6B4EFF),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CommunityMetaChip(
                  icon: Icons.person_outline,
                  label: 'They have ${overview.snapshot.friendHasForYou.length}',
                  color: const Color(0xFF355189),
                ),
                CommunityMetaChip(
                  icon: Icons.inventory_2_outlined,
                  label: 'You have ${overview.snapshot.youHaveForFriend.length}',
                  color: const Color(0xFF2C7A5B),
                ),
                if (overview.estimatedSelectedValue > 0)
                  CommunityMetaChip(
                    icon: Icons.payments_outlined,
                    label: CurrencySettings.formatSelectedAmount(overview.estimatedSelectedValue),
                    color: const Color(0xFF875A16),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (theyHave.isNotEmpty) ...[
              const Text(
                'They own cards on your wishlist',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...theyHave.take(2).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: WishlistTradeMiniTile(
                        item: item,
                        friendName: overview.friend.username,
                        onTap: () => onTapEntry(item.entry),
                      ),
                    ),
                  ),
            ],
            if (youHave.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'You own cards ${overview.friend.username} wants',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...youHave.take(2).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: WishlistTradeMiniTile(
                        item: item,
                        friendName: overview.friend.username,
                        onTap: () => onTapEntry(item.entry),
                      ),
                    ),
                  ),
            ],
            if (visibleTop.isEmpty)
              const Text(
                'No visible matches with the current filter.',
                style: TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canMessage ? onMessage : null,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Message'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenDetails,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF7DE77),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('View all'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
