import 'package:flutter/material.dart';

class GlimmerBorder extends StatefulWidget {
  const GlimmerBorder({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final double borderRadius;

  @override
  State<GlimmerBorder> createState() => _GlimmerBorderState();
}

class _GlimmerBorderState extends State<GlimmerBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final bright = Color.lerp(
          const Color(0xFFFFF2A8),
          Colors.white,
          t,
        )!;
        final mid = Color.lerp(
          const Color(0xFFF7DE77),
          const Color(0xFFFFE082),
          t,
        )!;
        final blur = 8.0 + (t * 8.0);
        final spread = 0.8 + (t * 1.4);
        final padding = 2.0 + (t * 0.8);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + (t * 2), -1),
              end: Alignment(1, 1 - (t * 2)),
              colors: [bright, mid, bright],
            ),
            boxShadow: [
              BoxShadow(
                color: mid.withValues(alpha: 0.45 + (t * 0.25)),
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
          padding: EdgeInsets.all(padding),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
