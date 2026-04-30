import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/friend_models.dart';
import '../services/friend_service.dart';
import '../utils/community_private_helpers.dart';
import 'friend_pokedex_pages.dart';
import 'friend_trade_matches_page.dart';
import 'social_pages.dart';
import 'wishlist_page.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({
    super.key,
    required this.currentProfile,
  });

  final AppUserProfile currentProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<List<FriendSummary>>(
          stream: FriendService.friendsStream(currentProfile.uid),
          builder: (context, snapshot) {
            final friends = snapshot.data ?? const <FriendSummary>[];
            if (friends.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No friends yet. Add them from community posts or private chats.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: friends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final friend = friends[index];
                return Card(
                  color: const Color(0xFF102754),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Friends since ${formatCommunityDate(friend.since).split('  ').first}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FriendProfilePage(
                                    currentProfile: currentProfile,
                                    friendUid: friend.uid,
                                    friendName: friend.username,
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF7DE77),
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.person_search_outlined),
                            label: const Text('View full profile'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FriendPokedexSetsPage(
                                        currentProfile: currentProfile,
                                        friendUid: friend.uid,
                                        friendName: friend.username,
                                      ),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C7A5B),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.collections_bookmark_outlined),
                                label: const Text('Pokédex'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WishlistPage(
                                        ownerUid: friend.uid,
                                        ownerName: friend.username,
                                        showAddHint: false,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.favorite_outline_rounded),
                                label: const Text('Wishlist'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FriendTradeMatchesPage(
                                    currentProfile: currentProfile,
                                    friendUid: friend.uid,
                                    friendName: friend.username,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.handshake_outlined),
                            label: const Text('Trade matches'),
                          ),
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
