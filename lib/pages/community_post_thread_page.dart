import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user_profile.dart';
import '../models/community_models.dart';
import '../services/community_image_services.dart';
import '../services/community_safety_service.dart';
import '../services/local_image_store.dart';
import '../services/user_profile_service.dart';
import '../utils/community_dialog_helpers.dart';
import '../utils/community_market_helpers.dart';
import '../widgets/community_image_widgets.dart';
import '../widgets/community_info_row.dart';
import '../widgets/community_meta_chip.dart';
import '../widgets/community_seller_trust_widgets.dart';
import '../widgets/community_user_avatar.dart';
import '../widgets/friend_action_button.dart';
import '../widgets/stored_image.dart';
import '../widgets/trade_safety_panel.dart';
import 'social_pages.dart';

class CommunityPostThreadPage extends StatefulWidget {
  const CommunityPostThreadPage({
    super.key,
    required this.post,
    required this.currentProfile,
  });

  final CommunityPost post;
  final AppUserProfile currentProfile;

  @override
  State<CommunityPostThreadPage> createState() =>
      _CommunityPostThreadPageState();
}

class _CommunityPostThreadPageState extends State<CommunityPostThreadPage> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Set<String>>? _blockedUsersSub;
  Set<String> _blockedUserIds = <String>{};
  bool _sending = false;
  bool _pendingScrollToLatestReply = false;
  bool _isAdmin = false;
  String? _replyImageBase64;

  DocumentReference<Map<String, dynamic>> get _postRef =>
      FirebaseFirestore.instance.collection('community_posts').doc(widget.post.id);

  CollectionReference<Map<String, dynamic>> get _repliesRef =>
      _postRef.collection('replies');

  String get _currentUid =>
      (FirebaseAuth.instance.currentUser?.uid ?? widget.currentProfile.uid).trim();

  @override
  void initState() {
    super.initState();

    final currentUid = _currentUid;
    if (currentUid.isEmpty) return;

    _loadAdminStatus();

    _blockedUsersSub = CommunitySafetyService.blockedUserIdsStream(currentUid).listen(
      (blockedUserIds) {
        if (!mounted) return;
        setState(() {
          _blockedUserIds = blockedUserIds;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _blockedUserIds = <String>{};
        });
      },
    );
  }

  @override
  void dispose() {
    _blockedUsersSub?.cancel();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminStatus() async {
    final currentUid = _currentUid;
    if (currentUid.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app_roles')
          .doc(currentUid)
          .get();

      final data = snapshot.data();
      final role = data?['role']?.toString().trim().toLowerCase() ?? '';
      final isAdminOrModerator = role == 'admin' || role == 'moderator';

      if (!mounted) return;
      setState(() {
        _isAdmin = isAdminOrModerator;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
      });
    }
  }

  Stream<CommunityPost> _postStream() async* {
    yield widget.post;

    try {
      await for (final snapshot in _postRef.snapshots()) {
        if (!snapshot.exists) {
          yield widget.post;
          continue;
        }

        try {
          yield CommunityPost.fromDoc(snapshot);
        } catch (_) {
          yield widget.post;
        }
      }
    } catch (_) {
      yield widget.post;
    }
  }

  Stream<List<CommunityReply>> _repliesStream() async* {
    try {
      await for (final snapshot in _repliesRef.orderBy('createdAtMs').snapshots()) {
        final replies = snapshot.docs
            .map(_safeReplyFromDoc)
            .whereType<CommunityReply>()
            .toList();

        yield replies;
      }
    } catch (_) {
      yield const <CommunityReply>[];
    }
  }

  CommunityReply? _safeReplyFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return CommunityReply.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  void _requestScrollToLatestReply() {
    _pendingScrollToLatestReply = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollRepliesToLatest();
    });
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _scrollRepliesToLatest();
    });
  }

  void _scrollRepliesToLatest() {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    _pendingScrollToLatestReply = false;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<String?> _currentProfileImageBase64ForCommunity() async {
    final sharedImage = widget.currentProfile.profileImageBase64?.trim() ?? '';
    if (sharedImage.isNotEmpty) {
      return sharedImage;
    }

    try {
      final localImagePath =
          await LocalProfileImageStore.loadForUser(widget.currentProfile.uid);
      if (localImagePath == null || localImagePath.trim().isEmpty) {
        return null;
      }

      final imageRef = await CommunityImageCodec.storeFileForFirestore(
        localImagePath,
        storageFolder: 'profile_images',
      );
      await UserProfileService.updateProfileImageBase64(
        uid: widget.currentProfile.uid,
        imageBase64: imageRef,
      );
      return imageRef;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickReplyImage() async {
    if (_sending) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF102754),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                title: const Text(
                  'Take photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library_outlined, color: Colors.white),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final encoded = await CommunityImageCodec.pickAndEncodeSingle(source);
      if (encoded == null || !mounted) return;
      setState(() {
        _replyImageBase64 = encoded;
      });
    } catch (_) {
      _showThreadMessage('Could not add photo right now.');
    }
  }

  Future<void> _addReply() async {
    final authorId = _currentUid;
    if (authorId.isEmpty) {
      _showThreadMessage('Please sign in to send replies.');
      return;
    }

    final message = _replyController.text.trim();
    final imageBase64 = _replyImageBase64?.trim();
    if ((message.isEmpty && (imageBase64 == null || imageBase64.isEmpty)) ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final replyDoc = _repliesRef.doc();
      final authorProfileImageBase64 =
          await _currentProfileImageBase64ForCommunity();

      await replyDoc.set(
        CommunityReply(
          id: replyDoc.id,
          authorId: authorId,
          authorName: widget.currentProfile.displayName,
          message: message,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          imageBase64: imageBase64,
          authorProfileImageBase64: authorProfileImageBase64,
        ).toJson(),
      );

      _replyController.clear();
      if (mounted) {
        setState(() {
          _replyImageBase64 = null;
        });
      }
      _requestScrollToLatestReply();
    } on FirebaseException catch (error) {
      _showThreadMessage(error.message ?? 'Could not send reply.');
    } catch (_) {
      _showThreadMessage('Could not send reply.');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _deletePost(CommunityPost livePost) async {
    final currentUid = _currentUid;
    final canDeletePost = currentUid.isNotEmpty &&
        (currentUid == livePost.authorId.trim() || _isAdmin);

    if (!canDeletePost) {
      _showThreadMessage('Only the post author or an admin can delete this post.');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102754),
        title: Text(
          _isAdmin && currentUid != livePost.authorId.trim()
              ? 'Admin delete post'
              : 'Delete post',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _isAdmin && currentUid != livePost.authorId.trim()
              ? 'This will permanently remove this post and all replies for everyone.'
              : 'This will permanently remove your post and all replies.',
          style: const TextStyle(color: Color(0xFFC8D4F0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB13B59),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final replies = await _repliesRef.get();
      final replyImageRefs = replies.docs
          .map(_safeReplyFromDoc)
          .whereType<CommunityReply>()
          .map((reply) => reply.imageBase64)
          .whereType<String>()
          .toList();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in replies.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_postRef);
      await batch.commit();

      for (final imageRef in <String>[
        ...livePost.imageBase64List,
        ...replyImageRefs,
      ]) {
        unawaited(FirebaseImageStorageService.deleteByDownloadUrl(imageRef));
      }

      if (!mounted) return;
      _showThreadMessage('Post deleted.');
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      _showThreadMessage(error.message ?? 'Could not delete post.');
    } catch (_) {
      _showThreadMessage('Could not delete post.');
    }
  }

  Future<void> _deleteReply(CommunityReply reply) async {
    final currentUid = _currentUid;
    if (currentUid.isEmpty) {
      _showThreadMessage('You need to be signed in to delete comments.');
      return;
    }

    try {
      if (currentUid == reply.authorId || _isAdmin) {
        await _repliesRef.doc(reply.id).delete();
        unawaited(FirebaseImageStorageService.deleteByDownloadUrl(reply.imageBase64));
      } else if (currentUid == widget.post.authorId) {
        await _postRef.set(
          {
            'hiddenReplyIds': FieldValue.arrayUnion([reply.id]),
          },
          SetOptions(merge: true),
        );
      } else {
        _showThreadMessage(
          'Only the comment author, post owner, or an admin can delete comments.',
        );
        return;
      }
      _showThreadMessage('Comment deleted.');
    } on FirebaseException catch (error) {
      _showThreadMessage(error.message ?? 'Could not delete comment.');
    } catch (_) {
      _showThreadMessage('Could not delete comment.');
    }
  }

  Future<void> _openReplyMemberSheet({
    required CommunityReply reply,
    required CommunityPost livePost,
  }) async {
    final currentUid = _currentUid;
    final replyAuthorId = reply.authorId.trim();
    final replyAuthorName =
        reply.authorName.trim().isEmpty ? 'Trainer' : reply.authorName.trim();
    final canDelete =
        currentUid == reply.authorId || currentUid == livePost.authorId || _isAdmin;
    final canAddFriend = replyAuthorId.isNotEmpty && replyAuthorId != currentUid;

    if (!canDelete && !canAddFriend) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = MediaQuery.of(context).size.height * 0.88;

              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        replyAuthorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose an action for this reply.',
                        style: TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      if (canAddFriend) ...[
                        const SizedBox(height: 16),
                        CommunitySellerTrustPanel(
                          sellerId: replyAuthorId,
                          sellerName: replyAuthorName,
                          compact: true,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _openMemberRatingSheet(
                              memberId: replyAuthorId,
                              memberName: replyAuthorName,
                              livePost: livePost,
                            );
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: const Color(0xFFF7DE77),
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.star_outline_rounded),
                          label: const Text(
                            'Rate this member',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FriendActionButton(
                          currentProfile: widget.currentProfile,
                          otherUserId: replyAuthorId,
                          otherUserName: replyAuthorName,
                          onOpenFriendProfile: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FriendProfilePage(
                                  currentProfile: widget.currentProfile,
                                  friendUid: replyAuthorId,
                                  friendName: replyAuthorName,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _reportReply(reply: reply, livePost: livePost);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3F5C96)),
                          ),
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text(
                            'Report reply',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _blockCommunityMember(
                              memberId: replyAuthorId,
                              memberName: replyAuthorName,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: const Color(0xFFFFCDD2),
                            side: const BorderSide(color: Color(0xFFB13B59)),
                          ),
                          icon: const Icon(Icons.block_outlined),
                          label: const Text(
                            'Block member',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                      if (canDelete) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _deleteReply(reply);
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: const Color(0xFFB13B59),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(
                            _isAdmin && currentUid != reply.authorId
                                ? 'Admin delete message'
                                : 'Delete message',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openSellerRatingSheet(CommunityPost livePost) async {
    final sellerId = livePost.authorId.trim();
    final currentUid = _currentUid;
    if (sellerId.isEmpty) {
      _showThreadMessage('This member cannot be rated right now.');
      return;
    }
    if (sellerId == currentUid) {
      _showThreadMessage('You cannot rate yourself.');
      return;
    }

    final saved = await showCommunityRatingSheet(
      context: context,
      currentProfile: widget.currentProfile,
      sellerId: sellerId,
      sellerName: livePost.authorName,
      sourcePostId: livePost.id,
      sourcePostTitle: livePost.title,
    );
    if (saved == true) {
      _showThreadMessage('Rating saved.');
    }
  }

  Future<void> _openMemberRatingSheet({
    required String memberId,
    required String memberName,
    required CommunityPost livePost,
  }) async {
    final trimmedMemberId = memberId.trim();
    final currentUid = _currentUid;
    if (trimmedMemberId.isEmpty) {
      _showThreadMessage('This member cannot be rated right now.');
      return;
    }
    if (trimmedMemberId == currentUid) {
      _showThreadMessage('You cannot rate yourself.');
      return;
    }

    final saved = await showCommunityRatingSheet(
      context: context,
      currentProfile: widget.currentProfile,
      sellerId: trimmedMemberId,
      sellerName: memberName,
      sourcePostId: livePost.id,
      sourcePostTitle: livePost.title,
    );
    if (saved == true) {
      _showThreadMessage('Rating saved.');
    }
  }

  Future<void> _reportPost(CommunityPost livePost) async {
    await showCommunityReportSheet(
      context: context,
      currentProfile: widget.currentProfile,
      reportedUid: livePost.authorId,
      reportedName: livePost.authorName,
      targetType: 'post',
      targetId: livePost.id,
      targetTitle: livePost.title,
    );
  }

  Future<void> _reportReply({
    required CommunityReply reply,
    required CommunityPost livePost,
  }) async {
    await showCommunityReportSheet(
      context: context,
      currentProfile: widget.currentProfile,
      reportedUid: reply.authorId,
      reportedName: reply.authorName,
      targetType: 'reply',
      targetId: reply.id,
      targetTitle: livePost.title,
    );
  }

  Future<void> _blockCommunityMember({
    required String memberId,
    required String memberName,
  }) async {
    final blocked = await confirmBlockCommunityUser(
      context: context,
      currentProfile: widget.currentProfile,
      blockedUid: memberId,
      blockedName: memberName,
      source: 'community_thread',
    );
    if (blocked && mounted) {
      setState(() {
        _blockedUserIds = <String>{..._blockedUserIds, memberId.trim()};
      });
    }
  }

  void _showThreadMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateMarketStatus(CommunityPost livePost, String status) async {
    if (!livePost.isMarketplace) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _postRef.set(
        <String, dynamic>{
          'marketStatus': normalizeCommunityMarketStatus(status),
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
      _showThreadMessage(
        'Listing marked as ${normalizeCommunityMarketStatus(status)}.',
      );
    } on FirebaseException catch (error) {
      _showThreadMessage(error.message ?? 'Could not update listing status.');
    } catch (_) {
      _showThreadMessage('Could not update listing status.');
    }
  }

  Future<void> _bumpListing() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _postRef.set(
        <String, dynamic>{
          'lastBumpedAtMs': now,
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
      _showThreadMessage('Listing bumped.');
    } on FirebaseException catch (error) {
      _showThreadMessage(error.message ?? 'Could not bump listing.');
    } catch (_) {
      _showThreadMessage('Could not bump listing.');
    }
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  $hour:$minute';
  }

  Widget _buildThreadHeaderCard({
    required CommunityPost livePost,
    required bool keyboardOpen,
  }) {
    final currentUid = _currentUid.isEmpty ? null : _currentUid;
    final canManageListing = currentUid != null &&
        currentUid == livePost.authorId &&
        livePost.isMarketplace;
    final canDeletePost = currentUid != null &&
        (currentUid == livePost.authorId.trim() || _isAdmin);
    final accentColor = communityPostAccentColor(livePost);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: keyboardOpen
            ? Card(
                key: const ValueKey('compact-thread-header'),
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          livePost.postType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (livePost.isMarketplace) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: communityMarketStatusColor(
                              livePost.normalizedMarketStatus,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            livePost.normalizedMarketStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              livePost.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              livePost.compactMarketplaceSummary ??
                                  'Replying to ${livePost.authorName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD8E3FB),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(livePost.createdAt).split('  ').first,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Card(
                key: const ValueKey('full-thread-header'),
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          CommunityMetaChip(
                            icon: livePost.isDiscussion
                                ? Icons.forum_outlined
                                : livePost.isForSale
                                    ? Icons.sell_outlined
                                    : livePost.isWanted
                                        ? Icons.search_rounded
                                        : Icons.swap_horiz_rounded,
                            label: livePost.isDiscussion
                                ? 'Discussion'
                                : livePost.postType,
                            color: accentColor,
                          ),
                          if (livePost.isMarketplace)
                            CommunityMetaChip(
                              icon: communityMarketStatusIcon(
                                livePost.normalizedMarketStatus,
                              ),
                              label: livePost.normalizedMarketStatus,
                              color: communityMarketStatusColor(
                                livePost.normalizedMarketStatus,
                              ),
                            ),
                          if (_isAdmin)
                            const CommunityMetaChip(
                              icon: Icons.admin_panel_settings_outlined,
                              label: 'Admin',
                              color: Color(0xFFB13B59),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              _formatDate(livePost.createdAt),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        livePost.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        livePost.description,
                        style: const TextStyle(
                          color: Color(0xFFD8E3FB),
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      if (livePost.hasImages) ...[
                        const SizedBox(height: 12),
                        CommunityImageStrip(
                          imageBase64List: livePost.imageBase64List,
                          height: 180,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CommunityUserAvatar(
                            userId: livePost.authorId,
                            displayName: livePost.authorName,
                            size: 38,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Posted by',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  livePost.authorName,
                                  style: const TextStyle(
                                    color: Color(0xFFD8E3FB),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (livePost.isMarketplace)
                        CommunitySellerTrustPanel(
                          sellerId: livePost.authorId,
                          sellerName: livePost.authorName,
                          onRate: livePost.authorId.trim() ==
                                  (FirebaseAuth.instance.currentUser?.uid ??
                                      widget.currentProfile.uid)
                              ? null
                              : () => _openSellerRatingSheet(livePost),
                        ),
                      if (livePost.isMarketplace) ...[
                        const SizedBox(height: 10),
                        CommunityInfoRow(
                          label: 'Status',
                          value: livePost.normalizedMarketStatus,
                        ),
                        if (livePost.isForSale)
                          CommunityInfoRow(
                            label: 'Asking price',
                            value: livePost.hasPrice
                                ? livePost.formattedPrice
                                : 'Not added',
                          ),
                        if (livePost.cardCondition.trim().isNotEmpty)
                          CommunityInfoRow(
                            label: 'Condition',
                            value: livePost.cardCondition.trim(),
                          ),
                        if (livePost.deliveryMethod.trim().isNotEmpty)
                          CommunityInfoRow(
                            label: 'Delivery',
                            value: livePost.deliveryMethod.trim(),
                          ),
                        if (livePost.locationText.trim().isNotEmpty)
                          CommunityInfoRow(
                            label: 'Location',
                            value: livePost.locationText.trim(),
                          ),
                        if (livePost.isSwap &&
                            livePost.wantedTradeFor.trim().isNotEmpty)
                          CommunityInfoRow(
                            label: 'Wanted in trade',
                            value: livePost.wantedTradeFor.trim(),
                          ),
                        if (livePost.isWanted &&
                            livePost.wantedTradeFor.trim().isNotEmpty)
                          CommunityInfoRow(
                            label: 'Looking for',
                            value: livePost.wantedTradeFor.trim(),
                          ),
                        const SizedBox(height: 10),
                        TradeSafetyPanel(post: livePost),
                      ],
                      if (livePost.hasImages)
                        CommunityInfoRow(
                          label: 'Photos',
                          value: communityImageCountLabel(livePost.imageCount),
                        ),
                      if (livePost.lastBumpedAt != null)
                        CommunityInfoRow(
                          label: 'Last bumped',
                          value: _formatDate(livePost.lastBumpedAt!),
                        ),
                      if (currentUid != null &&
                          livePost.authorId.trim().isNotEmpty &&
                          livePost.authorId != currentUid) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _reportPost(livePost),
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('Report post'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF3F5C96)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _blockCommunityMember(
                                memberId: livePost.authorId,
                                memberName: livePost.authorName,
                              ),
                              icon: const Icon(Icons.block_outlined),
                              label: const Text('Block member'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFFCDD2),
                                side: const BorderSide(color: Color(0xFFB13B59)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (canManageListing) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _updateMarketStatus(
                                livePost,
                                livePost.normalizedMarketStatus == 'Pending'
                                    ? 'Available'
                                    : 'Pending',
                              ),
                              icon: Icon(
                                livePost.normalizedMarketStatus == 'Pending'
                                    ? Icons.storefront_outlined
                                    : Icons.schedule_outlined,
                              ),
                              label: Text(
                                livePost.normalizedMarketStatus == 'Pending'
                                    ? 'Mark available'
                                    : 'Mark pending',
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _updateMarketStatus(
                                livePost,
                                livePost.isForSale ? 'Sold' : 'Traded',
                              ),
                              icon: Icon(
                                livePost.isForSale
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.swap_horiz_rounded,
                              ),
                              label: Text(
                                livePost.isForSale ? 'Mark sold' : 'Mark traded',
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _bumpListing,
                              icon: const Icon(Icons.north_rounded),
                              label: const Text('Bump'),
                            ),
                          ],
                        ),
                      ],
                      if (canDeletePost) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => _deletePost(livePost),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(
                            _isAdmin && currentUid != livePost.authorId.trim()
                                ? 'Admin delete post'
                                : 'Delete post',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFCDD2),
                            side: const BorderSide(color: Color(0xFFB13B59)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildReplyCard({
    required CommunityReply reply,
    required CommunityPost livePost,
    required String? currentUid,
  }) {
    final canDelete =
        reply.authorId == currentUid || livePost.authorId == currentUid || _isAdmin;
    final isMine = currentUid != null && reply.authorId == currentUid;
    final authorName = reply.authorName.trim().isEmpty
        ? 'Trainer'
        : reply.authorName.trim();
    final replyTime = _formatDate(reply.createdAt).split('  ').last;

    Widget optionsButton() {
      if (!canDelete) {
        return IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          onPressed: () => _openReplyMemberSheet(
            reply: reply,
            livePost: livePost,
          ),
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: Colors.white54,
            size: 18,
          ),
          tooltip: 'Reply options',
        );
      }

      return PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 18,
        iconColor: Colors.white60,
        color: const Color(0xFF264A8A),
        onSelected: (value) {
          if (value == 'delete') {
            _deleteReply(reply);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.redAccent),
                const SizedBox(width: 10),
                Text(
                  _isAdmin && currentUid != reply.authorId
                      ? 'Admin delete comment'
                      : 'Delete comment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final bubbleColor = isMine ? const Color(0xFF173A78) : const Color(0xFF102754);
    final borderColor = isMine
        ? const Color(0xFFF7DE77).withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            InkWell(
              onTap: () => _openReplyMemberSheet(
                reply: reply,
                livePost: livePost,
              ),
              borderRadius: BorderRadius.circular(999),
              child: CommunityUserAvatar(
                userId: reply.authorId,
                displayName: authorName,
                size: 30,
                initialImageBase64: reply.authorProfileImageBase64,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMine ? 18 : 6),
                    bottomRight: Radius.circular(isMine ? 6 : 18),
                  ),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _openReplyMemberSheet(
                                reply: reply,
                                livePost: livePost,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Text(
                                isMine ? 'You' : authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isMine
                                      ? const Color(0xFFF7DE77)
                                      : const Color(0xFFE4ECFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            replyTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          optionsButton(),
                        ],
                      ),
                      if (reply.message.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          reply.message.trim(),
                          style: const TextStyle(
                            color: Color(0xFFD8E3FB),
                            fontSize: 13,
                            height: 1.32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (reply.hasImage) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CommunityImageViewerPage(
                                  imageBase64List: [reply.imageBase64!],
                                  initialIndex: 0,
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: StoredImage(
                              imageRef: reply.imageBase64,
                              fit: BoxFit.cover,
                              height: 150,
                              width: double.infinity,
                              errorChild: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Image could not be displayed.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            CommunityUserAvatar(
              userId: reply.authorId,
              displayName: authorName,
              size: 30,
              initialImageBase64: reply.authorProfileImageBase64,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepliesEmptyCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF102754),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFF7DE77)),
            SizedBox(height: 8),
            Text(
              'No replies yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Start the conversation below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepliesLoadError() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Could not load replies right now.\nPlease check your connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildReplyComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF041B4A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyImageBase64 != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: StoredImage(
                        imageRef: _replyImageBase64,
                        height: 78,
                        width: 78,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => setState(() => _replyImageBase64 = null),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF16366E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3F5C96)),
                ),
                child: IconButton(
                  onPressed: _sending ? null : _pickReplyImage,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 21),
                  color: Colors.white,
                  tooltip: 'Add photo reply',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _replyController,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Write a reply...',
                    hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
                    filled: true,
                    fillColor: const Color(0xFF16366E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF3F5C96)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF3F5C96)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFF7DE77),
                        width: 1.4,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: _sending ? null : _addReply,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: const Color(0xFFF7DE77),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _currentUid.isEmpty ? null : _currentUid;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(_isAdmin ? 'Post replies • Admin' : 'Post replies'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: StreamBuilder<CommunityPost>(
          stream: _postStream(),
          initialData: widget.post,
          builder: (context, postSnapshot) {
            final livePost = postSnapshot.data ?? widget.post;
            final hiddenReplyIds = livePost.hiddenReplyIds.toSet();

            return Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<CommunityReply>>(
                    stream: _repliesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildRepliesLoadError();
                      }

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          snapshot.data == null) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final replies = (snapshot.data ?? const <CommunityReply>[])
                          .where((reply) => !hiddenReplyIds.contains(reply.id))
                          .where(
                            (reply) =>
                                reply.authorId == currentUid ||
                                !_blockedUserIds.contains(reply.authorId),
                          )
                          .toList();

                      if (_pendingScrollToLatestReply && replies.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollRepliesToLatest();
                        });
                      }

                      final itemCount = replies.isEmpty ? 2 : replies.length + 1;

                      return ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildThreadHeaderCard(
                              livePost: livePost,
                              keyboardOpen: keyboardOpen,
                            );
                          }

                          if (replies.isEmpty) {
                            return _buildRepliesEmptyCard();
                          }

                          final reply = replies[index - 1];
                          return _buildReplyCard(
                            reply: reply,
                            livePost: livePost,
                            currentUid: currentUid,
                          );
                        },
                      );
                    },
                  ),
                ),
                _buildReplyComposer(),
              ],
            );
          },
        ),
      ),
    );
  }
}
