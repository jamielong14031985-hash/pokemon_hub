import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendActionStatus { none, pendingOutgoing, pendingIncoming, friends }

class FriendActionState {
  const FriendActionState({
    required this.status,
    this.request,
  });

  final FriendActionStatus status;
  final FriendRequest? request;
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    required this.toName,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String fromName;
  final String toName;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

  bool get isPending => status == 'pending';

  factory FriendRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    return FriendRequest(
      id: doc.id,
      fromUid: (json['fromUid'] ?? '').toString(),
      toUid: (json['toUid'] ?? '').toString(),
      fromName: (json['fromName'] ?? 'Trainer').toString(),
      toName: (json['toName'] ?? 'Trainer').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class FriendSummary {
  const FriendSummary({
    required this.uid,
    required this.username,
    required this.sinceMs,
  });

  final String uid;
  final String username;
  final int sinceMs;

  DateTime get since => DateTime.fromMillisecondsSinceEpoch(sinceMs);

  factory FriendSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    return FriendSummary(
      uid: (json['uid'] ?? doc.id).toString(),
      username: (json['username'] ?? 'Trainer').toString(),
      sinceMs: (json['sinceMs'] as num?)?.toInt() ?? 0,
    );
  }
}
