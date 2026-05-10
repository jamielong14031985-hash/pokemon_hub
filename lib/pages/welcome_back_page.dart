import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';

/// This uses the launcher icon path from your pubspec.yaml screenshot.
/// Change it if your preferred logo is somewhere else.
const String _kWelcomeBackLogoAsset = 'assets/images/pocketdex_icon.png';

class WelcomeBackPage extends StatefulWidget {
  const WelcomeBackPage({
    super.key,
    required this.profile,
    required this.onFinished,
  });

  final AppUserProfile profile;
  final Future<void> Function() onFinished;

  @override
  State<WelcomeBackPage> createState() => _WelcomeBackPageState();
}

class _WelcomeBackPageState extends State<WelcomeBackPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoTurns;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _welcomeOpacity;
  late final Animation<Offset> _welcomeOffset;
  bool _finished = false;

  String get _displayName {
    final name = widget.profile.displayName.trim();
    return name.isEmpty ? 'Trainer' : name;
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.18, end: 0.74)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.74, end: 1.24)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.24, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 32,
      ),
    ]).animate(_controller);

    _logoTurns = Tween<double>(begin: 2.35, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.62, curve: Curves.easeOutCubic),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
      ),
    );

    _welcomeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.56, 0.82, curve: Curves.easeOut),
      ),
    );

    _welcomeOffset = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.56, 0.86, curve: Curves.easeOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishAfterShortPause();
      }
    });

    _controller.forward();
  }

  Future<void> _finishAfterShortPause() async {
    if (_finished) return;
    _finished = true;

    await Future<void>.delayed(const Duration(milliseconds: 850));

    if (!mounted) return;
    await widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (disableAnimations && !_controller.isCompleted) {
      _controller.value = 1.0;
      unawaited(_finishAfterShortPause());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      body: SafeArea(
        child: Stack(
          children: [
            const _WelcomeBackGlow(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Transform.rotate(
                              angle: _logoTurns.value * math.pi * 2,
                              child: const _LogoBurst(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        FadeTransition(
                          opacity: _welcomeOpacity,
                          child: SlideTransition(
                            position: _welcomeOffset,
                            child: Column(
                              children: [
                                const Text(
                                  'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _displayName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFF7DE77),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoBurst extends StatelessWidget {
  const _LogoBurst();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFF7DE77).withValues(alpha: 0.26),
                const Color(0xFF2F6DD7).withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.34),
                blurRadius: 44,
                spreadRadius: 7,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 138,
              height: 138,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D2658),
                border: Border.all(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.46),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  _kWelcomeBackLogoAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.10),
                      ),
                      child: const Icon(
                        Icons.catching_pokemon_rounded,
                        color: Color(0xFFF7DE77),
                        size: 60,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'PocketChase',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _WelcomeBackGlow extends StatelessWidget {
  const _WelcomeBackGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned(
          top: -90,
          left: -80,
          child: _GlowOrb(
            size: 230,
            color: Color(0xFF2F6DD7),
            alpha: 0.15,
          ),
        ),
        Positioned(
          bottom: -100,
          right: -80,
          child: _GlowOrb(
            size: 240,
            color: Color(0xFFF7DE77),
            alpha: 0.10,
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
