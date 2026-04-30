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

  String get _joinedLabel {
    if (profile.createdAtMs <= 0) return 'Friend profile';
    final joinedDate = _formatCommunityDate(
      DateTime.fromMillisecondsSinceEpoch(profile.createdAtMs),
    ).split('  ').first;
    return 'Trainer since $joinedDate';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = profile.displayName.trim().isEmpty ? 'Trainer' : profile.displayName.trim();

    return Card(
      color: const Color(0xFF102754),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B4387),
              Color(0xFF102754),
              Color(0xFF061A42),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -42,
              top: -52,
              child: Container(
                width: 164,
                height: 164,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -70,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF82D8FF).withValues(alpha: 0.055),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _FriendAvatar(
                        displayName: displayName,
                        imageProvider: imageProvider,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Friend profile',
                              style: TextStyle(
                                color: Color(0xFFF7DE77),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _joinedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFC8D4F0),
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFF7DE77),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'View their collection progress, wishlist cards, trade matches, showcase, and achievement badges.',
                            style: TextStyle(
                              color: Color(0xFFE4ECFF),
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderActionButton(
                          label: 'Pokédex',
                          icon: Icons.collections_bookmark_outlined,
                          onPressed: onOpenPokedex,
                          filled: true,
                          color: const Color(0xFF2C7A5B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeaderActionButton(
                          label: 'Wishlist',
                          icon: Icons.favorite_outline_rounded,
                          onPressed: onOpenWishlist,
                          color: const Color(0xFFFF8EC3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderActionButton(
                          label: 'Trade matches',
                          icon: Icons.handshake_outlined,
                          onPressed: onOpenTradeMatches,
                          color: const Color(0xFFF7DE77),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeaderActionButton(
                          label: 'Message',
                          icon: Icons.mail_outline_rounded,
                          onPressed: onMessage,
                          color: const Color(0xFF82D8FF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({
    required this.displayName,
    required this.imageProvider,
  });

  final String displayName;
  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 86,
          height: 86,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7DE77), Color(0xFF82D8FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: const Color(0xFF16366E),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Text(
                    _avatarInitial(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          right: -1,
          bottom: 2,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF7DE77),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF102754), width: 3),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF071B43),
              size: 17,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: color.withValues(alpha: 0.42)),
        backgroundColor: Colors.white.withValues(alpha: 0.035),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
