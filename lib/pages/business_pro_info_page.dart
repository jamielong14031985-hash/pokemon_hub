import 'package:flutter/material.dart';

class BusinessProInfoPage extends StatelessWidget {
  const BusinessProInfoPage({super.key});

  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Business Pro'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: const [
          _HeroCard(),
          SizedBox(height: 16),
          _SectionTitle(
            icon: Icons.workspace_premium_outlined,
            title: 'What Business Pro includes',
            subtitle:
                'Premium visibility tools for physical TCG shops and online-only sellers.',
          ),
          SizedBox(height: 10),
          _FeatureGrid(),
          SizedBox(height: 16),
          _SectionTitle(
            icon: Icons.payments_outlined,
            title: 'Pricing',
            subtitle:
                'Pricing is not live yet while the feature is being tested.',
          ),
          SizedBox(height: 10),
          _PricingPlaceholderCard(),
          SizedBox(height: 16),
          _SectionTitle(
            icon: Icons.admin_panel_settings_outlined,
            title: 'How activation works for now',
            subtitle:
                'Business Pro is currently controlled by PocketChase admins.',
          ),
          SizedBox(height: 10),
          _AdminApprovalCard(),
          SizedBox(height: 16),
          _SectionTitle(
            icon: Icons.info_outline,
            title: 'Important',
            subtitle:
                'Payments should only be connected after App Store and Google Play purchase verification is added.',
          ),
          SizedBox(height: 10),
          _PaymentSafetyCard(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BusinessProInfoPage._cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: BusinessProInfoPage._goldColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BusinessProInfoPage._goldColor.withValues(alpha: 0.16),
            BusinessProInfoPage._cardColor,
            BusinessProInfoPage._backgroundColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: BusinessProInfoPage._goldColor.withValues(alpha: 0.10),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: BusinessProInfoPage._goldColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: BusinessProInfoPage._goldColor.withValues(alpha: 0.32),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: BusinessProInfoPage._backgroundColor,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PocketChase Business Pro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Promote your TCG business across PocketChase and help collectors find your shop faster.',
            style: TextStyle(
              color: BusinessProInfoPage._softTextColor,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroChip(
                icon: Icons.campaign_outlined,
                label: 'More visibility',
              ),
              _HeroChip(
                icon: Icons.map_outlined,
                label: 'Map promotion',
              ),
              _HeroChip(
                icon: Icons.language,
                label: 'Online shops',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: BusinessProInfoPage._backgroundColor.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: BusinessProInfoPage._goldColor.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: BusinessProInfoPage._goldColor, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
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
      children: [
        Icon(icon, color: BusinessProInfoPage._goldColor),
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
                  color: BusinessProInfoPage._softTextColor,
                  fontSize: 12,
                  height: 1.28,
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

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _BusinessProFeatureCard(
          icon: Icons.view_carousel_outlined,
          title: 'Featured moving banner',
          description:
              'Your business can appear in the moving featured banner at the top of the TCG Shop Map page.',
        ),
        SizedBox(height: 10),
        _BusinessProFeatureCard(
          icon: Icons.storefront_outlined,
          title: 'Featured map shop',
          description:
              'Physical shops can be highlighted on the map with premium placement and a featured marker.',
        ),
        SizedBox(height: 10),
        _BusinessProFeatureCard(
          icon: Icons.language,
          title: 'Featured online shop placement',
          description:
              'Online-only businesses can appear in the Online Shops directory and premium featured areas.',
        ),
        SizedBox(height: 10),
        _BusinessProFeatureCard(
          icon: Icons.forum_outlined,
          title: 'Featured community posts',
          description:
              'Your business posts can be promoted so collectors see them more easily in the community area.',
        ),
        SizedBox(height: 10),
        _BusinessProFeatureCard(
          icon: Icons.image_outlined,
          title: 'Premium business profile',
          description:
              'Show your business name, description, website, contact details, area, and featured banner image.',
        ),
      ],
    );
  }
}

class _BusinessProFeatureCard extends StatelessWidget {
  const _BusinessProFeatureCard({
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
        color: BusinessProInfoPage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessProInfoPage._borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: BusinessProInfoPage._goldColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: BusinessProInfoPage._goldColor.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              icon,
              color: BusinessProInfoPage._goldColor,
              size: 23,
            ),
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
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: BusinessProInfoPage._softTextColor,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.check_circle_outline,
            color: BusinessProInfoPage._successColor,
            size: 21,
          ),
        ],
      ),
    );
  }
}

class _PricingPlaceholderCard extends StatelessWidget {
  const _PricingPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BusinessProInfoPage._fieldColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessProInfoPage._goldColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sell_outlined, color: BusinessProInfoPage._goldColor),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Business Pro pricing is coming soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'For now, this page explains the benefits while you test the feature. Add the real monthly or yearly price here later.',
            style: TextStyle(
              color: BusinessProInfoPage._softTextColor,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminApprovalCard extends StatelessWidget {
  const _AdminApprovalCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BusinessProInfoPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessProInfoPage._borderColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdminStep(
            number: '1',
            title: 'Create a business profile',
            description:
                'Business users create their profile from their business account.',
          ),
          _StepDivider(),
          _AdminStep(
            number: '2',
            title: 'Contact admin to activate Business Pro',
            description:
                'Business Pro access is currently controlled from the admin Business Profiles area.',
          ),
          _StepDivider(),
          _AdminStep(
            number: '3',
            title: 'Admin turns premium on',
            description:
                'Admins can enable premium, featured map shop, and featured post options.',
          ),
        ],
      ),
    );
  }
}

class _AdminStep extends StatelessWidget {
  const _AdminStep({
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
          backgroundColor: BusinessProInfoPage._goldColor,
          child: Text(
            number,
            style: const TextStyle(
              color: BusinessProInfoPage._backgroundColor,
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
                  color: BusinessProInfoPage._softTextColor,
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

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 15, top: 8, bottom: 8),
      height: 18,
      width: 1.5,
      color: BusinessProInfoPage._goldColor.withValues(alpha: 0.45),
    );
  }
}

class _PaymentSafetyCard extends StatelessWidget {
  const _PaymentSafetyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
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
              'When payments are added, Apple and Google purchase verification should activate premium securely. The app should not directly set premiumActive after payment without backend verification.',
              style: TextStyle(
                color: BusinessProInfoPage._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
