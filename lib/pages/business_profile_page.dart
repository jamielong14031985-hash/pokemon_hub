import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import 'business_onboarding_page.dart';
import 'business_quick_actions_page.dart';
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

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: const Text(
            'Log out?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'You will be signed out of this business account.',
            style: TextStyle(
              color: softTextColor,
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
                backgroundColor: goldColor,
                foregroundColor: backgroundColor,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Log out',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

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
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context),
          ),
          const SizedBox(width: 6),
        ],
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
        if (!_BusinessSetupPreviewCard.isSetupComplete(profile)) ...[
          const SizedBox(height: 12),
          _BusinessSetupPreviewCard(
            profile: profile,
            onTap: () => _openBusinessOnboarding(context),
          ),
        ],
        const SizedBox(height: 12),
        _BusinessQuickActionsPreviewCard(
          profile: profile,
          onTap: () => _openBusinessQuickActions(context),
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
          icon: Icons.visibility_outlined,
          title: 'Business overview',
          subtitle: 'Your main management tools are now inside Business Quick Actions.',
        ),
        const SizedBox(height: 10),
        _ProfileDetailsCard(profile: profile),
        const SizedBox(height: 16),
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


  void _openBusinessOnboarding(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessOnboardingPage(profile: profile),
      ),
    );
  }

  void _openBusinessQuickActions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessQuickActionsPage(profile: profile),
      ),
    );
  }


}


class _BusinessQuickActionsPreviewCard extends StatelessWidget {
  const _BusinessQuickActionsPreviewCard({
    required this.profile,
    required this.onTap,
  });

  final BusinessProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOpen = profile.isOpenNow ?? profile.openingStatus == 'open';
    final statusColor = isOpen
        ? BusinessProfilePage.successColor
        : Colors.redAccent;

    return Material(
      color: BusinessProfilePage.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: BusinessProfilePage.fieldColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BusinessProfilePage.borderColor),
                ),
                child: Icon(
                  isOpen ? Icons.lock_open_outlined : Icons.lock_outline,
                  color: statusColor,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Business quick actions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isOpen
                          ? 'Open now. Quickly manage offers, events, products and enquiries.'
                          : 'Closed now. Quickly manage offers, events, products and enquiries.',
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
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: BusinessProfilePage.goldColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessSetupPreviewCard extends StatelessWidget {
  const _BusinessSetupPreviewCard({
    required this.profile,
    required this.onTap,
  });

  final BusinessProfile profile;
  final VoidCallback onTap;

  static bool isSetupComplete(BusinessProfile profile) {
    const total = 4;
    var count = 0;

    if (profile.hasRequiredBusinessDetails) count++;
    if (!profile.hasPhysicalShop || profile.hasLinkedShop) count++;
    if (profile.hasAnyOpeningHours) count++;
    if (profile.logoUrl.trim().isNotEmpty ||
        profile.bannerUrl.trim().isNotEmpty) {
      count++;
    }

    return count == total;
  }

  int get _completeCount {
    var count = 0;

    if (profile.hasRequiredBusinessDetails) count++;
    if (!profile.hasPhysicalShop || profile.hasLinkedShop) count++;
    if (profile.hasAnyOpeningHours) count++;
    if (profile.logoUrl.trim().isNotEmpty ||
        profile.bannerUrl.trim().isNotEmpty) {
      count++;
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    const total = 4;
    final completeCount = _completeCount;
    final complete = completeCount == total;
    final progress = completeCount / total;

    return Material(
      color: BusinessProfilePage.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: complete
                  ? BusinessProfilePage.successColor
                  : BusinessProfilePage.goldColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: BusinessProfilePage.fieldColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BusinessProfilePage.borderColor),
                ),
                child: Icon(
                  complete
                      ? Icons.verified_outlined
                      : Icons.checklist_rounded,
                  color: complete
                      ? BusinessProfilePage.successColor
                      : BusinessProfilePage.goldColor,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Business setup checklist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      complete
                          ? 'Required setup complete. Add extra polish when ready.'
                          : '$completeCount of $total required setup steps complete.',
                      style: const TextStyle(
                        color: BusinessProfilePage.softTextColor,
                        height: 1.35,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        minHeight: 7,
                        backgroundColor: BusinessProfilePage.fieldColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          complete
                              ? BusinessProfilePage.successColor
                              : BusinessProfilePage.goldColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: BusinessProfilePage.goldColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _BusinessLogoBadge extends StatelessWidget {
  const _BusinessLogoBadge({required this.logoUrl});

  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final cleanLogoUrl = logoUrl.trim();

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: BusinessProfilePage.fieldColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessProfilePage.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: cleanLogoUrl.isEmpty
            ? const Icon(
                Icons.storefront_outlined,
                color: BusinessProfilePage.goldColor,
                size: 36,
              )
            : Image.network(
                cleanLogoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.storefront_outlined,
                    color: BusinessProfilePage.goldColor,
                    size: 36,
                  );
                },
              ),
      ),
    );
  }
}

class _HeroStatusChip extends StatelessWidget {
  const _HeroStatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: filled
              ? color.withValues(alpha: 0.16)
              : BusinessProfilePage.fieldColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: filled ? color : BusinessProfilePage.borderColor,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: filled ? Colors.white : BusinessProfilePage.softTextColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final location = profile.displayLocation.trim();
    final businessName = profile.businessName.trim().isEmpty
        ? 'Business profile'
        : profile.businessName.trim();
    final isApproved = profile.status == 'approved';
    final isPending = profile.status == 'pending';
    final approvalLabel = isApproved
        ? 'Approved'
        : isPending
            ? 'Pending'
            : profile.status;
    final approvalColor = isApproved
        ? BusinessProfilePage.successColor
        : BusinessProfilePage.warningColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BusinessLogoBadge(logoUrl: profile.logoUrl),
              const SizedBox(width: 13),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: BusinessProfilePage.fieldColor
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: BusinessProfilePage.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              color: BusinessProfilePage.goldColor,
                              size: 18,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: BusinessProfilePage.softTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              _HeroStatusChip(
                icon: isApproved
                    ? Icons.check_circle_outline
                    : Icons.pending_actions_outlined,
                label: approvalLabel,
                color: approvalColor,
                filled: isApproved,
              ),
              const SizedBox(width: 7),
              _HeroStatusChip(
                icon: profile.verified
                    ? Icons.verified_outlined
                    : Icons.radio_button_unchecked,
                label: profile.verified ? 'Verified' : 'Not verified',
                color: profile.verified
                    ? BusinessProfilePage.goldColor
                    : BusinessProfilePage.softTextColor,
                filled: profile.verified,
              ),
              const SizedBox(width: 7),
              _HeroStatusChip(
                icon: profile.premiumIsActive
                    ? Icons.workspace_premium
                    : Icons.lock_outline,
                label: profile.premiumIsActive ? 'Pro active' : 'Pro inactive',
                color: profile.premiumIsActive
                    ? BusinessProfilePage.goldColor
                    : BusinessProfilePage.softTextColor,
                filled: profile.premiumIsActive,
              ),
            ],
          ),
        ],
      ),
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
