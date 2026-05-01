import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RestockAlert {
  const RestockAlert({
    required this.id,
    required this.shopName,
    required this.productName,
    required this.productUrl,
    required this.imageUrl,
    required this.notes,
    required this.inStock,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUid,
    required this.createdByName,
  });

  final String id;
  final String shopName;
  final String productName;
  final String productUrl;
  final String imageUrl;
  final String notes;
  final bool inStock;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdByUid;
  final String createdByName;

  factory RestockAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    return RestockAlert(
      id: doc.id,
      shopName: data['shopName']?.toString() ?? '',
      productName: data['productName']?.toString() ?? '',
      productUrl: data['productUrl']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      notes: data['notes']?.toString() ?? '',
      inStock: data['inStock'] == true,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      createdByUid: data['createdByUid']?.toString() ?? '',
      createdByName: data['createdByName']?.toString() ?? '',
    );
  }
}

class RestockAlertService {
  RestockAlertService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static CollectionReference<Map<String, dynamic>> get _alertsCollection {
    return _firestore.collection('restock_alerts');
  }

  static Stream<List<RestockAlert>> watchLatestAlerts({int limit = 100}) {
    return _alertsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(RestockAlert.fromDoc).toList(),
        );
  }

  static Future<void> createAlert({
    required String shopName,
    required String productName,
    required String productUrl,
    required String imageUrl,
    required String notes,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('You must be signed in to create restock alerts.');
    }

    final cleanedShopName = shopName.trim();
    final cleanedProductName = productName.trim();
    final cleanedProductUrl = productUrl.trim();
    final cleanedImageUrl = imageUrl.trim();
    final cleanedNotes = notes.trim();

    if (cleanedShopName.isEmpty) {
      throw ArgumentError('Add the shop name.');
    }

    if (cleanedProductName.isEmpty) {
      throw ArgumentError('Add the product name.');
    }

    await _alertsCollection.add({
      'shopName': cleanedShopName,
      'productName': cleanedProductName,
      'productUrl': cleanedProductUrl,
      'imageUrl': cleanedImageUrl,
      'notes': cleanedNotes,
      'inStock': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByUid': user.uid,
      'createdByName': _displayNameForUser(user),
    });
  }

  static Future<void> deleteAlert(String alertId) async {
    await _alertsCollection.doc(alertId).delete();
  }

  static String _displayNameForUser(User user) {
    final displayName = user.displayName?.trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email?.trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Admin';
  }
}
