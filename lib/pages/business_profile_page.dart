import 'package:flutter/material.dart';

import '../models/business_enquiry.dart';
import '../models/business_pro_request.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import 'business_enquiries_page.dart';
import 'business_pro_request_page.dart';
import 'business_profile_dashboard_page.dart';
import 'business_profile_editor_page.dart';

class BusinessProfilePage extends StatelessWidget {
  const BusinessProfilePage({super.key});

  static const Color backgroundColor = Color(0xFF041B4A);
  static const Color cardColor = Color(0xFF102754);
  static const Color fieldColor = Color(0xFF16366E);
  static const Color borderColor = Color(0xFF3F5C96);
  static const Color goldColor = Color(0xFFF7DE77);
  static const Color softTextColor = Color(0xFFC8D4F0);
  static const Color successColor = Color(0xFF4ADE80);
  static const Color warningColor = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    final service = BusinessProfileService();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Business Profile'),
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<BusinessProfile?>(
        stream: service.watchMyBusinessProfile(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: goldColor),
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return _EmptyBusinessProfileState(
              onCreate: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BusinessProfileEditorPage(),
                  ),
                );
              },
            );
          }

          return _BusinessProfileMenu(profile: profile);
        },
      ),
    );
  }
}

class _BusinessProfileMenu extends StatelessWidget {
  const _BusinessProfileMenu({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      children: [
        _ProfileHeroCard(profile: profile),
        const SizedBox(height: 12),
        _BusinessNotificationSummary(profile: profile),
        const SizedBox(height: 16),
        const _SectionHeader(
          icon: Icons.menu_rounded,
          title: 'Business menu',
          subtitle: 'Manage your business profile and future premium features.',
        ),
        const SizedBox(height: 10),
        _MenuCard(
          children: [
            _MenuTile(
              icon: Icons.edit_outlined,
              iconColor: BusinessProfilePage.goldColor,
              title: 'Edit business profile',
              subtitle: 'Update your business name, description, website, phone and area.',
              onTap: () => _openEditor(context),
            ),
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.store_mall_directory_outlined,
              iconColor: profile.linkedShopId.isEmpty
                  ? BusinessProfilePage.softTextColor
                  : BusinessProfilePage.goldColor,
              title: profile.linkedShopId.isEmpty
                  ? 'Link a TCG shop later'
                  : 'Linked TCG shop',
              subtitle: profile.linkedShopName.isEmpty
                  ? 'Optional. Your profile can work without a featured shop.'
                  : profile.linkedShopName,
              onTap: () => _openEditor(context),
            ),
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.mark_email_unread_outlined,
              iconColor: BusinessProfilePage.goldColor,
              title: 'Customer enquiries',
              subtitle: 'View messages and questions from users.',
              trailing: _BusinessEnquiriesBadge(profile: profile),
              onTap: () => _openCustomerEnquiries(context),
            ),
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.dashboard_customize_outlined,
              iconColor: BusinessProfilePage.goldColor,
              title: 'Business Pro dashboard',
              subtitle: profile.premiumIsActive
                  ? 'Manage offers, events, products, enquiries, analytics and Pro tools.'
                  : 'View Pro tools and request access from the app admin.',
              trailing: _SmallPill(
                text: profile.premiumIsActive ? 'Active' : 'Pro',
                color: profile.premiumIsActive
                    ? BusinessProfilePage.successColor
                    : BusinessProfilePage.goldColor,
                textColor: BusinessProfilePage.backgroundColor,
              ),
              onTap: () => _openBusinessProDashboard(context),
            ),
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.contact_support_outlined,
              iconColor: BusinessProfilePage.goldColor,
              title: profile.premiumIsActive
                  ? 'Request Pro renewal'
                  : 'Request Business Pro',
              subtitle: 'Send a request or message to the app admin about Business Pro.',
              trailing: _BusinessProRequestsBadge(profile: profile),
              onTap: () => _openBusinessProRequest(context),
            ),
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.info_outline,
              iconColor: BusinessProfilePage.softTextColor,
              title: 'What Business Pro includes',
              subtitle: 'Featured placements, offers, events, products, reviews and enquiries.',
              onTap: () => _showBusinessProInfo(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
          icon: Icons.visibility_outlined,
          title: 'Profile details',
          subtitle: 'What is currently saved on this business profile.',
        ),
        const SizedBox(height: 10),
        _ProfileDetailsCard(profile: profile),
        const SizedBox(height: 16),
        const _SectionHeader(
          icon: Icons.verified_outlined,
          title: 'Status',
          subtitle: 'Approval and premium are protected by Firestore rules.',
        ),
        const SizedBox(height: 10),
        _StatusCard(profile: profile),
        const SizedBox(height: 16),
        _BusinessProCard(profile: profile),
        const SizedBox(height: 16),
        const _SectionHeader(
          icon: Icons.warning_amber_rounded,
          title: 'Danger zone',
          subtitle: 'Delete this business profile if you no longer need it.',
        ),
        const SizedBox(height: 10),
        _DangerZoneCard(
          profile: profile,
          onDelete: () => _confirmDelete(context),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: BusinessProfilePage.cardColor,
          title: const Text(
            'Delete business profile?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will permanently delete "${profile.businessName}". This cannot be undone.',
            style: const TextStyle(
              color: BusinessProfilePage.softTextColor,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await BusinessProfileService().deleteBusinessProfile(profile.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business profile deleted.')),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete profile: $error')),
      );
    }
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessProfileEditorPage(profile: profile),
      ),
    );
  }

  void _openBusinessProDashboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessProDashboardPage(profile: profile),
      ),
    );
  }

  void _openCustomerEnquiries(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessEnquiriesPage(profile: profile),
      ),
    );
  }

  void _openBusinessProRequest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessProRequestPage(profile: profile),
      ),
    );
  }

  void _showBusinessProInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: BusinessProfilePage.cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: BusinessProfilePage.goldColor,
                      size: 30,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PocketChase Business Pro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Business Pro gives shop owners extra visibility and tools inside PocketChase.',
                  style: TextStyle(
                    color: BusinessProfilePage.softTextColor,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                const _FeatureLine(
                  enabled: true,
                  text: 'Featured moving banner and featured map/online shop placements',
                ),
                const _FeatureLine(
                  enabled: true,
                  text: 'Offers, shop events, product showcase and customer enquiries',
                ),
                const _FeatureLine(
                  enabled: true,
                  text: 'Reviews, replies, analytics and Pro request/renewal support',
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BusinessProfilePage.fieldColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BusinessProfilePage.borderColor),
                  ),
                  child: const Text(
                    'Use Request Business Pro or Request Pro renewal to contact the app admin. Admin can then activate or renew Pro access.',
                    style: TextStyle(
                      color: BusinessProfilePage.softTextColor,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: BusinessProfilePage.goldColor,
                      foregroundColor: BusinessProfilePage.backgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _BusinessNotificationSummary extends StatelessWidget {
  const _BusinessNotificationSummary({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessEnquiry>>(
      stream: BusinessProfileService().watchBusinessEnquiries(profile.id),
      builder: (context, enquirySnapshot) {
        final enquiries = enquirySnapshot.data ?? const <BusinessEnquiry>[];
        final openEnquiries = enquiries
            .where((enquiry) => enquiry.status == 'open')
            .length;

        return StreamBuilder<List<BusinessProRequest>>(
          stream: BusinessProfileService().watchBusinessProRequestsForBusiness(
            profile.id,
          ),
          builder: (context, requestSnapshot) {
            final requests =
                requestSnapshot.data ?? const <BusinessProRequest>[];
            final pendingRequests = requests
                .where((request) => request.status == 'pending')
                .length;
            final latestRequest = requests.isEmpty ? null : requests.first;

            final hasExpiryAlert =
                profile.premiumExpiresSoon || profile.premiumIsExpired;
            final hasNotifications =
                openEnquiries > 0 || pendingRequests > 0 || hasExpiryAlert;

            final subtitle = hasNotifications
                ? 'You have business updates to check.'
                : 'No urgent business notifications.';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hasNotifications
                    ? BusinessProfilePage.goldColor.withValues(alpha: 0.12)
                    : BusinessProfilePage.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasNotifications
                      ? BusinessProfilePage.goldColor
                      : BusinessProfilePage.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: BusinessProfilePage.fieldColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: BusinessProfilePage.borderColor,
                              ),
                            ),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: BusinessProfilePage.goldColor,
                            ),
                          ),
                          if (hasNotifications)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Business notifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: BusinessProfilePage.softTextColor,
                                height: 1.35,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _NotificationPill(
                        icon: Icons.mark_email_unread_outlined,
                        text: openEnquiries == 0
                            ? 'No open enquiries'
                            : '$openEnquiries open enquiry${openEnquiries == 1 ? '' : 'ies'}',
                        highlighted: openEnquiries > 0,
                      ),
                      _NotificationPill(
                        icon: Icons.contact_support_outlined,
                        text: pendingRequests == 0
                            ? 'No pending Pro requests'
                            : '$pendingRequests Pro request${pendingRequests == 1 ? '' : 's'} pending',
                        highlighted: pendingRequests > 0,
                      ),
                      if (latestRequest != null && latestRequest.status != 'pending')
                        _NotificationPill(
                          icon: latestRequest.isApproved
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          text: 'Latest Pro request: ${latestRequest.statusLabel}',
                          highlighted: true,
                        ),
                      if (profile.premiumIsExpired)
                        const _NotificationPill(
                          icon: Icons.lock_clock_outlined,
                          text: 'Business Pro expired',
                          highlighted: true,
                        )
                      else if (profile.premiumExpiresSoon)
                        const _NotificationPill(
                          icon: Icons.schedule_outlined,
                          text: 'Business Pro expires soon',
                          highlighted: true,
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BusinessEnquiriesBadge extends StatelessWidget {
  const _BusinessEnquiriesBadge({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessEnquiry>>(
      stream: BusinessProfileService().watchBusinessEnquiries(profile.id),
      builder: (context, snapshot) {
        final enquiries = snapshot.data ?? const <BusinessEnquiry>[];
        final openCount =
            enquiries.where((enquiry) => enquiry.status == 'open').length;

        if (openCount <= 0) {
          return const Icon(
            Icons.chevron_right,
            color: BusinessProfilePage.goldColor,
          );
        }

        return _CountBadge(count: openCount);
      },
    );
  }
}

class _BusinessProRequestsBadge extends StatelessWidget {
  const _BusinessProRequestsBadge({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessProRequest>>(
      stream: BusinessProfileService().watchBusinessProRequestsForBusiness(
        profile.id,
      ),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <BusinessProRequest>[];
        final pendingCount =
            requests.where((request) => request.status == 'pending').length;

        if (pendingCount <= 0) {
          return const Icon(
            Icons.chevron_right,
            color: BusinessProfilePage.goldColor,
          );
        }

        return _CountBadge(count: pendingCount);
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NotificationPill extends StatelessWidget {
  const _NotificationPill({
    required this.icon,
    required this.text,
    required this.highlighted,
  });

  final IconData icon;
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? BusinessProfilePage.goldColor
            : BusinessProfilePage.fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? BusinessProfilePage.goldColor
              : BusinessProfilePage.borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted
                ? BusinessProfilePage.backgroundColor
                : BusinessProfilePage.goldColor,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: highlighted
                  ? BusinessProfilePage.backgroundColor
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

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final isApproved = profile.status == 'approved';
    final isPending = profile.status == 'pending';
    final location = profile.displayLocation;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BusinessProfilePage.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: profile.premiumIsActive
              ? BusinessProfilePage.goldColor
              : BusinessProfilePage.borderColor,
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
              CircleAvatar(
                radius: 32,
                backgroundColor: BusinessProfilePage.fieldColor,
                child: profile.logoUrl.isEmpty
                    ? const Icon(
                        Icons.storefront_outlined,
                        color: BusinessProfilePage.goldColor,
                        size: 34,
                      )
                    : ClipOval(
                        child: Image.network(
                          profile.logoUrl,
                          fit: BoxFit.cover,
                          width: 64,
                          height: 64,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.storefront_outlined,
                              color: BusinessProfilePage.goldColor,
                              size: 34,
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.businessName.isEmpty
                          ? 'Business profile'
                          : profile.businessName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _SmallPill(
                          text: isApproved
                              ? 'Approved'
                              : isPending
                                  ? 'Pending'
                                  : profile.status,
                          color: isApproved
                              ? BusinessProfilePage.successColor
                              : BusinessProfilePage.warningColor,
                          textColor: Colors.black,
                        ),
                        if (profile.verified)
                          const _SmallPill(
                            text: 'Verified',
                            color: BusinessProfilePage.goldColor,
                            textColor: BusinessProfilePage.backgroundColor,
                          ),
                        if (profile.premiumIsActive)
                          const _SmallPill(
                            text: 'Business Pro',
                            color: BusinessProfilePage.goldColor,
                            textColor: BusinessProfilePage.backgroundColor,
                          )
                        else
                          const _SmallPill(
                            text: 'Basic',
                            color: BusinessProfilePage.fieldColor,
                            textColor: Colors.white,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.description.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              profile.description,
              style: const TextStyle(
                color: BusinessProfilePage.softTextColor,
                height: 1.35,
              ),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: BusinessProfilePage.goldColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      color: BusinessProfilePage.softTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BusinessProfilePage.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessProfilePage.borderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: BusinessProfilePage.fieldColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: BusinessProfilePage.softTextColor,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  color: BusinessProfilePage.goldColor,
                ),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: BusinessProfilePage.borderColor,
      height: 1,
      thickness: 1,
      indent: 68,
    );
  }
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      children: [
        _InfoRow(
          icon: Icons.storefront_outlined,
          label: 'Business name',
          value: profile.businessName.isEmpty
              ? 'Not added yet'
              : profile.businessName,
        ),
        _InfoRow(
          icon: Icons.notes_outlined,
          label: 'Description',
          value: profile.description.isEmpty
              ? 'Not added yet'
              : profile.description,
        ),
        _InfoRow(
          icon: Icons.language,
          label: 'Website',
          value: profile.website.isEmpty ? 'Not added yet' : profile.website,
        ),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: profile.phone.isEmpty ? 'Not added yet' : profile.phone,
        ),
        _InfoRow(
          icon: Icons.place_outlined,
          label: 'Area',
          value: profile.displayLocation.isEmpty
              ? 'Not added yet'
              : profile.displayLocation,
        ),
        _InfoRow(
          icon: Icons.map_outlined,
          label: 'Linked shop',
          value: profile.linkedShopName.isEmpty
              ? 'No shop linked'
              : profile.linkedShopName,
          bottomPadding: 0,
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final isApproved = profile.status == 'approved';

    return _InfoCard(
      children: [
        _StatusLine(
          icon: isApproved
              ? Icons.check_circle_outline
              : Icons.pending_actions_outlined,
          iconColor: isApproved
              ? BusinessProfilePage.successColor
              : BusinessProfilePage.warningColor,
          title: 'Profile approval',
          value: isApproved ? 'Approved' : 'Pending approval',
        ),
        const SizedBox(height: 10),
        _StatusLine(
          icon: profile.verified
              ? Icons.verified_outlined
              : Icons.radio_button_unchecked,
          iconColor: profile.verified
              ? BusinessProfilePage.goldColor
              : BusinessProfilePage.softTextColor,
          title: 'Verified business',
          value: profile.verified ? 'Verified' : 'Not verified yet',
        ),
        const SizedBox(height: 10),
        _StatusLine(
          icon: profile.premiumIsActive
              ? Icons.workspace_premium
              : Icons.lock_outline,
          iconColor: profile.premiumIsActive
              ? BusinessProfilePage.goldColor
              : BusinessProfilePage.softTextColor,
          title: 'Business Pro',
          value: profile.premiumIsActive ? 'Active' : 'Not active',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BusinessProfilePage.fieldColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BusinessProfilePage.borderColor),
          ),
          child: const Text(
            'Users can edit profile details, but approval and premium settings are protected so users cannot give themselves premium access.',
            style: TextStyle(
              color: BusinessProfilePage.softTextColor,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}


class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({
    required this.profile,
    required this.onDelete,
  });

  final BusinessProfile profile;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.delete_forever_outlined,
                color: Colors.redAccent,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delete business profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The business owner can delete their own profile. Admins and moderators can delete business profiles from the admin business profiles page.',
            style: TextStyle(
              color: BusinessProfilePage.softTextColor,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text(
                'Delete this business profile',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessProCard extends StatelessWidget {
  const _BusinessProCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final premiumActive = profile.premiumIsActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: premiumActive
            ? BusinessProfilePage.goldColor.withValues(alpha: 0.14)
            : BusinessProfilePage.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: premiumActive
              ? BusinessProfilePage.goldColor
              : BusinessProfilePage.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: BusinessProfilePage.goldColor,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  premiumActive
                      ? 'Business Pro active'
                      : 'Business Pro not active',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Business Pro helps shops stand out to collectors using PocketChase.',
            style: TextStyle(
              color: BusinessProfilePage.softTextColor,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _FeatureLine(
            enabled: profile.featuredShopEnabled && premiumActive,
            text: 'Featured shop placement on the map',
          ),
          _FeatureLine(
            enabled: profile.autoFeaturePosts && premiumActive,
            text: 'Automatically featured community posts',
          ),
          _FeatureLine(
            enabled: premiumActive,
            text: 'Reviews, replies, analytics and Pro request/renewal support',
          ),
        ],
      ),
    );
  }
}

class _EmptyBusinessProfileState extends StatelessWidget {
  const _EmptyBusinessProfileState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: BusinessProfilePage.cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: BusinessProfilePage.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: BusinessProfilePage.goldColor,
                size: 54,
              ),
              const SizedBox(height: 14),
              const Text(
                'Create your business profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your shop or business details so collectors can learn more about you on PocketChase.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BusinessProfilePage.softTextColor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BusinessProfilePage.fieldColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BusinessProfilePage.borderColor),
                ),
                child: const Column(
                  children: [
                    _FeatureLine(
                      enabled: true,
                      text: 'Create a public business profile',
                    ),
                    _FeatureLine(
                      enabled: true,
                      text: 'Add contact and area details',
                    ),
                    _FeatureLine(
                      enabled: true,
                      text: 'Link a TCG shop later if wanted',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: BusinessProfilePage.goldColor,
                    foregroundColor: BusinessProfilePage.backgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text(
                    'Create business profile',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onPressed: onCreate,
                ),
              ),
            ],
          ),
        ),
      ],
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
        Icon(icon, color: BusinessProfilePage.goldColor, size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: BusinessProfilePage.softTextColor,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BusinessProfilePage.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessProfilePage.borderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.bottomPadding = 11,
  });

  final IconData icon;
  final String label;
  final String value;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BusinessProfilePage.goldColor, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: BusinessProfilePage.softTextColor,
                  height: 1.3,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: BusinessProfilePage.softTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.enabled,
    required this.text,
  });

  final bool enabled;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.radio_button_unchecked,
            color: enabled
                ? BusinessProfilePage.goldColor
                : BusinessProfilePage.softTextColor,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: BusinessProfilePage.goldColor,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load your business profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BusinessProfilePage.softTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
