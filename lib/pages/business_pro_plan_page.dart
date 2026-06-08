import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import 'business_pro_request_page.dart';

class BusinessProPlanPage extends StatelessWidget {
  const BusinessProPlanPage({
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
    if (value == null) return '';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }

  void _openRequestPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessProRequestPage(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final premiumActive = profile.premiumIsActive;
    final businessName = profile.businessName.trim().isEmpty
        ? 'Your business'
        : profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Business Pro Plan'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _HeroPlanCard(
              businessName: businessName,
              premiumActive: premiumActive,
              statusLabel: profile.premiumStatusLabel,
              expiryText: profile.premiumExpiresAt == null
                  ? 'No expiry date set'
                  : 'Expires ${_formatDate(profile.premiumExpiresAt?.toDate())}',
              onRequest: () => _openRequestPage(context),
            ),
            const SizedBox(height: 16),
            const _SectionHeader(
              icon: Icons.workspace_premium_outlined,
              title: 'Included with Business Pro',
              subtitle: 'The main tools unlocked for business profiles.',
            ),
            const SizedBox(height: 10),
            const _PlanFeatureGrid(),
            const SizedBox(height: 18),
            const _SectionHeader(
              icon: Icons.verified_user_outlined,
              title: 'Current setup',
              subtitle: 'Business Pro is currently managed by admin approval.',
            ),
            const SizedBox(height: 10),
            _CurrentSetupCard(
              premiumActive: premiumActive,
              onRequest: () => _openRequestPage(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPlanCard extends StatelessWidget {
  const _HeroPlanCard({
    required this.businessName,
    required this.premiumActive,
    required this.statusLabel,
    required this.expiryText,
    required this.onRequest,
  });

  final String businessName;
  final bool premiumActive;
  final String statusLabel;
  final String expiryText;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final statusColor = premiumActive
        ? BusinessProPlanPage._successColor
        : BusinessProPlanPage._goldColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BusinessProPlanPage._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor),
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
                premiumActive
                    ? Icons.workspace_premium
                    : Icons.workspace_premium_outlined,
                color: BusinessProPlanPage._goldColor,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusPill(
                icon: premiumActive
                    ? Icons.check_circle_outline
                    : Icons.lock_open_outlined,
                text: statusLabel,
                color: statusColor,
                filled: premiumActive,
              ),
              _StatusPill(
                icon: Icons.schedule_outlined,
                text: expiryText,
                color: BusinessProPlanPage._goldColor,
                filled: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BusinessProPlanPage._goldColor,
                foregroundColor: BusinessProPlanPage._backgroundColor,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                premiumActive ? Icons.update_outlined : Icons.send_outlined,
              ),
              label: Text(
                premiumActive
                    ? 'Request renewal / contact admin'
                    : 'Request Business Pro',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: onRequest,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.text,
    required this.color,
    required this.filled,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.16)
            : BusinessProPlanPage._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? color : BusinessProPlanPage._borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentSetupCard extends StatelessWidget {
  const _CurrentSetupCard({
    required this.premiumActive,
    required this.onRequest,
  });

  final bool premiumActive;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BusinessProPlanPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessProPlanPage._borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BusinessProPlanPage._fieldColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BusinessProPlanPage._borderColor),
            ),
            child: Icon(
              premiumActive
                  ? Icons.admin_panel_settings_outlined
                  : Icons.contact_support_outlined,
              color: BusinessProPlanPage._goldColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premiumActive
                      ? 'Manual admin approval active'
                      : 'Request admin approval',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  premiumActive
                      ? 'Payments are not live yet, so Pro is managed by the app admin.'
                      : 'Send a request and the app admin can review your business profile.',
                  style: const TextStyle(
                    color: BusinessProPlanPage._softTextColor,
                    height: 1.3,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: premiumActive ? 'Request renewal' : 'Request Pro',
            color: BusinessProPlanPage._goldColor,
            icon: const Icon(Icons.chevron_right),
            onPressed: onRequest,
          ),
        ],
      ),
    );
  }
}

class _PlanFeatureGrid extends StatelessWidget {
  const _PlanFeatureGrid();

  static const List<_PlanFeature> _features = <_PlanFeature>[
    _PlanFeature(
      icon: Icons.local_offer_outlined,
      title: 'Offers',
      description: 'Post deals and discount codes.',
    ),
    _PlanFeature(
      icon: Icons.event_outlined,
      title: 'Events',
      description: 'Promote trade nights and tournaments.',
    ),
    _PlanFeature(
      icon: Icons.inventory_2_outlined,
      title: 'Products',
      description: 'Showcase featured stock.',
    ),
    _PlanFeature(
      icon: Icons.mail_outline,
      title: 'Enquiries',
      description: 'Receive customer questions.',
    ),
    _PlanFeature(
      icon: Icons.star_rate_rounded,
      title: 'Reviews',
      description: 'Collect reviews and reply.',
    ),
    _PlanFeature(
      icon: Icons.insights_outlined,
      title: 'Analytics',
      description: 'Track useful customer actions.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: 1.22,
      children: _features
          .map(
            (feature) => _FeatureCard(feature: feature),
          )
          .toList(),
    );
  }
}

class _PlanFeature {
  const _PlanFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _PlanFeature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BusinessProPlanPage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessProPlanPage._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            feature.icon,
            color: BusinessProPlanPage._goldColor,
            size: 25,
          ),
          const Spacer(),
          Text(
            feature.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            feature.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BusinessProPlanPage._softTextColor,
              height: 1.2,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
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
        Icon(icon, color: BusinessProPlanPage._goldColor, size: 22),
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
                  color: BusinessProPlanPage._softTextColor,
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
