import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessReview {
  const BusinessReview({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.reviewerUid,
    required this.reviewerName,
    required this.stars,
    required this.comment,
    required this.businessReply,
    required this.businessReplyByUid,
    this.businessReplyCreatedAt,
    this.businessReplyUpdatedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String reviewerUid;
  final String reviewerName;
  final int stars;
  final String comment;
  final String businessReply;
  final String businessReplyByUid;
  final Timestamp? businessReplyCreatedAt;
  final Timestamp? businessReplyUpdatedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  static String cleanString(dynamic value) => (value ?? '').toString().trim();

  static int cleanStars(dynamic value) {
    if (value is int) return value.clamp(1, 5);
    if (value is num) return value.toInt().clamp(1, 5);
    return 1;
  }

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  factory BusinessReview.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return BusinessReview(
      id: doc.id,
      businessId: cleanString(data['businessId']),
      businessName: cleanString(data['businessName']),
      reviewerUid: cleanString(data['reviewerUid']),
      reviewerName: cleanString(data['reviewerName']),
      stars: cleanStars(data['stars']),
      comment: cleanString(data['comment']),
      businessReply: cleanString(data['businessReply']),
      businessReplyByUid: cleanString(data['businessReplyByUid']),
      businessReplyCreatedAt: cleanTimestamp(data['businessReplyCreatedAt']),
      businessReplyUpdatedAt: cleanTimestamp(data['businessReplyUpdatedAt']),
      createdAt: cleanTimestamp(data['createdAt']),
      updatedAt: cleanTimestamp(data['updatedAt']),
    );
  }

  String get displayReviewerName {
    return reviewerName.trim().isEmpty ? 'PocketChase user' : reviewerName;
  }

  DateTime? get displayDate {
    final timestamp = updatedAt ?? createdAt;
    return timestamp?.toDate();
  }

  bool get hasBusinessReply => businessReply.trim().isNotEmpty;

  DateTime? get businessReplyDisplayDate {
    final timestamp = businessReplyUpdatedAt ?? businessReplyCreatedAt;
    return timestamp?.toDate();
  }
}
