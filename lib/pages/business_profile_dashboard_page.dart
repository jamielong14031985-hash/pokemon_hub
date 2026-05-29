import 'package:flutter/material.dart';

import '../models/business_analytics.dart';
import '../models/business_enquiry.dart';
import '../models/business_pro_request.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import '../widgets/business_rating_summary.dart';
import 'business_enquiries_page.dart';
import 'business_events_page.dart';
import 'business_offers_page.dart';
import 'business_products_page.dart';
import 'business_pro_request_page.dart';
import 'business_profile_editor_page.dart';
import 'business_reviews_page.dart';

class BusinessProDashboardPage extends StatelessWidget {
  const BusinessProDashboardPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);

  static String _formatDate(DateTime? value) {
    if (value == null) return 'Not set';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }

  static String _premiumExpiryText(BusinessProfile profile) {
    if (!profile.premiumActive) return 'Not active';
    if (profile.premiumExpiresAt == null) return 'No expiry date';
    return _formatDate(profile.premiumExpiresAt?.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final premiumActive = profile.premiumIsActive;
    final isPhysicalShop = profile.hasPhysicalShop;
    final hasLinkedShop = profile.hasLinkedShop;
    final hasBannerImage = profile.hasFeaturedBannerImage;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Business Pro Dashboard'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _HeroCard(profile: profile),
          const SizedBox(height: 16),
          _SectionHeader(
            icon: Icons.workspace_premium_outlined,
            title: 'Pro status',
            subtitle: premiumActive
                ? 'Business Pro is active for this business.'
                : 'Business Pro is not active yet.',
          ),
          const SizedBox(height: 10),
          _StatusGrid(
            children: [
              _StatusTile(
                icon: Icons.workspace_premium,
                title: 'Business Pro',
                value: profile.premiumStatusLabel,
                enabled: premiumActive,
              ),
              _StatusTile(
                icon: Icons.calendar_today_outlined,
                title: 'Pro expiry',
                value: _premiumExpiryText(profile),
                enabled: premiumActive && !profile.premiumIsExpired,
              ),
              _StatusTile(
                icon: Icons.verified_outlined,
                title: 'Verified',
                value: profile.verified ? 'Verified' : 'Not verified',
                enabled: profile.verified,
              ),
              _StatusTile(
                icon: Icons.image_outlined,
                title: 'Banner image',
                value: hasBannerImage ? 'Added' : 'Missing',
                enabled: hasBannerImage,
              ),
              _StatusTile(
                icon: isPhysicalShop
                    ? Icons.storefront_outlined
                    : Icons.language,
                title: 'Shop type',
                value: isPhysicalShop ? 'Physical shop' : 'Online-only',
                enabled: true,
              ),
            ],
          ),
          if (profile.premiumExpiresSoon || profile.premiumIsExpired) ...[
            const SizedBox(height: 12),
            _PremiumExpiryWarningCard(profile: profile),
          ],
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.contact_support_outlined,
            title: 'Pro requests',
            subtitle: 'Request Pro, renewal or contact the app admin.',
          ),
          const SizedBox(height: 10),
          _BusinessProRequestDashboardCard(profile: profile),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.campaign_outlined,
            title: 'Premium placements',
            subtitle: 'See which Pro placements are ready or still need setup.',
          ),
          const SizedBox(height: 10),
          _FeatureChecklistCard(
            items: [
              _FeatureChecklistItem(
                icon: Icons.view_carousel_outlined,
                title: 'Featured moving banner',
                description: hasBannerImage
                    ? 'Ready to show your image when Business Pro is active.'
                    : 'Upload a wide banner image in your business profile.',
                completed: premiumActive && hasBannerImage,
              ),
              _FeatureChecklistItem(
                icon: Icons.map_outlined,
                title: 'Featured map shop',
                description: isPhysicalShop
                    ? hasLinkedShop
                        ? 'Linked to ${profile.linkedShopName}.'
                        : 'Physical shops must link to a TCG Shop Map listing.'
                    : 'Not needed for online-only businesses.',
                completed: !isPhysicalShop || (premiumActive && hasLinkedShop),
              ),
              _FeatureChecklistItem(
                icon: Icons.language,
                title: 'Featured online shop placement',
                description: isPhysicalShop
                    ? 'This is mainly for online-only businesses.'
                    : 'Your online shop can appear in premium online shop areas.',
                completed: premiumActive && !isPhysicalShop,
              ),
              _FeatureChecklistItem(
                icon: Icons.forum_outlined,
                title: 'Featured community posts',
                description: profile.autoFeaturePosts
                    ? 'Your eligible business posts can be featured.'
                    : 'Admin can enable this when Business Pro is active.',
                completed: premiumActive && profile.autoFeaturePosts,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.star_rate_rounded,
            title: 'Reviews summary',
            subtitle: 'Quick view of how customers are rating this business.',
          ),
          const SizedBox(height: 10),
          _ReviewsSummaryCard(profile: profile),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.local_offer_outlined,
            title: 'Offers & deals',
            subtitle: 'Create discount codes, promotions and new stock updates.',
          ),
          const SizedBox(height: 10),
          _OffersDashboardCard(profile: profile),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.event_available_outlined,
            title: 'Shop events',
            subtitle: 'Create trade nights, tournaments, release days and meetups.',
          ),
          const SizedBox(height: 10),
          _EventsDashboardCard(profile: profile),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Product showcase',
            subtitle: 'Promote products, pre-orders, singles and new arrivals.',
          ),
          const SizedBox(height: 10),
          _ProductsDashboardCard(profile: profile),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.mark_email_unread_outlined,
            title: 'Customer enquiries',
            subtitle: 'View messages and questions sent by users.',
          ),
          const SizedBox(height: 10),
          _EnquiriesDashboardCard(profile: profile),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.insights_outlined,
            title: 'Analytics',
            subtitle: 'Track how users interact with this business.',
          ),
          const SizedBox(height: 10),
          _AnalyticsCard(profile: profile),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.upgrade_outlined,
            title: 'Upgrade actions',
            subtitle: 'For now, Business Pro is activated manually by an admin.',
          ),
          const SizedBox(height: 10),
          _ActionCard(profile: profile),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final premiumActive = profile.premiumIsActive;
    final businessName = profile.businessName.trim().isEmpty
        ? 'Business profile'
        : profile.businessName.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BusinessProDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: premiumActive
              ? BusinessProDashboardPage._goldColor
              : BusinessProDashboardPage._borderColor,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BusinessProDashboardPage._goldColor.withValues(
              alpha: premiumActive ? 0.18 : 0.08,
            ),
            BusinessProDashboardPage._cardColor,
            BusinessProDashboardPage._backgroundColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: BusinessProDashboardPage._fieldColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: premiumActive
                        ? BusinessProDashboardPage._goldColor
                        : BusinessProDashboardPage._borderColor,
                  ),
                ),
                child: Icon(
                  premiumActive
                      ? Icons.workspace_premium
                      : Icons.storefront_outlined,
                  color: BusinessProDashboardPage._goldColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          text: premiumActive ? 'Business Pro active' : 'Basic',
                          icon: premiumActive
                              ? Icons.workspace_premium
                              : Icons.lock_outline,
                          highlighted: premiumActive,
                        ),
                        _Pill(
                          text: profile.hasPhysicalShop
                              ? 'Physical shop'
                              : 'Online-only',
                          icon: profile.hasPhysicalShop
                              ? Icons.storefront_outlined
                              : Icons.language,
                          highlighted: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.description.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              profile.description.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BusinessProDashboardPage._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.icon,
    required this.highlighted,
  });

  final String text;
  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? BusinessProDashboardPage._goldColor
            : BusinessProDashboardPage._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? BusinessProDashboardPage._goldColor
              : BusinessProDashboardPage._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: highlighted
                ? BusinessProDashboardPage._backgroundColor
                : BusinessProDashboardPage._goldColor,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: highlighted
                  ? BusinessProDashboardPage._backgroundColor
                  : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: BusinessProDashboardPage._goldColor),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: BusinessProDashboardPage._softTextColor,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.36,
      children: children,
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? BusinessProDashboardPage._successColor
        : BusinessProDashboardPage._softTextColor;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BusinessProDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessProDashboardPage._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BusinessProDashboardPage._softTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}



class _BusinessProRequestDashboardCard extends StatelessWidget {
  const _BusinessProRequestDashboardCard({required this.profile});

  final BusinessProfile profile;

  Color _statusColor(BusinessProRequest request) {
    if (request.isApproved) return BusinessProDashboardPage._successColor;
    if (request.isRejected) return Colors.redAccent;
    return BusinessProDashboardPage._goldColor;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessProRequest>>(
      stream: BusinessProfileService().watchBusinessProRequestsForBusiness(
        profile.id,
      ),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <BusinessProRequest>[];
        final latest = requests.isEmpty ? null : requests.first;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BusinessProDashboardPage._cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: BusinessProDashboardPage._borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.contact_support_outlined,
                color: BusinessProDashboardPage._goldColor,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.premiumIsActive
                          ? 'Request renewal or contact admin'
                          : 'Request Business Pro',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      latest == null
                          ? 'Send a request to the app admin from inside PocketChase.'
                          : 'Latest request: ${latest.statusLabel} • ${latest.requestTypeLabel}',
                      style: const TextStyle(
                        color: BusinessProDashboardPage._softTextColor,
                        height: 1.35,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (latest != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: _statusColor(latest),
                            size: 10,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              latest.adminResponse.trim().isEmpty
                                  ? latest.statusLabel
                                  : latest.adminResponse.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: BusinessProDashboardPage._softTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Open Pro requests',
                color: BusinessProDashboardPage._goldColor,
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BusinessProRequestPage(profile: profile),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PremiumExpiryWarningCard extends StatelessWidget {
  const _PremiumExpiryWarningCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final expired = profile.premiumIsExpired;
    final days = profile.premiumDaysRemaining;
    final message = expired
        ? 'Business Pro has expired. Premium placements and Pro tools are hidden until an admin renews the plan.'
        : days == null
            ? 'Business Pro is active.'
            : 'Business Pro expires in $days day${days == 1 ? '' : 's'}. Contact the app admin to renew.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: expired
            ? Colors.redAccent.withValues(alpha: 0.12)
            : BusinessProDashboardPage._goldColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: expired
              ? Colors.redAccent
              : BusinessProDashboardPage._goldColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            expired ? Icons.lock_clock_outlined : Icons.schedule_outlined,
            color:
                expired ? Colors.redAccent : BusinessProDashboardPage._goldColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: BusinessProDashboardPage._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChecklistCard extends StatelessWidget {
  const _FeatureChecklistCard({required this.items});

  final List<_FeatureChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BusinessProDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessProDashboardPage._borderColor),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            items[index],
            if (index != items.length - 1)
              const Divider(
                height: 1,
                color: BusinessProDashboardPage._borderColor,
                indent: 62,
              ),
          ],
        ],
      ),
    );
  }
}

class _FeatureChecklistItem extends StatelessWidget {
  const _FeatureChecklistItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.completed,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? BusinessProDashboardPage._successColor
        : BusinessProDashboardPage._goldColor;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: BusinessProDashboardPage._softTextColor,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            completed
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            color: completed
                ? BusinessProDashboardPage._successColor
                : BusinessProDashboardPage._softTextColor,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _ReviewsSummaryCard extends StatelessWidget {
  const _ReviewsSummaryCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BusinessProDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessProDashboardPage._borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_rate_rounded,
            color: BusinessProDashboardPage._goldColor,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BusinessRatingSummary(
              businessId: profile.id,
              starColor: BusinessProDashboardPage._goldColor,
              textColor: Colors.white,
              mutedTextColor: BusinessProDashboardPage._softTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open reviews',
            color: BusinessProDashboardPage._goldColor,
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BusinessReviewsPage(profile: profile),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


class _OffersDashboardCard extends StatelessWidget {
  const _OffersDashboardCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final premiumActive = profile.premiumIsActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BusinessProDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: premiumActive
              ? BusinessProDashboardPage._goldColor
              : BusinessProDashboardPage._borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_offer_outlined,
            color: premiumActive
                ? BusinessProDashboardPage._goldColor
                : BusinessProDashboardPage._softTextColor,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premiumActive
                      ? 'Manage Pro offers'
                      : 'Offers unlock with Business Pro',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  premiumActive
                      ? 'Post discount codes, promotions, new stock updates and announcements.'
                      : 'Once Pro is active, this business can post deals and promotions for users.',
                  style: const TextStyle(
                    color: BusinessProDashboardPage._softTextColor,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open offers',
            color: BusinessProDashboardPage._goldColor,
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BusinessOffersPage(profile: profile),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


class _EventsDashboardCard extends StatelessWidget {
  const _EventsDashboardCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final premiumActive = profile.premiumIsActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BusinessProDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: premiumActive
              ? BusinessProDashboardPage._goldColor
              : BusinessProDashboardPage._borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_available_outlined,
            color: premiumActive
                ? BusinessProDashboardPage._goldColor
                : BusinessProDashboardPage._softTextColor,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premiumActive
                      ? 'Manage shop events'
                      : 'Events unlock with Business Pro',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  premiumActive
                      ? 'Post trade nights, tournaments, pre-release events and meetups.'
                      : 'Once Pro is active, this business can publish events for users to discover.',
                  style: const TextStyle(
                    color: BusinessProDashboardPage._softTextColor,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open events',
            color: BusinessProDashboardPage._goldColor,
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BusinessEventsPage(profile: profile),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


class _ProductsDashboardCard extends StatelessWidget {
  const _ProductsDashboardCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final premiumActive = profile.premiumIsActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BusinessProDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: premiumActive
              ? BusinessProDashboardPage._goldColor
              : BusinessProDashboardPage._borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: premiumActive
                ? BusinessProDashboardPage._goldColor
                : BusinessProDashboardPage._softTextColor,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premiumActive
                      ? 'Manage product showcase'
                      : 'Product showcase unlocks with Business Pro',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  premiumActive
                      ? 'Promote products, prices, pre-orders, singles and buy links.'
                      : 'Once Pro is active, this business can show products to users.',
                  style: const TextStyle(
                    color: BusinessProDashboardPage._softTextColor,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open product showcase',
            color: BusinessProDashboardPage._goldColor,
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BusinessProductsPage(profile: profile),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


class _EnquiriesDashboardCard extends StatelessWidget {
  const _EnquiriesDashboardCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessEnquiry>>(
      stream: BusinessProfileService().watchBusinessEnquiries(profile.id),
      builder: (context, snapshot) {
        final enquiries = snapshot.data ?? const <BusinessEnquiry>[];
        final openCount = enquiries.where((item) => item.status == 'open').length;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BusinessProDashboardPage._cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: BusinessProDashboardPage._borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                color: BusinessProDashboardPage._goldColor,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage customer enquiries',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      enquiries.isEmpty
                          ? 'Users can send questions about stock, events, products and trades.'
                          : '${enquiries.length} total enquiry${enquiries.length == 1 ? '' : 's'} • $openCount open',
                      style: const TextStyle(
                        color: BusinessProDashboardPage._softTextColor,
                        height: 1.35,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Open enquiries',
                color: BusinessProDashboardPage._goldColor,
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BusinessEnquiriesPage(profile: profile),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BusinessAnalytics>(
      stream: BusinessProfileService().watchBusinessAnalytics(profile.id),
      builder: (context, snapshot) {
        final analytics = snapshot.data ?? BusinessAnalytics.empty(profile.id);

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BusinessProDashboardPage._cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: BusinessProDashboardPage._borderColor),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BusinessProDashboardPage._goldColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Loading analytics...',
                    style: TextStyle(
                      color: BusinessProDashboardPage._softTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BusinessProDashboardPage._cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: BusinessProDashboardPage._borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnalyticsTotalRow(analytics: analytics),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.38,
                children: [
                  _AnalyticsTile(
                    icon: Icons.map_outlined,
                    title: 'Map views',
                    value: analytics.mapViews,
                  ),
                  _AnalyticsTile(
                    icon: Icons.open_in_new,
                    title: 'Website clicks',
                    value: analytics.websiteClicks,
                  ),
                  _AnalyticsTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone taps',
                    value: analytics.phoneClicks,
                  ),
                  _AnalyticsTile(
                    icon: Icons.local_offer_outlined,
                    title: 'Offer opens',
                    value: analytics.offerViews,
                  ),
                  _AnalyticsTile(
                    icon: Icons.event_available_outlined,
                    title: 'Event opens',
                    value: analytics.eventViews,
                  ),
                  _AnalyticsTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Product opens',
                    value: analytics.productViews,
                  ),
                  _AnalyticsTile(
                    icon: Icons.visibility_outlined,
                    title: 'Profile views',
                    value: analytics.profileViews,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'These numbers are early Business Pro analytics and will grow as users interact with the shop, offers, and events.',
                style: TextStyle(
                  color: BusinessProDashboardPage._softTextColor,
                  height: 1.35,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsTotalRow extends StatelessWidget {
  const _AnalyticsTotalRow({required this.analytics});

  final BusinessAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: BusinessProDashboardPage._fieldColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BusinessProDashboardPage._borderColor),
          ),
          child: const Icon(
            Icons.insights_outlined,
            color: BusinessProDashboardPage._goldColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total engagement',
                style: TextStyle(
                  color: BusinessProDashboardPage._softTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                analytics.totalEngagement.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  const _AnalyticsTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BusinessProDashboardPage._fieldColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BusinessProDashboardPage._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: BusinessProDashboardPage._goldColor,
            size: 22,
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BusinessProDashboardPage._softTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final premiumActive = profile.premiumIsActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: premiumActive
            ? BusinessProDashboardPage._goldColor.withValues(alpha: 0.12)
            : BusinessProDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: premiumActive
              ? BusinessProDashboardPage._goldColor
              : BusinessProDashboardPage._borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            premiumActive
                ? 'Business Pro is active'
                : 'Want to activate Business Pro?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            premiumActive
                ? 'You can edit your business profile, banner image, and linked shop at any time.'
                : 'For now, Business Pro is activated manually by a PocketChase admin while this feature is being tested.',
            style: const TextStyle(
              color: BusinessProDashboardPage._softTextColor,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: BusinessProDashboardPage._goldColor,
              foregroundColor: BusinessProDashboardPage._backgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Icon(premiumActive ? Icons.edit_outlined : Icons.mail_outline),
            label: Text(
              premiumActive ? 'Edit business profile' : 'Contact admin',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: () {
              if (premiumActive) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BusinessProfileEditorPage(profile: profile),
                  ),
                );
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Business Pro activation is currently handled by admin.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
