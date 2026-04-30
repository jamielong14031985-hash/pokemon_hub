import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/community_private_models.dart';
import '../services/community_safety_service.dart';
import '../utils/community_private_helpers.dart';
import 'social_pages.dart';

class CommunityPrivateInboxPage extends StatelessWidget {
  const CommunityPrivateInboxPage({
    super.key,
    required this.currentProfile,
  });

  final AppUserProfile currentProfile;

  Future<void> _deleteConversationForCurrentUser(
    BuildContext context,
    CommunityPrivateConversation conversation,
  ) async {
    final currentUid = (FirebaseAuth.instance.currentUser?.uid ?? currentProfile.uid).trim();
    if (currentUid.isEmpty) return;

    final otherName = conversation.otherUserName(currentUid);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102754),
          title: const Text(
            'Delete private chat?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'This will delete your private chat with $otherName from your inbox. It will not delete it for the other person.',
            style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE85D5D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await deleteCommunityPrivateConversationForUser(
        ownerUid: currentUid,
        conversationId: conversation.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private chat deleted from your inbox')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete private chat')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = (FirebaseAuth.instance.currentUser?.uid ?? currentProfile.uid).trim();

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Private inbox'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<Set<String>>(
          stream: CommunitySafetyService.blockedUserIdsStream(currentUid),
          builder: (context, blockedSnapshot) {
            final blockedUserIds = blockedSnapshot.data ?? const <String>{};

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUid)
                  .collection('community_private_conversations')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    blockedSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load private messages.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }

                final conversations = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(CommunityPrivateConversation.fromDoc)
                    .where((conversation) {
                      final otherUid = conversation.otherUserId(currentUid);
                      return otherUid.isEmpty || !blockedUserIds.contains(otherUid);
                    })
                    .toList()
                  ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

                if (conversations.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No private conversations yet. Open a post and tap Message. Blocked members are hidden from this inbox.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final otherUserId = conversation.otherUserId(currentUid);
                    final otherName = conversation.otherUserName(currentUid);
                    return Card(
                      color: const Color(0xFF102754),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CommunityPrivateChatPage(
                                conversationId: conversation.id,
                                currentProfile: currentProfile,
                                otherUserId: otherUserId,
                                otherUserName: otherName,
                                relatedPostId: conversation.relatedPostId,
                                relatedPostTitle: conversation.relatedPostTitle,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      otherName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatCommunityRelativeTime(conversation.updatedAt),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: 'Delete private chat',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _deleteConversationForCurrentUser(context, conversation),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFE85D5D),
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                conversation.relatedPostTitle,
                                style: const TextStyle(
                                  color: Color(0xFFF7DE77),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                conversation.lastMessage.trim().isEmpty
                                    ? 'Tap to start the conversation.'
                                    : conversation.lastMessage,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD8E3FB),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
