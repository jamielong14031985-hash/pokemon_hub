import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import 'community_meta_chip.dart';

String _avatarInitial(String displayName, {String fallback = 'P'}) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed.substring(0, 1).toUpperCase();
}

String _formatCommunityDate(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$day/$month/$year  $hour:$minute';
}

class FriendProfileHeaderCard extends StatelessWidget {
  const FriendProfileHeaderCard({
    super.key,
    required this.profile,
    required this.imageProvider,
    required this.onOpenWishlist,
    required this.onOpenPokedex,
    required this.onOpenTradeMatches,
    required this.onMessage,
  });

  final AppUserProfile profile;
  final ImageProvider? imageProvider;
  final VoidCallback onOpenWishlist;
  final VoidCallback onOpenPokedex;
  final VoidCallback onOpenTradeMatches;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF183A78),
              Color(0xFF102754),
              Color(0xFF071F4D),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white12,
                    backgroundImage: imageProvider,
                    child: imageProvider == null
                        ? Text(
                            _avatarInitial(profile.displayName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.createdAtMs > 0
                              ? 'Trainer since ${_formatCommunityDate(DateTime.fromMillisecondsSinceEpoch(profile.createdAtMs)).split('  ').first}'
                              : 'Friend profile',
                          style: const TextStyle(color: Color(0xFFC8D4F0), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  CommunityMetaChip(
                    icon: Icons.favorite_outline_rounded,
                    label: 'Wishlist',
                    color: Color(0xFFB13B59),
                  ),
                  CommunityMetaChip(
                    icon: Icons.emoji_events_outlined,
                    label: 'Achievements',
                    color: Color(0xFF875A16),
                  ),
                  CommunityMetaChip(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Showcase',
                    color: Color(0xFF6B4EFF),
                  ),
                  CommunityMetaChip(
                    icon: Icons.collections_bookmark_outlined,
                    label: 'Pokédex',
                    color: Color(0xFF2C7A5B),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onOpenPokedex,
                      icon: const Icon(Icons.collections_bookmark_outlined),
                      label: const Text('Pokédex'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2C7A5B),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenWishlist,
                      icon: const Icon(Icons.favorite_outline_rounded),
                      label: const Text('Wishlist'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenTradeMatches,
                      icon: const Icon(Icons.handshake_outlined),
                      label: const Text('Trade matches'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMessage,
                      icon: const Icon(Icons.mail_outline_rounded),
                      label: const Text('Message'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
