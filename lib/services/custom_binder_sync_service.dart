import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/card_ownership.dart';
import '../models/custom_binder_models.dart';
import '../models/tcg_card.dart';
import 'collection_refresh_notifier.dart';
import 'community_image_services.dart';
import 'local_custom_binder_store.dart';

class CustomBinderSyncService {
  static CollectionReference<Map<String, dynamic>> _binderCollection(String ownerUid) =>
      FirebaseFirestore.instance.collection('users').doc(ownerUid).collection('custom_binders');

  static CollectionReference<Map<String, dynamic>> _cardCollection(String ownerUid, String binderId) =>
      _binderCollection(ownerUid).doc(binderId).collection('cards');

  static Future<List<CustomBinder>> _fetchBindersFromCloud(String ownerUid) async {
    if (ownerUid.trim().isEmpty) {
      return const <CustomBinder>[];
    }

    final snapshot = await _binderCollection(ownerUid).get();
    final binders = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = (data['id'] ?? doc.id).toString();
      return CustomBinder.fromJson(data);
    }).where((binder) => binder.id.trim().isNotEmpty).toList()
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

    return binders;
  }

  static Future<Map<String, CustomBinderCardEntry>> _fetchCardsFromCloud({
    required String ownerUid,
    required String binderId,
  }) async {
    if (ownerUid.trim().isEmpty || binderId.trim().isEmpty) {
      return const <String, CustomBinderCardEntry>{};
    }

    final snapshot = await _cardCollection(ownerUid, binderId).get();
    final cardMap = <String, CustomBinderCardEntry>{};

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['cardId'] = (data['cardId'] ?? doc.id).toString();
      final entry = CustomBinderCardEntry.fromJson(data);
      if (entry.cardId.trim().isNotEmpty && entry.copies > 0) {
        cardMap[entry.cardId] = entry;
      }
    }

    return cardMap;
  }

  static Future<void> ensureCurrentUserBindersReady() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await restoreCurrentUserBindersFromCloud();
      await syncCurrentUserLocalBinders();
    } catch (_) {}
  }

  static Future<int> restoreCurrentUserBindersFromCloud({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final cloudBinders = await _fetchBindersFromCloud(user.uid);
    if (cloudBinders.isEmpty) return 0;

    final localBinders = await LocalCustomBinderStore.loadBinders();
    final localById = <String, CustomBinder>{
      for (final binder in localBinders) binder.id: binder,
    };

    var restoredCount = 0;
    for (final cloudBinder in cloudBinders) {
      final localBinder = localById[cloudBinder.id];
      final shouldRestore = force ||
          localBinder == null ||
          cloudBinder.updatedAtMs > localBinder.updatedAtMs;

      if (!shouldRestore) continue;

      final cloudCards = await _fetchCardsFromCloud(
        ownerUid: user.uid,
        binderId: cloudBinder.id,
      );

      await LocalCustomBinderStore.saveBinder(cloudBinder, notify: false);
      await LocalCustomBinderStore.saveCardMap(
        cloudBinder.id,
        cloudCards,
        touchBinder: false,
        notify: false,
      );
      restoredCount++;
    }

    if (restoredCount > 0) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'customBindersRestoredAtMs': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      collectionRefreshNotifier.value++;
    }

    return restoredCount;
  }

  static Future<void> syncCurrentUserLocalBinders({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final profileSnapshot = await profileRef.get();
    final migratedAtMs = (profileSnapshot.data()?['customBindersMigratedAtMs'] as num?)?.toInt() ?? 0;
    if (!force && migratedAtMs > 0) return;

    final binders = await LocalCustomBinderStore.loadBinders();
    for (final binder in binders) {
      await syncBinderFromLocal(ownerUid: user.uid, binderId: binder.id);
    }

    await profileRef.set({
      'customBindersMigratedAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  static Future<void> syncBinderFromLocal({
    required String ownerUid,
    required String binderId,
  }) async {
    if (ownerUid.trim().isEmpty || binderId.trim().isEmpty) return;

    final binder = await LocalCustomBinderStore.loadBinder(binderId);
    if (binder == null) {
      await deleteBinderFromCloud(ownerUid: ownerUid, binderId: binderId);
      return;
    }

    final cards = await LocalCustomBinderStore.loadCards(binderId);
    final existingCards = await _cardCollection(ownerUid, binderId).get();
    final desiredIds = cards.map((entry) => entry.cardId).toSet();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      _binderCollection(ownerUid).doc(binderId),
      {
        ...binder.toJson(),
        'cardCount': cards.length,
        'syncedAtMs': DateTime.now().millisecondsSinceEpoch,
      },
      SetOptions(merge: true),
    );

    for (final cardDoc in existingCards.docs) {
      if (!desiredIds.contains(cardDoc.id)) {
        batch.delete(cardDoc.reference);
      }
    }

    for (final entry in cards) {
      batch.set(
        _cardCollection(ownerUid, binderId).doc(entry.cardId),
        entry.toJson(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static Future<void> deleteBinderFromCloud({
    required String ownerUid,
    required String binderId,
  }) async {
    if (ownerUid.trim().isEmpty || binderId.trim().isEmpty) return;

    final binderRef = _binderCollection(ownerUid).doc(binderId);
    final binderSnapshot = await binderRef.get();
    final binderImageRef = binderSnapshot.exists
        ? CustomBinder.fromJson({
            ...?binderSnapshot.data(),
            'id': binderId,
          }).imageBase64
        : null;

    final existingCards = await _cardCollection(ownerUid, binderId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final cardDoc in existingCards.docs) {
      batch.delete(cardDoc.reference);
    }
    batch.delete(binderRef);
    await batch.commit();
    unawaited(FirebaseImageStorageService.deleteByDownloadUrl(binderImageRef));
  }

  static Future<List<CustomBinder>> loadCurrentUserBinders() async {
    await ensureCurrentUserBindersReady();
    return LocalCustomBinderStore.loadBinders();
  }

  static Future<CustomBinder?> loadCurrentUserBinder(String binderId) async {
    await ensureCurrentUserBindersReady();
    return LocalCustomBinderStore.loadBinder(binderId);
  }

  static Future<List<CustomBinderCardEntry>> loadCurrentUserCards(String binderId) async {
    await ensureCurrentUserBindersReady();
    return LocalCustomBinderStore.loadCards(binderId);
  }

  static Future<int> cardCount(String binderId) async {
    final cards = await LocalCustomBinderStore.loadCards(binderId);
    return cards.length;
  }

  static Future<void> saveCurrentUserBinder(CustomBinder binder) async {
    await LocalCustomBinderStore.saveBinder(binder);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await syncBinderFromLocal(ownerUid: user.uid, binderId: binder.id);
    } catch (_) {}
  }

  static Future<void> deleteCurrentUserBinder(String binderId) async {
    await LocalCustomBinderStore.deleteBinder(binderId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await deleteBinderFromCloud(ownerUid: user.uid, binderId: binderId);
    } catch (_) {}
  }

  static Future<void> addCardToBinder({
    required String binderId,
    required TcgCard card,
    CardOwnership ownership = const CardOwnership(normal: true, copies: 1),
  }) async {
    await LocalCustomBinderStore.addCardToBinder(
      binderId: binderId,
      card: card,
      ownership: ownership,
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await syncBinderFromLocal(ownerUid: user.uid, binderId: binderId);
    } catch (_) {}
  }

  static Future<void> saveCardEntry({
    required String binderId,
    required CustomBinderCardEntry entry,
  }) async {
    await LocalCustomBinderStore.saveCardEntry(
      binderId: binderId,
      entry: entry,
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await syncBinderFromLocal(ownerUid: user.uid, binderId: binderId);
    } catch (_) {}
  }

  static Future<void> removeCardFromBinder({
    required String binderId,
    required String cardId,
  }) async {
    await LocalCustomBinderStore.removeCardFromBinder(
      binderId: binderId,
      cardId: cardId,
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await syncBinderFromLocal(ownerUid: user.uid, binderId: binderId);
    } catch (_) {}
  }
}
