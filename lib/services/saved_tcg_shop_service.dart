import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/saved_tcg_shop.dart';
import '../models/tcg_shop.dart';

class SavedTcgShopService {
  SavedTcgShopService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _savedShops(String uid) {
    return _firestore.collection('users').doc(uid).collection('saved_tcg_shops');
  }

  Stream<Set<String>> watchSavedShopIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream<Set<String>>.value(<String>{});

    return _savedShops(user.uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  Stream<List<SavedTcgShop>> watchSavedShops() {
    final user = _auth.currentUser;
    if (user == null) return Stream<List<SavedTcgShop>>.value(const []);

    return _savedShops(user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(SavedTcgShop.fromDoc).toList();
    });
  }

  Future<bool> isShopSaved(String shopId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _savedShops(user.uid).doc(shopId).get();
    return snapshot.exists;
  }

  Future<void> saveShop(TcgShop shop) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to save shops.');
    }

    final cleanShopId = shop.id.trim();
    if (cleanShopId.isEmpty) {
      throw ArgumentError('Missing shop id.');
    }

    await _savedShops(user.uid).doc(cleanShopId).set(
      <String, Object?>{
        'userId': user.uid,
        'shopId': cleanShopId,
        'name': shop.name.trim(),
        'address': shop.singleLineAddress.trim(),
        'town': shop.town.trim(),
        'imageUrl': shop.imageUrl.trim(),
        'website': shop.website.trim(),
        'phone': shop.phone.trim(),
        'lat': shop.lat,
        'lng': shop.lng,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> unsaveShop(String shopId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to unsave shops.');
    }

    final cleanShopId = shopId.trim();
    if (cleanShopId.isEmpty) return;

    await _savedShops(user.uid).doc(cleanShopId).delete();
  }

  Future<void> toggleSaved(TcgShop shop) async {
    final saved = await isShopSaved(shop.id);

    if (saved) {
      await unsaveShop(shop.id);
    } else {
      await saveShop(shop);
    }
  }
}
