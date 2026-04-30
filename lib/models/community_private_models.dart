import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPrivateConversation {
  const CommunityPrivateConversation({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.relatedPostId,
    required this.relatedPostTitle,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.lastMessage,
    required this.lastSenderId,
  });

  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String relatedPostId;
  final String relatedPostTitle;
  final int createdAtMs;
  final int updatedAtMs;
  final String lastMessage;
  final String lastSenderId;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

  String otherUserId(String currentUid) {
    for (final participant in participants) {
      if (participant != currentUid) {
        return participant;
      }
    }
    return '';
  }

  String otherUserName(String currentUid) {
    for (final participant in participants) {
      if (participant != currentUid) {
        final name = participantNames[participant]?.trim() ?? '';
        if (name.isNotEmpty) return name;
      }
    }
    return 'Trainer';
  }

  factory CommunityPrivateConversation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = doc.data() ?? <String, dynamic>{};
    final rawParticipants = (json['participants'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList();
    final rawNames = json['participantNames'] as Map<String, dynamic>? ?? const {};
    final participantNames = <String, String>{
      for (final entry in rawNames.entries) entry.key: entry.value.toString(),
    };

    return CommunityPrivateConversation(
      id: doc.id,
      participants: rawParticipants,
      participantNames: participantNames,
      relatedPostId: (json['relatedPostId'] ?? '').toString(),
      relatedPostTitle: (json['relatedPostTitle'] ?? 'Community post').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      lastMessage: (json['lastMessage'] ?? '').toString(),
      lastSenderId: (json['lastSenderId'] ?? '').toString(),
    );
  }
}

class CommunityPrivateMessage {
  const CommunityPrivateMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.message,
    required this.createdAtMs,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String message;
  final int createdAtMs;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  Map<String, dynamic> toJson() => {
        'authorId': authorId,
        'authorName': authorName,
        'message': message,
        'createdAtMs': createdAtMs,
      };

  factory CommunityPrivateMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = doc.data() ?? <String, dynamic>{};
    return CommunityPrivateMessage(
      id: doc.id,
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (json['authorName'] ?? 'Trainer').toString(),
      message: (json['message'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
