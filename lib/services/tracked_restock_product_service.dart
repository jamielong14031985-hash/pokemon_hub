import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrackedRestockProduct {
  const TrackedRestockProduct({
    required this.id,
    required this.shopName,
    required this.productName,
    required this.productUrl,
    required this.imageUrl,
    required this.notes,
    required this.enabled,
    required this.inStock,
    required this.inStockKeywords,
    required this.outOfStockKeywords,
    this.createdAt,
    this.updatedAt,
    this.lastCheckedAt,
    this.lastAlertedAt,
    this.lastCheckStatus,
    this.lastCheckError,
  });

  final String id;
  final String shopName;
  final String productName;
  final String productUrl;
  final String imageUrl;
  final String notes;
  final bool enabled;
  final bool inStock;
  final List<String> inStockKeywords;
  final List<String> outOfStockKeywords;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastCheckedAt;
  final DateTime? lastAlertedAt;
  final String? lastCheckStatus;
  final String? lastCheckError;

  factory TrackedRestockProduct.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return TrackedRestockProduct(
      id: doc.id,
      shopName: data['shopName']?.toString() ?? '',
      productName: data['productName']?.toString() ?? '',
      productUrl: data['productUrl']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      notes: data['notes']?.toString() ?? '',
      enabled: data['enabled'] == true,
      inStock: data['inStock'] == true,
      inStockKeywords: _stringList(data['inStockKeywords']),
      outOfStockKeywords: _stringList(data['outOfStockKeywords']),
      createdAt: _timestampToDate(data['createdAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
      lastCheckedAt: _timestampToDate(data['lastCheckedAt']),
      lastAlertedAt: _timestampToDate(data['lastAlertedAt']),
      lastCheckStatus: data['lastCheckStatus']?.toString(),
      lastCheckError: data['lastCheckError']?.toString(),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static DateTime? _timestampToDate(Object? value) {
    return value is Timestamp ? value.toDate() : null;
  }
}

class TrackedRestockProductService {
  TrackedRestockProductService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _productsCollection {
    return _firestore.collection('tracked_restock_products');
  }

  static Stream<List<TrackedRestockProduct>> watchProducts() {
    return _productsCollection
        .orderBy('shopName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(TrackedRestockProduct.fromDoc)
              .toList(),
        );
  }

  static Future<void> createProduct({
    required String shopName,
    required String productName,
    required String productUrl,
    required String imageUrl,
    required String notes,
    required List<String> inStockKeywords,
    required List<String> outOfStockKeywords,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to add tracked products.');
    }

    final cleanedShopName = shopName.trim();
    final cleanedProductName = productName.trim();
    final cleanedProductUrl = productUrl.trim();

    if (cleanedShopName.isEmpty) {
      throw ArgumentError('Add a shop name.');
    }

    if (cleanedProductName.isEmpty) {
      throw ArgumentError('Add a product name.');
    }

    if (cleanedProductUrl.isEmpty ||
        !cleanedProductUrl.toLowerCase().startsWith('http')) {
      throw ArgumentError('Add a valid product page URL.');
    }

    await _productsCollection.add({
      'shopName': cleanedShopName,
      'productName': cleanedProductName,
      'productUrl': cleanedProductUrl,
      'imageUrl': imageUrl.trim(),
      'notes': notes.trim(),
      'enabled': true,
      'inStock': false,
      'inStockKeywords': _cleanKeywords(inStockKeywords),
      'outOfStockKeywords': _cleanKeywords(outOfStockKeywords),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByUid': currentUser.uid,
      'lastCheckedAt': null,
      'lastAlertedAt': null,
      'lastCheckStatus': 'not_checked_yet',
      'lastCheckError': '',
    });
  }

  static Future<void> setProductEnabled({
    required String productId,
    required bool enabled,
  }) async {
    await _productsCollection.doc(productId).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteProduct(String productId) async {
    await _productsCollection.doc(productId).delete();
  }

  static List<String> _cleanKeywords(List<String> keywords) {
    final seen = <String>{};
    final cleaned = <String>[];

    for (final keyword in keywords) {
      final value = keyword.trim().toLowerCase();

      if (value.isEmpty || seen.contains(value)) continue;

      seen.add(value);
      cleaned.add(value);

      if (cleaned.length >= 30) break;
    }

    return cleaned;
  }
}
