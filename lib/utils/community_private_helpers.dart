import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_private_models.dart';

const Duration _kFirebaseReadTimeout = Duration(seconds: 12);
const Duration _kFirebaseWriteTimeout = Duration(seconds: 15);

String _safeText(String value, {String fallback = ''}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _safeDisplayName(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Trainer' : trimmed;
}

String formatCommunityDate(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$day/$month/$year  $hour:$minute';
}

String formatCommunityRelativeTime(DateTime dt) {
  final difference = DateTime.now().difference(dt);
  if (difference.inSeconds < 45) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return formatCommunityDate(dt).split('  ').first;
}

String communityConversationIdForPost({
  required String postId,
  required String userAId,
  required String userBId,
}) {
  final ids = <String>[
    userAId.trim(),
    userBId.trim(),
  ].where((uid) => uid.isNotEmpty).toList()
    ..sort();

  final safePostId = postId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  if (safePostId.isEmpty || ids.length < 2) {
    return '';
  }

  final safeUserPart = ids
      .map((uid) => uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_'))
      .join('_');

  return '${safePostId}_$safeUserPart';
}

DocumentReference<Map<String, dynamic>> _communityPrivateConversationRef(
  String conversationId,
) =>
    FirebaseFirestore.instance
        .collection('community_private_conversations')
        .doc(conversationId.trim());

DocumentReference<Map<String, dynamic>> userCommunityPrivateConversationRef({
  required String ownerUid,
  required String conversationId,
}) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUid.trim())
        .collection('community_private_conversations')
        .doc(conversationId.trim());

Map<String, dynamic> _communityPrivateConversationData({
  required String currentUid,
  required String currentUserName,
  required String otherUserId,
  required String otherUserName,
  required String relatedPostId,
  required String relatedPostTitle,
  required int createdAtMs,
  required int updatedAtMs,
  required String lastMessage,
  required String lastSenderId,
  bool? hasUnreadPrivateMessage,
  int? unreadUpdatedAtMs,
  int? lastReadAtMs,
}) {
  final safeCurrentUid = currentUid.trim();
  final safeOtherUserId = otherUserId.trim();

  final data = <String, dynamic>{
    'participants': <String>[safeCurrentUid, safeOtherUserId],
    'participantNames': <String, String>{
      safeCurrentUid: _safeDisplayName(currentUserName),
      safeOtherUserId: _safeDisplayName(otherUserName),
    },
    'relatedPostId': relatedPostId.trim(),
    'relatedPostTitle': relatedPostTitle.trim(),
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
    'lastMessage': lastMessage.trim(),
    'lastSenderId': lastSenderId.trim(),
  };

  if (hasUnreadPrivateMessage != null) {
    data['hasUnreadPrivateMessage'] = hasUnreadPrivateMessage;
  }

  if (unreadUpdatedAtMs != null) {
    data['unreadUpdatedAtMs'] = unreadUpdatedAtMs;
  }

  if (lastReadAtMs != null) {
    data['lastReadAtMs'] = lastReadAtMs;
  }

  return data;
}

Future<void> syncCommunityPrivateConversation({
  required String conversationId,
  required String currentUid,
  required String currentUserName,
  required String otherUserId,
  required String otherUserName,
  required String relatedPostId,
  required String relatedPostTitle,
  required int createdAtMs,
  required int updatedAtMs,
  String lastMessage = '',
  String lastSenderId = '',
}) async {
  final safeConversationId = conversationId.trim();
  final safeCurrentUid = currentUid.trim();
  final safeOtherUserId = otherUserId.trim();

  if (safeConversationId.isEmpty ||
      safeCurrentUid.isEmpty ||
      safeOtherUserId.isEmpty ||
      safeCurrentUid == safeOtherUserId) {
    return;
  }

  final data = _communityPrivateConversationData(
    currentUid: safeCurrentUid,
    currentUserName: currentUserName,
    otherUserId: safeOtherUserId,
    otherUserName: otherUserName,
    relatedPostId: relatedPostId,
    relatedPostTitle: relatedPostTitle,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs,
    lastMessage: lastMessage,
    lastSenderId: lastSenderId,
  );

  final batch = FirebaseFirestore.instance.batch();

  batch.set(
    _communityPrivateConversationRef(safeConversationId),
    data,
    SetOptions(merge: true),
  );

  batch.set(
    userCommunityPrivateConversationRef(
      ownerUid: safeCurrentUid,
      conversationId: safeConversationId,
    ),
    data,
    SetOptions(merge: true),
  );

  batch.set(
    userCommunityPrivateConversationRef(
      ownerUid: safeOtherUserId,
      conversationId: safeConversationId,
    ),
    data,
    SetOptions(merge: true),
  );

  try {
    await batch.commit().timeout(_kFirebaseWriteTimeout);
  } catch (_) {
    throw Exception(
      'Could not sync this private conversation. Please check your connection and try again.',
    );
  }
}

Future<void> syncCommunityPrivateMessage({
  required String conversationId,
  required String currentUid,
  required String currentUserName,
  required String otherUserId,
  required String otherUserName,
  required String relatedPostId,
  required String relatedPostTitle,
  required CommunityPrivateMessage message,
}) async {
  final safeConversationId = conversationId.trim();
  final safeCurrentUid = currentUid.trim();
  final safeOtherUserId = otherUserId.trim();
  final safeMessageId = message.id.trim();
  final safeSenderId = message.authorId.trim();

  if (safeConversationId.isEmpty ||
      safeCurrentUid.isEmpty ||
      safeOtherUserId.isEmpty ||
      safeMessageId.isEmpty ||
      safeCurrentUid == safeOtherUserId) {
    return;
  }

  final conversationData = _communityPrivateConversationData(
    currentUid: safeCurrentUid,
    currentUserName: currentUserName,
    otherUserId: safeOtherUserId,
    otherUserName: otherUserName,
    relatedPostId: relatedPostId,
    relatedPostTitle: relatedPostTitle,
    createdAtMs: message.createdAtMs,
    updatedAtMs: message.createdAtMs,
    lastMessage: message.message,
    lastSenderId: safeSenderId,
  );

  final currentUserHasUnread =
      safeSenderId.isNotEmpty && safeSenderId != safeCurrentUid;
  final otherUserHasUnread =
      safeSenderId.isNotEmpty && safeSenderId != safeOtherUserId;

  final currentConversationData = <String, dynamic>{
    ...conversationData,
    'hasUnreadPrivateMessage': currentUserHasUnread,
    'unreadUpdatedAtMs': message.createdAtMs,
    if (!currentUserHasUnread) 'lastReadAtMs': message.createdAtMs,
  };

  final otherConversationData = <String, dynamic>{
    ...conversationData,
    'hasUnreadPrivateMessage': otherUserHasUnread,
    'unreadUpdatedAtMs': message.createdAtMs,
    if (!otherUserHasUnread) 'lastReadAtMs': message.createdAtMs,
  };

  final messageData = <String, dynamic>{
    ...message.toJson(),
    'id': safeMessageId,
    'message': _safeText(message.message),
    'authorId': safeSenderId,
    'authorName': _safeDisplayName(message.authorName),
  };

  final sharedConversationRef = _communityPrivateConversationRef(
    safeConversationId,
  );

  final currentConversationRef = userCommunityPrivateConversationRef(
    ownerUid: safeCurrentUid,
    conversationId: safeConversationId,
  );

  final otherConversationRef = userCommunityPrivateConversationRef(
    ownerUid: safeOtherUserId,
    conversationId: safeConversationId,
  );

  final batch = FirebaseFirestore.instance.batch();

  batch.set(sharedConversationRef, conversationData, SetOptions(merge: true));
  batch.set(
    currentConversationRef,
    currentConversationData,
    SetOptions(merge: true),
  );
  batch.set(
    otherConversationRef,
    otherConversationData,
    SetOptions(merge: true),
  );

  batch.set(
    sharedConversationRef.collection('messages').doc(safeMessageId),
    messageData,
    SetOptions(merge: true),
  );

  batch.set(
    currentConversationRef.collection('messages').doc(safeMessageId),
    messageData,
    SetOptions(merge: true),
  );

  batch.set(
    otherConversationRef.collection('messages').doc(safeMessageId),
    messageData,
    SetOptions(merge: true),
  );

  try {
    await batch.commit().timeout(_kFirebaseWriteTimeout);
  } catch (_) {
    throw Exception(
      'Could not send this private message. Please check your connection and try again.',
    );
  }
}

Future<void> deleteCommunityPrivateConversationForUser({
  required String ownerUid,
  required String conversationId,
}) async {
  final trimmedOwnerUid = ownerUid.trim();
  final trimmedConversationId = conversationId.trim();

  if (trimmedOwnerUid.isEmpty || trimmedConversationId.isEmpty) return;

  final conversationRef = userCommunityPrivateConversationRef(
    ownerUid: trimmedOwnerUid,
    conversationId: trimmedConversationId,
  );

  try {
    while (true) {
      final messagesSnapshot = await conversationRef
          .collection('messages')
          .limit(400)
          .get()
          .timeout(_kFirebaseReadTimeout);

      if (messagesSnapshot.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (final messageDoc in messagesSnapshot.docs) {
        batch.delete(messageDoc.reference);
      }

      await batch.commit().timeout(_kFirebaseWriteTimeout);
    }

    await conversationRef.delete().timeout(_kFirebaseWriteTimeout);
  } catch (_) {
    throw Exception(
      'Could not delete this private conversation. Please check your connection and try again.',
    );
  }
}
