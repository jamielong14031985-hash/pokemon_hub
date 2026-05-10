import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Tracks unread private community messages using Firestore, not local storage.
///
/// The app watches:
///
/// users/{uid}/community_private_conversations
///
/// Each conversation can have:
///
/// hasUnreadPrivateMessage: true / false
///
/// This is more reliable for testers and Play Store builds because the unread
/// state follows the user account instead of being stored only on one phone.
class CommunityUnreadPrivateMessageService {
  CommunityUnreadPrivateMessageService._();

  static final ValueNotifier<int> privateInboxSeenVersion = ValueNotifier<int>(0);

  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static DocumentReference<Map<String, dynamic>> _conversationRef({
    required String ownerUid,
    required String conversationId,
  }) {
    return _users
        .doc(ownerUid.trim())
        .collection('community_private_conversations')
        .doc(conversationId.trim());
  }

  static bool _hasUnreadForUser({
    required Map<String, dynamic> data,
    required String uid,
  }) {
    final explicitUnread = data['hasUnreadPrivateMessage'];
    if (explicitUnread is bool) {
      return explicitUnread;
    }

    // Fallback for older conversation documents that were created before
    // hasUnreadPrivateMessage existed.
    final lastSenderId = (data['lastSenderId'] ?? '').toString().trim();
    final lastMessage = (data['lastMessage'] ?? '').toString().trim();

    return lastMessage.isNotEmpty &&
        lastSenderId.isNotEmpty &&
        lastSenderId != uid.trim();
  }

  static Stream<bool> hasUnreadPrivateMessagesStream(String uid) async* {
    final safeUid = uid.trim();

    if (safeUid.isEmpty) {
      yield false;
      return;
    }

    try {
      await for (final snapshot
          in _users.doc(safeUid).collection('community_private_conversations').snapshots()) {
        final hasUnread = snapshot.docs.any(
          (doc) => _hasUnreadForUser(data: doc.data(), uid: safeUid),
        );

        yield hasUnread;
      }
    } catch (_) {
      yield false;
    }
  }

  static Future<void> markConversationRead({
    required String ownerUid,
    required String conversationId,
  }) async {
    final safeOwnerUid = ownerUid.trim();
    final safeConversationId = conversationId.trim();

    if (safeOwnerUid.isEmpty || safeConversationId.isEmpty) {
      return;
    }

    try {
      await _conversationRef(
        ownerUid: safeOwnerUid,
        conversationId: safeConversationId,
      ).set(
        <String, dynamic>{
          'hasUnreadPrivateMessage': false,
          'lastReadAtMs': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // The chat should still open even if the read marker cannot be saved.
    }

    privateInboxSeenVersion.value = privateInboxSeenVersion.value + 1;
  }

  /// Kept for older code compatibility.
  ///
  /// Opening the inbox should not clear unread messages anymore. The glow now
  /// clears when the user opens the actual private chat conversation.
  static Future<void> markPrivateInboxSeen(String uid) async {
    privateInboxSeenVersion.value = privateInboxSeenVersion.value + 1;
  }
}
