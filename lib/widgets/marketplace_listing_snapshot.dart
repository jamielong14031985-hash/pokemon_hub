import 'package:flutter/material.dart';

import '../models/community_models.dart';
import 'marketplace_detail_chip.dart';

String _communityImageCountLabel(int count) {
  if (count <= 0) return 'No photos';
  if (count == 1) return '1 photo';
  return '$count photos';
}

String _normalizeCommunityMarketStatus(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  switch (normalized) {
    case 'pending':
      return 'Pending';
    case 'sold':
      return 'Sold';
    case 'traded':
      return 'Traded';
    case 'found':
      return 'Found';
    case 'available':
    default:
      return 'Available';
  }
}

Color _communityPostAccentColor(CommunityPost post) {
  if (post.isDiscussion) return const Color(0xFF5B3FD6);
  if (post.isForSale) return const Color(0xFF8E1E2E);
  if (post.isWanted) return const Color(0xFF2D7EF7);
  return const Color(0xFF0B6B5B);
}

Color _communityMarketStatusColor(String? status) {
  switch (_normalizeCommunityMarketStatus(status)) {
    case 'Pending':
      return const Color(0xFFF0A83A);
    case 'Sold':
      return const Color(0xFFB13B59);
    case 'Traded':
      return const Color(0xFF0B6B5B);
    case 'Found':
      return const Color(0xFF54D39A);
    case 'Available':
    default:
      return const Color(0xFF2D7EF7);
  }
}

class MarketplaceListingSnapshot extends StatefulWidget {
  const MarketplaceListingSnapshot({super.key, required this.post});

  final CommunityPost post;

  @override
  State<MarketplaceListingSnapshot> createState() => MarketplaceListingSnapshotState();
}

class MarketplaceListingSnapshotState extends State<MarketplaceListingSnapshot> {
  bool _expanded = false;

  String get _primaryValue {
    if (widget.post.isForSale) {
      return widget.post.hasPrice ? widget.post.formattedPrice : 'Price not set';
    }
    if (widget.post.isWanted) return 'Wanted';
    return 'Swap offer';
  }

  String get _primaryLabel {
    if (widget.post.isForSale) return 'Price';
    if (widget.post.isWanted) return 'Wanted';
    return 'Swap';
  }

  String get _targetLabel => widget.post.isWanted ? 'Card wanted' : 'Wanted';

  IconData get _primaryIcon {
    if (widget.post.isForSale) return Icons.sell_outlined;
    if (widget.post.isWanted) return Icons.search_rounded;
    return Icons.swap_horiz_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final accent = _communityPostAccentColor(post);
    final statusColor = _communityMarketStatusColor(post.normalizedMarketStatus);
    final details = <Widget>[
      MarketplaceDetailChip(
        icon: Icons.verified_outlined,
        label: 'Condition',
        value: post.cardCondition.trim().isEmpty ? 'Not set' : post.cardCondition.trim(),
      ),
      MarketplaceDetailChip(
        icon: post.deliveryMethod == 'Meetup'
            ? Icons.handshake_outlined
            : Icons.local_shipping_outlined,
        label: 'Delivery',
        value: post.deliveryMethod.trim().isEmpty ? 'Not set' : post.deliveryMethod.trim(),
      ),
      MarketplaceDetailChip(
        icon: Icons.place_outlined,
        label: 'Location',
        value: post.locationText.trim().isEmpty ? 'Not set' : post.locationText.trim(),
      ),
      MarketplaceDetailChip(
        icon: Icons.photo_library_outlined,
        label: 'Photos',
        value: post.hasImages ? _communityImageCountLabel(post.imageCount) : 'No photos',
      ),
    ];
    final visibleDetails = _expanded ? details : details.take(2).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(_primaryIcon, color: const Color(0xFFF7DE77), size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _primaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _primaryValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.32)),
                ),
                child: Text(
                  post.normalizedMarketStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if ((post.isSwap || post.isWanted) && post.wantedTradeFor.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.catching_pokemon_outlined, color: Color(0xFFF7DE77), size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_targetLabel: ${post.wantedTradeFor.trim()}',
                    maxLines: _expanded ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD8E3FB),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: visibleDetails,
          ),
          if (details.length > 2) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: const Color(0xFFFFF2B3),
                      size: 17,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _expanded ? 'Hide details' : 'More details',
                      style: const TextStyle(
                        color: Color(0xFFFFF2B3),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
