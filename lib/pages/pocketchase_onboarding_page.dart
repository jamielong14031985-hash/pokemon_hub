import 'dart:async';

import 'package:flutter/material.dart';

class PocketChaseOnboardingPage extends StatefulWidget {
  const PocketChaseOnboardingPage({
    super.key,
    this.profile,
    this.currentProfile,
    this.onFinished,
    this.onFinish,
    this.onComplete,
    this.onDone,
    this.onGetStarted,
    this.onSkip,
    this.onClose,
    this.showCloseButton = true,
  });

  /// Kept as Object? so this page stays compatible with AppUserProfile without
  /// importing your profile model here.
  final Object? profile;
  final Object? currentProfile;

  /// Multiple callback names are supported so this file works with whichever
  /// callback AppShell currently uses.
  final FutureOr<void> Function()? onFinished;
  final FutureOr<void> Function()? onFinish;
  final FutureOr<void> Function()? onComplete;
  final FutureOr<void> Function()? onDone;
  final FutureOr<void> Function()? onGetStarted;
  final FutureOr<void> Function()? onSkip;
  final FutureOr<void> Function()? onClose;
  final bool showCloseButton;

  @override
  State<PocketChaseOnboardingPage> createState() =>
      _PocketChaseOnboardingPageState();
}

class _PocketChaseOnboardingPageState extends State<PocketChaseOnboardingPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _darkBackgroundColor = Color(0xFF020D26);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _greenColor = Color(0xFF4ADE80);

  late final PageController _pageController;
  int _currentPage = 0;
  bool _closing = false;

  final List<_GuideSlide> _slides = const <_GuideSlide>[
    _GuideSlide(
      title: 'Search the hobby faster',
      subtitle:
          'Find Pokémon cards, sets and collection numbers with a clean card-first search experience.',
      eyebrow: 'Card search',
      buttonLabel: 'Next',
      icon: Icons.style_outlined,
      kind: _PreviewKind.search,
      bullets: <String>[
        'Search by card, set or number',
        'Open details instantly',
        'See clear card images',
      ],
    ),
    _GuideSlide(
      title: 'Scan cards quickly',
      subtitle:
          'Use the scanner to line up a card, identify it, and jump into the card details screen faster.',
      eyebrow: 'Card scanner',
      buttonLabel: 'Next',
      icon: Icons.document_scanner_outlined,
      kind: _PreviewKind.scan,
      bullets: <String>[
        'Open the scanner',
        'Line up your card',
        'Check the card details',
      ],
    ),
    _GuideSlide(
      title: 'Build your Master Sets',
      subtitle:
          'Track what you own, add duplicate copies, and keep normal, reverse holo and holo cards separate.',
      eyebrow: 'Collection tracking',
      buttonLabel: 'Next',
      icon: Icons.collections_bookmark_outlined,
      kind: _PreviewKind.masterSets,
      bullets: <String>[
        'Tap cards to update them',
        'Hold grey cards to add quickly',
        'See progress at a glance',
      ],
    ),
    _GuideSlide(
      title: 'Check raw prices',
      subtitle:
          'Use live raw price estimates and refresh cards when you want to check newer market data.',
      eyebrow: 'Price tools',
      buttonLabel: 'Next',
      icon: Icons.sell_outlined,
      kind: _PreviewKind.prices,
      bullets: <String>[
        'Raw price estimates',
        'Manual refresh button',
        'Sold-results shortcut',
      ],
    ),
    _GuideSlide(
      title: 'Discover shops and events',
      subtitle:
          'Find local TCG shops, online shops, events and offers from one map directory.',
      eyebrow: 'Shop map',
      buttonLabel: 'Next',
      icon: Icons.map_outlined,
      kind: _PreviewKind.map,
      bullets: <String>[
        'Local shop map',
        'Events and offers',
        'Online shop directory',
      ],
    ),
    _GuideSlide(
      title: 'Connect with collectors',
      subtitle:
          'Post, reply, message and arrange swaps with other collectors in the community area.',
      eyebrow: 'Community',
      buttonLabel: 'Get started',
      icon: Icons.forum_outlined,
      kind: _PreviewKind.community,
      bullets: <String>[
        'Create posts and listings',
        'Message safely',
        'Keep replies organised',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _runCallback(FutureOr<void> Function()? callback) async {
    if (callback == null) return;
    await callback();
  }

  Future<void> _finish({bool skipped = false}) async {
    if (_closing) return;
    setState(() => _closing = true);

    try {
      if (skipped) {
        await _runCallback(widget.onSkip);
      }

      await _runCallback(
        widget.onFinished ??
            widget.onFinish ??
            widget.onComplete ??
            widget.onDone ??
            widget.onGetStarted ??
            widget.onClose,
      );

      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _closing = false);
      }
    }
  }

  Future<void> _next() async {
    if (_currentPage >= _slides.length - 1) {
      await _finish();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    if (_currentPage <= 0) return;

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF08245A),
              _backgroundColor,
              _darkBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildTopBar(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _OnboardingSlideView(
                      slide: _slides[index],
                      index: index,
                      totalSlides: _slides.length,
                      cardColor: _cardColor,
                      fieldColor: _fieldColor,
                      borderColor: _borderColor,
                      goldColor: _goldColor,
                      softTextColor: _softTextColor,
                      greenColor: _greenColor,
                    );
                  },
                ),
              ),
              _buildBottomControls(isLastPage: isLastPage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _goldColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: _goldColor.withValues(alpha: 0.30)),
            ),
            child: const Icon(
              Icons.catching_pokemon_rounded,
              color: _goldColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PocketChase',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Quick app guide',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _softTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (widget.showCloseButton)
            TextButton(
              onPressed: _closing ? null : () => _finish(skipped: true),
              style: TextButton.styleFrom(
                foregroundColor: _softTextColor,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls({required bool isLastPage}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      decoration: BoxDecoration(
        color: _darkBackgroundColor.withValues(alpha: 0.72),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(_slides.length, (index) {
              final selected = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: selected
                      ? _goldColor
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _currentPage == 0 || _closing ? null : _back,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white24,
                    side: BorderSide(
                      color: _currentPage == 0
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _closing ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: _goldColor,
                    foregroundColor: _backgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isLastPage ? 'Get Started' : _slides[_currentPage].buttonLabel,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({
    required this.slide,
    required this.index,
    required this.totalSlides,
    required this.cardColor,
    required this.fieldColor,
    required this.borderColor,
    required this.goldColor,
    required this.softTextColor,
    required this.greenColor,
  });

  final _GuideSlide slide;
  final int index;
  final int totalSlides;
  final Color cardColor;
  final Color fieldColor;
  final Color borderColor;
  final Color goldColor;
  final Color softTextColor;
  final Color greenColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 610;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            18,
            compactHeight ? 6 : 10,
            18,
            compactHeight ? 14 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _PremiumPreviewCard(
                slide: slide,
                cardColor: cardColor,
                fieldColor: fieldColor,
                borderColor: borderColor,
                goldColor: goldColor,
                softTextColor: softTextColor,
                greenColor: greenColor,
                compactHeight: compactHeight,
              ),
              SizedBox(height: compactHeight ? 18 : 24),
              _SlideTextPanel(
                slide: slide,
                index: index,
                totalSlides: totalSlides,
                goldColor: goldColor,
                softTextColor: softTextColor,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PremiumPreviewCard extends StatelessWidget {
  const _PremiumPreviewCard({
    required this.slide,
    required this.cardColor,
    required this.fieldColor,
    required this.borderColor,
    required this.goldColor,
    required this.softTextColor,
    required this.greenColor,
    required this.compactHeight,
  });

  final _GuideSlide slide;
  final Color cardColor;
  final Color fieldColor;
  final Color borderColor;
  final Color goldColor;
  final Color softTextColor;
  final Color greenColor;
  final bool compactHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: goldColor.withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: goldColor.withValues(alpha: 0.30)),
                ),
                child: Icon(slide.icon, color: goldColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  slide.eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: greenColor,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: greenColor.withValues(alpha: 0.55),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PhonePreviewFrame(
            kind: slide.kind,
            height: compactHeight ? 288 : 345,
            fieldColor: fieldColor,
            borderColor: borderColor,
            goldColor: goldColor,
            softTextColor: softTextColor,
            greenColor: greenColor,
          ),
        ],
      ),
    );
  }
}

class _SlideTextPanel extends StatelessWidget {
  const _SlideTextPanel({
    required this.slide,
    required this.index,
    required this.totalSlides,
    required this.goldColor,
    required this.softTextColor,
  });

  final _GuideSlide slide;
  final int index;
  final int totalSlides;
  final Color goldColor;
  final Color softTextColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '0${index + 1} / 0$totalSlides',
          style: TextStyle(
            color: goldColor,
            fontSize: 12,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slide.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          slide.subtitle,
          style: TextStyle(
            color: softTextColor,
            fontSize: 15,
            height: 1.38,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slide.bullets.map((bullet) {
            return _FeaturePill(
              text: bullet,
              goldColor: goldColor,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.text,
    required this.goldColor,
  });

  final String text;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_rounded, color: goldColor, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhonePreviewFrame extends StatelessWidget {
  const _PhonePreviewFrame({
    required this.kind,
    required this.height,
    required this.fieldColor,
    required this.borderColor,
    required this.goldColor,
    required this.softTextColor,
    required this.greenColor,
  });

  final _PreviewKind kind;
  final double height;
  final Color fieldColor;
  final Color borderColor;
  final Color goldColor;
  final Color softTextColor;
  final Color greenColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 0.62,
        child: Container(
          constraints: BoxConstraints(maxHeight: height),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF020D26),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              color: const Color(0xFF041B4A),
              child: Column(
                children: <Widget>[
                  _MiniStatusBar(goldColor: goldColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: _buildPreview(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    switch (kind) {
      case _PreviewKind.search:
        return _SearchPreview(
          fieldColor: fieldColor,
          borderColor: borderColor,
          goldColor: goldColor,
          softTextColor: softTextColor,
        );
      case _PreviewKind.scan:
        return _ScanPreview(
          fieldColor: fieldColor,
          borderColor: borderColor,
          goldColor: goldColor,
          greenColor: greenColor,
          softTextColor: softTextColor,
        );
      case _PreviewKind.masterSets:
        return _MasterSetsPreview(
          fieldColor: fieldColor,
          borderColor: borderColor,
          goldColor: goldColor,
          greenColor: greenColor,
          softTextColor: softTextColor,
        );
      case _PreviewKind.prices:
        return _PricesPreview(
          fieldColor: fieldColor,
          borderColor: borderColor,
          goldColor: goldColor,
          greenColor: greenColor,
          softTextColor: softTextColor,
        );
      case _PreviewKind.map:
        return _MapPreview(
          fieldColor: fieldColor,
          borderColor: borderColor,
          goldColor: goldColor,
          greenColor: greenColor,
          softTextColor: softTextColor,
        );
      case _PreviewKind.community:
        return _CommunityPreview(
          fieldColor: fieldColor,
          borderColor: borderColor,
          goldColor: goldColor,
          greenColor: greenColor,
          softTextColor: softTextColor,
        );
    }
  }
}

class _MiniStatusBar extends StatelessWidget {
  const _MiniStatusBar({required this.goldColor});

  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Text(
            'PocketChase',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Container(
            width: 22,
            height: 4,
            decoration: BoxDecoration(
              color: goldColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPreview extends StatelessWidget {
  const _SearchPreview({
    required this.fieldColor,
    required this.borderColor,
    required this.goldColor,
    required this.softTextColor,
  });

  final Color fieldColor;
  final Color borderColor;
  final Color goldColor;
  final Color softTextColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AppLikeHeader(
          title: 'PocketChase',
          subtitle: 'Search cards, sets and collection numbers',
          icon: Icons.style_outlined,
          goldColor: goldColor,
          softTextColor: softTextColor,
        ),
        const SizedBox(height: 8),
        _MiniSearchBar(fieldColor: fieldColor, borderColor: borderColor),
        const SizedBox(height: 7),
        Row(
          children: <Widget>[
            _MiniFilterPill(
              label: 'Cards',
              selected: true,
              goldColor: goldColor,
              fieldColor: fieldColor,
              borderColor: borderColor,
            ),
            const SizedBox(width: 6),
            _MiniFilterPill(
              label: 'Sets',
              selected: false,
              goldColor: goldColor,
              fieldColor: fieldColor,
              borderColor: borderColor,
            ),
            const SizedBox(width: 6),
            _MiniFilterPill(
              label: 'Number',
              selected: false,
              goldColor: goldColor,
              fieldColor: fieldColor,
              borderColor: borderColor,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.64,
            children: const <Widget>[
              _MiniCardTile(
                title: 'Charizard',
                tag: 'x2',
                owned: true,
                imageUrl: 'https://images.pokemontcg.io/base1/4_hires.png',
              ),
              _MiniCardTile(
                title: 'Pikachu',
                tag: 'Base',
                owned: false,
                imageUrl: 'https://images.pokemontcg.io/base1/58_hires.png',
              ),
              _MiniCardTile(
                title: 'Blastoise',
                tag: 'x1',
                owned: true,
                imageUrl: 'https://images.pokemontcg.io/base1/2_hires.png',
              ),
              _MiniCardTile(
                title: 'Venusaur',
                tag: 'Base',
                owned: false,
                imageUrl: 'https://images.pokemontcg.io/base1/15_hires.png',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _MiniBottomNavigation(selectedIndex: 0, goldColor: goldColor),
      ],
    );
  }
}

class _MasterSetsPreview extends StatelessWidget {
  const _MasterSetsPreview({
    required this.fieldColor,
    required this.borderColor,
    required this.goldColor,
    required this.greenColor,
    required this.softTextColor,
  });

  final Color fieldColor;
  final Color borderColor;
  final Color goldColor;
  final Color greenColor;
  final Color softTextColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AppLikeHeader(
          title: 'Master Sets',
          subtitle: 'Track and manage your sets',
          icon: Icons.collections_bookmark_outlined,
          goldColor: goldColor,
          softTextColor: softTextColor,
        ),
        const SizedBox(height: 8),
        _MasterSetProgressCard(
          goldColor: goldColor,
          borderColor: borderColor,
          softTextColor: softTextColor,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: borderColor),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.search, color: Color(0xFFC8D4F0), size: 15),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Search set cards',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: goldColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.tune_rounded, color: Color(0xFF041B4A), size: 15),
                  SizedBox(width: 4),
                  Text(
                    'Owned',
                    style: TextStyle(
                      color: Color(0xFF041B4A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.66,
            children: <Widget>[
              _SetSlotTile(
                label: 'x3',
                color: goldColor,
                owned: true,
                imageUrl: 'https://images.pokemontcg.io/base1/4_hires.png',
              ),
              _SetSlotTile(
                label: 'RH',
                color: fieldColor,
                owned: false,
                imageUrl: 'https://images.pokemontcg.io/base1/4_hires.png',
              ),
              _SetSlotTile(
                label: 'H',
                color: fieldColor,
                owned: false,
                imageUrl: 'https://images.pokemontcg.io/base1/4_hires.png',
              ),
              _SetSlotTile(
                label: 'x1',
                color: goldColor,
                owned: true,
                imageUrl: 'https://images.pokemontcg.io/base1/58_hires.png',
              ),
              _SetSlotTile(
                label: 'x2',
                color: goldColor,
                owned: true,
                imageUrl: 'https://images.pokemontcg.io/base1/2_hires.png',
              ),
              _SetSlotTile(
                label: '',
                color: fieldColor,
                owned: false,
                imageUrl: 'https://images.pokemontcg.io/base1/15_hires.png',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _MiniBottomNavigation(selectedIndex: 2, goldColor: goldColor),
      ],
    );
  }
}

class _AppLikeHeader extends StatelessWidget {
  const _AppLikeHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.goldColor,
    required this.softTextColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color goldColor;
  final Color softTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.07),
            const Color(0xFF173A78).withValues(alpha: 0.20),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: goldColor.withValues(alpha: 0.14),
              border: Border.all(color: goldColor.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: goldColor, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: softTextColor,
                    fontSize: 9.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 17),
          ),
        ],
      ),
    );
  }
}

class _MiniFilterPill extends StatelessWidget {
  const _MiniFilterPill({
    required this.label,
    required this.selected,
    required this.goldColor,
    required this.fieldColor,
    required this.borderColor,
  });

  final String label;
  final bool selected;
  final Color goldColor;
  final Color fieldColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? goldColor : fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? goldColor : borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFF041B4A) : Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MasterSetProgressCard extends StatelessWidget {
  const _MasterSetProgressCard({
    required this.goldColor,
    required this.borderColor,
    required this.softTextColor,
  });

  final Color goldColor;
  final Color borderColor;
  final Color softTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CircularProgressIndicator(
                  value: 0.72,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  color: goldColor,
                ),
                const Center(
                  child: Text(
                    '72%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Base Set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Normal • Reverse Holo • Holo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: softTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: goldColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: goldColor.withValues(alpha: 0.36)),
            ),
            child: Text(
              '102 cards',
              style: TextStyle(
                color: goldColor,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBottomNavigation extends StatelessWidget {
  const _MiniBottomNavigation({
    required this.selectedIndex,
    required this.goldColor,
  });

  final int selectedIndex;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    const items = <_MiniNavItemData>[
      _MiniNavItemData(Icons.style_outlined, Icons.style, 'Cards'),
      _MiniNavItemData(Icons.document_scanner_outlined, Icons.document_scanner, 'Scan'),
      _MiniNavItemData(Icons.collections_bookmark_outlined, Icons.collections_bookmark, 'Sets'),
      _MiniNavItemData(Icons.map_outlined, Icons.map, 'Map'),
      _MiniNavItemData(Icons.forum_outlined, Icons.forum, 'Community'),
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B214F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: List<Widget>.generate(items.length, (index) {
          final item = items[index];
          final selected = index == selectedIndex;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? goldColor : Colors.white54,
                  size: 15,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? goldColor : Colors.white54,
                    fontSize: item.label == 'Community' ? 6.5 : 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _MiniNavItemData {
  const _MiniNavItemData(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _PricesPreview extends StatelessWidget {
  const _PricesPreview({
    required this.fieldColor,
    required this.borderColor,
    required this.goldColor,
    required this.greenColor,
    required this.softTextColor,
  });

  final Color fieldColor;
  final Color borderColor;
  final Color goldColor;
  final Color greenColor;
  final Color softTextColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PreviewHeader(title: 'Card Details', subtitle: 'Prices and collection'),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 0.72,
              child: _PokemonCardImage(
                imageUrl: 'https://images.pokemontcg.io/base1/4_hires.png',
                borderRadius: BorderRadius.circular(18),
                borderColor: goldColor,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _InfoPanel(
          icon: Icons.sell_outlined,
          title: 'Raw Price',
          value: '£12.80',
          accentColor: greenColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _SmallActionButton(label: 'Refresh', color: goldColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SmallActionButton(label: 'Add Card', color: greenColor),
            ),
          ],
        ),
      ],
    );
  }
}


class _ScanPreview extends StatelessWidget {
  const _ScanPreview({
    required this.fieldColor,
    required this.borderColor,
    required this.goldColor,
    required this.greenColor,
    required this.softTextColor,
  });

  final Color fieldColor;
  final Color borderColor;
  final Color goldColor;
  final Color greenColor;
  final Color softTextColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PreviewHeader(title: 'Scan Card', subtitle: 'Camera card scanner'),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF020D26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFF0E2C63),
                          Color(0xFF06183A),
                          Color(0xFF102754),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScannerGridPainter(
                      lineColor: Colors.white.withValues(alpha: 0.07),
                      glowColor: goldColor.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 54,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: goldColor, width: 2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: goldColor.withValues(alpha: 0.16),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: _PokemonCardImage(
                              imageUrl: 'https://images.pokemontcg.io/base1/4_hires.png',
                              borderRadius: BorderRadius.circular(14),
                              borderColor: Colors.white.withValues(alpha: 0.22),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 54,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: greenColor,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: greenColor.withValues(alpha: 0.75),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const _ScannerCorner(alignment: Alignment.topLeft),
                        const _ScannerCorner(alignment: Alignment.topRight),
                        const _ScannerCorner(alignment: Alignment.bottomLeft),
                        const _ScannerCorner(alignment: Alignment.bottomRight),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102754).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.center_focus_strong, color: goldColor, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Line up the card inside the frame',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: greenColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: greenColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'Ready',
                      style: TextStyle(
                        color: greenColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  const _ScannerCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment.x < 0;
    final isTop = alignment.y < 0;

    return Align(
      alignment: alignment,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(
            left: isLeft
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            top: isTop
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ScannerGridPainter extends CustomPainter {
  const _ScannerGridPainter({
    required this.lineColor,
    required this.glowColor,
  });

  final Color lineColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    for (var x = 0.0; x <= size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.35),
      size.width * 0.38,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.fieldColor,
    required this.borderColor,
    required this.goldColor,
    required this.greenColor,
    required this.softTextColor,
  });

  final Color fieldColor;
  final Color borderColor;
  final Color goldColor;
  final Color greenColor;
  final Color softTextColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PreviewHeader(title: 'TCG Shop Map', subtitle: 'Shops and directories'),
        const SizedBox(height: 10),
        Expanded(
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF102754),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16366E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(Icons.search, color: Color(0xFFC8D4F0), size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Area',
                              style: TextStyle(
                                color: Color(0xFFC8D4F0),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(Icons.close, color: Color(0xFFC8D4F0), size: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MiniMapFilterPill(
                            label: 'Game',
                            value: 'All',
                            borderColor: borderColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniMapFilterPill(
                            label: 'Service',
                            value: 'All',
                            borderColor: borderColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEF2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(child: CustomPaint(painter: _MapTilesPainter())),
                      Positioned(
                        top: 10,
                        left: 12,
                        right: 12,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF041B4A).withValues(alpha: 0.86),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: goldColor.withValues(alpha: 0.55)),
                            ),
                            child: Text(
                              'Zoom in to separate nearby shops',
                              style: TextStyle(
                                color: goldColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _MapPin(left: 26, top: 56, color: goldColor, label: '3'),
                      _MapPin(left: 120, top: 84, color: const Color(0xFFD62828), label: '1'),
                      _MapPin(left: 80, top: 152, color: const Color(0xFFD62828), label: '5'),
                      Positioned(
                        right: 12,
                        bottom: 52,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: goldColor,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_location_alt_outlined,
                            color: Color(0xFF041B4A),
                            size: 18,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: _MiniMapDirectoryButton(
                                icon: Icons.event_available_outlined,
                                label: 'Events',
                                color: goldColor,
                                borderColor: borderColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _MiniMapDirectoryButton(
                                icon: Icons.local_offer_outlined,
                                label: 'Offers',
                                color: goldColor,
                                borderColor: borderColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _MiniMapDirectoryButton(
                                icon: Icons.language,
                                label: 'Online',
                                color: goldColor,
                                borderColor: borderColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        left: 10,
                        bottom: 54,
                        child: Text(
                          'OpenStreetMap',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityPreview extends StatelessWidget {
  const _CommunityPreview({
    required this.fieldColor,
    required this.borderColor,
    required this.goldColor,
    required this.greenColor,
    required this.softTextColor,
  });

  final Color fieldColor;
  final Color borderColor;
  final Color goldColor;
  final Color greenColor;
  final Color softTextColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PreviewHeader(title: 'Community', subtitle: 'Post, reply and message'),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(child: _CommunityTab(label: 'Marketplace', selected: true, color: goldColor)),
            const SizedBox(width: 8),
            Expanded(child: _CommunityTab(label: 'Discussions', selected: false, color: fieldColor)),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.74,
            children: <Widget>[
              _CommunityPostMiniCard(
                title: 'Swap cards',
                subtitle: 'Looking to swap Scarlet & Violet hits in Manchester.',
                username: '@jamiecollector',
                tag: 'Swap',
                imageUrl: 'https://images.pokemontcg.io/base1/4_hires.png',
                accentColor: goldColor,
                borderColor: borderColor,
              ),
              _CommunityPostMiniCard(
                title: 'Looking for Charizard',
                subtitle: 'Need the reverse holo to finish my set binder.',
                username: '@pokemaddie',
                tag: 'Wanted',
                imageUrl: 'https://images.pokemontcg.io/base1/6_hires.png',
                accentColor: greenColor,
                borderColor: borderColor,
              ),
              _CommunityPostMiniCard(
                title: 'Trade night Friday',
                subtitle: 'Join us at PocketChase for a local community meet-up.',
                username: '@pocketchase',
                tag: 'Event',
                imageUrl: 'https://images.pokemontcg.io/base1/2_hires.png',
                accentColor: goldColor,
                borderColor: borderColor,
              ),
              _CommunityPostMiniCard(
                title: 'Pack pulls today',
                subtitle: 'Show your best pulls and chat with other collectors.',
                username: '@tcglauren',
                tag: 'Post',
                imageUrl: 'https://images.pokemontcg.io/base1/15_hires.png',
                accentColor: greenColor,
                borderColor: borderColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFC8D4F0),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.more_horiz_rounded, color: Colors.white54, size: 18),
      ],
    );
  }
}

class _MiniSearchBar extends StatelessWidget {
  const _MiniSearchBar({required this.fieldColor, required this.borderColor});

  final Color fieldColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.search, color: Color(0xFFC8D4F0), size: 17),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Search Pokémon cards...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCardTile extends StatelessWidget {
  const _MiniCardTile({
    required this.title,
    required this.tag,
    required this.owned,
    required this.imageUrl,
  });

  final String title;
  final String tag;
  final bool owned;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: owned
              ? const Color(0xFFF7DE77)
              : Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: <BoxShadow>[
          if (owned)
            BoxShadow(
              color: const Color(0xFFF7DE77).withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 7, 7, 5),
              child: _PokemonCardImage(
                imageUrl: imageUrl,
                borderRadius: BorderRadius.circular(10),
                borderColor: owned
                    ? const Color(0xFFF7DE77).withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: owned
                        ? const Color(0xFFF7DE77)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: owned
                          ? const Color(0xFF041B4A)
                          : const Color(0xFFC8D4F0),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
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

class _SetSlotTile extends StatelessWidget {
  const _SetSlotTile({
    required this.label,
    required this.color,
    required this.owned,
    required this.imageUrl,
  });

  final String label;
  final Color color;
  final bool owned;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final borderColor = owned ? color : Colors.white.withValues(alpha: 0.10);

    return Container(
      decoration: BoxDecoration(
        color: owned
            ? color.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: owned
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _CardFallbackIcon(color: color);
                      },
                    )
                  : ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 0.38, 0,
                      ]),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _CardFallbackIcon(color: Colors.white24);
                        },
                      ),
                    ),
            ),
          ),
          if (!owned)
            Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF041B4A).withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          if (label.isNotEmpty)
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: owned ? color : const Color(0xFF16366E),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: owned ? const Color(0xFF041B4A) : Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PokemonCardImage extends StatelessWidget {
  const _PokemonCardImage({
    required this.imageUrl,
    required this.borderRadius,
    required this.borderColor,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final BorderRadius borderRadius;
  final Color borderColor;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF020D26),
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const _CardFallbackIcon(color: Color(0xFFF7DE77));
        },
        errorBuilder: (context, error, stackTrace) {
          return const _CardFallbackIcon(color: Color(0xFFF7DE77));
        },
      ),
    );
  }
}

class _CardFallbackIcon extends StatelessWidget {
  const _CardFallbackIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16366E),
      alignment: Alignment.center,
      child: Icon(
        Icons.style_outlined,
        color: color,
        size: 24,
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.value,
    required this.accentColor,
    required this.borderColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accentColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF041B4A),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniMapFilterPill extends StatelessWidget {
  const _MiniMapFilterPill({
    required this.label,
    required this.value,
    required this.borderColor,
  });

  final String label;
  final String value;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16366E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC8D4F0), size: 15),
        ],
      ),
    );
  }
}

class _MiniMapDirectoryButton extends StatelessWidget {
  const _MiniMapDirectoryButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF102754).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.left,
    required this.top,
    required this.color,
    required this.label,
  });

  final double left;
  final double top;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color == const Color(0xFFF7DE77)
                  ? const Color(0xFF041B4A)
                  : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityTab extends StatelessWidget {
  const _CommunityTab({
    required this.label,
    required this.selected,
    required this.color,
  });

  final String label;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? color : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? color : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? const Color(0xFF041B4A) : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CommunityPostMiniCard extends StatelessWidget {
  const _CommunityPostMiniCard({
    required this.title,
    required this.subtitle,
    required this.username,
    required this.tag,
    required this.imageUrl,
    required this.accentColor,
    required this.borderColor,
  });

  final String title;
  final String subtitle;
  final String username;
  final String tag;
  final String imageUrl;
  final Color accentColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 76,
            width: double.infinity,
            color: const Color(0xFF0B214B),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: Icon(Icons.image_outlined, color: Color(0xFFF7DE77), size: 22),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.image_outlined, color: Color(0xFFF7DE77), size: 22),
                    );
                  },
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_outline, color: accentColor, size: 13),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC8D4F0),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC8D4F0),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      Icon(Icons.chat_bubble_outline, color: Colors.white.withValues(alpha: 0.72), size: 11),
                      const SizedBox(width: 4),
                      const Text(
                        '12',
                        style: TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.favorite_border, color: Colors.white.withValues(alpha: 0.72), size: 11),
                      const SizedBox(width: 4),
                      const Text(
                        '8',
                        style: TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTilesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blockPaint = Paint()..color = const Color(0xFFDDE6EC);
    final parkPaint = Paint()..color = const Color(0xFFD6ECCC);
    final waterPaint = Paint()..color = const Color(0xFFCDE7F5);
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final minorRoadPaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final railPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Offset.zero & size, blockPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.02, size.height * 0.10, size.width * 0.22, size.height * 0.16),
        const Radius.circular(18),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.68, size.height * 0.16, size.width * 0.22, size.height * 0.18),
        const Radius.circular(18),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.70, size.width * 0.26, size.height * 0.14),
        const Radius.circular(18),
      ),
      parkPaint,
    );

    final river = Path()
      ..moveTo(size.width * 0.86, -8)
      ..cubicTo(size.width * 0.76, size.height * 0.20, size.width * 0.88, size.height * 0.42,
          size.width * 0.72, size.height * 0.66)
      ..cubicTo(size.width * 0.64, size.height * 0.78, size.width * 0.68, size.height * 0.90,
          size.width * 0.60, size.height + 12)
      ..lineTo(size.width + 12, size.height + 12)
      ..lineTo(size.width + 12, -12)
      ..close();
    canvas.drawPath(river, waterPaint);

    final road1 = Path()
      ..moveTo(-10, size.height * 0.24)
      ..cubicTo(size.width * 0.18, size.height * 0.18, size.width * 0.40, size.height * 0.30,
          size.width * 0.62, size.height * 0.22)
      ..cubicTo(size.width * 0.80, size.height * 0.16, size.width * 0.94, size.height * 0.24,
          size.width + 12, size.height * 0.20);
    canvas.drawPath(road1, roadPaint);

    final road2 = Path()
      ..moveTo(size.width * 0.10, size.height + 12)
      ..cubicTo(size.width * 0.16, size.height * 0.78, size.width * 0.26, size.height * 0.62,
          size.width * 0.40, size.height * 0.56)
      ..cubicTo(size.width * 0.58, size.height * 0.48, size.width * 0.62, size.height * 0.24,
          size.width * 0.58, -12);
    canvas.drawPath(road2, roadPaint);

    final road3 = Path()
      ..moveTo(-10, size.height * 0.66)
      ..cubicTo(size.width * 0.14, size.height * 0.58, size.width * 0.32, size.height * 0.64,
          size.width * 0.46, size.height * 0.78)
      ..cubicTo(size.width * 0.58, size.height * 0.90, size.width * 0.82, size.height * 0.80,
          size.width + 10, size.height * 0.72);
    canvas.drawPath(road3, minorRoadPaint);

    final road4 = Path()
      ..moveTo(size.width * 0.24, -12)
      ..cubicTo(size.width * 0.30, size.height * 0.18, size.width * 0.22, size.height * 0.34,
          size.width * 0.28, size.height * 0.52)
      ..cubicTo(size.width * 0.34, size.height * 0.72, size.width * 0.26, size.height * 0.88,
          size.width * 0.32, size.height + 10);
    canvas.drawPath(road4, minorRoadPaint);

    final rail = Path()
      ..moveTo(size.width * 0.06, size.height * 0.48)
      ..lineTo(size.width * 0.34, size.height * 0.46)
      ..lineTo(size.width * 0.50, size.height * 0.40)
      ..lineTo(size.width * 0.70, size.height * 0.44);
    canvas.drawPath(rail, railPaint);

    final labelStyle = const TextStyle(
      color: Color(0xFF64748B),
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );
    void drawLabel(String text, Offset offset) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, offset);
    }

    drawLabel('London', Offset(size.width * 0.18, size.height * 0.28));
    drawLabel('Bristol', Offset(size.width * 0.08, size.height * 0.58));
    drawLabel('Card shop cluster', Offset(size.width * 0.42, size.height * 0.11));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GuideSlide {
  const _GuideSlide({
    required this.title,
    required this.subtitle,
    required this.eyebrow,
    required this.buttonLabel,
    required this.icon,
    required this.kind,
    required this.bullets,
  });

  final String title;
  final String subtitle;
  final String eyebrow;
  final String buttonLabel;
  final IconData icon;
  final _PreviewKind kind;
  final List<String> bullets;
}

enum _PreviewKind {
  search,
  scan,
  masterSets,
  prices,
  map,
  community,
}
