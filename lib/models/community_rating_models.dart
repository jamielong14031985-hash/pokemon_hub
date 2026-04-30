import 'package:cloud_firestore/cloud_firestore.dart';

class CommunitySellerRating {
  const CommunitySellerRating({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.raterId,
    required this.raterName,
    required this.stars,
    required this.comment,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.sourcePostId = '',
    this.sourcePostTitle = '',
  });

  final String id;
  final String sellerId;
  final String sellerName;
  final String raterId;
  final String raterName;
  final int stars;
  final String comment;
  final int createdAtMs;
  final int updatedAtMs;
  final String sourcePostId;
  final String sourcePostTitle;

  int get normalizedStars => _clampCommunityRatingStars(stars);
  bool get hasComment => comment.trim().isNotEmpty;
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(
        updatedAtMs > 0 ? updatedAtMs : createdAtMs,
      );

  Map<String, dynamic> toJson() => {
        'sellerId': sellerId,
        'sellerName': sellerName,
        'raterId': raterId,
        'raterName': raterName,
        'stars': normalizedStars,
        'comment': comment.trim(),
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        if (sourcePostId.trim().isNotEmpty) 'sourcePostId': sourcePostId.trim(),
        if (sourcePostTitle.trim().isNotEmpty) 'sourcePostTitle': sourcePostTitle.trim(),
      };

  factory CommunitySellerRating.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    return CommunitySellerRating(
      id: doc.id,
      sellerId: (json['sellerId'] ?? '').toString(),
      sellerName: (json['sellerName'] ?? 'Trainer').toString(),
      raterId: (json['raterId'] ?? '').toString(),
      raterName: (json['raterName'] ?? 'Trainer').toString(),
      stars: _clampCommunityRatingStars((json['stars'] as num?)?.toInt() ?? 0),
      comment: (json['comment'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      sourcePostId: (json['sourcePostId'] ?? '').toString(),
      sourcePostTitle: (json['sourcePostTitle'] ?? '').toString(),
    );
  }
}

class CommunitySellerRatingSummary {
  const CommunitySellerRatingSummary({
    required this.ratingCount,
    required this.averageStars,
    required this.recentRatings,
  });

  final int ratingCount;
  final double averageStars;
  final List<CommunitySellerRating> recentRatings;

  bool get hasRatings => ratingCount > 0;
  String get averageLabel => hasRatings ? averageStars.toStringAsFixed(1) : 'New';
  String get countLabel {
    if (ratingCount == 0) return 'No ratings yet';
    if (ratingCount == 1) return '1 rating';
    return '$ratingCount ratings';
  }

  factory CommunitySellerRatingSummary.fromRatings(List<CommunitySellerRating> ratings) {
    if (ratings.isEmpty) {
      return const CommunitySellerRatingSummary(
        ratingCount: 0,
        averageStars: 0,
        recentRatings: <CommunitySellerRating>[],
      );
    }
    final sorted = ratings.toList()
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    final totalStars = sorted.fold<int>(0, (total, rating) => total + rating.normalizedStars);
    return CommunitySellerRatingSummary(
      ratingCount: sorted.length,
      averageStars: totalStars / sorted.length,
      recentRatings: sorted.take(3).toList(),
    );
  }
}

int _clampCommunityRatingStars(int value) {
  if (value < 1) return 1;
  if (value > 5) return 5;
  return value;
}
