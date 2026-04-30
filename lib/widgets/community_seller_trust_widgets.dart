import 'package:flutter/material.dart';

import '../models/community_rating_models.dart';
import '../services/community_rating_service.dart';
import 'community_rating_stars.dart';

String communitySellerTrustLabel(CommunitySellerRatingSummary summary) {
  if (!summary.hasRatings) return 'No seller ratings yet';
  if (summary.averageStars >= 4.7 && summary.ratingCount >= 3) return 'Highly trusted seller';
  if (summary.averageStars >= 4.2) return 'Trusted seller';
  if (summary.averageStars >= 3.2) return 'Mixed seller rating';
  return 'Low seller rating';
}

Color communitySellerTrustColor(CommunitySellerRatingSummary summary) {
  if (!summary.hasRatings) return Colors.white54;
  if (summary.averageStars >= 4.2) return const Color(0xFF54D39A);
  if (summary.averageStars >= 3.2) return const Color(0xFFF0A83A);
  return const Color(0xFFB13B59);
}

class CommunitySellerRatingBadge extends StatelessWidget {
  const CommunitySellerRatingBadge({
    super.key,
    required this.sellerId,
    this.compact = false,
  });

  final String sellerId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final trimmedSellerId = sellerId.trim();
    if (trimmedSellerId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<CommunitySellerRatingSummary>(
      stream: CommunityRatingService.summaryStream(trimmedSellerId),
      builder: (context, snapshot) {
        final summary = snapshot.data ??
            const CommunitySellerRatingSummary(
              ratingCount: 0,
              averageStars: 0,
              recentRatings: <CommunitySellerRating>[],
            );
        final trustColor = communitySellerTrustColor(summary);
        final label = summary.hasRatings
            ? '${summary.averageLabel} • ${summary.countLabel}'
            : 'No ratings yet';

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 10,
            vertical: compact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: trustColor.withValues(alpha: summary.hasRatings ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: trustColor.withValues(alpha: summary.hasRatings ? 0.36 : 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                summary.hasRatings ? Icons.verified_user_outlined : Icons.verified_outlined,
                color: trustColor,
                size: compact ? 14 : 15,
              ),
              const SizedBox(width: 6),
              if (summary.hasRatings) ...[
                CommunityRatingStars(value: summary.averageStars, size: compact ? 13 : 14),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: summary.hasRatings ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CommunitySellerTrustPanel extends StatelessWidget {
  const CommunitySellerTrustPanel({
    super.key,
    required this.sellerId,
    required this.sellerName,
    this.onRate,
    this.compact = false,
  });

  final String sellerId;
  final String sellerName;
  final VoidCallback? onRate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final trimmedSellerId = sellerId.trim();
    if (trimmedSellerId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<CommunitySellerRatingSummary>(
      stream: CommunityRatingService.summaryStream(trimmedSellerId),
      builder: (context, snapshot) {
        final summary = snapshot.data ??
            const CommunitySellerRatingSummary(
              ratingCount: 0,
              averageStars: 0,
              recentRatings: <CommunitySellerRating>[],
            );
        final trustColor = communitySellerTrustColor(summary);
        final title = communitySellerTrustLabel(summary);

        if (compact) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: trustColor.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: trustColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified_user_outlined, color: trustColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (summary.hasRatings) ...[
                            CommunityRatingStars(value: summary.averageStars, size: 13),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              summary.hasRatings
                                  ? '${summary.averageLabel}/5 from ${summary.countLabel}'
                                  : 'Be the first to rate after a trade.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: trustColor.withValues(alpha: 0.26)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: trustColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_user_outlined, color: trustColor, size: 21),
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
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (summary.hasRatings) ...[
                              CommunityRatingStars(value: summary.averageStars, size: 15),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                summary.hasRatings
                                    ? '${summary.averageLabel}/5 from ${summary.countLabel}'
                                    : '$sellerName has not been rated yet.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFC8D4F0),
                                  fontSize: 13,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onRate != null)
                    TextButton.icon(
                      onPressed: onRate,
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label: const Text('Rate'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF7DE77),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              if (summary.recentRatings.any((rating) => rating.hasComment)) ...[
                const SizedBox(height: 12),
                ...summary.recentRatings
                    .where((rating) => rating.hasComment)
                    .take(2)
                    .map(
                      (rating) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CommunityRatingStars(value: rating.normalizedStars.toDouble(), size: 13),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      rating.raterName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rating.comment.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD8E3FB),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}
