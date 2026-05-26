import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
    required this.profile,
    required this.onStart,
  });

  final AppUserProfile profile;
  final Future<void> Function() onStart;

  String get _displayName {
    final name = profile.displayName.trim();
    return name.isEmpty ? 'Trainer' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      body: SafeArea(
        child: Stack(
          children: [
            const _WelcomeGlow(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: [
                    const SizedBox(height: 8),
                    _HeroCard(
                      displayName: _displayName,
                      isBusinessAccount: profile.isBusinessAccount,
                    ),
                    const SizedBox(height: 16),
                    _FeatureGrid(isBusinessAccount: profile.isBusinessAccount),
                    const SizedBox(height: 18),
                    _StartButton(
                      onStart: onStart,
                      isBusinessAccount: profile.isBusinessAccount,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You can update your profile, collection, wishlist, and community settings anytime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFAFC0E6),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeGlow extends StatelessWidget {
  const _WelcomeGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -90,
          child: _GlowOrb(
            size: 240,
            color: const Color(0xFFF7DE77),
            alpha: 0.11,
          ),
        ),
        Positioned(
          bottom: -130,
          left: -110,
          child: _GlowOrb(
            size: 270,
            color: const Color(0xFF2F6DD7),
            alpha: 0.16,
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.alpha,
  });

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: alpha * 1.8),
            blurRadius: 90,
            spreadRadius: 35,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.displayName,
    required this.isBusinessAccount,
  });

  final String displayName;
  final bool isBusinessAccount;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
              border: Border.all(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.38),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.22),
                  blurRadius: 26,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.catching_pokemon_rounded,
              color: Color(0xFFF7DE77),
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isBusinessAccount
                ? 'Welcome to PocketChase Business, $displayName'
                : 'Welcome to PocketChase, $displayName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isBusinessAccount
                ? 'Set up your business account, create your business profile, and get ready for future Business Pro tools.'
                : 'Your Pokémon collecting hub for searching cards, tracking master sets, scanning your collection, and connecting with collectors.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD8E3FB),
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.isBusinessAccount});

  final bool isBusinessAccount;

  @override
  Widget build(BuildContext context) {
    final features = isBusinessAccount
        ? const [
            _Feature(
              Icons.storefront_outlined,
              'Business profile',
              'Add your shop or business details.',
            ),
            _Feature(
              Icons.map_outlined,
              'Shop map ready',
              'Link a shop listing later if needed.',
            ),
            _Feature(
              Icons.workspace_premium_outlined,
              'Business Pro',
              'Premium features coming soon.',
            ),
            _Feature(
              Icons.forum_outlined,
              'Community',
              'Connect with local collectors.',
            ),
          ]
        : const [
      _Feature(
        Icons.search_rounded,
        'Search cards',
        'Find cards, sets and prices.',
      ),
      _Feature(
        Icons.document_scanner_outlined,
        'Scan cards',
        'Identify cards from your camera.',
      ),
      _Feature(
        Icons.collections_bookmark_outlined,
        'Master sets',
        'Track set progress.',
      ),
      _Feature(
        Icons.forum_outlined,
        'Community',
        'Message, trade and connect.',
      ),
      _Feature(
        Icons.notifications_active_outlined,
        'Restocks',
        'Watch products for stock.',
      ),
      _Feature(
        Icons.workspace_premium_outlined,
        'Achievements',
        'Unlock long-term goals.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 520;
        final itemWidth =
            twoColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: features
              .map(
                (feature) => SizedBox(
                  width: itemWidth,
                  child: _FeatureCard(feature: feature),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF102754).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF7DE77).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(feature.icon, color: const Color(0xFFF7DE77), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  feature.description,
                  style: const TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 12.5,
                    height: 1.35,
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173A78), Color(0xFF102754), Color(0xFF071D4A)],
        ),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFF7DE77).withValues(alpha: 0.12),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StartButton extends StatefulWidget {
  const _StartButton({
    required this.onStart,
    required this.isBusinessAccount,
  });

  final Future<void> Function() onStart;
  final bool isBusinessAccount;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _starting = false;

  Future<void> _handleStart() async {
    if (_starting) return;

    setState(() => _starting = true);

    try {
      await widget.onStart();
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _starting ? null : _handleStart,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF7DE77),
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      icon: _starting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_forward_rounded),
      label: Text(
        _starting
            ? 'Opening PocketChase...'
            : widget.isBusinessAccount
                ? 'Start business setup'
                : 'Start collecting',
      ),
    );
  }
}
