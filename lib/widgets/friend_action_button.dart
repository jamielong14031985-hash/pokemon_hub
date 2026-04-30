import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/friend_models.dart';
import '../services/friend_service.dart';

class FriendActionButton extends StatefulWidget {
  const FriendActionButton({
    super.key,
    required this.currentProfile,
    required this.otherUserId,
    required this.otherUserName,
    required this.onOpenFriendProfile,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
  });

  final AppUserProfile currentProfile;
  final String otherUserId;
  final String otherUserName;
  final Future<void> Function() onOpenFriendProfile;
  final EdgeInsetsGeometry padding;

  @override
  State<FriendActionButton> createState() => _FriendActionButtonState();
}

class _FriendActionButtonState extends State<FriendActionButton> {
  bool _working = false;

  Future<void> _handleAction(FriendActionState state) async {
    if (_working) return;
    setState(() {
      _working = true;
    });

    try {
      if (state.status == FriendActionStatus.none) {
        await FriendService.sendRequest(
          currentProfile: widget.currentProfile,
          otherUid: widget.otherUserId,
          otherName: widget.otherUserName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Friend request sent to ${widget.otherUserName}.')),
          );
        }
      } else if (state.status == FriendActionStatus.pendingIncoming && state.request != null) {
        await FriendService.acceptRequest(state.request!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You are now friends with ${widget.otherUserName}.')),
          );
        }
      } else if (state.status == FriendActionStatus.pendingOutgoing) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Friend request already sent.')),
          );
        }
      } else if (state.status == FriendActionStatus.friends) {
        await widget.onOpenFriendProfile();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update friendship right now.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.otherUserId.trim().isEmpty || widget.otherUserId == widget.currentProfile.uid) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<FriendActionState>(
      stream: FriendService.watchActionState(
        currentUid: widget.currentProfile.uid,
        otherUid: widget.otherUserId,
      ),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const FriendActionState(status: FriendActionStatus.none);

        IconData icon;
        String label;
        Color? backgroundColor;
        Color? foregroundColor;

        switch (state.status) {
          case FriendActionStatus.pendingIncoming:
            icon = Icons.handshake_outlined;
            label = 'Accept Friend';
            backgroundColor = const Color(0xFFF7DE77);
            foregroundColor = Colors.black;
            break;
          case FriendActionStatus.pendingOutgoing:
            icon = Icons.schedule_outlined;
            label = 'Request Sent';
            backgroundColor = const Color(0xFF1B3B73);
            foregroundColor = Colors.white;
            break;
          case FriendActionStatus.friends:
            icon = Icons.person_search_outlined;
            label = 'View Profile';
            backgroundColor = const Color(0xFF2C7A5B);
            foregroundColor = Colors.white;
            break;
          case FriendActionStatus.none:
            icon = Icons.person_add_alt_1_outlined;
            label = 'Add Friend';
            backgroundColor = const Color(0xFF16366E);
            foregroundColor = Colors.white;
            break;
        }

        return FilledButton.icon(
          onPressed: _working
              ? null
              : () => _handleAction(state),
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: widget.padding,
          ),
          icon: _working
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      },
    );
  }
}
