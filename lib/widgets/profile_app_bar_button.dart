import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../services/local_image_store.dart';
import 'profile_initial_avatar.dart';
import 'stored_image.dart';

class ProfileAppBarButton extends StatefulWidget {
  const ProfileAppBarButton({
    super.key,
    required this.profile,
    required this.onOpenProfile,
  });

  final AppUserProfile profile;
  final Future<void> Function() onOpenProfile;

  @override
  State<ProfileAppBarButton> createState() => _ProfileAppBarButtonState();
}

class _ProfileAppBarButtonState extends State<ProfileAppBarButton> {
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  @override
  void didUpdateWidget(covariant ProfileAppBarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.uid != widget.profile.uid) {
      _loadProfileImage();
    }
  }

  Future<void> _loadProfileImage() async {
    final imagePath = await LocalProfileImageStore.loadForUser(widget.profile.uid);
    if (!mounted) return;
    setState(() {
      _profileImagePath = imagePath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayLetter = widget.profile.displayName.isEmpty
        ? 'P'
        : widget.profile.displayName[0].toUpperCase();
    final imageFile = _profileImagePath != null ? File(_profileImagePath!) : null;
    final existingImageFile = imageFile != null && imageFile.existsSync() ? imageFile : null;
    final sharedImageRef = widget.profile.profileImageBase64?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          await widget.onOpenProfile();
          await _loadProfileImage();
        },
        child: Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF7DE77),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: existingImageFile != null
                ? Image.file(
                    existingImageFile,
                    fit: BoxFit.cover,
                    width: 42,
                    height: 42,
                    errorBuilder: (_, __, ___) => ProfileInitialAvatar(
                      displayLetter: displayLetter,
                    ),
                  )
                : sharedImageRef.isNotEmpty
                    ? StoredImage(
                        imageRef: sharedImageRef,
                        fit: BoxFit.cover,
                        width: 42,
                        height: 42,
                        errorChild: ProfileInitialAvatar(displayLetter: displayLetter),
                      )
                    : ProfileInitialAvatar(displayLetter: displayLetter),
          ),
        ),
      ),
    );
  }
}
