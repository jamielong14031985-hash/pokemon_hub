import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'private_chat_screen.dart';

class MessagesInboxScreen extends StatelessWidget {
  const MessagesInboxScreen({super.key});

  int _timestampMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return '';

    final date = value.toDate();
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

    final chatsRef = FirebaseFirestore.instance.collection('chats');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chatsRef
            .where('participants', arrayContains: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Could not load messages.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs.toList() ?? [];

          docs.sort((a, b) {
            final aTime = _timestampMillis(a.data()['updatedAt']);
            final bTime = _timestampMillis(b.data()['updatedAt']);
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text('No private messages yet.'),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final participants =
                  (data['participants'] as List<dynamic>? ?? [])
                      .map((item) => item.toString())
                      .toList();

              final otherUserId = participants.firstWhere(
                (id) => id != currentUser.uid,
                orElse: () => '',
              );

              if (otherUserId.isEmpty) {
                return const SizedBox.shrink();
              }

              final participantNames =
                  data['participantNames'] as Map<String, dynamic>? ?? {};
              final participantPhotoUrls =
                  data['participantPhotoUrls'] as Map<String, dynamic>? ?? {};

              final otherUserName = _safeString(
                participantNames[otherUserId],
                fallback: 'User',
              );

              final otherUserPhotoUrl =
                  _safeString(participantPhotoUrls[otherUserId]);

              final lastMessage = _safeString(
                data['lastMessage'],
                fallback: 'No messages yet',
              );

              final updatedAt = _formatTimestamp(data['updatedAt']);

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: otherUserPhotoUrl.isNotEmpty
                      ? NetworkImage(otherUserPhotoUrl)
                      : null,
                  child: otherUserPhotoUrl.isEmpty
                      ? Text(
                          otherUserName.isNotEmpty
                              ? otherUserName[0].toUpperCase()
                              : '?',
                        )
                      : null,
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
            },
          );
        },
      ),
    );
  }
}
