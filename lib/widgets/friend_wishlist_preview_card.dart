import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/wishlist_entry.dart';
import '../services/wishlist_service.dart';

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
                    const Icon(Icons.favorite_outline_rounded, color: Color(0xFFFF8EC3)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${profile.displayName}\'s wishlist',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenWishlist,
                      child: const Text('View all'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (wishlist.isEmpty)
                  const Text(
                    'No wishlist cards saved yet.',
                    style: TextStyle(color: Color(0xFFC8D4F0)),
                  )
                else
                  ...preview.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 42,
                          height: 58,
                          child: entry.imageUrl == null
                              ? const ColoredBox(
                                  color: Color(0xFF0E2A5E),
                                  child: Icon(Icons.image_not_supported, color: Colors.white54, size: 18),
                                )
                              : Image.network(entry.imageUrl!, fit: BoxFit.cover),
                        ),
                      ),
                      title: Text(
                        entry.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        entry.setName,
                        style: const TextStyle(color: Color(0xFFC8D4F0)),
                      ),
                      onTap: () => onTapEntry(entry),
                    ),
                  ),
                if (wishlist.length > preview.length) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${wishlist.length - preview.length} more wishlist card${wishlist.length - preview.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
