import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessOffer {
  const BusinessOffer({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerUid,
    required this.title,
    required this.description,
    required this.category,
    required this.code,
    required this.websiteUrl,
    required this.imageUrl,
    required this.imagePath,
    required this.active,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String ownerUid;
  final String title;
  final String description;
  final String category;
  final String code;
  final String websiteUrl;
  final String imageUrl;
  final String imagePath;
  final bool active;
  final Timestamp? startsAt;
  final Timestamp? endsAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  static String cleanString(dynamic value) => (value ?? '').toString().trim();

  static bool cleanBool(dynamic value) {
    if (value is bool) return value;
    return false;
  }

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  factory BusinessOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return BusinessOffer(
      id: doc.id,
      businessId: cleanString(data['businessId']),
      businessName: cleanString(data['businessName']),
      ownerUid: cleanString(data['ownerUid']),
      title: cleanString(data['title']),
      description: cleanString(data['description']),
      category: cleanString(data['category']),
      code: cleanString(data['code']),
      websiteUrl: cleanString(data['websiteUrl']),
      imageUrl: cleanString(data['imageUrl']),
      imagePath: cleanString(data['imagePath']),
      active: cleanBool(data['active']),
      startsAt: cleanTimestamp(data['startsAt']),
      endsAt: cleanTimestamp(data['endsAt']),
      createdAt: cleanTimestamp(data['createdAt']),
      updatedAt: cleanTimestamp(data['updatedAt']),
    );
  }

  String get categoryLabel {
    return switch (category) {
      'discount' => 'Discount code',
      'new_stock' => 'New stock',
      'event' => 'Event',
      'announcement' => 'Announcement',
      _ => 'Offer',
    };
  }

  bool get hasCode => code.trim().isNotEmpty;

  bool get hasWebsite => websiteUrl.trim().isNotEmpty;

  bool get hasImage => imageUrl.trim().isNotEmpty;

  bool get isCurrentlyVisible {
    if (!active) return false;

    final now = DateTime.now();

    final start = startsAt?.toDate();
    if (start != null && start.isAfter(now)) return false;

    final end = endsAt?.toDate();
    if (end != null && end.isBefore(now)) return false;

    return true;
  }
}
