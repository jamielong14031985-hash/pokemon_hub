import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/community_models.dart';
import '../models/community_post_menu_action.dart';
import '../pages/social_pages.dart';
import '../utils/community_market_helpers.dart';
import '../utils/community_private_helpers.dart';
import 'community_image_widgets.dart';
import 'community_new_badge.dart';
import 'community_seller_trust_widgets.dart';
import 'community_user_avatar.dart';
import 'friend_action_button.dart';
import 'marketplace_listing_snapshot.dart';
import 'trade_safety_panel.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.currentProfile,
    required this.canEdit,
    required this.canMessage,
    required this.isNew,
    required this.onEdit,
    required this.onDelete,
    required this.onMessage,
    required this.onOpen,
    this.onAuthorTap,
    this.onReport,
    this.onBlock,
    this.onSetMarketStatus,
    this.onBump,
    this.compact = false,
    this.canUserFeature = false,
    this.canAdminFeature = false,
    this.onToggleUserFeatured,
    this.onToggleAdminFeatured,
  });

  final CommunityPost post;
  final AppUserProfile currentProfile;
  final bool canEdit;
  final bool canMessage;
  final bool isNew;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMessage;
  final VoidCallback onOpen;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final ValueChanged<String>? onSetMarketStatus;
  final VoidCallback? onBump;
  final bool compact;
  final bool canUserFeature;
  final bool canAdminFeature;
  final VoidCallback? onToggleUserFeatured;
  final VoidCallback? onToggleAdminFeatured;

  Widget _buildFeaturedPanel() {
    final showUserChip = post.isUserFeatured;
    final showAdminChip = post.isAdminFeatured;
    final showControls = canUserFeature || canAdminFeature;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7DE77).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF7DE77).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (showUserChip)
                _FeaturedBadge(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Pro featured',
                ),
              if (showAdminChip)
                _FeaturedBadge(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Admin featured',
                ),
              if (!showUserChip && !showAdminChip)
                const _FeaturedBadge(
                  icon: Icons.star_border_rounded,
                  label: 'Feature this post',
                ),
            ],
          ),
          if (showControls) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canUserFeature)
                  OutlinedButton.icon(
                    onPressed: onToggleUserFeatured,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFF2B3),
                      side: const BorderSide(color: Color(0xFFF7DE77)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      post.isUserFeatured
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 18,
                    ),
                    label: Text(
                      post.isUserFeatured
                          ? 'Remove my featured post'
                          : 'Make my featured post',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                if (canAdminFeature)
                  OutlinedButton.icon(
                    onPressed: onToggleAdminFeatured,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      post.isAdminFeatured
                          ? Icons.admin_panel_settings
                          : Icons.admin_panel_settings_outlined,
                      size: 18,
                    ),
                    label: Text(
                      post.isAdminFeatured
                          ? 'Remove admin feature'
                          : 'Admin feature',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDiscussion = post.isDiscussion;
    final accentColor = communityPostAccentColor(post);
    final canManageListing = canEdit && post.isMarketplace && onSetMarketStatus != null;
    final showFeaturedPanel = post.isFeatured || canUserFeature || canAdminFeature;

    void handleMenuAction(CommunityPostMenuAction value) {
      switch (value) {
        case CommunityPostMenuAction.edit:
          onEdit();
          break;
        case CommunityPostMenuAction.available:
          onSetMarketStatus?.call('Available');
          break;
        case CommunityPostMenuAction.pending:
          onSetMarketStatus?.call('Pending');
          break;
        case CommunityPostMenuAction.sold:
          onSetMarketStatus?.call('Sold');
          break;
        case CommunityPostMenuAction.traded:
          onSetMarketStatus?.call('Traded');
          break;
        case CommunityPostMenuAction.found:
          onSetMarketStatus?.call('Found');
          break;
        case CommunityPostMenuAction.bump:
          onBump?.call();
          break;
        case CommunityPostMenuAction.report:
          onReport?.call();
          break;
        case CommunityPostMenuAction.block:
          onBlock?.call();
          break;
        case CommunityPostMenuAction.delete:
          onDelete();
          break;
      }
    }

    List<PopupMenuEntry<CommunityPostMenuAction>> buildMenuItems() {
      final items = <PopupMenuEntry<CommunityPostMenuAction>>[];

      if (canEdit) {
        items.add(
          const PopupMenuItem<CommunityPostMenuAction>(
            value: CommunityPostMenuAction.edit,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: Color(0xFFF7DE77)),
                SizedBox(width: 10),
                Text(
                  'Edit post',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );

        if (canManageListing) {
          items.addAll([
            const PopupMenuDivider(),
            const PopupMenuItem<CommunityPostMenuAction>(
              value: CommunityPostMenuAction.available,
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined, color: Colors.lightBlueAccent),
                  SizedBox(width: 10),
                  Text(
                    'Mark available',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const PopupMenuItem<CommunityPostMenuAction>(
              value: CommunityPostMenuAction.pending,
              child: Row(
                children: [
                  Icon(Icons.schedule_outlined, color: Color(0xFFF0A83A)),
                  SizedBox(width: 10),
                  Text(
                    'Mark pending',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            PopupMenuItem<CommunityPostMenuAction>(
              value: post.isForSale
                  ? CommunityPostMenuAction.sold
                  : post.isWanted
                      ? CommunityPostMenuAction.found
                      : CommunityPostMenuAction.traded,
              child: Row(
                children: [
                  Icon(
                    post.isForSale
                        ? Icons.check_circle_outline_rounded
                        : post.isWanted
                            ? Icons.task_alt_rounded
                            : Icons.swap_horiz_rounded,
                    color: post.isForSale ? Colors.redAccent : const Color(0xFF54D39A),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    post.isForSale
                        ? 'Mark sold'
                        : post.isWanted
                            ? 'Mark found'
                            : 'Mark traded',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const PopupMenuItem<CommunityPostMenuAction>(
              value: CommunityPostMenuAction.bump,
              child: Row(
                children: [
                  Icon(Icons.north_rounded, color: Color(0xFFF7DE77)),
                  SizedBox(width: 10),
                  Text(
                    'Bump listing',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ]);
        }

        items.addAll(const [
          PopupMenuDivider(),
          PopupMenuItem<CommunityPostMenuAction>(
            value: CommunityPostMenuAction.delete,
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.redAccent),
                SizedBox(width: 10),
                Text(
                  'Delete post',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ]);
      } else {
        if (onReport != null) {
          items.add(
            const PopupMenuItem<CommunityPostMenuAction>(
              value: CommunityPostMenuAction.report,
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: Color(0xFFF7DE77)),
                  SizedBox(width: 10),
                  Text(
                    'Report post',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (onBlock != null) {
          items.add(
            const PopupMenuItem<CommunityPostMenuAction>(
              value: CommunityPostMenuAction.block,
              child: Row(
                children: [
                  Icon(Icons.block_outlined, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text(
                    'Block member',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      return items;
    }

    if (compact) {
      Widget compactChip({
        required String label,
        required Color backgroundColor,
        required Color foregroundColor,
        IconData? icon,
      }) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foregroundColor.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 11, color: foregroundColor),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: post.isFeatured
                ? const Color(0xFFF7DE77).withValues(alpha: 0.44)
                : isNew
                    ? const Color(0xFFF7DE77).withValues(alpha: 0.34)
                    : Colors.white.withValues(alpha: 0.07),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          color: const Color(0xFF102754),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor,
                        const Color(0xFF143163),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                if (post.hasImages)
                  ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: CommunityImageStrip(
                      imageBase64List: post.imageBase64List,
                      height: 74,
                    ),
                  )
                else
                  Container(
                    height: 44,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.18),
                          const Color(0xFF143163).withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      isDiscussion
                          ? Icons.forum_outlined
                          : Icons.storefront_outlined,
                      color: const Color(0xFFF7DE77),
                      size: 24,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CommunityUserAvatar(
                              userId: post.authorId,
                              displayName: post.authorName,
                              size: 26,
                              onTap: onAuthorTap,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    formatCommunityRelativeTime(post.createdAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canEdit || onReport != null || onBlock != null)
                              SizedBox(
                                width: 26,
                                height: 26,
                                child: PopupMenuButton<CommunityPostMenuAction>(
                                  padding: EdgeInsets.zero,
                                  iconSize: 17,
                                  iconColor: Colors.white70,
                                  color: const Color(0xFF143163),
                                  onSelected: handleMenuAction,
                                  itemBuilder: (_) => buildMenuItems(),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            compactChip(
                              label: post.isMarketplace ? post.postType : 'Thread',
                              backgroundColor: accentColor.withValues(alpha: 0.16),
                              foregroundColor: const Color(0xFFF7DE77),
                              icon: post.isMarketplace
                                  ? Icons.sell_outlined
                                  : Icons.forum_outlined,
                            ),
                            if (post.isMarketplace)
                              compactChip(
                                label: post.normalizedMarketStatus,
                                backgroundColor: const Color(0xFF16366E),
                                foregroundColor: const Color(0xFFC8D4F0),
                              ),
                            if (post.isFeatured)
                              compactChip(
                                label: 'Featured',
                                backgroundColor: const Color(0xFFF7DE77),
                                foregroundColor: Colors.black,
                                icon: Icons.star_rounded,
                              ),
                            if (isNew)
                              const CommunityNewBadge(compact: true),
                          ],
                        ),
                        if (post.isMarketplace) ...[
                          const SizedBox(height: 5),
                          CommunitySellerRatingBadge(
                            sellerId: post.authorId,
                            compact: true,
                          ),
                        ],
                        if (post.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              post.description.trim(),
                              maxLines: post.hasImages ? 3 : 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD8E3FB),
                                fontSize: 10,
                                height: 1.22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 30,
                                child: OutlinedButton.icon(
                                  onPressed: onOpen,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.14),
                                    ),
                                    backgroundColor: const Color(0xFF16366E),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.forum_outlined, size: 14),
                                  label: Text(
                                    isDiscussion ? 'Open' : 'Thread',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (canMessage) ...[
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 34,
                                height: 30,
                                child: FilledButton(
                                  onPressed: onMessage,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFF7DE77),
                                    foregroundColor: Colors.black,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Icon(Icons.mail_outline_rounded, size: 15),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: post.isFeatured
              ? const Color(0xFFF7DE77).withValues(alpha: 0.44)
              : isNew
                  ? const Color(0xFFF7DE77).withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Card(
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor,
                      const Color(0xFF143163),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommunityUserAvatar(
                          userId: post.authorId,
                          displayName: post.authorName,
                          size: 36,
                          onTap: onAuthorTap,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      post.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                  if (isNew) ...[
                                    const SizedBox(width: 6),
                                    const CommunityNewBadge(compact: true),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${post.authorName} • ${formatCommunityRelativeTime(post.createdAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (post.isMarketplace) ...[
                                const SizedBox(height: 5),
                                CommunitySellerRatingBadge(
                                  sellerId: post.authorId,
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (canEdit || onReport != null || onBlock != null)
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: PopupMenuButton<CommunityPostMenuAction>(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              iconColor: Colors.white70,
                              color: const Color(0xFF143163),
                              onSelected: handleMenuAction,
                              itemBuilder: (_) => buildMenuItems(),
                            ),
                          ),
                      ],
                    ),
                    if (showFeaturedPanel) ...[
                      const SizedBox(height: 10),
                      _buildFeaturedPanel(),
                    ],
                    if (post.hasImages) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CommunityImageStrip(
                          imageBase64List: post.imageBase64List,
                          height: 112,
                        ),
                      ),
                    ],
                    if (post.isMarketplace) ...[
                      const SizedBox(height: 9),
                      MarketplaceListingSnapshot(post: post),
                    ],
                    if (post.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        post.description.trim(),
                        maxLines: post.isMarketplace ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD8E3FB),
                          fontSize: 13,
                          height: 1.32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (post.isMarketplace) ...[
                      const SizedBox(height: 8),
                      TradeSafetyPanel(
                        post: post,
                        compact: true,
                        showGuideButton: false,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onOpen,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                              backgroundColor: const Color(0xFF16366E),
                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.forum_outlined, size: 17),
                            label: Text(
                              isDiscussion ? 'Open' : 'Thread',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        if (canMessage) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onMessage,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF7DE77),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.mail_outline_rounded, size: 17),
                              label: const Text(
                                'Message',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (canMessage) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FriendActionButton(
                          currentProfile: currentProfile,
                          otherUserId: post.authorId,
                          otherUserName: post.authorName,
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                          onOpenFriendProfile: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FriendProfilePage(
                                  currentProfile: currentProfile,
                                  friendUid: post.authorId,
                                  friendName: post.authorName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7DE77),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF7DE77).withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
