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
    required this.region,
    required this.storeName,
    required this.storeId,
    required this.storeAddress,
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
  final String region;
  final String storeName;
  final String storeId;
  final String storeAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastCheckedAt;
  final DateTime? lastAlertedAt;
  final String? lastCheckStatus;
  final String? lastCheckError;

  String get storeDisplayName {
    final cleanStore = storeName.trim();
    if (cleanStore.isNotEmpty) return cleanStore;

    final cleanRegion = region.trim();
    if (cleanRegion.isNotEmpty) return cleanRegion;

    return 'All stores';
  }

  String get regionDisplayName {
    final cleanRegion = region.trim();
    return cleanRegion.isEmpty ? 'All regions' : cleanRegion;
  }

  String get effectiveStoreId {
    final cleanStoreId = storeId.trim();
    if (cleanStoreId.isNotEmpty) return cleanStoreId;

    final parts = <String>[
      shopName,
      region,
      storeName,
      productUrl,
    ];

    return parts
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .join('|');
  }

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
      region: data['region']?.toString() ?? '',
      storeName: data['storeName']?.toString() ?? '',
      storeId: data['storeId']?.toString() ?? '',
      storeAddress: data['storeAddress']?.toString() ?? '',
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

class UserRestockAlertPreferences {
  const UserRestockAlertPreferences({
    required this.userId,
    required this.enabled,
    required this.selectedShops,
    required this.selectedRegions,
    required this.selectedStoreIds,
    this.updatedAt,
  });

  final String userId;
  final bool enabled;
  final List<String> selectedShops;
  final List<String> selectedRegions;
  final List<String> selectedStoreIds;
  final DateTime? updatedAt;

  factory UserRestockAlertPreferences.empty(String userId) {
    return UserRestockAlertPreferences(
      userId: userId,
      enabled: true,
      selectedShops: const <String>[],
      selectedRegions: const <String>[],
      selectedStoreIds: const <String>[],
    );
  }

  factory UserRestockAlertPreferences.fromDoc({
    required String userId,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();

    if (data == null) {
      return UserRestockAlertPreferences.empty(userId);
    }

    return UserRestockAlertPreferences(
      userId: userId,
      enabled: data['enabled'] != false,
      selectedShops: TrackedRestockProduct._stringList(data['selectedShops']),
      selectedRegions: TrackedRestockProduct._stringList(data['selectedRegions']),
      selectedStoreIds: TrackedRestockProduct._stringList(data['selectedStoreIds']),
      updatedAt: TrackedRestockProduct._timestampToDate(data['updatedAt']),
    );
  }
}

class TrackedRestockProductService {
  TrackedRestockProductService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _productsCollection {
    return _firestore.collection('tracked_restock_products');
  }

  static CollectionReference<Map<String, dynamic>> get _preferencesCollection {
    return _firestore.collection('user_restock_alert_preferences');
  }

  static CollectionReference<Map<String, dynamic>> _userTrackedProductsCollection(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('tracked_restock_products');
  }

  static Stream<List<TrackedRestockProduct>> watchProducts() {
    return _productsCollection
        .orderBy('shopName')
        .snapshots()
        .map(
          (snapshot) {
            final products = snapshot.docs
                .map(TrackedRestockProduct.fromDoc)
                .toList();

            products.sort((a, b) {
              final shopCompare = a.shopName.toLowerCase().compareTo(
                    b.shopName.toLowerCase(),
                  );
              if (shopCompare != 0) return shopCompare;

              final regionCompare = a.region.toLowerCase().compareTo(
                    b.region.toLowerCase(),
                  );
              if (regionCompare != 0) return regionCompare;

              final storeCompare = a.storeName.toLowerCase().compareTo(
                    b.storeName.toLowerCase(),
                  );
              if (storeCompare != 0) return storeCompare;

              return a.productName.toLowerCase().compareTo(
                    b.productName.toLowerCase(),
                  );
            });

            return products;
          },
        );
  }

  static Stream<UserRestockAlertPreferences> watchCurrentUserPreferences() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream<UserRestockAlertPreferences>.value(
          UserRestockAlertPreferences.empty(''),
        );
      }

      return _preferencesCollection.doc(user.uid).snapshots().map(
            (doc) => UserRestockAlertPreferences.fromDoc(
              userId: user.uid,
              doc: doc,
            ),
          );
    });
  }

  static Future<void> saveCurrentUserPreferences({
    required bool enabled,
    required Iterable<String> selectedShops,
    required Iterable<String> selectedRegions,
    required Iterable<String> selectedStoreIds,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to save alert preferences.');
    }

    await _preferencesCollection.doc(currentUser.uid).set(
      <String, dynamic>{
        'userId': currentUser.uid,
        'enabled': enabled,
        'selectedShops': _cleanStringValues(selectedShops, maxItems: 100),
        'selectedRegions': _cleanStringValues(selectedRegions, maxItems: 200),
        'selectedStoreIds': _cleanStringValues(selectedStoreIds, maxItems: 500),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
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
    String region = '',
    String storeName = '',
    String storeId = '',
    String storeAddress = '',
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to add tracked products.');
    }

    final cleanedShopName = shopName.trim();
    final cleanedProductName = productName.trim();
    final cleanedProductUrl = productUrl.trim();
    final cleanedRegion = region.trim();
    final cleanedStoreName = storeName.trim();
    final cleanedStoreAddress = storeAddress.trim();
    final cleanedStoreId = storeId.trim().isNotEmpty
        ? storeId.trim()
        : _buildStoreId(
            shopName: cleanedShopName,
            region: cleanedRegion,
            storeName: cleanedStoreName,
            storeAddress: cleanedStoreAddress,
          );

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
      'region': cleanedRegion,
      'storeName': cleanedStoreName,
      'storeId': cleanedStoreId,
      'storeAddress': cleanedStoreAddress,
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

  static Future<void> updateProduct({
    required String productId,
    required String shopName,
    required String productName,
    required String productUrl,
    required String imageUrl,
    required String notes,
    required List<String> inStockKeywords,
    required List<String> outOfStockKeywords,
    String region = '',
    String storeName = '',
    String storeId = '',
    String storeAddress = '',
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to update tracked products.');
    }

    final cleanedProductId = productId.trim();
    final cleanedShopName = shopName.trim();
    final cleanedProductName = productName.trim();
    final cleanedProductUrl = productUrl.trim();
    final cleanedRegion = region.trim();
    final cleanedStoreName = storeName.trim();
    final cleanedStoreAddress = storeAddress.trim();
    final cleanedStoreId = storeId.trim().isNotEmpty
        ? storeId.trim()
        : _buildStoreId(
            shopName: cleanedShopName,
            region: cleanedRegion,
            storeName: cleanedStoreName,
            storeAddress: cleanedStoreAddress,
          );

    if (cleanedProductId.isEmpty) {
      throw ArgumentError('Missing product ID.');
    }

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

    await _productsCollection.doc(cleanedProductId).update({
      'shopName': cleanedShopName,
      'productName': cleanedProductName,
      'productUrl': cleanedProductUrl,
      'imageUrl': imageUrl.trim(),
      'notes': notes.trim(),
      'region': cleanedRegion,
      'storeName': cleanedStoreName,
      'storeId': cleanedStoreId,
      'storeAddress': cleanedStoreAddress,
      'inStockKeywords': _cleanKeywords(inStockKeywords),
      'outOfStockKeywords': _cleanKeywords(outOfStockKeywords),
      'updatedAt': FieldValue.serverTimestamp(),
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

  static Stream<List<TrackedRestockProduct>> watchCurrentUserTrackedProducts() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream<List<TrackedRestockProduct>>.value(
          const <TrackedRestockProduct>[],
        );
      }

      return _userTrackedProductsCollection(user.uid)
          .orderBy('shopName')
          .snapshots()
          .map((snapshot) {
        final products = snapshot.docs.map(TrackedRestockProduct.fromDoc).toList();

        products.sort((a, b) {
          final shopCompare = a.shopName.toLowerCase().compareTo(
                b.shopName.toLowerCase(),
              );
          if (shopCompare != 0) return shopCompare;

          final regionCompare = a.region.toLowerCase().compareTo(
                b.region.toLowerCase(),
              );
          if (regionCompare != 0) return regionCompare;

          final storeCompare = a.storeName.toLowerCase().compareTo(
                b.storeName.toLowerCase(),
              );
          if (storeCompare != 0) return storeCompare;

          return a.productName.toLowerCase().compareTo(
                b.productName.toLowerCase(),
              );
        });

        return products;
      });
    });
  }

  static Future<void> createCurrentUserTrackedProduct({
    required String shopName,
    required String productName,
    required String productUrl,
    required String imageUrl,
    required String notes,
    required List<String> inStockKeywords,
    required List<String> outOfStockKeywords,
    String region = '',
    String storeName = '',
    String storeId = '',
    String storeAddress = '',
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to track products.');
    }

    final cleanedShopName = shopName.trim();
    final cleanedProductName = productName.trim();
    final cleanedProductUrl = productUrl.trim();
    final cleanedRegion = region.trim();
    final cleanedStoreName = storeName.trim();
    final cleanedStoreAddress = storeAddress.trim();
    final cleanedStoreId = storeId.trim().isNotEmpty
        ? storeId.trim()
        : _buildStoreId(
            shopName: cleanedShopName,
            region: cleanedRegion,
            storeName: cleanedStoreName,
            storeAddress: cleanedStoreAddress,
          );

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

    await _userTrackedProductsCollection(currentUser.uid).add({
      'userId': currentUser.uid,
      'shopName': cleanedShopName,
      'productName': cleanedProductName,
      'productUrl': cleanedProductUrl,
      'imageUrl': imageUrl.trim(),
      'notes': notes.trim(),
      'enabled': true,
      'inStock': false,
      'region': cleanedRegion,
      'storeName': cleanedStoreName,
      'storeId': cleanedStoreId,
      'storeAddress': cleanedStoreAddress,
      'inStockKeywords': _cleanKeywords(inStockKeywords),
      'outOfStockKeywords': _cleanKeywords(outOfStockKeywords),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastCheckedAt': null,
      'lastAlertedAt': null,
      'lastCheckStatus': 'not_checked_yet',
      'lastCheckError': '',
    });
  }

  static Future<void> updateCurrentUserTrackedProduct({
    required String productId,
    required String shopName,
    required String productName,
    required String productUrl,
    required String imageUrl,
    required String notes,
    required List<String> inStockKeywords,
    required List<String> outOfStockKeywords,
    String region = '',
    String storeName = '',
    String storeId = '',
    String storeAddress = '',
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to update tracked products.');
    }

    final cleanedProductId = productId.trim();
    final cleanedShopName = shopName.trim();
    final cleanedProductName = productName.trim();
    final cleanedProductUrl = productUrl.trim();
    final cleanedRegion = region.trim();
    final cleanedStoreName = storeName.trim();
    final cleanedStoreAddress = storeAddress.trim();
    final cleanedStoreId = storeId.trim().isNotEmpty
        ? storeId.trim()
        : _buildStoreId(
            shopName: cleanedShopName,
            region: cleanedRegion,
            storeName: cleanedStoreName,
            storeAddress: cleanedStoreAddress,
          );

    if (cleanedProductId.isEmpty) {
      throw ArgumentError('Missing product ID.');
    }

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

    await _userTrackedProductsCollection(currentUser.uid)
        .doc(cleanedProductId)
        .update({
      'shopName': cleanedShopName,
      'productName': cleanedProductName,
      'productUrl': cleanedProductUrl,
      'imageUrl': imageUrl.trim(),
      'notes': notes.trim(),
      'region': cleanedRegion,
      'storeName': cleanedStoreName,
      'storeId': cleanedStoreId,
      'storeAddress': cleanedStoreAddress,
      'inStockKeywords': _cleanKeywords(inStockKeywords),
      'outOfStockKeywords': _cleanKeywords(outOfStockKeywords),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setCurrentUserTrackedProductEnabled({
    required String productId,
    required bool enabled,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to update tracked products.');
    }

    await _userTrackedProductsCollection(currentUser.uid).doc(productId).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteCurrentUserTrackedProduct(String productId) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be signed in to delete tracked products.');
    }

    await _userTrackedProductsCollection(currentUser.uid).doc(productId).delete();
  }

  static String _buildStoreId({
    required String shopName,
    required String region,
    required String storeName,
    required String storeAddress,
  }) {
    final value = <String>[
      shopName,
      region,
      storeName,
      storeAddress,
    ]
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .join('-')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    if (value.isNotEmpty) return value;

    return 'store-${DateTime.now().millisecondsSinceEpoch}';
  }

  static List<String> _cleanStringValues(
    Iterable<String> values, {
    required int maxItems,
  }) {
    final seen = <String>{};
    final cleaned = <String>[];

    for (final value in values) {
      final cleanValue = value.trim();
      final lookupValue = cleanValue.toLowerCase();

      if (cleanValue.isEmpty || seen.contains(lookupValue)) continue;

      seen.add(lookupValue);
      cleaned.add(cleanValue);

      if (cleaned.length >= maxItems) break;
    }

    return cleaned;
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
