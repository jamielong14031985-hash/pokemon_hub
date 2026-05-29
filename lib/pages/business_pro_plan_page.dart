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
              icon: Icons.payments_outlined,
              title: 'Pricing placeholder',
              subtitle: 'Prices can be finalised before payments go live.',
            ),
            const SizedBox(height: 10),
            _PricingCards(
              premiumActive: premiumActive,
              onRequest: () => _openRequestPage(context),
            ),
            const SizedBox(height: 18),
            const _SectionHeader(
              icon: Icons.workspace_premium_outlined,
              title: 'What Business Pro includes',
              subtitle: 'Everything included in the Pro package for shops.',
            ),
            const SizedBox(height: 10),
            const _PlanFeatureGrid(),
            const SizedBox(height: 18),
            const _SectionHeader(
              icon: Icons.verified_user_outlined,
              title: 'How approval works',
              subtitle: 'For now, Pro is controlled manually by the app admin.',
            ),
            const SizedBox(height: 10),
            _ApprovalFlowCard(
              premiumActive: premiumActive,
              onRequest: () => _openRequestPage(context),
            ),
            const SizedBox(height: 18),
            const _SectionHeader(
              icon: Icons.info_outline,
              title: 'Important notes',
              subtitle: 'This can be updated later when payments are added.',
            ),
            const SizedBox(height: 10),
            const _NotesCard(),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BusinessProPlanPage._cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: premiumActive
              ? BusinessProPlanPage._successColor
              : BusinessProPlanPage._goldColor,
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
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: BusinessProPlanPage._fieldColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: BusinessProPlanPage._borderColor),
                ),
                child: Icon(
                  premiumActive
                      ? Icons.workspace_premium
                      : Icons.workspace_premium_outlined,
                  color: BusinessProPlanPage._goldColor,
                  size: 34,
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
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        color: BusinessProPlanPage._softTextColor,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: BusinessProPlanPage._fieldColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BusinessProPlanPage._borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  premiumActive
                      ? Icons.check_circle_outline
                      : Icons.lock_open_outlined,
                  color: premiumActive
                      ? BusinessProPlanPage._successColor
                      : BusinessProPlanPage._goldColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    premiumActive
                        ? 'Business Pro is active. $expiryText.'
                        : 'Business Pro is not active yet. Send a request to the app admin.',
                    style: const TextStyle(
                      color: BusinessProPlanPage._softTextColor,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BusinessProPlanPage._goldColor,
                foregroundColor: BusinessProPlanPage._backgroundColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                premiumActive
                    ? Icons.update_outlined
                    : Icons.send_outlined,
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

class _PricingCards extends StatelessWidget {
  const _PricingCards({
    required this.premiumActive,
    required this.onRequest,
  });

  final bool premiumActive;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PriceCard(
          title: 'Monthly Pro',
          price: 'Price placeholder',
          subtitle: 'Flexible monthly Business Pro access.',
          badge: 'Monthly',
          highlighted: false,
          onRequest: onRequest,
        ),
        const SizedBox(height: 10),
        _PriceCard(
          title: 'Yearly Pro',
          price: 'Price placeholder',
          subtitle: 'Best for shops that want long-term visibility.',
          badge: 'Best value',
          highlighted: true,
          onRequest: onRequest,
        ),
        const SizedBox(height: 10),
        _PriceCard(
          title: 'Manual admin approval',
          price: premiumActive ? 'Currently active' : 'Request access',
          subtitle:
              'Payments are not live yet, so admin reviews and activates Pro manually.',
          badge: 'Current setup',
          highlighted: premiumActive,
          onRequest: onRequest,
        ),
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.badge,
    required this.highlighted,
    required this.onRequest,
  });

  final String title;
  final String price;
  final String subtitle;
  final String badge;
  final bool highlighted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BusinessProPlanPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlighted
              ? BusinessProPlanPage._goldColor
              : BusinessProPlanPage._borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: BusinessProPlanPage._fieldColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BusinessProPlanPage._borderColor),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: BusinessProPlanPage._goldColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _TinyBadge(text: badge),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    color: BusinessProPlanPage._goldColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: BusinessProPlanPage._softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Request this plan',
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
      icon: Icons.view_carousel_outlined,
      title: 'Featured moving banner',
      description: 'Use a business image to appear in the moving Pro banner.',
    ),
    _PlanFeature(
      icon: Icons.map_outlined,
      title: 'Featured map shop',
      description: 'Extra visibility for physical shops on the TCG Shop Map.',
    ),
    _PlanFeature(
      icon: Icons.language,
      title: 'Featured online shop',
      description: 'Online-only shops can stand out in online shop areas.',
    ),
    _PlanFeature(
      icon: Icons.campaign_outlined,
      title: 'Featured community posts',
      description: 'Eligible business posts can get extra visibility.',
    ),
    _PlanFeature(
      icon: Icons.local_offer_outlined,
      title: 'Offers & deals',
      description: 'Post offers, discounts, codes and announcements.',
    ),
    _PlanFeature(
      icon: Icons.event_outlined,
      title: 'Shop events',
      description: 'Promote trade nights, tournaments and releases.',
    ),
    _PlanFeature(
      icon: Icons.inventory_2_outlined,
      title: 'Product showcase',
      description: 'Show featured products, prices and product links.',
    ),
    _PlanFeature(
      icon: Icons.mail_outline,
      title: 'Customer enquiries',
      description: 'Receive questions about stock, events and products.',
    ),
    _PlanFeature(
      icon: Icons.star_rate_rounded,
      title: 'Reviews and replies',
      description: 'Customers can rate shops and businesses can reply.',
    ),
    _PlanFeature(
      icon: Icons.insights_outlined,
      title: 'Business analytics',
      description: 'Track profile views and useful customer actions.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BusinessProPlanPage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessProPlanPage._borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            feature.icon,
            color: BusinessProPlanPage._goldColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: const TextStyle(
                    color: BusinessProPlanPage._softTextColor,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _ApprovalFlowCard extends StatelessWidget {
  const _ApprovalFlowCard({
    required this.premiumActive,
    required this.onRequest,
  });

  final bool premiumActive;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BusinessProPlanPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessProPlanPage._borderColor),
      ),
      child: Column(
        children: [
          _ApprovalStep(
            number: '1',
            title: premiumActive ? 'Request renewal' : 'Request Business Pro',
            description:
                'The business sends a Pro request from inside PocketChase.',
            active: true,
          ),
          const _ApprovalStep(
            number: '2',
            title: 'Admin reviews request',
            description:
                'Admin checks the business profile and decides whether to approve.',
            active: true,
          ),
          const _ApprovalStep(
            number: '3',
            title: 'Admin activates Pro',
            description:
                'Admin sets Pro active, start date, expiry date and any notes.',
            active: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: BusinessProPlanPage._goldColor,
                side: const BorderSide(color: BusinessProPlanPage._goldColor),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.contact_support_outlined),
              label: Text(
                premiumActive
                    ? 'Request renewal'
                    : 'Contact admin about Pro',
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

class _ApprovalStep extends StatelessWidget {
  const _ApprovalStep({
    required this.number,
    required this.title,
    required this.description,
    required this.active,
  });

  final String number;
  final String title;
  final String description;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? BusinessProPlanPage._goldColor
                  : BusinessProPlanPage._fieldColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: active
                    ? BusinessProPlanPage._backgroundColor
                    : BusinessProPlanPage._softTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: BusinessProPlanPage._softTextColor,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _NotesCard extends StatelessWidget {
  const _NotesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BusinessProPlanPage._fieldColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessProPlanPage._borderColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoteLine(
            icon: Icons.admin_panel_settings_outlined,
            text:
                'For now, Pro access is activated manually by admin approval.',
          ),
          _NoteLine(
            icon: Icons.payments_outlined,
            text:
                'Monthly and yearly prices are placeholders until you choose final pricing.',
          ),
          _NoteLine(
            icon: Icons.lock_outline,
            text:
                'Businesses cannot give themselves Pro access because premium fields are protected.',
          ),
          _NoteLine(
            icon: Icons.update_outlined,
            text:
                'Renewals can be requested from this page or the Business Pro request page.',
          ),
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: BusinessProPlanPage._goldColor,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BusinessProPlanPage._softTextColor,
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

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BusinessProPlanPage._goldColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: BusinessProPlanPage._backgroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
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
