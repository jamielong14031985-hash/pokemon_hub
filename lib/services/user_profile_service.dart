import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_profile.dart';
import 'community_image_services.dart';

const Duration _kFirebaseReadTimeout = Duration(seconds: 12);
const Duration _kFirebaseWriteTimeout = Duration(seconds: 15);

String _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

int? _readIntMs(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString().trim());
}

String _readAccountType(dynamic value) {
  final text = (value ?? '').toString().trim().toLowerCase();
  if (text == 'business') return 'business';
  return 'personal';
}

class UserProfileService {
  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static AppUserProfile? _profileFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    try {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return AppUserProfile.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  static Stream<AppUserProfile?> streamProfile(String uid) async* {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      yield null;
      return;
    }

    try {
      await for (final snapshot in _users.doc(safeUid).snapshots()) {
        yield _profileFromSnapshot(snapshot);
      }
    } catch (_) {
      yield null;
    }
  }

  static Future<AppUserProfile?> fetchProfile(String uid) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) return null;

    try {
      final snapshot = await _users.doc(safeUid).get().timeout(
            _kFirebaseReadTimeout,
          );
      return _profileFromSnapshot(snapshot);
    } catch (_) {
      return null;
    }
  }

  static Future<void> upsertProfile({
    required User user,
    required String username,
    int? dateOfBirthMs,
    String? accountType,
    bool? businessProfileCreated,
  }) async {
    final safeUid = user.uid.trim();
    if (safeUid.isEmpty) {
      throw Exception('Could not save profile because the user id is missing.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final safeUsername = username.trim().isEmpty ? 'Collector' : username.trim();

    Map<String, dynamic>? existingData;
    try {
      final existing = await _users.doc(safeUid).get().timeout(
            _kFirebaseReadTimeout,
          );
      existingData = existing.data();
    } catch (_) {
      existingData = null;
    }

    final createdAtMs = _readIntMs(existingData?['createdAtMs']) ?? now;
    final resolvedDateOfBirthMs =
        dateOfBirthMs ?? _readIntMs(existingData?['dateOfBirthMs']);

    final resolvedAccountType = _readAccountType(
      accountType ?? existingData?['accountType'],
    );

    final resolvedBusinessProfileCreated = businessProfileCreated ??
        (existingData?['businessProfileCreated'] == true);

    final existingProfileImageBase64 = _firstNonEmptyString([
      existingData?['profileImageRef'],
      existingData?['profileImageUrl'],
      existingData?['profileImageBase64'],
    ]);

    final profile = AppUserProfile(
      uid: safeUid,
      email: user.email ?? '',
      username: safeUsername,
      createdAtMs: createdAtMs,
      updatedAtMs: now,
      accountType: resolvedAccountType,
      businessProfileCreated: resolvedBusinessProfileCreated,
      dateOfBirthMs: resolvedDateOfBirthMs,
      profileImageBase64:
          existingProfileImageBase64.isEmpty ? null : existingProfileImageBase64,
    );

    try {
      await _users.doc(safeUid).set(
            profile.toJson(),
            SetOptions(merge: true),
          ).timeout(
            _kFirebaseWriteTimeout,
          );
    } catch (_) {
      throw Exception(
        'Could not save your profile. Please check your connection and try again.',
      );
    }
  }

  static Future<void> markBusinessProfileCreated({
    required String uid,
    required bool created,
  }) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      throw Exception('Could not update business profile status because the user id is missing.');
    }

    try {
      await _users.doc(safeUid).set(
        {
          'businessProfileCreated': created,
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      ).timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not update your business profile status. Please check your connection and try again.',
      );
    }
  }

  static Future<void> updateProfileImageBase64({
    required String uid,
    required String? imageBase64,
  }) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      throw Exception('Could not update profile image because the user id is missing.');
    }

    final trimmedImage = imageBase64?.trim() ?? '';
    final isRemoteImage = FirebaseImageStorageService.isRemoteRef(trimmedImage);

    try {
      await _users.doc(safeUid).set(
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
      ).timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not update your profile image. Please check your connection and try again.',
      );
    }
  }
}
