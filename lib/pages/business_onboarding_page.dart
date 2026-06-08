import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import 'business_profile_editor_page.dart';

class BusinessOnboardingPage extends StatelessWidget {
  const BusinessOnboardingPage({
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
  static const Color _warningColor = Color(0xFFFBBF24);

  List<_OnboardingStep> _requiredSteps(BuildContext context) {
    return <_OnboardingStep>[
      _OnboardingStep(
        icon: Icons.badge_outlined,
        title: 'Business details',
        subtitle: 'Name, website, phone and location.',
        complete: profile.hasRequiredBusinessDetails,
        actionLabel: 'Edit',
        onTap: () => _openEditor(context),
      ),
      _OnboardingStep(
        icon: Icons.storefront_outlined,
        title: 'Shop type & map link',
        subtitle: profile.hasPhysicalShop
            ? 'Physical shop should be linked to the map once.'
            : 'Online-only businesses do not need a map listing.',
        complete: !profile.hasPhysicalShop || profile.hasLinkedShop,
        actionLabel: profile.hasPhysicalShop ? 'Link' : 'Review',
        onTap: () => _openEditor(context),
      ),
      _OnboardingStep(
        icon: Icons.schedule_outlined,
        title: 'Opening hours',
        subtitle: 'Set opening times or use the quick open/closed toggle.',
        complete: profile.hasAnyOpeningHours,
        actionLabel: 'Set',
        onTap: () => _openEditor(context),
      ),
      _OnboardingStep(
        icon: Icons.image_outlined,
        title: 'Images',
        subtitle: 'Add a logo or banner for the public profile.',
        complete: profile.logoUrl.trim().isNotEmpty ||
            profile.bannerUrl.trim().isNotEmpty,
        actionLabel: 'Add',
        onTap: () => _openEditor(context),
      ),
    ];
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessProfileEditorPage(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requiredSteps = _requiredSteps(context);
    final completeCount = requiredSteps.where((step) => step.complete).length;
    final requiredTotal = requiredSteps.length;
    final progress = requiredTotal == 0 ? 0.0 : completeCount / requiredTotal;
    final setupComplete = completeCount == requiredTotal;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Business Setup'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _SetupHeroCard(
            profile: profile,
            completeCount: completeCount,
            totalCount: requiredTotal,
            progress: progress,
            setupComplete: setupComplete,
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            icon: Icons.checklist_rounded,
            title: 'Required setup',
            subtitle: 'Complete the basics customers need to see.',
          ),
          const SizedBox(height: 10),
          ...requiredSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _OnboardingStepCard(step: step),
            ),
          ),
          const SizedBox(height: 8),
          _NextBestActionCard(
            setupComplete: setupComplete,
            onEditProfile: () => _openEditor(context),
          ),
        ],
      ),
    );
  }
}

class _SetupHeroCard extends StatelessWidget {
  const _SetupHeroCard({
    required this.profile,
    required this.completeCount,
    required this.totalCount,
    required this.progress,
    required this.setupComplete,
  });

  final BusinessProfile profile;
  final int completeCount;
  final int totalCount;
  final double progress;
  final bool setupComplete;

  @override
  Widget build(BuildContext context) {
    final businessName = profile.businessName.trim().isEmpty
        ? 'Your business'
        : profile.businessName.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BusinessOnboardingPage._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: setupComplete
              ? BusinessOnboardingPage._successColor
              : BusinessOnboardingPage._goldColor,
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
            children: [
              Icon(
                setupComplete
                    ? Icons.verified_outlined
                    : Icons.rocket_launch_outlined,
                color: setupComplete
                    ? BusinessOnboardingPage._successColor
                    : BusinessOnboardingPage._goldColor,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniBadge(
                icon: setupComplete
                    ? Icons.check_circle_outline
                    : Icons.pending_actions_outlined,
                label: setupComplete
                    ? 'Setup complete'
                    : '$completeCount of $totalCount complete',
                highlighted: setupComplete,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 9,
                    backgroundColor: BusinessOnboardingPage._fieldColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      setupComplete
                          ? BusinessOnboardingPage._successColor
                          : BusinessOnboardingPage._goldColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(
                icon: profile.isApproved
                    ? Icons.check_circle_outline
                    : Icons.pending_actions_outlined,
                label: profile.isApproved ? 'Approved' : 'Pending approval',
                highlighted: profile.isApproved,
              ),
              _MiniBadge(
                icon: profile.openingStatus == 'open'
                    ? Icons.lock_open_outlined
                    : profile.openingStatus == 'closed'
                        ? Icons.lock_outline
                        : Icons.schedule_outlined,
                label: profile.openStatusLabel,
                highlighted: profile.openingStatus == 'open',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool complete;
  final String actionLabel;
  final VoidCallback onTap;
}

class _OnboardingStepCard extends StatelessWidget {
  const _OnboardingStepCard({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final statusColor = step.complete
        ? BusinessOnboardingPage._successColor
        : BusinessOnboardingPage._warningColor;

    return Material(
      color: BusinessOnboardingPage._cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: step.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: step.complete
                  ? BusinessOnboardingPage._borderColor
                  : BusinessOnboardingPage._warningColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: BusinessOnboardingPage._fieldColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: BusinessOnboardingPage._borderColor,
                  ),
                ),
                child: Icon(
                  step.icon,
                  color: BusinessOnboardingPage._goldColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          step.complete
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          color: statusColor,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            step.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BusinessOnboardingPage._softTextColor,
                        height: 1.22,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.complete ? 'Done' : step.actionLabel,
                    style: TextStyle(
                      color: step.complete
                          ? BusinessOnboardingPage._successColor
                          : BusinessOnboardingPage._goldColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.chevron_right,
                    color: step.complete
                        ? BusinessOnboardingPage._successColor
                        : BusinessOnboardingPage._goldColor,
                    size: 21,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextBestActionCard extends StatelessWidget {
  const _NextBestActionCard({
    required this.setupComplete,
    required this.onEditProfile,
  });

  final bool setupComplete;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final title = setupComplete ? 'Setup complete' : 'Finish setup';
    final body = setupComplete
        ? 'Your required business setup is ready. Use Quick Actions for Pro tools, analytics, offers, events and enquiries.'
        : 'Tap any item above, or continue editing the profile to finish the missing setup.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: setupComplete
            ? BusinessOnboardingPage._successColor.withValues(alpha: 0.12)
            : BusinessOnboardingPage._goldColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: setupComplete
              ? BusinessOnboardingPage._successColor
              : BusinessOnboardingPage._goldColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            setupComplete
                ? Icons.check_circle_outline
                : Icons.lightbulb_outline,
            color: setupComplete
                ? BusinessOnboardingPage._successColor
                : BusinessOnboardingPage._goldColor,
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
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: BusinessOnboardingPage._softTextColor,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!setupComplete) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: BusinessOnboardingPage._goldColor,
                      foregroundColor: BusinessOnboardingPage._backgroundColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(
                      'Continue setup',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onPressed: onEditProfile,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? BusinessOnboardingPage._successColor
        : BusinessOnboardingPage._goldColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.14)
            : BusinessOnboardingPage._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? color : BusinessOnboardingPage._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
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
        Icon(icon, color: BusinessOnboardingPage._goldColor, size: 22),
        const SizedBox(width: 8),
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
                  color: BusinessOnboardingPage._softTextColor,
                  height: 1.3,
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
