import 'package:flutter/material.dart';

import '../models/friend_models.dart';
import '../services/friend_service.dart';

String _formatCommunityRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 45) return 'Just now';
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }

  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year.toString();
  return '$day/$month/$year';
}

class FriendRequestCard extends StatefulWidget {
  const FriendRequestCard({
    super.key,
    required this.request,
    required this.incoming,
  });

  final FriendRequest request;
  final bool incoming;

  @override
  State<FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends State<FriendRequestCard> {
  bool _working = false;

  Future<void> _accept() async {
    setState(() {
      _working = true;
    });
    try {
      await FriendService.acceptRequest(widget.request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are now friends with ${widget.request.fromName}.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept the request.')),
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

  Future<void> _decline() async {
    setState(() {
      _working = true;
    });
    try {
      await FriendService.declineRequest(widget.request);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the request.')),
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
    final title = widget.incoming ? widget.request.fromName : widget.request.toName;
    final subtitle = widget.incoming
        ? "Wants to see each other's Pokédex."
        : 'Waiting for them to accept your request.';

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCommunityRelativeTime(widget.request.createdAt),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (widget.incoming) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _working ? null : _decline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _working ? null : _accept,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7DE77),
                        foregroundColor: Colors.black,
                      ),
                      child: _working
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
