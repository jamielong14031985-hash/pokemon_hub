import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_profile.dart';
import '../models/community_blocked_user.dart';

class CommunitySafetyService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('community_reports');

  static CollectionReference<Map<String, dynamic>> _blockedUsers(String ownerUid) =>
      _db.collection('users').doc(ownerUid).collection('blocked_users');

  static Stream<List<CommunityBlockedUser>> blockedUsersStream(String ownerUid) {
    final trimmedOwnerUid = ownerUid.trim();
    if (trimmedOwnerUid.isEmpty) {
      return Stream<List<CommunityBlockedUser>>.value(const <CommunityBlockedUser>[]);
    }

    return _blockedUsers(trimmedOwnerUid).snapshots().map((snapshot) {
      final items = snapshot.docs.map(CommunityBlockedUser.fromDoc).toList()
        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return items;
    });
  }

  static Stream<Set<String>> blockedUserIdsStream(String ownerUid) {
    return blockedUsersStream(ownerUid).map(
      (items) => items.map((item) => item.blockedUid.trim()).where((uid) => uid.isNotEmpty).toSet(),
    );
  }

  static Future<Set<String>> fetchBlockedUserIds(String ownerUid) async {
    final trimmedOwnerUid = ownerUid.trim();
    if (trimmedOwnerUid.isEmpty) return const <String>{};

    final snapshot = await _blockedUsers(trimmedOwnerUid).get();
    return snapshot.docs
        .map((doc) => (doc.data()['blockedUid'] ?? doc.id).toString().trim())
        .where((uid) => uid.isNotEmpty)
        .toSet();
  }

  static Future<bool> isBlocked({
    required String ownerUid,
    required String blockedUid,
  }) async {
    final trimmedOwnerUid = ownerUid.trim();
    final trimmedBlockedUid = blockedUid.trim();
    if (trimmedOwnerUid.isEmpty || trimmedBlockedUid.isEmpty) return false;
    final doc = await _blockedUsers(trimmedOwnerUid).doc(trimmedBlockedUid).get();
    return doc.exists;
  }

  static Future<void> blockUser({
    required AppUserProfile currentProfile,
    required String blockedUid,
    required String blockedName,
    String source = 'community',
  }) async {
    final ownerUid = currentProfile.uid.trim();
    final targetUid = blockedUid.trim();
    if (ownerUid.isEmpty || targetUid.isEmpty) {
      throw StateError('Missing user details.');
    }
    if (ownerUid == targetUid) {
      throw StateError('You cannot block yourself.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await _blockedUsers(ownerUid).doc(targetUid).set({
      'blockedUid': targetUid,
      'blockedName': blockedName.trim().isEmpty ? 'Trainer' : blockedName.trim(),
      'blockedByUid': ownerUid,
      'blockedByName': currentProfile.displayName,
      'source': source.trim().isEmpty ? 'community' : source.trim(),
      'createdAtMs': now,
      'updatedAtMs': now,
    }, SetOptions(merge: true));
  }

  static Future<void> unblockUser({
    required String ownerUid,
    required String blockedUid,
  }) async {
    final trimmedOwnerUid = ownerUid.trim();
    final trimmedBlockedUid = blockedUid.trim();
    if (trimmedOwnerUid.isEmpty || trimmedBlockedUid.isEmpty) return;
    await _blockedUsers(trimmedOwnerUid).doc(trimmedBlockedUid).delete();
  }

  static Future<void> submitReport({
    required AppUserProfile currentProfile,
    required String reportedUid,
    required String reportedName,
    required String targetType,
    required String targetId,
    required String targetTitle,
    required String reason,
    required String details,
  }) async {
    final reporterUid = currentProfile.uid.trim();
    final targetUid = reportedUid.trim();
    final normalizedTargetType = targetType.trim().isEmpty ? 'unknown' : targetType.trim();
    final normalizedReason = reason.trim().isEmpty ? 'Other' : reason.trim();

    if (reporterUid.isEmpty) {
      throw StateError('You need to be signed in to report this.');
    }
    if (targetUid.isNotEmpty && targetUid == reporterUid) {
      throw StateError('You cannot report yourself.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await _reports.add({
      'reporterUid': reporterUid,
      'reporterName': currentProfile.displayName,
      'reportedUid': targetUid,
      'reportedName': reportedName.trim().isEmpty ? 'Trainer' : reportedName.trim(),
      'targetType': normalizedTargetType,
      'targetId': targetId.trim(),
      'targetTitle': targetTitle.trim(),
      'reason': normalizedReason,
      'details': details.trim(),
      'status': 'open',
      'appArea': 'community',
      'createdAtMs': now,
      'updatedAtMs': now,
    });
  }
}
