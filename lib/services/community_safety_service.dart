import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_profile.dart';
import '../models/community_blocked_user.dart';

const Duration _kFirebaseReadTimeout = Duration(seconds: 12);
const Duration _kFirebaseWriteTimeout = Duration(seconds: 15);

String _safeDisplayName(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Trainer' : trimmed;
}

String _safeText(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

class CommunitySafetyService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('community_reports');

  static CollectionReference<Map<String, dynamic>> _blockedUsers(
    String ownerUid,
  ) =>
      _db.collection('users').doc(ownerUid.trim()).collection('blocked_users');

  static CommunityBlockedUser? _safeBlockedUserFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return CommunityBlockedUser.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  static Stream<List<CommunityBlockedUser>> blockedUsersStream(
    String ownerUid,
  ) async* {
    final trimmedOwnerUid = ownerUid.trim();
    if (trimmedOwnerUid.isEmpty) {
      yield const <CommunityBlockedUser>[];
      return;
    }

    try {
      await for (final snapshot in _blockedUsers(trimmedOwnerUid).snapshots()) {
        final items = snapshot.docs
            .map(_safeBlockedUserFromDoc)
            .whereType<CommunityBlockedUser>()
            .toList()
          ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

        yield items;
      }
    } catch (_) {
      yield const <CommunityBlockedUser>[];
    }
  }

  static Stream<Set<String>> blockedUserIdsStream(String ownerUid) {
    return blockedUsersStream(ownerUid).map(
      (items) => items
          .map((item) => item.blockedUid.trim())
          .where((uid) => uid.isNotEmpty)
          .toSet(),
    );
  }

  static Future<Set<String>> fetchBlockedUserIds(String ownerUid) async {
    final trimmedOwnerUid = ownerUid.trim();
    if (trimmedOwnerUid.isEmpty) return const <String>{};

    try {
      final snapshot = await _blockedUsers(trimmedOwnerUid).get().timeout(
            _kFirebaseReadTimeout,
          );

      return snapshot.docs
          .map((doc) => (doc.data()['blockedUid'] ?? doc.id).toString().trim())
          .where((uid) => uid.isNotEmpty)
          .toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  static Future<bool> isBlocked({
    required String ownerUid,
    required String blockedUid,
  }) async {
    final trimmedOwnerUid = ownerUid.trim();
    final trimmedBlockedUid = blockedUid.trim();

    if (trimmedOwnerUid.isEmpty || trimmedBlockedUid.isEmpty) {
      return false;
    }

    try {
      final doc = await _blockedUsers(trimmedOwnerUid)
          .doc(trimmedBlockedUid)
          .get()
          .timeout(_kFirebaseReadTimeout);

      return doc.exists;
    } catch (_) {
      return false;
    }
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

    try {
      await _blockedUsers(ownerUid).doc(targetUid).set({
        'blockedUid': targetUid,
        'blockedName': _safeDisplayName(blockedName),
        'blockedByUid': ownerUid,
        'blockedByName': _safeDisplayName(currentProfile.displayName),
        'source': _safeText(source, fallback: 'community'),
        'createdAtMs': now,
        'updatedAtMs': now,
      }, SetOptions(merge: true)).timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not block this user. Please check your connection and try again.',
      );
    }
  }

  static Future<void> unblockUser({
    required String ownerUid,
    required String blockedUid,
  }) async {
    final trimmedOwnerUid = ownerUid.trim();
    final trimmedBlockedUid = blockedUid.trim();

    if (trimmedOwnerUid.isEmpty || trimmedBlockedUid.isEmpty) return;

    try {
      await _blockedUsers(trimmedOwnerUid)
          .doc(trimmedBlockedUid)
          .delete()
          .timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not unblock this user. Please check your connection and try again.',
      );
    }
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
    final normalizedTargetType = _safeText(targetType, fallback: 'unknown');
    final normalizedReason = _safeText(reason, fallback: 'Other');

    if (reporterUid.isEmpty) {
      throw StateError('You need to be signed in to report this.');
    }

    if (targetUid.isNotEmpty && targetUid == reporterUid) {
      throw StateError('You cannot report yourself.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _reports.add({
        'reporterUid': reporterUid,
        'reporterName': _safeDisplayName(currentProfile.displayName),
        'reportedUid': targetUid,
        'reportedName': _safeDisplayName(reportedName),
        'targetType': normalizedTargetType,
        'targetId': targetId.trim(),
        'targetTitle': targetTitle.trim(),
        'reason': normalizedReason,
        'details': details.trim(),
        'status': 'open',
        'appArea': 'community',
        'createdAtMs': now,
        'updatedAtMs': now,
      }).timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not submit your report. Please check your connection and try again.',
      );
    }
  }
}
