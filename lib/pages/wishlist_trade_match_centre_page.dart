import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/friend_trade_match_models.dart';
import '../models/wishlist_entry.dart';
import '../services/currency_settings.dart';
import '../services/friend_trade_match_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../utils/community_private_helpers.dart';
import '../widgets/glass_page_header.dart';
import '../widgets/wishlist_trade_friend_card.dart';
import 'card_details_page.dart';
import 'friend_trade_matches_page.dart';
import 'my_trades_page.dart';
import 'trade_offer_compose_page.dart';
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
  bool _showLikelySpareOnly = true;

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

  Future<void> _makeDeal(FriendTradeMatchOverview overview, {String? cardId, bool ownerIsFriend = false}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TradeOfferComposePage(
        currentProfile: widget.currentProfile,
        friendUid: overview.friend.uid,
        friendName: overview.friend.username,
        initialOfferedCardId: ownerIsFriend ? null : cardId,
        initialRequestedCardId: ownerIsFriend ? cardId : null,
      ),
    ));
  }

  Future<void> _openMyTrades() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MyTradesPage(currentProfile: widget.currentProfile),
    ));
  }

  List<FriendTradeMatchOverview> _visibleOverviews(WishlistTradeMatchCentreSnapshot snapshot) {
    if (!_showLikelySpareOnly) return snapshot.overviews;
    return snapshot.overviews.where((overview) => overview.likelySpareMatches > 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: const GlassPageAppBar(
        title: 'Trade matches',
        subtitle: 'Duplicates and wishlists',
        icon: Icons.handshake_outlined,
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
                  _TradeOverviewCard(
                    data: data,
                    duplicatesOnly: _showLikelySpareOnly,
                    onDuplicatesOnlyChanged: (value) {
                      setState(() {
                        _showLikelySpareOnly = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FilledButton.icon(
                      onPressed: _openMyTrades,
                      icon: const Icon(Icons.handshake_outlined),
                      label: const Text('My Trades — view offers and replies'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7DE77),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  if (data.friendsScanned == 0)
                    const _TradeEmptyState(
                      icon: Icons.group_add_outlined,
                      title: 'Add friends to start matching',
                      message: 'Once you have friends, this page checks your wishlists and synced Pokédex collections for possible swaps.',
                    )
                  else if (data.totalMatches == 0)
                    const _TradeEmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'No matches yet',
                      message: 'Matches appear when your wishlist overlaps with a friend’s owned cards, or their wishlist overlaps with your collection.',
                    )
                  else if (visibleOverviews.isEmpty)
                    const _TradeEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No duplicate matches yet',
                      message: 'Turn off the duplicate filter to see collection matches that are not confirmed spares.',
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
                          onDeal: (item) => _makeDeal(overview, cardId: item.entry.cardId, ownerIsFriend: item.ownerIsFriend),
                          onMakeDeal: () => _makeDeal(overview),
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

class _TradeOverviewCard extends StatelessWidget {
  const _TradeOverviewCard({
    required this.data,
    required this.duplicatesOnly,
    required this.onDuplicatesOnlyChanged,
  });

  final WishlistTradeMatchCentreSnapshot data;
  final bool duplicatesOnly;
  final ValueChanged<bool> onDuplicatesOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValue = duplicatesOnly
        ? data.estimatedSpareValue
        : data.estimatedSelectedValue;

    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const Row(
              children: [
                _HeaderIcon(),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duplicate matching',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your spare cards matched with friends’ wishlists.',
                        style: TextStyle(
                          color: Color(0xFFBFCBE5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TradeStat(width: width, value: '${data.friendsScanned}', label: 'Friends', icon: Icons.people_outline),
                    _TradeStat(width: width, value: '${data.yourWishlistCount}', label: 'Wishlist', icon: Icons.favorite_border_rounded),
                    _TradeStat(width: width, value: '${data.yourOwnedCount}', label: 'Owned', icon: Icons.inventory_2_outlined),
                    _TradeStat(width: width, value: '${data.totalMatches}', label: 'Matches', icon: Icons.handshake_outlined),
                    _TradeStat(width: width, value: '${data.spareCopies}', label: 'Spares', icon: Icons.content_copy_rounded),
                    if (selectedValue > 0)
                      _TradeStat(
                        width: width,
                        value: CurrencySettings.formatSelectedAmount(selectedValue),
                        label: 'Trade value',
                        icon: Icons.payments_outlined,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B2250),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF294879)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, color: Color(0xFFF7DE77), size: 21),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tradeable duplicates only',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'One of each variant stays in your collection.',
                          style: TextStyle(color: Color(0xFFBFCBE5), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: duplicatesOnly,
                    activeThumbColor: const Color(0xFFF7DE77),
                    onChanged: onDuplicatesOnlyChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.auto_awesome_outlined, color: Color(0xFFF7DE77), size: 22),
    );
  }
}

class _TradeStat extends StatelessWidget {
  const _TradeStat({
    required this.width,
    required this.value,
    required this.label,
    required this.icon,
  });

  final double width;
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF173568),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF7DE77), size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFBFCBE5), fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeEmptyState extends StatelessWidget {
  const _TradeEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF254474)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF173568),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFF7DE77), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: Color(0xFFBFCBE5), fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

