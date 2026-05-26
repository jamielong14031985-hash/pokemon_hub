import 'package:flutter/material.dart';

import '../models/business_review.dart';
import '../services/business_profile_service.dart';

class BusinessRatingSummary extends StatelessWidget {
  const BusinessRatingSummary({
    super.key,
    required this.businessId,
    this.starColor = const Color(0xFFF7DE77),
    this.textColor = Colors.white,
    this.mutedTextColor = const Color(0xFFC8D4F0),
    this.fontSize = 13,
    this.showNoReviews = true,
    this.onTap,
  });

  final String businessId;
  final Color starColor;
  final Color textColor;
  final Color mutedTextColor;
  final double fontSize;
  final bool showNoReviews;
  final VoidCallback? onTap;

  double _averageStars(List<BusinessReview> reviews) {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<int>(0, (sum, review) => sum + review.stars);
    return total / reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    final cleanBusinessId = businessId.trim();
    if (cleanBusinessId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<BusinessReview>>(
      stream: BusinessProfileService().watchBusinessReviews(cleanBusinessId),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <BusinessReview>[];
        final reviewCount = reviews.length;

        if (reviewCount == 0 && !showNoReviews) {
          return const SizedBox.shrink();
        }

        final average = _averageStars(reviews);
        final label = reviewCount == 0
            ? 'No reviews yet'
            : '${average.toStringAsFixed(1)} • $reviewCount review${reviewCount == 1 ? '' : 's'}';

        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reviewCount == 0 ? Icons.star_border_rounded : Icons.star_rounded,
              color: starColor,
              size: fontSize + 6,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: reviewCount == 0 ? mutedTextColor : textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );

        if (onTap == null) return content;

        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: content,
          ),
        );
      },
    );
  }
}
