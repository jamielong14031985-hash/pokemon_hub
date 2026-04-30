import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_rating_models.dart';

const Duration _kFirebaseReadTimeout = Duration(seconds: 12);
const Duration _kFirebaseWriteTimeout = Duration(seconds: 15);

String _communityRatingDocId({
  required String sellerId,
  required String raterId,
}) {
  final safeSeller = sellerId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final safeRater = raterId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return '${safeSeller}_rated_by_$safeRater';
}

String _safeDisplayName(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Trainer' : trimmed;
}

int _readInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString().trim()) ?? 0;
}

class CommunityRatingService {
  static CollectionReference<Map<String, dynamic>> get _ratings =>
      FirebaseFirestore.instance.collection('community_user_ratings');

  static CommunitySellerRating? _safeRatingFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      if (!doc.exists || doc.data() == null) return null;
      return CommunitySellerRating.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  static Stream<List<CommunitySellerRating>> ratingsForSellerStream(
    String sellerId,
  ) async* {
    final trimmedSellerId = sellerId.trim();
    if (trimmedSellerId.isEmpty) {
      yield const <CommunitySellerRating>[];
      return;
    }

    try {
      await for (final snapshot
          in _ratings.where('sellerId', isEqualTo: trimmedSellerId).snapshots()) {
        final ratings = snapshot.docs
            .map(_safeRatingFromDoc)
            .whereType<CommunitySellerRating>()
            .toList()
          ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

        yield ratings;
      }
    } catch (_) {
      yield const <CommunitySellerRating>[];
    }
  }

  static Stream<CommunitySellerRatingSummary> summaryStream(String sellerId) {
    return ratingsForSellerStream(sellerId).map(
      CommunitySellerRatingSummary.fromRatings,
    );
  }

  static Future<CommunitySellerRating?> fetchRating({
    required String sellerId,
    required String raterId,
  }) async {
    final trimmedSellerId = sellerId.trim();
    final trimmedRaterId = raterId.trim();

    if (trimmedSellerId.isEmpty || trimmedRaterId.isEmpty) return null;

    try {
      final doc = await _ratings
          .doc(
            _communityRatingDocId(
              sellerId: trimmedSellerId,
              raterId: trimmedRaterId,
            ),
          )
          .get()
          .timeout(_kFirebaseReadTimeout);

      return _safeRatingFromDoc(doc);
    } catch (_) {
      return null;
    }
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
      _communityRatingDocId(
        sellerId: trimmedSellerId,
        raterId: trimmedRaterId,
      ),
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    var createdAtMs = now;

    try {
      final existing = await docRef.get().timeout(_kFirebaseReadTimeout);
      createdAtMs = _readInt(existing.data()?['createdAtMs']);
      if (createdAtMs <= 0) {
        createdAtMs = now;
      }
    } catch (_) {
      createdAtMs = now;
    }

    final safeStars = stars.clamp(1, 5).toInt();

    try {
      await docRef.set(
        CommunitySellerRating(
          id: docRef.id,
          sellerId: trimmedSellerId,
          sellerName: _safeDisplayName(sellerName),
          raterId: trimmedRaterId,
          raterName: _safeDisplayName(raterName),
          stars: safeStars,
          comment: comment.trim(),
          createdAtMs: createdAtMs,
          updatedAtMs: now,
          sourcePostId: sourcePostId.trim(),
          sourcePostTitle: sourcePostTitle.trim(),
        ).toJson(),
        SetOptions(merge: true),
      ).timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not submit your rating. Please check your connection and try again.',
      );
    }
  }
}
