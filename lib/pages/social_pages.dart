import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/glass_page_header.dart';

import '../models/app_user_profile.dart';
import '../models/community_private_models.dart';
import '../models/profile_stats.dart';
import '../models/tcg_card.dart';
import '../models/wishlist_entry.dart';
import '../services/community_safety_service.dart';
import '../services/currency_settings.dart';
import '../services/pokemon_tcg_service.dart';
import '../services/user_profile_service.dart';
import '../utils/community_dialog_helpers.dart';
import '../utils/community_private_helpers.dart';
import '../utils/profile_stats_helpers.dart';
import '../widgets/achievement_badges.dart';
import '../widgets/friend_action_button.dart';
import '../widgets/friend_pokedex_preview_card.dart';
import '../widgets/friend_profile_header_card.dart';
import '../widgets/friend_wishlist_preview_card.dart';
import '../widgets/profile_collection_widgets.dart';
import '../widgets/profile_stat_card.dart';
import '../widgets/trade_safety_panel.dart';
import '../widgets/trade_safety_private_reminder.dart';
import 'card_details_page.dart';
import 'friend_pokedex_pages.dart';
import 'friend_trade_matches_page.dart';
import 'wishlist_page.dart';

class CommunityPrivateChatPage extends StatefulWidget {
  const CommunityPrivateChatPage({
    super.key,
    required this.conversationId,
    required this.currentProfile,
    required this.otherUserId,
    required this.otherUserName,
    required this.relatedPostId,
    required this.relatedPostTitle,
  });

  final String conversationId;
  final AppUserProfile currentProfile;
  final String otherUserId;
  final String otherUserName;
  final String relatedPostId;
  final String relatedPostTitle;

  @override
  State<CommunityPrivateChatPage> createState() =>
      _CommunityPrivateChatPageState();
}

class _CommunityPrivateChatPageState extends State<CommunityPrivateChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? widget.currentProfile.uid;

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      userCommunityPrivateConversationRef(
        ownerUid: _currentUid,
        conversationId: widget.conversationId,
      ).collection('messages');

  @override
  void initState() {
    super.initState();
    _ensureConversationExists();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  CommunityPrivateMessage? _safeMessageFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return CommunityPrivateMessage.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureConversationExists() async {
    final currentUid =
        (FirebaseAuth.instance.currentUser?.uid ?? widget.currentProfile.uid)
            .trim();
    final otherUserId = widget.otherUserId.trim();
    final conversationId = widget.conversationId.trim();

    if (currentUid.isEmpty || otherUserId.isEmpty || conversationId.isEmpty) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await syncCommunityPrivateConversation(
        conversationId: conversationId,
        currentUid: currentUid,
        currentUserName: widget.currentProfile.displayName,
        otherUserId: otherUserId,
        otherUserName: widget.otherUserName,
        relatedPostId: widget.relatedPostId,
        relatedPostTitle: widget.relatedPostTitle,
        createdAtMs: now,
        updatedAtMs: now,
      );
    } catch (_) {
      // The chat screen can still load existing local/user-scoped messages.
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final currentUid =
          (FirebaseAuth.instance.currentUser?.uid ?? widget.currentProfile.uid)
              .trim();
      final otherUserId = widget.otherUserId.trim();
      final conversationId = widget.conversationId.trim();

      if (currentUid.isEmpty) {
        throw StateError('Please sign in before sending a message.');
      }
      if (otherUserId.isEmpty || conversationId.isEmpty) {
        throw StateError('This private chat cannot be opened right now.');
      }
      if (currentUid == otherUserId) {
        throw StateError('You cannot message yourself.');
      }

      var isBlocked = false;
      try {
        isBlocked = await CommunitySafetyService.isBlocked(
          ownerUid: currentUid,
          blockedUid: otherUserId,
        );
      } catch (_) {
        isBlocked = false;
      }

      if (isBlocked) {
        _showChatMessage(
          'You have blocked this member. Unblock them before sending a message.',
        );
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final doc = _messagesRef.doc();
      final privateMessage = CommunityPrivateMessage(
        id: doc.id,
        authorId: currentUid,
        authorName: widget.currentProfile.displayName,
        message: message,
        createdAtMs: now,
      );

      await syncCommunityPrivateMessage(
        conversationId: conversationId,
        currentUid: currentUid,
        currentUserName: widget.currentProfile.displayName,
        otherUserId: otherUserId,
        otherUserName: widget.otherUserName,
        relatedPostId: widget.relatedPostId,
        relatedPostTitle: widget.relatedPostTitle,
        message: privateMessage,
      );

      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      });
    } on FirebaseException catch (error) {
      _showChatMessage(error.message ?? 'Could not send private message');
    } on StateError catch (error) {
      _showChatMessage(error.message);
    } catch (_) {
      _showChatMessage('Could not send private message');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _showChatMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reportConversation() async {
    await showCommunityReportSheet(
      context: context,
      currentProfile: widget.currentProfile,
      reportedUid: widget.otherUserId,
      reportedName: widget.otherUserName,
      targetType: 'private_message',
      targetId: widget.conversationId,
      targetTitle: widget.relatedPostTitle,
    );
  }

  Future<void> _blockOtherUser() async {
    final navigator = Navigator.of(context);

    final blocked = await confirmBlockCommunityUser(
      context: context,
      currentProfile: widget.currentProfile,
      blockedUid: widget.otherUserId,
      blockedName: widget.otherUserName,
      source: 'private_message',
    );

    if (blocked && mounted) {
      navigator.pop();
    }
  }

  Future<void> _deleteThisConversation() async {
    final currentUid = _currentUid.trim();
    if (currentUid.isEmpty) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

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
            'This will delete your private chat with ${widget.otherUserName} from your inbox. It will not delete it for the other person.',
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
        conversationId: widget.conversationId,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Private chat deleted from your inbox')),
      );
    } on FirebaseException catch (error) {
      _showChatMessage(error.message ?? 'Could not delete private chat');
    } catch (_) {
      _showChatMessage('Could not delete private chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _currentUid.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(
          widget.otherUserName.trim().isEmpty
              ? 'Private chat'
              : widget.otherUserName.trim(),
        ),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Report private chat',
            onPressed: _reportConversation,
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: 'Block member',
            onPressed: _blockOtherUser,
            icon: const Icon(Icons.block_outlined),
          ),
          IconButton(
            tooltip: 'Delete private chat',
            onPressed: _deleteThisConversation,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Card(
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFF7DE77).withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: Color(0xFFF7DE77),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Private chat about',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.relatedPostTitle.trim().isEmpty
                                      ? 'Community message'
                                      : widget.relatedPostTitle.trim(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FriendActionButton(
                          currentProfile: widget.currentProfile,
                          otherUserId: widget.otherUserId,
                          otherUserName: widget.otherUserName,
                          onOpenFriendProfile: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FriendProfilePage(
                                  currentProfile: widget.currentProfile,
                                  friendUid: widget.otherUserId,
                                  friendName: widget.otherUserName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TradeSafetyPrivateReminder(
                onTap: () => showTradeSafetyGuide(context),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesRef.orderBy('createdAtMs').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Could not load messages. Please check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  final messages = (snapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      .map(_safeMessageFromDoc)
                      .whereType<CommunityPrivateMessage>()
                      .toList();

                  if (messages.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No private messages yet. Say hello below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMine = message.authorId == currentUid;
                      return Align(
                        alignment:
                            isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? const Color(0xFF204D97)
                                  : const Color(0xFF102754),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMine ? 18 : 8),
                                bottomRight: Radius.circular(isMine ? 8 : 18),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isMine ? 'You' : message.authorName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatCommunityRelativeTime(
                                        message.createdAt,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  message.message,
                                  style: const TextStyle(
                                    color: Color(0xFFD8E3FB),
                                    fontSize: 14,
                                    height: 1.4,
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
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Write a private message...',
                        hintStyle: TextStyle(color: Color(0xFFAFC0E6)),
                        filled: true,
                        fillColor: Color(0xFF16366E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: Color(0xFF3F5C96)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: Color(0xFF3F5C96)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(
                            color: Color(0xFFF7DE77),
                            width: 1.5,
                          ),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF7DE77),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
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

class FriendProfilePage extends StatefulWidget {
  const FriendProfilePage({
    super.key,
    required this.currentProfile,
    required this.friendUid,
    required this.friendName,
  });

  final AppUserProfile currentProfile;
  final String friendUid;
  final String friendName;

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  late Future<AppUserProfile?> _friendProfileFuture;
  late Future<ProfileStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadFriendData();
  }

  void _loadFriendData() {
    _friendProfileFuture = UserProfileService.fetchProfile(widget.friendUid);
    _statsFuture = loadProfileStatsForOwner(widget.friendUid);
  }

  Future<void> _refresh() async {
    setState(_loadFriendData);

    try {
      await Future.wait<dynamic>([_friendProfileFuture, _statsFuture]);
    } catch (_) {
      // The FutureBuilders below display the individual error cards.
    }
  }

  Future<void> _openWishlist(AppUserProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishlistPage(
          ownerUid: profile.uid,
          ownerName: profile.displayName,
          showAddHint: false,
        ),
      ),
    );
  }

  Future<void> _openPokedex(AppUserProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendPokedexSetsPage(
          currentProfile: widget.currentProfile,
          friendUid: profile.uid,
          friendName: profile.displayName,
        ),
      ),
    );
  }

  Future<void> _openTradeMatches(AppUserProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendTradeMatchesPage(
          currentProfile: widget.currentProfile,
          friendUid: profile.uid,
          friendName: profile.displayName,
        ),
      ),
    );
  }

  Future<void> _openCardDetails(TcgCard card) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardDetailsPage(card: card)),
    );
  }

  Future<void> _messageFriend(AppUserProfile profile) async {
    if (!widget.currentProfile.isAdult) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Community messages are only available to adult accounts.'),
        ),
      );
      return;
    }

    final currentUid = widget.currentProfile.uid.trim();
    final friendUid = profile.uid.trim();
    if (currentUid.isEmpty || friendUid.isEmpty || currentUid == friendUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This member cannot be messaged right now.')),
      );
      return;
    }

    var isBlocked = false;
    try {
      isBlocked = await CommunitySafetyService.isBlocked(
        ownerUid: currentUid,
        blockedUid: friendUid,
      );
    } catch (_) {
      isBlocked = false;
    }

    if (!mounted) return;

    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have blocked this member. Unblock them before sending a message.'),
        ),
      );
      return;
    }

    final conversationId = communityConversationIdForPost(
      postId: 'friend_profile',
      userAId: currentUid,
      userBId: friendUid,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPrivateChatPage(
          conversationId: conversationId,
          currentProfile: widget.currentProfile,
          otherUserId: profile.uid,
          otherUserName: profile.displayName,
          relatedPostId: 'friend_profile',
          relatedPostTitle: '${profile.displayName} profile',
        ),
      ),
    );
  }

  Future<void> _openWishlistCard(WishlistEntry entry) async {
    try {
      final card = await PokemonTcgService.fetchCardById(entry.cardId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CardDetailsPage(card: card)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this card right now.')),
      );
    }
  }

  AppUserProfile _fallbackProfile() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return AppUserProfile(
      uid: widget.friendUid,
      email: '',
      username:
          widget.friendName.trim().isEmpty ? 'Trainer' : widget.friendName.trim(),
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName =
        widget.friendName.trim().isEmpty ? 'Friend' : widget.friendName.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: GlassPageAppBar(
        title: '$fallbackName profile',
        subtitle: 'Friend profile',
        icon: Icons.person_search_outlined,
      ),
      body: SafeArea(
        child: FutureBuilder<AppUserProfile?>(
          future: _friendProfileFuture,
          builder: (context, profileSnapshot) {
            final friendProfile = profileSnapshot.data ?? _fallbackProfile();
            final imageProvider =
                profileImageProviderFromRef(friendProfile.profileImageBase64);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FriendProfileHeaderCard(
                    profile: friendProfile,
                    imageProvider: imageProvider,
                    onOpenWishlist: () => _openWishlist(friendProfile),
                    onOpenPokedex: () => _openPokedex(friendProfile),
                    onOpenTradeMatches: () => _openTradeMatches(friendProfile),
                    onMessage: () => _messageFriend(friendProfile),
                  ),
                  if (profileSnapshot.hasError)
                    Card(
                      color: const Color(0xFF102754),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Could not load the latest profile details. Showing a basic profile instead.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  FutureBuilder<ProfileStats>(
                    future: _statsFuture,
                    builder: (context, statsSnapshot) {
                      if (statsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (statsSnapshot.hasError) {
                        return Card(
                          color: const Color(0xFF102754),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'Could not load this friend’s showcase right now.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      }

                      final stats = statsSnapshot.data ?? emptyProfileStats();

                      return Column(
                        children: [
                          ProfileShowcaseCard(
                            profileName: friendProfile.displayName,
                            imageProvider: imageProvider,
                            stats: stats,
                            onOpenCard: _openCardDetails,
                          ),
                          const SizedBox(height: 12),
                          FriendWishlistPreviewCard(
                            profile: friendProfile,
                            onOpenWishlist: () => _openWishlist(friendProfile),
                            onTapEntry: _openWishlistCard,
                          ),
                          const SizedBox(height: 12),
                          FriendPokedexPreviewCard(
                            profile: friendProfile,
                            stats: stats,
                            onOpenPokedex: () => _openPokedex(friendProfile),
                          ),
                          const SizedBox(height: 12),
                          AchievementBadges(
                            stats: stats,
                            visibilityToggleEnabled: false,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ProfileStatCard(
                                  title: 'Total Cards',
                                  value: '${stats.totalCards}',
                                  icon: Icons.style_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ProfileStatCard(
                                  title: 'Total Value',
                                  value: CurrencySettings.formatSelectedAmount(
                                    stats.totalEstimatedPrice,
                                  ),
                                  icon: Icons.payment_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          MostExpensiveCardWidget(
                            card: stats.mostExpensiveCard,
                            copies: stats.mostExpensiveCardCopies,
                            onOpenCard: _openCardDetails,
                          ),
                        ],
                      );
                    },
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

