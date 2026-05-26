import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import '../widgets/business_rating_summary.dart';
import 'business_profile_dashboard_page.dart';
import 'business_profile_editor_page.dart';
import 'business_reviews_page.dart';

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
              icon: Icons.dashboard_customize_outlined,
              iconColor: BusinessProfilePage.goldColor,
              title: 'Business Pro Dashboard',
              subtitle: 'View premium status, placements, reviews and future analytics.',
              onTap: () => _openBusinessProDashboard(context),
            ),
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.workspace_premium_outlined,
              iconColor: BusinessProfilePage.goldColor,
              title: 'Business Pro',
              subtitle: 'See what Business Pro includes and how activation works.',
              trailing: const _SmallPill(
                text: 'Info',
                color: BusinessProfilePage.goldColor,
                textColor: BusinessProfilePage.backgroundColor,
              ),
              onTap: () => _showBusinessProInfo(context),
            ),
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.star_rate_rounded,
              iconColor: BusinessProfilePage.goldColor,
              title: 'Reviews & ratings',
              subtitle: 'View ratings and reviews left by PocketChase users.',
              onTap: () => _openReviews(context),
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
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await BusinessProfileService().deleteBusinessProfile(profile.id);

      if (!context.mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Business profile deleted.')),
      );

      // Do not pop this page after deletion.
      // The profile stream updates automatically and shows the empty/create state.
      // Popping while Firestore is rebuilding this page can cause Flutter's
      // _dependents.isEmpty assertion on some devices.
    } catch (error) {
      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete profile: $error')),
      );
    }
  }

  void _openBusinessProDashboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessProDashboardPage(profile: profile),
      ),
    );
  }

  void _openReviews(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessReviewsPage(profile: profile),
      ),
    );
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessProfileEditorPage(profile: profile),
      ),
    );
  }

  void _showBusinessProInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: BusinessProfilePage.cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (sheetContext, scrollController) {
            return SafeArea(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BusinessProfilePage.goldColor.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: BusinessProfilePage.goldColor),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: BusinessProfilePage.goldColor,
                          size: 34,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PocketChase Business Pro',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Promote your TCG business across PocketChase and help collectors find your shop faster.',
                                style: TextStyle(
                                  color: BusinessProfilePage.softTextColor,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _BusinessProInfoHeading(
                    icon: Icons.check_circle_outline,
                    title: 'What Business Pro includes',
                  ),
                  const SizedBox(height: 10),
                  const _BusinessProInfoCard(
                    icon: Icons.view_carousel_outlined,
                    title: 'Featured moving banner',
                    description:
                        'Your business can appear in the moving featured banner at the top of the TCG Shop Map page.',
                  ),
                  const SizedBox(height: 10),
                  const _BusinessProInfoCard(
                    icon: Icons.storefront_outlined,
                    title: 'Featured map shop',
                    description:
                        'Physical shops can be highlighted on the map with premium placement and a featured marker.',
                  ),
                  const SizedBox(height: 10),
                  const _BusinessProInfoCard(
                    icon: Icons.language,
                    title: 'Featured online shop placement',
                    description:
                        'Online-only businesses can appear in the Online Shops directory and premium featured areas.',
                  ),
                  const SizedBox(height: 10),
                  const _BusinessProInfoCard(
                    icon: Icons.forum_outlined,
                    title: 'Featured community posts',
                    description:
                        'Your business posts can be promoted so collectors see them more easily in the community area.',
                  ),
                  const SizedBox(height: 10),
                  const _BusinessProInfoCard(
                    icon: Icons.image_outlined,
                    title: 'Premium business profile',
                    description:
                        'Show your business name, description, website, contact details, area, and featured banner image.',
                  ),
                  const SizedBox(height: 16),
                  const _BusinessProInfoHeading(
                    icon: Icons.sell_outlined,
                    title: 'Pricing',
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BusinessProfilePage.fieldColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BusinessProfilePage.goldColor),
                    ),
                    child: const Text(
                      'Business Pro pricing is coming soon. For now, this feature is being tested and can be activated by a PocketChase admin.',
                      style: TextStyle(
                        color: BusinessProfilePage.softTextColor,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _BusinessProInfoHeading(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Contact/admin approval for now',
                  ),
                  const SizedBox(height: 10),
                  const _BusinessProStep(
                    number: '1',
                    title: 'Create your business profile',
                    description:
                        'Business users create and complete their business profile first.',
                  ),
                  const _BusinessProStepDivider(),
                  const _BusinessProStep(
                    number: '2',
                    title: 'Contact admin to activate Business Pro',
                    description:
                        'Business Pro access is currently controlled from the admin Business Profiles area.',
                  ),
                  const _BusinessProStepDivider(),
                  const _BusinessProStep(
                    number: '3',
                    title: 'Admin turns premium on',
                    description:
                        'Admins can enable premium, featured map shop, and featured post options.',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.55),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.security_outlined,
                          color: Colors.orangeAccent,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'When payments are added later, Apple and Google purchase verification should activate premium securely. The app should not directly set premiumActive after payment without backend verification.',
                            style: TextStyle(
                              color: BusinessProfilePage.softTextColor,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
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
            );
          },
        );
      },
    );
  }

}


class _BusinessProInfoHeading extends StatelessWidget {
  const _BusinessProInfoHeading({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: BusinessProfilePage.goldColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessProInfoCard extends StatelessWidget {
  const _BusinessProInfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BusinessProfilePage.fieldColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BusinessProfilePage.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BusinessProfilePage.goldColor, size: 24),
          const SizedBox(width: 11),
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
                    color: BusinessProfilePage.softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessProStep extends StatelessWidget {
  const _BusinessProStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: BusinessProfilePage.goldColor,
          child: Text(
            number,
            style: const TextStyle(
              color: BusinessProfilePage.backgroundColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: BusinessProfilePage.softTextColor,
                  height: 1.35,
                  fontSize: 12,
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

class _BusinessProStepDivider extends StatelessWidget {
  const _BusinessProStepDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 15, top: 8, bottom: 8),
      height: 18,
      width: 1.5,
      color: BusinessProfilePage.goldColor.withValues(alpha: 0.45),
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
                    const SizedBox(height: 8),
                    BusinessRatingSummary(
                      businessId: profile.id,
                      starColor: BusinessProfilePage.goldColor,
                      textColor: Colors.white,
                      mutedTextColor: BusinessProfilePage.softTextColor,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BusinessReviewsPage(profile: profile),
                          ),
                        );
                      },
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
                      : 'Business Pro coming soon',
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
            'Business Pro will help shops stand out to collectors using PocketChase.',
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
            text: 'Premium business badge',
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
