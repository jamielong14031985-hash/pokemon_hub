import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_profile.dart';
import 'community_image_services.dart';

String _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

class UserProfileService {
  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static Stream<AppUserProfile?> streamProfile(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return AppUserProfile.fromMap(data);
    });
  }

  static Future<AppUserProfile?> fetchProfile(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return AppUserProfile.fromMap(data);
  }

  static Future<void> upsertProfile({
    required User user,
    required String username,
    int? dateOfBirthMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _users.doc(user.uid).get();
    final createdAtMs = (existing.data()?['createdAtMs'] as num?)?.toInt() ?? now;
    final resolvedDateOfBirthMs = dateOfBirthMs ?? (existing.data()?['dateOfBirthMs'] as num?)?.toInt();
    final existingProfileImageBase64 = _firstNonEmptyString([
      existing.data()?['profileImageRef'],
      existing.data()?['profileImageUrl'],
      existing.data()?['profileImageBase64'],
    ]);

    final profile = AppUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      username: username,
      createdAtMs: createdAtMs,
      updatedAtMs: now,
      dateOfBirthMs: resolvedDateOfBirthMs,
      profileImageBase64: existingProfileImageBase64.isEmpty ? null : existingProfileImageBase64,
    );

    await _users.doc(user.uid).set(profile.toJson(), SetOptions(merge: true));
  }

  static Future<void> updateProfileImageBase64({
    required String uid,
    required String? imageBase64,
  }) async {
    final trimmedImage = imageBase64?.trim() ?? '';
    final isRemoteImage = FirebaseImageStorageService.isRemoteRef(trimmedImage);
    await _users.doc(uid).set(
      {
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        if (trimmedImage.isEmpty) ...{
          'profileImageRef': FieldValue.delete(),
          'profileImageUrl': FieldValue.delete(),
          'profileImageBase64': FieldValue.delete(),
        } else ...{
          'profileImageRef': trimmedImage,
          if (isRemoteImage) 'profileImageUrl': trimmedImage,
          if (isRemoteImage)
            'profileImageBase64': FieldValue.delete()
          else
            'profileImageBase64': trimmedImage,
        },
      },
      SetOptions(merge: true),
    );
  }
}
