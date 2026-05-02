import 'package:flutter/material.dart';

import '../widgets/glass_page_header.dart';

import '../models/app_user_profile.dart';
import '../models/friend_trade_match_models.dart';
import '../models/wishlist_entry.dart';
import '../pages/card_details_page.dart';
import '../services/friend_trade_match_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../widgets/community_meta_chip.dart';
import '../widgets/friend_trade_match_widgets.dart';

class FriendTradeMatchesPage extends StatefulWidget {
  const FriendTradeMatchesPage({
    super.key,
    required this.currentProfile,
    required this.friendUid,
    required this.friendName,
  });

  final AppUserProfile currentProfile;
  final String friendUid;
  final String friendName;

  @override
  State<FriendTradeMatchesPage> createState() => _FriendTradeMatchesPageState();
}

class _FriendTradeMatchesPageState extends State<FriendTradeMatchesPage> {
  late Future<FriendTradeMatchSnapshot> _matchesFuture;
  bool _showLikelySpareOnly = false;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _loadMatches();
  }

  Future<FriendTradeMatchSnapshot> _loadMatches() {
    return FriendTradeMatchService.loadMatches(
      currentProfile: widget.currentProfile,
      friendUid: widget.friendUid,
    );
  }

  Future<void> _refreshMatches() async {
    setState(() {
      _matchesFuture = _loadMatches();
    });
    await _matchesFuture;
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

  List<FriendTradeMatchEntry> _applyFilters(List<FriendTradeMatchEntry> items) {
    if (!_showLikelySpareOnly) return items;
    return items.where((item) => item.hasLikelySpare).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: GlassPageAppBar(
        title: 'Trade matches',
        subtitle: widget.friendName,
        icon: Icons.handshake_outlined,
      ),
      body: SafeArea(
        child: FutureBuilder<FriendTradeMatchSnapshot>(
          future: _matchesFuture,
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
                      const Text(
                        'Could not load trade matches right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _refreshMatches,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final matches = snapshot.data ??
                const FriendTradeMatchSnapshot(
                  friendHasForYou: <FriendTradeMatchEntry>[],
                  youHaveForFriend: <FriendTradeMatchEntry>[],
                  yourWishlistCount: 0,
                  friendWishlistCount: 0,
                  yourOwnedCount: 0,
                  friendOwnedCount: 0,
                );
            final friendHasForYou = _applyFilters(matches.friendHasForYou);
            final youHaveForFriend = _applyFilters(matches.youHaveForFriend);
            final hasAnyVisibleMatches = friendHasForYou.isNotEmpty || youHaveForFriend.isNotEmpty;

            return RefreshIndicator(
              onRefresh: _refreshMatches,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Card(
                    color: const Color(0xFF102754),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D3D7A),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.handshake_outlined, color: Color(0xFFF7DE77)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smart friend matching',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Based on wishlists and synced Pokédex cards for you and ${widget.friendName}.',
                                      style: const TextStyle(
                                        color: Color(0xFFC8D4F0),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              CommunityMetaChip(
                                icon: Icons.favorite_outline_rounded,
                                label: 'Your wishlist ${matches.yourWishlistCount}',
                                color: const Color(0xFF355189),
                              ),
                              CommunityMetaChip(
                                icon: Icons.favorite_outline_rounded,
                                label: '${widget.friendName} wishlist ${matches.friendWishlistCount}',
                                color: const Color(0xFF355189),
                              ),
                              CommunityMetaChip(
                                icon: Icons.collections_bookmark_outlined,
                                label: 'Your cards ${matches.yourOwnedCount}',
                                color: const Color(0xFF2C7A5B),
                              ),
                              CommunityMetaChip(
                                icon: Icons.collections_bookmark_outlined,
                                label: '${widget.friendName} cards ${matches.friendOwnedCount}',
                                color: const Color(0xFF2C7A5B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          FilterChip(
                            selected: _showLikelySpareOnly,
                            label: const Text('Likely spare copies only'),
                            onSelected: (value) {
                              setState(() {
                                _showLikelySpareOnly = value;
                              });
                            },
                            avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                            selectedColor: const Color(0xFFF7DE77),
                            checkmarkColor: Colors.black,
                            labelStyle: TextStyle(
                              color: _showLikelySpareOnly ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            backgroundColor: const Color(0xFF16366E),
                            side: const BorderSide(color: Color(0xFF3F5C96)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FriendTradeMatchSection(
                    title: 'They have cards from your wishlist',
                    subtitle: 'Cards you want that ${widget.friendName} already owns.',
                    emptyMessage: _showLikelySpareOnly
                        ? '${widget.friendName} does not currently have any visible likely-spare matches for your wishlist.'
                        : '${widget.friendName} does not currently own any cards from your wishlist.',
                    items: friendHasForYou,
                    onTapEntry: _openCard,
                  ),
                  const SizedBox(height: 16),
                  FriendTradeMatchSection(
                    title: 'You have cards from their wishlist',
                    subtitle: 'Cards ${widget.friendName} wants that already exist in your synced Pokédex.',
                    emptyMessage: _showLikelySpareOnly
                        ? 'You do not currently have any visible likely-spare matches for ${widget.friendName}. '
                            'Try turning the spare-only filter off.'
                        : "You do not currently own any cards from ${widget.friendName}'s wishlist.",
                    items: youHaveForFriend,
                    onTapEntry: _openCard,
                  ),
                  if (!hasAnyVisibleMatches) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFF102754),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Trade matches will improve as both of you add cards to your wishlist and keep your Pokédex synced.',
                          style: TextStyle(
                            color: Color(0xFFD8E3FB),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
