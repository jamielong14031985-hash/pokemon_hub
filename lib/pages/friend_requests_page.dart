import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/friend_models.dart';
import '../services/friend_service.dart';
import '../widgets/friend_request_card.dart';

class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({
    super.key,
    required this.currentProfile,
  });

  final AppUserProfile currentProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Friend requests'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Incoming',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<FriendRequest>>(
              stream: FriendService.incomingRequestsStream(currentProfile.uid),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? const <FriendRequest>[];
                if (requests.isEmpty) {
                  return _friendEmptyCard('No incoming friend requests right now.');
                }
                return Column(
                  children: requests
                      .map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FriendRequestCard(
                            request: request,
                            incoming: true,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'Sent',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<FriendRequest>>(
              stream: FriendService.outgoingRequestsStream(currentProfile.uid),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? const <FriendRequest>[];
                if (requests.isEmpty) {
                  return _friendEmptyCard('No pending sent requests.');
                }
                return Column(
                  children: requests
                      .map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FriendRequestCard(
                            request: request,
                            incoming: false,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget _friendEmptyCard(String text) {
  return Card(
    color: const Color(0xFF102754),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70),
      ),
    ),
  );
}
