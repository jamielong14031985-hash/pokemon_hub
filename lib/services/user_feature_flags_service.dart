import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserFeatureFlags {
  const UserFeatureFlags({
    required this.userId,
    required this.restockAlertsEnabled,
    required this.proEnabled,
    this.updatedAt,
    this.updatedBy,
  });

  final String userId;
  final bool restockAlertsEnabled;
  final bool proEnabled;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory UserFeatureFlags.disabled(String userId) {
    return UserFeatureFlags(
      userId: userId,
      restockAlertsEnabled: false,
      proEnabled: false,
    );
  }

  factory UserFeatureFlags.fromDoc({
    required String userId,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();

    if (data == null) {
      return UserFeatureFlags.disabled(userId);
    }

    final updatedAt = data['updatedAt'];

    return UserFeatureFlags(
      userId: userId,
      restockAlertsEnabled: data['restockAlertsEnabled'] == true,
      proEnabled: data['proEnabled'] == true,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      updatedBy: data['updatedBy']?.toString(),
    );
  }
}


class UserAppRole {
  const UserAppRole({
    required this.userId,
    required this.role,
    this.updatedAt,
    this.updatedBy,
  });

  final String userId;
  final String role;
  final DateTime? updatedAt;
  final String? updatedBy;

  bool get isAdmin => role.toLowerCase().trim() == 'admin';
  bool get isModerator => role.toLowerCase().trim() == 'moderator';
  bool get canManageFeatures => isAdmin || isModerator;

  factory UserAppRole.none(String userId) {
    return UserAppRole(userId: userId, role: '');
  }

  factory UserAppRole.fromDoc({
    required String userId,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();
    if (data == null) return UserAppRole.none(userId);

    final updatedAt = data['updatedAt'];

    return UserAppRole(
      userId: userId,
      role: data['role']?.toString().toLowerCase().trim() ?? '',
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      updatedBy: data['updatedBy']?.toString(),
    );
  }
}

class AppUserSummary {
  const AppUserSummary({
    required this.uid,
    required this.username,
    required this.email,
  });

  final String uid;
  final String username;
  final String email;

  factory AppUserSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return AppUserSummary(
      uid: data['uid']?.toString().trim().isNotEmpty == true
          ? data['uid'].toString()
          : doc.id,
      username: data['username']?.toString() ?? 'Unknown user',
      email: data['email']?.toString() ?? '',
    );
  }
}

class UserFeatureFlagsService {
  UserFeatureFlagsService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<bool> watchCurrentUserRestockAlertsEnabled() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<bool>.value(false);

      return _firestore
          .collection('user_feature_flags')
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return false;

        final data = doc.data();
        return data?['restockAlertsEnabled'] == true;
      });
    });
  }

  static Stream<bool> watchCurrentUserProEnabled() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<bool>.value(false);

      return _firestore
          .collection('user_feature_flags')
          .doc(user.uid)
          .snapshots()
          .map((doc) => doc.data()?['proEnabled'] == true);
    });
  }

  static Stream<bool> watchCurrentUserCanManageFeatureFlags() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<bool>.value(false);

      return _firestore.collection('app_roles').doc(user.uid).snapshots().map(
        (doc) {
          final role = doc.data()?['role']?.toString().toLowerCase();
          return role == 'admin' || role == 'moderator';
        },
      );
    });
  }

  static Stream<List<AppUserSummary>> watchUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs.map(AppUserSummary.fromDoc).toList();

      users.sort((a, b) {
        final usernameCompare = a.username.toLowerCase().compareTo(
              b.username.toLowerCase(),
            );

        if (usernameCompare != 0) return usernameCompare;

        return a.email.toLowerCase().compareTo(b.email.toLowerCase());
      });

      return users;
    });
  }

  static Stream<UserFeatureFlags> watchFlagsForUser(String userId) {
    return _firestore
        .collection('user_feature_flags')
        .doc(userId)
        .snapshots()
        .map(
          (doc) => UserFeatureFlags.fromDoc(
            userId: userId,
            doc: doc,
          ),
        );
  }

  static Stream<UserAppRole> watchRoleForUser(String userId) {
    return _firestore.collection('app_roles').doc(userId).snapshots().map(
          (doc) => UserAppRole.fromDoc(
            userId: userId,
            doc: doc,
          ),
        );
  }

  static Future<void> setRestockAlertsEnabled({
    required String userId,
    required bool enabled,
  }) async {
    await updateFeatureFlags(
      userId: userId,
      restockAlertsEnabled: enabled,
    );
  }

  static Future<void> setProEnabled({
    required String userId,
    required bool enabled,
  }) async {
    await updateFeatureFlags(
      userId: userId,
      proEnabled: enabled,
    );
  }

  static Future<void> updateFeatureFlags({
    required String userId,
    bool? restockAlertsEnabled,
    bool? proEnabled,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to manage feature flags.');
    }

    final docRef = _firestore.collection('user_feature_flags').doc(userId);
    final existing = await docRef.get();
    final existingData = existing.data() ?? <String, dynamic>{};

    final data = <String, dynamic>{
      'userId': userId,
      'restockAlertsEnabled': restockAlertsEnabled ??
          (existingData['restockAlertsEnabled'] == true),
      'proEnabled': proEnabled ?? (existingData['proEnabled'] == true),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': currentUser.uid,
    };

    await docRef.set(data, SetOptions(merge: true));
  }
  static Future<void> setAdminEnabled({
    required String userId,
    required bool enabled,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to manage admin permissions.');
    }

    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw StateError('Missing user ID.');
    }

    if (enabled) {
      await _firestore.collection('app_roles').doc(trimmedUserId).set(
        <String, dynamic>{
          'uid': trimmedUserId,
          'role': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': currentUser.uid,
        },
        SetOptions(merge: true),
      );
      return;
    }

    if (trimmedUserId == currentUser.uid) {
      throw StateError(
        'You cannot remove admin permission from yourself inside the app.',
      );
    }

    await _firestore.collection('app_roles').doc(trimmedUserId).delete();
  }

}
