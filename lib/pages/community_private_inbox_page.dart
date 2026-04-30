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

  Stream<List<CommunityPrivateConversation>> _conversationStream(
    String currentUid,
  ) async* {
    final safeUid = currentUid.trim();
    if (safeUid.isEmpty) {
      yield const <CommunityPrivateConversation>[];
      return;
    }

    try {
      await for (final snapshot in FirebaseFirestore.instance
          .collection('users')
          .doc(safeUid)
          .collection('community_private_conversations')
          .snapshots()) {
        final conversations = snapshot.docs
            .map(_safeConversationFromDoc)
            .whereType<CommunityPrivateConversation>()
            .toList()
          ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

        yield conversations;
      }
    } catch (_) {
      yield const <CommunityPrivateConversation>[];
    }
  }

  CommunityPrivateConversation? _safeConversationFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return CommunityPrivateConversation.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  String _safeText(String value, {required String fallback}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteConversationForCurrentUser(
    BuildContext context,
    CommunityPrivateConversation conversation,
  ) async {
    final currentUid =
        (FirebaseAuth.instance.currentUser?.uid ?? currentProfile.uid).trim();

    if (currentUid.isEmpty) return;

    final otherName = _safeText(
      conversation.otherUserName(currentUid),
      fallback: 'this trainer',
    );

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

    if (confirmed != true || !context.mounted) return;

    try {
      await deleteCommunityPrivateConversationForUser(
        ownerUid: currentUid,
        conversationId: conversation.id,
      );

      if (!context.mounted) return;
      _showSnackBar(context, 'Private chat deleted from your inbox');
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Could not delete private chat. Please check your connection and try again.',
      );
    }
  }

  Widget _buildEmptyState() {
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

  Widget _buildLoadErrorState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Could not load private messages right now.\nPlease check your connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildConversationCard({
    required BuildContext context,
    required String currentUid,
    required CommunityPrivateConversation conversation,
  }) {
    final otherUserId = conversation.otherUserId(currentUid).trim();
    final otherName = _safeText(
      conversation.otherUserName(currentUid),
      fallback: 'Trainer',
    );
    final relatedPostTitle = _safeText(
      conversation.relatedPostTitle,
      fallback: 'Community post',
    );
    final lastMessage = _safeText(
      conversation.lastMessage,
      fallback: 'Tap to start the conversation.',
    );

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (conversation.id.trim().isEmpty || otherUserId.isEmpty) {
            _showSnackBar(context, 'Could not open this private chat.');
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CommunityPrivateChatPage(
                conversationId: conversation.id,
                currentProfile: currentProfile,
                otherUserId: otherUserId,
                otherUserName: otherName,
                relatedPostId: conversation.relatedPostId,
                relatedPostTitle: relatedPostTitle,
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
                    onPressed: () => _deleteConversationForCurrentUser(
                      context,
                      conversation,
                    ),
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
                relatedPostTitle,
                style: const TextStyle(
                  color: Color(0xFFF7DE77),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lastMessage,
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
  }

  @override
  Widget build(BuildContext context) {
    final currentUid =
        (FirebaseAuth.instance.currentUser?.uid ?? currentProfile.uid).trim();

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Private inbox'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: currentUid.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Please sign in to view your private inbox.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            : StreamBuilder<Set<String>>(
                stream: CommunitySafetyService.blockedUserIdsStream(currentUid),
                builder: (context, blockedSnapshot) {
                  final blockedUserIds =
                      blockedSnapshot.data ?? const <String>{};

                  return StreamBuilder<List<CommunityPrivateConversation>>(
                    stream: _conversationStream(currentUid),
                    builder: (context, snapshot) {
                      if (snapshot.hasError || blockedSnapshot.hasError) {
                        return _buildLoadErrorState();
                      }

                      if (snapshot.connectionState == ConnectionState.waiting ||
                          blockedSnapshot.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final conversations =
                          snapshot.data ?? const <CommunityPrivateConversation>[];

                      final visibleConversations = conversations
                          .where((conversation) {
                            final otherUid =
                                conversation.otherUserId(currentUid).trim();
                            return otherUid.isEmpty ||
                                !blockedUserIds.contains(otherUid);
                          })
                          .toList()
                        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

                      if (visibleConversations.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleConversations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          try {
                            return _buildConversationCard(
                              context: context,
                              currentUid: currentUid,
                              conversation: visibleConversations[index],
                            );
                          } catch (_) {
                            return const SizedBox.shrink();
                          }
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
