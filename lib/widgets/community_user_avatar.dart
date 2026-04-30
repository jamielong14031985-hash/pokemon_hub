import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../services/user_profile_service.dart';
import 'stored_image.dart';

String _avatarInitial(String displayName, {String fallback = 'P'}) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed.substring(0, 1).toUpperCase();
}

class CommunityUserAvatar extends StatelessWidget {
  const CommunityUserAvatar({
    super.key,
    required this.userId,
    required this.displayName,
    this.size = 38,
    this.initialImageBase64,
    this.onTap,
  });

  final String userId;
  final String displayName;
  final double size;
  final String? initialImageBase64;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trimmedUserId = userId.trim();
    final trimmedInitialImage = initialImageBase64?.trim();
    if (trimmedUserId.isEmpty) {
      return _buildAvatar(
        displayName: displayName,
        imageBase64: trimmedInitialImage == null || trimmedInitialImage.isEmpty ? null : trimmedInitialImage,
      );
    }

    return StreamBuilder<AppUserProfile?>(
      stream: UserProfileService.streamProfile(trimmedUserId),
      builder: (context, snapshot) {
        final liveProfile = snapshot.data;
        final liveImage = liveProfile?.profileImageBase64?.trim();
        return _buildAvatar(
          displayName: liveProfile?.displayName ?? displayName,
          imageBase64: liveImage != null && liveImage.isNotEmpty
              ? liveImage
              : (trimmedInitialImage == null || trimmedInitialImage.isEmpty ? null : trimmedInitialImage),
        );
      },
    );
  }

  Widget _buildAvatar({
    required String displayName,
    required String? imageBase64,
  }) {
    final hasImage = imageBase64 != null && imageBase64.trim().isNotEmpty;
    final avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(math.max(1.5, size * 0.055)),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF7DE77),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: math.max(1, size * 0.035),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? StoredImage(
                imageRef: imageBase64,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorChild: _buildInitial(displayName),
              )
            : _buildInitial(displayName),
      ),
    );

    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }

  Widget _buildInitial(String displayName) {
    return Container(
      color: const Color(0xFF102754),
      alignment: Alignment.center,
      child: Text(
        _avatarInitial(displayName),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
