import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/card_ownership.dart';
import 'collection_refresh_notifier.dart';
import 'local_pokedex_store.dart';

const Duration _kFirebaseReadTimeout = Duration(seconds: 12);
const Duration _kFirebaseWriteTimeout = Duration(seconds: 15);

int _readInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString().trim()) ?? 0;
}

class PokedexSyncService {
  static CollectionReference<Map<String, dynamic>> _setCollection(
    String ownerUid,
  ) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid.trim())
          .collection('pokedex_sets');

  static bool _hasAnySavedCopies(Map<String, CardOwnership> ownershipByCardId) {
    return ownershipByCardId.values.any(LocalPokedexStore.hasSavedCopies);
  }

  static CardOwnership? _safeOwnershipFromMap(Map<String, dynamic> data) {
    try {
      return CardOwnership.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, CardOwnership>> _fetchSetOwnershipFromCloud({
    required String ownerUid,
    required String setId,
  }) async {
    final safeOwnerUid = ownerUid.trim();
    final safeSetId = setId.trim();

    if (safeOwnerUid.isEmpty || safeSetId.isEmpty) {
      return const <String, CardOwnership>{};
    }

    try {
      final cardsSnapshot = await _setCollection(safeOwnerUid)
          .doc(safeSetId)
          .collection('cards')
          .get()
          .timeout(_kFirebaseReadTimeout);

      final ownershipByCardId = <String, CardOwnership>{};

      for (final cardDoc in cardsSnapshot.docs) {
        final ownership = _safeOwnershipFromMap(cardDoc.data());
        if (ownership == null) continue;

        if (LocalPokedexStore.hasSavedCopies(ownership)) {
          ownershipByCardId[cardDoc.id] = ownership;
        }
      }

      return ownershipByCardId;
    } catch (_) {
      return const <String, CardOwnership>{};
    }
  }

  static Future<void> ensureCurrentUserPokedexReady() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final localSetIds = await LocalPokedexStore.allNonEmptySetIds();
      if (localSetIds.isEmpty) {
        await restoreCurrentUserPokedexFromCloud();
      } else {
        await syncCurrentUserLocalPokedex();
      }
    } catch (_) {
      // Keep the app open even if local storage or Firebase is temporarily unavailable.
    }
  }

  static Future<int> restoreCurrentUserPokedexFromCloud({
    bool force = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    QuerySnapshot<Map<String, dynamic>> setSnapshot;
    try {
      setSnapshot = await _setCollection(user.uid).get().timeout(
            _kFirebaseReadTimeout,
          );
    } catch (_) {
      return 0;
    }

    var restoredSetCount = 0;

    for (final setDoc in setSnapshot.docs) {
      final setId = setDoc.id.trim();
      if (setId.isEmpty) continue;

      try {
        final localOwnership = await LocalPokedexStore.loadSetOwnershipMap(setId);
        if (!force && _hasAnySavedCopies(localOwnership)) {
          continue;
        }

        final cloudOwnership = await _fetchSetOwnershipFromCloud(
          ownerUid: user.uid,
          setId: setId,
        );

        if (_hasAnySavedCopies(cloudOwnership)) {
          await LocalPokedexStore.saveSetOwnershipMap(
            setId,
            cloudOwnership,
            notify: false,
          );
          restoredSetCount++;
        }
      } catch (_) {
        // Skip one bad set instead of failing the whole restore.
      }
    }

    if (restoredSetCount > 0) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'pokedexRestoredAtMs': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true)).timeout(_kFirebaseWriteTimeout);
      } catch (_) {
        // The local restore already worked, so do not crash if this marker fails.
      }

      collectionRefreshNotifier.value++;
    }

    return restoredSetCount;
  }

  static Future<Map<String, CardOwnership>> loadCurrentUserSetOwnership(
    String setId,
  ) async {
    Map<String, CardOwnership> localOwnership;
    try {
      localOwnership = await LocalPokedexStore.loadSetOwnershipMap(setId);
    } catch (_) {
      localOwnership = const <String, CardOwnership>{};
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _hasAnySavedCopies(localOwnership)) {
      return localOwnership;
    }

    final cloudOwnership = await _fetchSetOwnershipFromCloud(
      ownerUid: user.uid,
      setId: setId,
    );

    if (_hasAnySavedCopies(cloudOwnership)) {
      try {
        await LocalPokedexStore.saveSetOwnershipMap(setId, cloudOwnership);
      } catch (_) {}
      return cloudOwnership;
    }

    return localOwnership;
  }

  static Future<Map<String, int>> loadCurrentUserCopyCountsBySetId({
    bool cleanEmptySets = true,
  }) async {
    try {
      await ensureCurrentUserPokedexReady();
      return await LocalPokedexStore.savedCopyCountsBySetId(
        cleanEmptySets: cleanEmptySets,
      );
    } catch (_) {
      return const <String, int>{};
    }
  }

  static Future<Map<String, int>> loadCurrentUserAllCardCopies() async {
    try {
      await ensureCurrentUserPokedexReady();
      return await LocalPokedexStore.loadAllCardCopies();
    } catch (_) {
      return const <String, int>{};
    }
  }

  static Future<void> syncCurrentUserLocalPokedex({
    bool force = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    var migratedAtMs = 0;
    try {
      final profileSnapshot = await profileRef.get().timeout(
            _kFirebaseReadTimeout,
          );
      migratedAtMs = _readInt(profileSnapshot.data()?['pokedexMigratedAtMs']);
    } catch (_) {
      migratedAtMs = 0;
    }

    if (!force && migratedAtMs > 0) return;

    Set<String> setIds;
    try {
      setIds = await LocalPokedexStore.allTrackedSetIds();
    } catch (_) {
      return;
    }

    for (final setId in setIds) {
      try {
        await syncSetFromLocal(ownerUid: user.uid, setId: setId);
      } catch (_) {
        // Keep syncing the rest of the sets even if one fails.
      }
    }

    try {
      await profileRef.set({
        'pokedexMigratedAtMs': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true)).timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      // Do not crash if this marker cannot be saved.
    }
  }

  static Future<void> syncCurrentSetForCurrentUser(String setId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await syncSetFromLocal(ownerUid: user.uid, setId: setId);
    } catch (_) {
      // Do not crash the app if a background sync fails.
    }
  }

  static Future<void> syncSetFromLocal({
    required String ownerUid,
    required String setId,
  }) async {
    final safeOwnerUid = ownerUid.trim();
    final safeSetId = setId.trim();

    if (safeOwnerUid.isEmpty || safeSetId.isEmpty) {
      return;
    }

    Map<String, CardOwnership> ownershipByCardId;
    try {
      ownershipByCardId = await LocalPokedexStore.loadSetOwnershipMap(safeSetId);
    } catch (_) {
      return;
    }

    final ownedEntries = ownershipByCardId.entries
        .where((entry) => LocalPokedexStore.hasSavedCopies(entry.value))
        .toList();

    final setRef = _setCollection(safeOwnerUid).doc(safeSetId);

    QuerySnapshot<Map<String, dynamic>> existingCards;
    try {
      existingCards = await setRef.collection('cards').get().timeout(
            _kFirebaseReadTimeout,
          );
    } catch (_) {
      return;
    }

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
      final cardId = entry.key.trim();
      if (cardId.isEmpty) continue;

      batch.set(
        setRef.collection('cards').doc(cardId),
        {
          'cardId': cardId,
          ...entry.value.toJson(),
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
    }

    if (ownedEntries.isEmpty && existingIds.isEmpty) {
      try {
        await setRef.delete().timeout(_kFirebaseWriteTimeout);
      } catch (_) {}
      return;
    }

    if (ownedEntries.isEmpty) {
      batch.delete(setRef);
    } else {
      batch.set(
        setRef,
        {
          'setId': safeSetId,
          'ownedCount': ownedEntries.length,
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
    }

    try {
      await batch.commit().timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      // Do not crash the app if cloud sync fails.
    }
  }

  static Future<Map<String, CardOwnership>> fetchAllOwnedCards(
    String ownerUid,
  ) async {
    final safeOwnerUid = ownerUid.trim();
    if (safeOwnerUid.isEmpty) {
      return const <String, CardOwnership>{};
    }

    QuerySnapshot<Map<String, dynamic>> setSnapshot;
    try {
      setSnapshot = await _setCollection(safeOwnerUid).get().timeout(
            _kFirebaseReadTimeout,
          );
    } catch (_) {
      return const <String, CardOwnership>{};
    }

    final ownershipByCardId = <String, CardOwnership>{};

    for (final setDoc in setSnapshot.docs) {
      try {
        final cardsSnapshot = await setDoc.reference.collection('cards').get().timeout(
              _kFirebaseReadTimeout,
            );

        for (final cardDoc in cardsSnapshot.docs) {
          final ownership = _safeOwnershipFromMap(cardDoc.data());
          if (ownership == null) continue;
          if (!LocalPokedexStore.isOwned(ownership)) continue;

          final existingCopies =
              ownershipByCardId[cardDoc.id]?.collectionCount ?? 0;
          final mergedCopies = existingCopies + ownership.collectionCount;

          ownershipByCardId[cardDoc.id] = ownership.copyWith(
            copies: mergedCopies,
          );
        }
      } catch (_) {
        // Skip one bad set instead of failing all owned cards.
      }
    }

    return ownershipByCardId;
  }

  static Stream<List<String>> ownedSetIdsStream(String ownerUid) async* {
    final safeOwnerUid = ownerUid.trim();
    if (safeOwnerUid.isEmpty) {
      yield const <String>[];
      return;
    }

    try {
      await for (final snapshot in _setCollection(safeOwnerUid).snapshots()) {
        final setIds = snapshot.docs
            .where((doc) => _readInt(doc.data()['ownedCount']) > 0)
            .map((doc) => doc.id)
            .where((id) => id.trim().isNotEmpty)
            .toList()
          ..sort();

        yield setIds;
      }
    } catch (_) {
      yield const <String>[];
    }
  }

  static Stream<Map<String, CardOwnership>> setOwnershipStream({
    required String ownerUid,
    required String setId,
  }) async* {
    final safeOwnerUid = ownerUid.trim();
    final safeSetId = setId.trim();

    if (safeOwnerUid.isEmpty || safeSetId.isEmpty) {
      yield const <String, CardOwnership>{};
      return;
    }

    try {
      await for (final snapshot in _setCollection(safeOwnerUid)
          .doc(safeSetId)
          .collection('cards')
          .snapshots()) {
        final ownershipByCardId = <String, CardOwnership>{};

        for (final doc in snapshot.docs) {
          final ownership = _safeOwnershipFromMap(doc.data());
          if (ownership == null) continue;
          ownershipByCardId[doc.id] = ownership;
        }

        yield ownershipByCardId;
      }
    } catch (_) {
      yield const <String, CardOwnership>{};
    }
  }
}
