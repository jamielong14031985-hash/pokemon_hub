import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/community_blocked_user.dart';
import '../services/community_safety_service.dart';
import '../widgets/community_user_avatar.dart';

class CommunityBlockedUsersPage extends StatelessWidget {
  const CommunityBlockedUsersPage({
    super.key,
    required this.currentProfile,
  });

  final AppUserProfile currentProfile;

  Future<void> _unblock(BuildContext context, CommunityBlockedUser blockedUser) async {
    try {
      await CommunitySafetyService.unblockUser(
        ownerUid: currentProfile.uid,
        blockedUid: blockedUser.blockedUid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${blockedUser.blockedName} unblocked.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not unblock this member.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Blocked users'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<List<CommunityBlockedUser>>(
          stream: CommunitySafetyService.blockedUsersStream(currentProfile.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final blockedUsers = snapshot.data ?? const <CommunityBlockedUser>[];
            if (blockedUsers.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'You have not blocked anyone. Blocked users will be hidden from your community feed and private inbox.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: blockedUsers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final blockedUser = blockedUsers[index];
                return Card(
                  color: const Color(0xFF102754),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CommunityUserAvatar(
                          userId: blockedUser.blockedUid,
                          displayName: blockedUser.blockedName,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                blockedUser.blockedName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Blocked ${_formatCommunityBlockedRelativeTime(blockedUser.createdAt)}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _unblock(context, blockedUser),
                          child: const Text('Unblock'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _formatCommunityBlockedDate(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$day/$month/$year  $hour:$minute';
}

String _formatCommunityBlockedRelativeTime(DateTime dt) {
  final difference = DateTime.now().difference(dt);
  if (difference.inSeconds < 45) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return _formatCommunityBlockedDate(dt).split('  ').first;
}
