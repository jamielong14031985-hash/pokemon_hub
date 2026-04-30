import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_private_models.dart';

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
  final ids = <String>[userAId, userBId]..sort();
  final safePostId = postId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return '${safePostId}_${ids.join('_')}';
}


DocumentReference<Map<String, dynamic>> _communityPrivateConversationRef(String conversationId) =>
    FirebaseFirestore.instance.collection('community_private_conversations').doc(conversationId);

DocumentReference<Map<String, dynamic>> userCommunityPrivateConversationRef({
  required String ownerUid,
  required String conversationId,
}) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUid)
        .collection('community_private_conversations')
        .doc(conversationId);

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
}) {
  return <String, dynamic>{
    'participants': <String>[currentUid, otherUserId],
    'participantNames': <String, String>{
      currentUid: currentUserName,
      otherUserId: otherUserName,
    },
    'relatedPostId': relatedPostId,
    'relatedPostTitle': relatedPostTitle,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
    'lastMessage': lastMessage,
    'lastSenderId': lastSenderId,
  };
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
  if (conversationId.trim().isEmpty ||
      currentUid.trim().isEmpty ||
      otherUserId.trim().isEmpty ||
      currentUid == otherUserId) {
    return;
  }

  final data = _communityPrivateConversationData(
    currentUid: currentUid,
    currentUserName: currentUserName,
    otherUserId: otherUserId,
    otherUserName: otherUserName,
    relatedPostId: relatedPostId,
    relatedPostTitle: relatedPostTitle,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs,
    lastMessage: lastMessage,
    lastSenderId: lastSenderId,
  );

  final batch = FirebaseFirestore.instance.batch();
  batch.set(_communityPrivateConversationRef(conversationId), data, SetOptions(merge: true));
  batch.set(
    userCommunityPrivateConversationRef(ownerUid: currentUid, conversationId: conversationId),
    data,
    SetOptions(merge: true),
  );
  batch.set(
    userCommunityPrivateConversationRef(ownerUid: otherUserId, conversationId: conversationId),
    data,
    SetOptions(merge: true),
  );
  await batch.commit();
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
  if (conversationId.trim().isEmpty ||
      currentUid.trim().isEmpty ||
      otherUserId.trim().isEmpty ||
      currentUid == otherUserId) {
    return;
  }

  final conversationData = _communityPrivateConversationData(
    currentUid: currentUid,
    currentUserName: currentUserName,
    otherUserId: otherUserId,
    otherUserName: otherUserName,
    relatedPostId: relatedPostId,
    relatedPostTitle: relatedPostTitle,
    createdAtMs: message.createdAtMs,
    updatedAtMs: message.createdAtMs,
    lastMessage: message.message,
    lastSenderId: message.authorId,
  );

  final messageData = message.toJson();
  final sharedConversationRef = _communityPrivateConversationRef(conversationId);
  final currentConversationRef = userCommunityPrivateConversationRef(
    ownerUid: currentUid,
    conversationId: conversationId,
  );
  final otherConversationRef = userCommunityPrivateConversationRef(
    ownerUid: otherUserId,
    conversationId: conversationId,
  );

  final batch = FirebaseFirestore.instance.batch();
  batch.set(sharedConversationRef, conversationData, SetOptions(merge: true));
  batch.set(currentConversationRef, conversationData, SetOptions(merge: true));
  batch.set(otherConversationRef, conversationData, SetOptions(merge: true));
  batch.set(
    sharedConversationRef.collection('messages').doc(message.id),
    messageData,
    SetOptions(merge: true),
  );
  batch.set(
    currentConversationRef.collection('messages').doc(message.id),
    messageData,
    SetOptions(merge: true),
  );
  batch.set(
    otherConversationRef.collection('messages').doc(message.id),
    messageData,
    SetOptions(merge: true),
  );
  await batch.commit();
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

  while (true) {
    final messagesSnapshot = await conversationRef.collection('messages').limit(400).get();
    if (messagesSnapshot.docs.isEmpty) break;

    final batch = FirebaseFirestore.instance.batch();
    for (final messageDoc in messagesSnapshot.docs) {
      batch.delete(messageDoc.reference);
    }
    await batch.commit();
  }

  await conversationRef.delete();
}
