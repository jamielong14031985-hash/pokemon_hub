import 'package:flutter/material.dart';

class CommunityRatingStars extends StatelessWidget {
  const CommunityRatingStars({
    super.key,
    required this.value,
    this.size = 16,
    this.showEmpty = true,
  });

  final double value;
  final double size;
  final bool showEmpty;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = value - index;
        final IconData icon;
        if (starValue >= 0.75) {
          icon = Icons.star_rounded;
        } else if (starValue >= 0.25) {
          icon = Icons.star_half_rounded;
        } else {
          icon = showEmpty ? Icons.star_border_rounded : Icons.star_outline_rounded;
        }
        return Icon(
          icon,
          color: const Color(0xFFF7DE77),
          size: size,
        );
      }),
    );
  }
}
