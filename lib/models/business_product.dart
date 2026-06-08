import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessProduct {
  const BusinessProduct({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerUid,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.imagePath,
    required this.buyUrl,
    required this.active,
    required this.featured,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String ownerUid;
  final String name;
  final String description;
  final String category;
  final String price;
  final String imageUrl;
  final String imagePath;
  final String buyUrl;
  final bool active;
  final bool featured;
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

  factory BusinessProduct.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return BusinessProduct(
      id: doc.id,
      businessId: cleanString(data['businessId']),
      businessName: cleanString(data['businessName']),
      ownerUid: cleanString(data['ownerUid']),
      name: cleanString(data['name']),
      description: cleanString(data['description']),
      category: cleanString(data['category']),
      price: cleanString(data['price']),
      imageUrl: cleanString(data['imageUrl']),
      imagePath: cleanString(data['imagePath']),
      buyUrl: cleanString(data['buyUrl']),
      active: cleanBool(data['active']),
      featured: cleanBool(data['featured']),
      createdAt: cleanTimestamp(data['createdAt']),
      updatedAt: cleanTimestamp(data['updatedAt']),
    );
  }

  String get categoryLabel {
    return switch (category) {
      'sealed' => 'Sealed product',
      'singles' => 'Singles',
      'accessories' => 'Accessories',
      'pre_order' => 'Pre-order',
      'new_arrival' => 'New arrival',
      'deal' => 'Deal',
      _ => 'Product',
    };
  }

  bool get hasImage => imageUrl.trim().isNotEmpty;

  bool get hasBuyUrl => buyUrl.trim().isNotEmpty;

  bool get isVisible => active;
}
