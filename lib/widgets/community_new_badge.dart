import 'package:flutter/material.dart';

class CommunityNewBadge extends StatelessWidget {
  const CommunityNewBadge({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7DE77),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }
}
