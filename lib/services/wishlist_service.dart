import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tcg_card.dart';
import '../models/wishlist_entry.dart';

class WishlistService {
  static CollectionReference<Map<String, dynamic>> _collection(String ownerUid) =>
      FirebaseFirestore.instance.collection('users').doc(ownerUid).collection('wishlist');

  static Stream<List<WishlistEntry>> wishlistStream(String ownerUid) {
    if (ownerUid.trim().isEmpty) {
      return Stream.value(const <WishlistEntry>[]);
    }
    return _collection(ownerUid).snapshots().map((snapshot) {
      final items = snapshot.docs.map(WishlistEntry.fromDoc).toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      return items;
    });
  }

  static Future<List<WishlistEntry>> fetchWishlist(String ownerUid) async {
    if (ownerUid.trim().isEmpty) {
      return const <WishlistEntry>[];
    }

    final snapshot = await _collection(ownerUid).get();
    final items = snapshot.docs.map(WishlistEntry.fromDoc).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return items;
  }

  static Stream<bool> cardInWishlistStream(String ownerUid, String cardId) {
    if (ownerUid.trim().isEmpty || cardId.trim().isEmpty) {
      return Stream.value(false);
    }
    return _collection(ownerUid).doc(cardId).snapshots().map((snapshot) => snapshot.exists);
  }

  static Future<void> addCard({required String ownerUid, required TcgCard card}) async {
    final safeRawPrice = card.rawPrice;
    final rawPriceValue = (safeRawPrice != null && safeRawPrice.isFinite) ? safeRawPrice : null;
    await _collection(ownerUid).doc(card.id).set({
      'cardId': card.id,
      'name': card.name,
      'setId': card.setId,
      'setName': card.setName,
      'number': card.number,
      'imageUrl': card.imageUrl,
      'largeImageUrl': card.largeImageUrl,
      'setLogoUrl': card.setLogoUrl,
      if (rawPriceValue != null) 'rawPrice': rawPriceValue,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  static Future<void> removeCard({required String ownerUid, required String cardId}) async {
    await _collection(ownerUid).doc(cardId).delete();
  }
}
