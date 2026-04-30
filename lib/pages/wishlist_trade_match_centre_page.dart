import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/friend_trade_match_models.dart';
import '../models/wishlist_entry.dart';
import '../services/currency_settings.dart';
import '../services/friend_trade_match_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../utils/community_private_helpers.dart';
import '../widgets/community_meta_chip.dart';
import '../widgets/wishlist_match_empty_card.dart';
import '../widgets/wishlist_trade_friend_card.dart';
import 'card_details_page.dart';
import 'friend_trade_matches_page.dart';
import 'social_pages.dart';

class WishlistTradeMatchCentrePage extends StatefulWidget {
  const WishlistTradeMatchCentrePage({
    super.key,
    required this.currentProfile,
  });

  final AppUserProfile currentProfile;

  @override
  State<WishlistTradeMatchCentrePage> createState() => _WishlistTradeMatchCentrePageState();
}

class _WishlistTradeMatchCentrePageState extends State<WishlistTradeMatchCentrePage> {
  late Future<WishlistTradeMatchCentreSnapshot> _snapshotFuture;
  bool _showLikelySpareOnly = false;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<WishlistTradeMatchCentreSnapshot> _loadSnapshot() {
    return WishlistTradeMatchCentreService.load(currentProfile: widget.currentProfile);
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
  }

  Future<void> _openCard(WishlistEntry entry) async {
    try {
      final fullCard = await PokemonTcgService.fetchCardById(entry.cardId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(card: fullCard),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(card: entry.toSummaryCard()),
        ),
      );
    }
  }

  Future<void> _openFriendDetails(FriendTradeMatchOverview overview) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendTradeMatchesPage(
          currentProfile: widget.currentProfile,
          friendUid: overview.friend.uid,
          friendName: overview.friend.username,
        ),
      ),
    );
  }

  Future<void> _messageFriend(FriendTradeMatchOverview overview) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.currentProfile.uid;
    final conversationId = communityConversationIdForPost(
      postId: 'wishlist_trade_matches',
      userAId: currentUid,
      userBId: overview.friend.uid,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPrivateChatPage(
          conversationId: conversationId,
          currentProfile: widget.currentProfile,
          otherUserId: overview.friend.uid,
          otherUserName: overview.friend.username,
          relatedPostId: 'wishlist_trade_matches',
          relatedPostTitle: 'Wishlist trade matches',
        ),
      ),
    );
  }

  List<FriendTradeMatchOverview> _visibleOverviews(WishlistTradeMatchCentreSnapshot snapshot) {
    if (!_showLikelySpareOnly) return snapshot.overviews;
    return snapshot.overviews.where((overview) => overview.likelySpareMatches > 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Wishlist Match Centre'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: FutureBuilder<WishlistTradeMatchCentreSnapshot>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFF7DE77), size: 42),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load wishlist matches right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data ??
                const WishlistTradeMatchCentreSnapshot(
                  overviews: <FriendTradeMatchOverview>[],
                  friendsScanned: 0,
                  yourWishlistCount: 0,
                  yourOwnedCount: 0,
                );
            final visibleOverviews = _visibleOverviews(data);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: const Color(0xFF102754),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7DE77),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.auto_awesome_outlined, color: Colors.black),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smart wishlist matching',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Find friends who own cards you want, and cards you own that they want.',
                                      style: TextStyle(color: Color(0xFFC8D4F0), height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              CommunityMetaChip(
                                icon: Icons.group_outlined,
                                label: '${data.friendsScanned} friends checked',
                                color: const Color(0xFF355189),
                              ),
                              CommunityMetaChip(
                                icon: Icons.favorite_outline_rounded,
                                label: '${data.yourWishlistCount} wishlist',
                                color: const Color(0xFFB13B59),
                              ),
                              CommunityMetaChip(
                                icon: Icons.inventory_2_outlined,
                                label: '${data.yourOwnedCount} owned',
                                color: const Color(0xFF2C7A5B),
                              ),
                              CommunityMetaChip(
                                icon: Icons.handshake_outlined,
                                label: '${data.totalMatches} matches',
                                color: const Color(0xFF6B4EFF),
                              ),
                              if (data.estimatedSelectedValue > 0)
                                CommunityMetaChip(
                                  icon: Icons.payments_outlined,
                                  label: CurrencySettings.formatSelectedAmount(data.estimatedSelectedValue),
                                  color: const Color(0xFF875A16),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile.adaptive(
                            value: _showLikelySpareOnly,
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFFF7DE77),
                            title: const Text(
                              'Show likely spares only',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'Only show matches where the owner has more than one copy saved.',
                              style: TextStyle(color: Color(0xFFC8D4F0)),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _showLikelySpareOnly = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (data.friendsScanned == 0)
                    WishlistMatchEmptyCard(
                      icon: Icons.group_add_outlined,
                      title: 'Add friends to start matching',
                      message: 'Once you have friends, this page checks your wishlists and synced Pokédex collections for possible swaps.',
                    )
                  else if (data.totalMatches == 0)
                    WishlistMatchEmptyCard(
                      icon: Icons.favorite_border_rounded,
                      title: 'No matches yet',
                      message: 'Matches appear when your wishlist overlaps with a friend’s owned cards, or their wishlist overlaps with your collection.',
                    )
                  else if (visibleOverviews.isEmpty)
                    WishlistMatchEmptyCard(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No likely-spare matches',
                      message: 'Turn off the spare-only filter to see all wishlist matches.',
                    )
                  else
                    ...visibleOverviews.map(
                      (overview) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: WishlistTradeFriendCard(
                          overview: overview,
                          showLikelySpareOnly: _showLikelySpareOnly,
                          canMessage: widget.currentProfile.isAdult,
                          onTapEntry: _openCard,
                          onOpenDetails: () => _openFriendDetails(overview),
                          onMessage: () => _messageFriend(overview),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

