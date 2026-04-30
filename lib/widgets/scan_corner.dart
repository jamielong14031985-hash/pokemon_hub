import 'package:flutter/material.dart';

class ScanCorner extends StatelessWidget {
  const ScanCorner({
    super.key,
    required this.alignment,
  });

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }
}
