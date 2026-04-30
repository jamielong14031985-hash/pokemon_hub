import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/wishlist_entry.dart';
import '../services/wishlist_service.dart';
import 'fast_network_image.dart';

class FriendWishlistPreviewCard extends StatelessWidget {
  const FriendWishlistPreviewCard({
    super.key,
    required this.profile,
    required this.onOpenWishlist,
    required this.onTapEntry,
  });

  final AppUserProfile profile;
  final VoidCallback onOpenWishlist;
  final Future<void> Function(WishlistEntry entry) onTapEntry;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WishlistEntry>>(
      stream: WishlistService.wishlistStream(profile.uid),
      builder: (context, snapshot) {
        final wishlist = snapshot.data ?? const <WishlistEntry>[];
        final preview = wishlist.take(3).toList();
        final displayName = profile.displayName.trim().isEmpty ? 'Trainer' : profile.displayName.trim();

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
                  _WishlistHeader(
                    displayName: displayName,
                    count: wishlist.length,
                    onOpenWishlist: onOpenWishlist,
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                    const _WishlistLoadingState()
                  else if (snapshot.hasError)
                    const _WishlistMessageState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Could not load wishlist',
                      message: 'Check your connection and try again.',
                      accent: Color(0xFFE85D5D),
                    )
                  else if (wishlist.isEmpty)
                    _WishlistMessageState(
                      icon: Icons.favorite_border_rounded,
                      title: 'No wishlist cards yet',
                      message: '$displayName has not saved any wishlist cards yet.',
                      accent: const Color(0xFFFF8EC3),
                    )
                  else ...[
                    ...preview.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WishlistPreviewRow(
                          entry: entry,
                          onTap: () => unawaited(onTapEntry(entry)),
                        ),
                      ),
                    ),
                    if (wishlist.length > preview.length)
                      _MoreWishlistItems(
                        extraCount: wishlist.length - preview.length,
                        onOpenWishlist: onOpenWishlist,
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WishlistHeader extends StatelessWidget {
  const _WishlistHeader({
    required this.displayName,
    required this.count,
    required this.onOpenWishlist,
  });

  final String displayName;
  final int count;
  final VoidCallback onOpenWishlist;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8EC3).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFFF8EC3).withValues(alpha: 0.26),
            ),
          ),
          child: const Icon(
            Icons.favorite_outline_rounded,
            color: Color(0xFFFF8EC3),
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$displayName\'s wishlist',
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
                count == 0
                    ? 'No saved wishlist cards'
                    : '$count saved wishlist card${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFFC8D4F0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onOpenWishlist,
          child: const Text('View all'),
        ),
      ],
    );
  }
}

class _WishlistPreviewRow extends StatelessWidget {
  const _WishlistPreviewRow({
    required this.entry,
    required this.onTap,
  });

  final WishlistEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = entry.imageUrl?.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 66,
                child: imageUrl == null || imageUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF0E2A5E),
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.white54,
                          size: 20,
                        ),
                      )
                    : FastNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 66,
                        cacheWidth: 120,
                        cacheHeight: 168,
                      ),
              ),
            ),
            const SizedBox(width: 12),
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
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.setName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC8D4F0),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8EC3).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFFF8EC3).withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Text(
                      'Wishlist card',
                      style: TextStyle(
                        color: Color(0xFFFFC6E0),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreWishlistItems extends StatelessWidget {
  const _MoreWishlistItems({
    required this.extraCount,
    required this.onOpenWishlist,
  });

  final int extraCount;
  final VoidCallback onOpenWishlist;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenWishlist,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFF8EC3).withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFF8EC3).withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.favorite_outline_rounded,
              color: Color(0xFFFF8EC3),
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '+$extraCount more wishlist card${extraCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFFFFC6E0),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFFFF8EC3),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistLoadingState extends StatelessWidget {
  const _WishlistLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading wishlist cards...',
              style: TextStyle(
                color: Color(0xFFE4ECFF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistMessageState extends StatelessWidget {
  const _WishlistMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
