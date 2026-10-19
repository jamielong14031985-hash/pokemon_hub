import 'package:flutter/material.dart';

import '../models/friend_trade_match_models.dart';
import '../models/wishlist_entry.dart';
import '../utils/promo_collection_labels.dart';
import '../services/currency_settings.dart';
import 'community_meta_chip.dart';

class WishlistTradeMiniTile extends StatelessWidget {
  const WishlistTradeMiniTile({
    super.key,
    required this.item,
    required this.friendName,
    required this.onTap,
    this.onMakeDeal,
  });

  final FriendTradeMatchEntry item;
  final String friendName;
  final VoidCallback onTap;
  final VoidCallback? onMakeDeal;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final ownerLabel = item.ownerIsFriend
        ? '$friendName owns x${item.ownerCopies}'
        : 'You own x${item.ownerCopies}';

    return Material(
      color: const Color(0xFF16366E),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 46,
                  height: 64,
                  child: entry.imageUrl == null || entry.imageUrl!.isEmpty
                      ? Container(
                          color: const Color(0xFF0E2A5E),
                          child: const Icon(Icons.image_not_supported, color: Colors.white, size: 18),
                        )
                      : Image.network(entry.imageUrl!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      PromoCollectionLabels.displaySetName(
                        cardId: entry.cardId, cardName: entry.name,
                        setId: entry.setId, number: entry.number,
                        fallbackSetName: entry.setName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        CommunityMetaChip(
                          icon: item.ownerIsFriend ? Icons.person_outline : Icons.inventory_2_outlined,
                          label: ownerLabel,
                          color: item.hasLikelySpare ? const Color(0xFF2C7A5B) : const Color(0xFF355189),
                        ),
                        if (item.hasLikelySpare)
                          CommunityMetaChip(
                            icon: Icons.auto_awesome_outlined,
                            label: '${item.ownerSpareCopies} spare',
                            color: const Color(0xFF6B4EFF),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onMakeDeal != null)
                IconButton(tooltip: 'Make a Deal', icon: const Icon(Icons.handshake_outlined,
                  color: Color(0xFFF7DE77)), onPressed: onMakeDeal)
              else
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class FriendTradeMatchSection extends StatelessWidget {
  const FriendTradeMatchSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.items,
    required this.onTapEntry,
    this.onDeal,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<FriendTradeMatchEntry> items;
  final Future<void> Function(WishlistEntry entry) onTapEntry;
  final ValueChanged<FriendTradeMatchEntry>? onDeal;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Text(
                emptyMessage,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return FriendTradeMatchCard(
                    item: item,
                    onTap: () { onTapEntry(item.entry); },
                    onDeal: onDeal == null || !item.hasLikelySpare ? null : () => onDeal!(item),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class FriendTradeMatchCard extends StatelessWidget {
  const FriendTradeMatchCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onDeal,
  });

  final FriendTradeMatchEntry item;
  final VoidCallback onTap;
  final VoidCallback? onDeal;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    return Material(
      color: const Color(0xFF16366E),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 88,
                  child: entry.imageUrl == null || entry.imageUrl!.isEmpty
                      ? Container(
                          color: const Color(0xFF0E2A5E),
                          child: const Icon(Icons.image_not_supported, color: Colors.white),
                        )
                      : Image.network(entry.imageUrl!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      PromoCollectionLabels.displaySetName(
                        cardId: entry.cardId, cardName: entry.name,
                        setId: entry.setId, number: entry.number,
                        fallbackSetName: entry.setName),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Card #${entry.number}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CommunityMetaChip(
                          icon: item.ownerIsFriend ? Icons.person_outline : Icons.inventory_2_outlined,
                          // This badge only shows ownership; the spare count has its own
                          // shorter badge so both fit on small screens.
                          label: item.ownerIsFriend
                              ? 'They own x${item.ownerCopies}'
                              : 'You own x${item.ownerCopies}',
                          color: item.hasLikelySpare ? const Color(0xFF2C7A5B) : const Color(0xFF355189),
                        ),
                        if (item.hasLikelySpare)
                          CommunityMetaChip(
                            icon: Icons.auto_awesome_outlined,
                            label: '${item.ownerSpareCopies} spare${item.ownerSpareCopies == 1 ? '' : 's'}',
                            color: const Color(0xFF6B4EFF),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.rawPrice == null
                          ? 'Price unavailable'
                          : 'Est. raw price: ${CurrencySettings.formatAmount(entry.rawPrice, fromCurrency: entry.rawPriceCurrency)}',
                      style: const TextStyle(
                        color: Color(0xFFF7DE77),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onDeal != null)
                IconButton(tooltip: 'Make a Deal', onPressed: onDeal,
                  icon: const Icon(Icons.handshake_outlined, color: Color(0xFFF7DE77)))
              else
                const Padding(padding: EdgeInsets.only(top: 26),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}
