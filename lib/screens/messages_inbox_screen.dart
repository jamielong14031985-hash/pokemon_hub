import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'private_chat_screen.dart';

class MessagesInboxScreen extends StatelessWidget {
  const MessagesInboxScreen({super.key});

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _chatsForUserStream(
    String uid,
  ) async* {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      yield const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      return;
    }

    try {
      await for (final snapshot in FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: safeUid)
          .snapshots()) {
        final docs = snapshot.docs.toList()
          ..sort((a, b) {
            final aTime = _timestampMillisFromData(a.data());
            final bTime = _timestampMillisFromData(b.data());
            return bTime.compareTo(aTime);
          });

        yield docs;
      }
    } catch (_) {
      yield const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
  }

  int _timestampMillisFromData(Map<String, dynamic> data) {
    final updatedAtMs = _readInt(data['updatedAtMs']);
    if (updatedAtMs > 0) return updatedAtMs;
    return _timestampMillis(data['updatedAt']);
  }

  int _timestampMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }

  int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }

  String _formatTimestampFromData(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) {
      return _formatDateTime(updatedAt.toDate());
    }

    final updatedAtMs = _readInt(data['updatedAtMs']);
    if (updatedAtMs > 0) {
      return _formatDateTime(
        DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      );
    }

    return '';
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();

    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (isToday) {
      return '$hour:$minute';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), mapValue),
      );
    }

    return const <String, dynamic>{};
  }

  List<String> _safeParticipants(dynamic value) {
    if (value is! List) return const <String>[];

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _firstAvatarLetter(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  Widget _buildAvatar({
    required String name,
    required String photoUrl,
  }) {
    final safePhotoUrl = photoUrl.trim();

    if (safePhotoUrl.isEmpty) {
      return CircleAvatar(
        child: Text(_firstAvatarLetter(name)),
      );
    }

    return CircleAvatar(
      backgroundImage: NetworkImage(safePhotoUrl),
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildErrorOrEmptyInbox() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'No private messages yet.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(
          child: Text('Please log in to view your messages.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _chatsForUserStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Could not load messages right now.\nPlease check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs =
              snapshot.data ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (docs.isEmpty) {
            return _buildErrorOrEmptyInbox();
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              try {
                final data = docs[index].data();

                final participants = _safeParticipants(data['participants']);
                final otherUserId = participants.firstWhere(
                  (id) => id != currentUser.uid,
                  orElse: () => '',
                );

                if (otherUserId.isEmpty) {
                  return const SizedBox.shrink();
                }

                final participantNames = _safeMap(data['participantNames']);
                final participantPhotoUrls = _safeMap(data['participantPhotoUrls']);

                final otherUserName = _safeString(
                  participantNames[otherUserId],
                  fallback: 'User',
                );

                final otherUserPhotoUrl = _safeString(
                  participantPhotoUrls[otherUserId],
                );

                final lastMessage = _safeString(
                  data['lastMessage'],
                  fallback: 'No messages yet',
                );

                final updatedAt = _formatTimestampFromData(data);

                return ListTile(
                  leading: _buildAvatar(
                    name: otherUserName,
                    photoUrl: otherUserPhotoUrl,
                  ),
                  title: Text(
                    otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: updatedAt.isEmpty
                      ? null
                      : Text(
                          updatedAt,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrivateChatScreen(
                          otherUserId: otherUserId,
                          otherUserName: otherUserName,
                          otherUserPhotoUrl: otherUserPhotoUrl,
                        ),
                      ),
                    );
                  },
                );
              } catch (_) {
                return const SizedBox.shrink();
              }
            },
          );
        },
      ),
    );
  }
}
