import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tcg_card.dart';
import '../models/wishlist_entry.dart';

const Duration _kFirebaseReadTimeout = Duration(seconds: 12);
const Duration _kFirebaseWriteTimeout = Duration(seconds: 15);

class WishlistService {
  static CollectionReference<Map<String, dynamic>> _collection(String ownerUid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid.trim())
          .collection('wishlist');

  static WishlistEntry? _safeWishlistEntryFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return WishlistEntry.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  static Stream<List<WishlistEntry>> wishlistStream(String ownerUid) async* {
    final safeOwnerUid = ownerUid.trim();
    if (safeOwnerUid.isEmpty) {
      yield const <WishlistEntry>[];
      return;
    }

    try {
      await for (final snapshot in _collection(safeOwnerUid).snapshots()) {
        final items = snapshot.docs
            .map(_safeWishlistEntryFromDoc)
            .whereType<WishlistEntry>()
            .toList()
          ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

        yield items;
      }
    } catch (_) {
      yield const <WishlistEntry>[];
    }
  }

  static Future<List<WishlistEntry>> fetchWishlist(String ownerUid) async {
    final safeOwnerUid = ownerUid.trim();
    if (safeOwnerUid.isEmpty) {
      return const <WishlistEntry>[];
    }

    try {
      final snapshot = await _collection(safeOwnerUid).get().timeout(
            _kFirebaseReadTimeout,
          );

      final items = snapshot.docs
          .map(_safeWishlistEntryFromDoc)
          .whereType<WishlistEntry>()
          .toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

      return items;
    } catch (_) {
      return const <WishlistEntry>[];
    }
  }

  static Stream<bool> cardInWishlistStream(String ownerUid, String cardId) async* {
    final safeOwnerUid = ownerUid.trim();
    final safeCardId = cardId.trim();

    if (safeOwnerUid.isEmpty || safeCardId.isEmpty) {
      yield false;
      return;
    }

    try {
      await for (final snapshot in _collection(safeOwnerUid).doc(safeCardId).snapshots()) {
        yield snapshot.exists;
      }
    } catch (_) {
      yield false;
    }
  }

  static Future<void> addCard({
    required String ownerUid,
    required TcgCard card,
  }) async {
    final safeOwnerUid = ownerUid.trim();
    final safeCardId = card.id.trim();

    if (safeOwnerUid.isEmpty || safeCardId.isEmpty) {
      return;
    }

    final safeRawPrice = card.rawPrice;
    final rawPriceValue =
        (safeRawPrice != null && safeRawPrice.isFinite) ? safeRawPrice : null;

    try {
      await _collection(safeOwnerUid).doc(safeCardId).set({
        'cardId': safeCardId,
        'name': card.name,
        'setId': card.setId,
        'setName': card.setName,
        'number': card.number,
        'imageUrl': card.imageUrl,
        'largeImageUrl': card.largeImageUrl,
        'setLogoUrl': card.setLogoUrl,
        if (rawPriceValue != null) 'rawPrice': rawPriceValue,
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true)).timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not add this card to your wishlist. Please check your connection and try again.',
      );
    }
  }

  static Future<void> removeCard({
    required String ownerUid,
    required String cardId,
  }) async {
    final safeOwnerUid = ownerUid.trim();
    final safeCardId = cardId.trim();

    if (safeOwnerUid.isEmpty || safeCardId.isEmpty) {
      return;
    }

    try {
      await _collection(safeOwnerUid)
          .doc(safeCardId)
          .delete()
          .timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not remove this card from your wishlist. Please check your connection and try again.',
      );
    }
  }

  /// Removes exact card IDs after they have been saved to the user's Pokédex.
  /// Firestore deletes are safe when a card is not currently in the wishlist.
  static Future<void> removeOwnedCards({
    required String ownerUid,
    required Iterable<String> cardIds,
  }) async {
    final safeOwnerUid = ownerUid.trim();
    if (safeOwnerUid.isEmpty) return;

    final ids = cardIds
        .map((cardId) => cardId.trim())
        .where((cardId) => cardId.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;

    // Stay below Firestore's per-batch operation limit for very large sets.
    const batchSize = 400;
    for (var start = 0; start < ids.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, ids.length).toInt();
      final batch = FirebaseFirestore.instance.batch();

      for (final cardId in ids.sublist(start, end)) {
        batch.delete(_collection(safeOwnerUid).doc(cardId));
      }

      await batch.commit().timeout(_kFirebaseWriteTimeout);
    }
  }
}
