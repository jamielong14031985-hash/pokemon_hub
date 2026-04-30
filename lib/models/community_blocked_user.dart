import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityBlockedUser {
  const CommunityBlockedUser({
    required this.blockedUid,
    required this.blockedName,
    required this.blockedByUid,
    required this.blockedByName,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.source = 'community',
  });

  final String blockedUid;
  final String blockedName;
  final String blockedByUid;
  final String blockedByName;
  final int createdAtMs;
  final int updatedAtMs;
  final String source;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  factory CommunityBlockedUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    return CommunityBlockedUser(
      blockedUid: (json['blockedUid'] ?? doc.id).toString(),
      blockedName: (json['blockedName'] ?? 'Trainer').toString(),
      blockedByUid: (json['blockedByUid'] ?? '').toString(),
      blockedByName: (json['blockedByName'] ?? 'Trainer').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      source: (json['source'] ?? 'community').toString(),
    );
  }
}
