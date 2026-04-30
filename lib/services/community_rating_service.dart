import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_rating_models.dart';

String _communityRatingDocId({
  required String sellerId,
  required String raterId,
}) {
  final safeSeller = sellerId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final safeRater = raterId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return '${safeSeller}_rated_by_$safeRater';
}

class CommunityRatingService {
  static CollectionReference<Map<String, dynamic>> get _ratings =>
      FirebaseFirestore.instance.collection('community_user_ratings');

  static Stream<List<CommunitySellerRating>> ratingsForSellerStream(String sellerId) {
    final trimmedSellerId = sellerId.trim();
    if (trimmedSellerId.isEmpty) {
      return Stream<List<CommunitySellerRating>>.value(const <CommunitySellerRating>[]);
    }
    return _ratings.where('sellerId', isEqualTo: trimmedSellerId).snapshots().map((snapshot) {
      return snapshot.docs.map(CommunitySellerRating.fromDoc).toList();
    });
  }

  static Stream<CommunitySellerRatingSummary> summaryStream(String sellerId) {
    return ratingsForSellerStream(sellerId).map(CommunitySellerRatingSummary.fromRatings);
  }

  static Future<CommunitySellerRating?> fetchRating({
    required String sellerId,
    required String raterId,
  }) async {
    final trimmedSellerId = sellerId.trim();
    final trimmedRaterId = raterId.trim();
    if (trimmedSellerId.isEmpty || trimmedRaterId.isEmpty) return null;
    final doc = await _ratings
        .doc(_communityRatingDocId(sellerId: trimmedSellerId, raterId: trimmedRaterId))
        .get();
    if (!doc.exists) return null;
    return CommunitySellerRating.fromDoc(doc);
  }

  static Future<void> submitRating({
    required String sellerId,
    required String sellerName,
    required String raterId,
    required String raterName,
    required int stars,
    required String comment,
    String sourcePostId = '',
    String sourcePostTitle = '',
  }) async {
    final trimmedSellerId = sellerId.trim();
    final trimmedRaterId = raterId.trim();
    if (trimmedSellerId.isEmpty || trimmedRaterId.isEmpty) {
      throw StateError('Missing seller or rater details.');
    }
    if (trimmedSellerId == trimmedRaterId) {
      throw StateError('You cannot rate yourself.');
    }

    final docRef = _ratings.doc(
      _communityRatingDocId(sellerId: trimmedSellerId, raterId: trimmedRaterId),
    );
    final existing = await docRef.get();
    final now = DateTime.now().millisecondsSinceEpoch;
    final createdAtMs = (existing.data()?['createdAtMs'] as num?)?.toInt() ?? now;

    await docRef.set(
      CommunitySellerRating(
        id: docRef.id,
        sellerId: trimmedSellerId,
        sellerName: sellerName.trim().isEmpty ? 'Trainer' : sellerName.trim(),
        raterId: trimmedRaterId,
        raterName: raterName.trim().isEmpty ? 'Trainer' : raterName.trim(),
        stars: stars,
        comment: comment,
        createdAtMs: createdAtMs,
        updatedAtMs: now,
        sourcePostId: sourcePostId,
        sourcePostTitle: sourcePostTitle,
      ).toJson(),
      SetOptions(merge: true),
    );
  }
}
