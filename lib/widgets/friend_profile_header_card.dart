import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
              padding: const EdgeInsets.all(16),
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
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderActionButton(
                          label: 'Pokédex',
                          icon: Icons.collections_bookmark_outlined,
                          onPressed: onOpenPokedex,
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
          width: 72,
          height: 72,
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
                      fontSize: 26,
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
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: const Color(0xFFF7DE77),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF102754), width: 3),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF071B43),
              size: 15,
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
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.white.withValues(alpha: 0.025),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
