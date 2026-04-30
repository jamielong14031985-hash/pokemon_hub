import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/card_ownership.dart';
import 'collection_refresh_notifier.dart';
import 'local_pokedex_store.dart';

class PokedexSyncService {
  static CollectionReference<Map<String, dynamic>> _setCollection(String ownerUid) =>
      FirebaseFirestore.instance.collection('users').doc(ownerUid).collection('pokedex_sets');

  static bool _hasAnySavedCopies(Map<String, CardOwnership> ownershipByCardId) {
    return ownershipByCardId.values.any(LocalPokedexStore.hasSavedCopies);
  }

  static Future<Map<String, CardOwnership>> _fetchSetOwnershipFromCloud({
    required String ownerUid,
    required String setId,
  }) async {
    if (ownerUid.trim().isEmpty || setId.trim().isEmpty) {
      return const <String, CardOwnership>{};
    }

    final cardsSnapshot = await _setCollection(ownerUid).doc(setId).collection('cards').get();
    final ownershipByCardId = <String, CardOwnership>{};

    for (final cardDoc in cardsSnapshot.docs) {
      final ownership = CardOwnership.fromJson(cardDoc.data());
      if (LocalPokedexStore.hasSavedCopies(ownership)) {
        ownershipByCardId[cardDoc.id] = ownership;
      }
    }

    return ownershipByCardId;
  }

  static Future<void> ensureCurrentUserPokedexReady() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final localSetIds = await LocalPokedexStore.allNonEmptySetIds();
    if (localSetIds.isEmpty) {
      await restoreCurrentUserPokedexFromCloud();
    } else {
      await syncCurrentUserLocalPokedex();
    }
  }

  static Future<int> restoreCurrentUserPokedexFromCloud({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final setSnapshot = await _setCollection(user.uid).get();
    var restoredSetCount = 0;

    for (final setDoc in setSnapshot.docs) {
      final setId = setDoc.id;
      final localOwnership = await LocalPokedexStore.loadSetOwnershipMap(setId);
      if (!force && _hasAnySavedCopies(localOwnership)) {
        continue;
      }

      final cloudOwnership = await _fetchSetOwnershipFromCloud(
        ownerUid: user.uid,
        setId: setId,
      );

      if (_hasAnySavedCopies(cloudOwnership)) {
        await LocalPokedexStore.saveSetOwnershipMap(setId, cloudOwnership, notify: false);
        restoredSetCount++;
      }
    }

    if (restoredSetCount > 0) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pokedexRestoredAtMs': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      collectionRefreshNotifier.value++;
    }

    return restoredSetCount;
  }

  static Future<Map<String, CardOwnership>> loadCurrentUserSetOwnership(String setId) async {
    final localOwnership = await LocalPokedexStore.loadSetOwnershipMap(setId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _hasAnySavedCopies(localOwnership)) {
      return localOwnership;
    }

    try {
      final cloudOwnership = await _fetchSetOwnershipFromCloud(
        ownerUid: user.uid,
        setId: setId,
      );
      if (_hasAnySavedCopies(cloudOwnership)) {
        await LocalPokedexStore.saveSetOwnershipMap(setId, cloudOwnership);
        return cloudOwnership;
      }
    } catch (_) {}

    return localOwnership;
  }

  static Future<Map<String, int>> loadCurrentUserCopyCountsBySetId({
    bool cleanEmptySets = true,
  }) async {
    await ensureCurrentUserPokedexReady();
    return LocalPokedexStore.savedCopyCountsBySetId(cleanEmptySets: cleanEmptySets);
  }

  static Future<Map<String, int>> loadCurrentUserAllCardCopies() async {
    await ensureCurrentUserPokedexReady();
    return LocalPokedexStore.loadAllCardCopies();
  }

  static Future<void> syncCurrentUserLocalPokedex({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final profileSnapshot = await profileRef.get();
    final migratedAtMs = (profileSnapshot.data()?['pokedexMigratedAtMs'] as num?)?.toInt() ?? 0;
    if (!force && migratedAtMs > 0) return;

    final setIds = await LocalPokedexStore.allTrackedSetIds();
    for (final setId in setIds) {
      await syncSetFromLocal(ownerUid: user.uid, setId: setId);
    }

    await profileRef.set({
      'pokedexMigratedAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  static Future<void> syncCurrentSetForCurrentUser(String setId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await syncSetFromLocal(ownerUid: user.uid, setId: setId);
  }

  static Future<void> syncSetFromLocal({
    required String ownerUid,
    required String setId,
  }) async {
    final ownershipByCardId = await LocalPokedexStore.loadSetOwnershipMap(setId);
    final ownedEntries = ownershipByCardId.entries.where((entry) => LocalPokedexStore.hasSavedCopies(entry.value)).toList();
    final setRef = _setCollection(ownerUid).doc(setId);
    final existingCards = await setRef.collection('cards').get();
    final existingIds = existingCards.docs.map((doc) => doc.id).toSet();
    final desiredIds = ownedEntries.map((entry) => entry.key).toSet();
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final cardDoc in existingCards.docs) {
      if (!desiredIds.contains(cardDoc.id)) {
        batch.delete(cardDoc.reference);
      }
    }

    for (final entry in ownedEntries) {
      batch.set(
        setRef.collection('cards').doc(entry.key),
        {
          'cardId': entry.key,
          ...entry.value.toJson(),
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
    }

    if (ownedEntries.isEmpty && existingIds.isEmpty) {
      await setRef.delete().catchError((_) {});
      return;
    }

    if (ownedEntries.isEmpty) {
      batch.delete(setRef);
    } else {
      batch.set(
        setRef,
        {
          'setId': setId,
          'ownedCount': ownedEntries.length,
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static Future<Map<String, CardOwnership>> fetchAllOwnedCards(String ownerUid) async {
    if (ownerUid.trim().isEmpty) {
      return const <String, CardOwnership>{};
    }

    final setSnapshot = await _setCollection(ownerUid).get();
    final ownershipByCardId = <String, CardOwnership>{};

    for (final setDoc in setSnapshot.docs) {
      final cardsSnapshot = await setDoc.reference.collection('cards').get();
      for (final cardDoc in cardsSnapshot.docs) {
        final ownership = CardOwnership.fromJson(cardDoc.data());
        if (!LocalPokedexStore.isOwned(ownership)) continue;
        final existingCopies = ownershipByCardId[cardDoc.id]?.collectionCount ?? 0;
        final mergedCopies = existingCopies + ownership.collectionCount;
        ownershipByCardId[cardDoc.id] = ownership.copyWith(copies: mergedCopies);
      }
    }

    return ownershipByCardId;
  }

  static Stream<List<String>> ownedSetIdsStream(String ownerUid) {
    return _setCollection(ownerUid).snapshots().map((snapshot) {
      final setIds = snapshot.docs
          .where((doc) => ((doc.data()['ownedCount'] as num?)?.toInt() ?? 0) > 0)
          .map((doc) => doc.id)
          .toList()
        ..sort();
      return setIds;
    });
  }

  static Stream<Map<String, CardOwnership>> setOwnershipStream({
    required String ownerUid,
    required String setId,
  }) {
    return _setCollection(ownerUid).doc(setId).collection('cards').snapshots().map((snapshot) {
      final ownershipByCardId = <String, CardOwnership>{};
      for (final doc in snapshot.docs) {
        ownershipByCardId[doc.id] = CardOwnership.fromJson(doc.data());
      }
      return ownershipByCardId;
    });
  }
}
