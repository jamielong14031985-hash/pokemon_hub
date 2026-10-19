import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_ownership.dart';
import 'collection_refresh_notifier.dart';

class LocalPokedexStore {
  static String storageKeyForSet(String setId) => 'set_pokedex_$setId';

  static bool isOwned(CardOwnership ownership) {
    return ownership.effectiveCopies > 0 ||
        ownership.normal ||
        ownership.reverseHolo ||
        ownership.holo;
  }

  static bool hasSavedCopies(CardOwnership ownership) {
    return ownership.collectionCount > 0;
  }

  static Future<Map<String, CardOwnership>> loadSetOwnershipMap(String setId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKeyForSet(setId));
    final ownershipByCardId = <String, CardOwnership>{};

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            ownershipByCardId[key] = CardOwnership.fromJson(value);
          } else if (value is Map) {
            ownershipByCardId[key] = CardOwnership.fromJson(Map<String, dynamic>.from(value));
          }
        });
      } catch (_) {}
    }

    return ownershipByCardId;
  }

  static Future<void> saveSetOwnershipMap(
    String setId,
    Map<String, CardOwnership> ownershipByCardId, {
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      for (final entry in ownershipByCardId.entries)
        if (hasSavedCopies(entry.value)) entry.key: entry.value.toJson(),
    };

    if (map.isEmpty) {
      await prefs.remove(storageKeyForSet(setId));
    } else {
      await prefs.setString(storageKeyForSet(setId), jsonEncode(map));
    }
    if (notify) {
      collectionRefreshNotifier.value++;
    }
  }

  static Future<void> removeCard(String setId, String cardId) async {
    final ownershipByCardId = await loadSetOwnershipMap(setId);
    ownershipByCardId.remove(cardId);
    await saveSetOwnershipMap(setId, ownershipByCardId);
  }

  static Future<void> clearSet(String setId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKeyForSet(setId));
    collectionRefreshNotifier.value++;
  }

  static Future<bool> mergeSetsInto({
    required String targetSetId,
    required Iterable<String> sourceSetIds,
  }) async {
    final cleanTargetId = targetSetId.trim();
    if (cleanTargetId.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final merged = await loadSetOwnershipMap(cleanTargetId);
    var changed = false;

    for (final rawSourceId in sourceSetIds) {
      final sourceId = rawSourceId.trim();
      if (sourceId.isEmpty || sourceId == cleanTargetId) continue;

      final source = await loadSetOwnershipMap(sourceId);
      for (final entry in source.entries) {
        if (!hasSavedCopies(entry.value)) continue;
        // The same physical card may already have been migrated by an earlier
        // build. Keep the existing target record instead of doubling copies.
        merged.putIfAbsent(entry.key, () => entry.value);
      }

      if (source.isNotEmpty || prefs.containsKey(storageKeyForSet(sourceId))) {
        await prefs.remove(storageKeyForSet(sourceId));
        changed = true;
      }
    }

    if (!changed) return false;
    await saveSetOwnershipMap(cleanTargetId, merged, notify: false);
    collectionRefreshNotifier.value++;
    return true;
  }

  static Future<Set<String>> allTrackedSetIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((key) => key.startsWith('set_pokedex_'))
        .map((key) => key.replaceFirst('set_pokedex_', ''))
        .toSet();
  }

  static Future<Map<String, Map<String, CardOwnership>>>
      loadAllOwnershipBySet() async {
    final setIds = await allTrackedSetIds();
    final ownershipBySet = <String, Map<String, CardOwnership>>{};

    for (final setId in setIds) {
      final ownership = await loadSetOwnershipMap(setId);
      final saved = <String, CardOwnership>{
        for (final entry in ownership.entries)
          if (hasSavedCopies(entry.value)) entry.key: entry.value,
      };
      if (saved.isNotEmpty) ownershipBySet[setId] = saved;
    }

    return ownershipBySet;
  }

  static Future<void> replaceAllOwnershipBySet(
    Map<String, Map<String, CardOwnership>> ownershipBySet,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final existingKeys = prefs
        .getKeys()
        .where((key) => key.startsWith('set_pokedex_'))
        .toList(growable: false);

    for (final key in existingKeys) {
      await prefs.remove(key);
    }

    for (final setEntry in ownershipBySet.entries) {
      await saveSetOwnershipMap(
        setEntry.key,
        setEntry.value,
        notify: false,
      );
    }

    collectionRefreshNotifier.value++;
  }

  static Future<Set<String>> allNonEmptySetIds() async {
    final prefs = await SharedPreferences.getInstance();
    final setIds = await allTrackedSetIds();
    final nonEmpty = <String>{};

    for (final setId in setIds) {
      final ownershipByCardId = await loadSetOwnershipMap(setId);
      final hasAnySavedCopies = ownershipByCardId.values.any(hasSavedCopies);

      if (hasAnySavedCopies) {
        nonEmpty.add(setId);
      } else {
        // Remove old empty/zero-copy local records so the Sets page
        // immediately stops showing this set.
        await prefs.remove(storageKeyForSet(setId));
      }
    }

    return nonEmpty;
  }

  static Future<Map<String, int>> savedCopyCountsBySetId({
    bool cleanEmptySets = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final setIds = await allTrackedSetIds();
    final counts = <String, int>{};

    for (final setId in setIds) {
      final ownershipByCardId = await loadSetOwnershipMap(setId);
      var totalCopies = 0;

      for (final ownership in ownershipByCardId.values) {
        final ownedCount = ownership.collectionCount;
        if (ownedCount > 0) {
          totalCopies += ownedCount;
        }
      }

      if (totalCopies > 0) {
        counts[setId] = totalCopies;
      } else if (cleanEmptySets) {
        await prefs.remove(storageKeyForSet(setId));
      }
    }

    return counts;
  }

  static Future<Map<String, int>> loadAllCardCopies() async {
    final setIds = await allTrackedSetIds();
    final cardCopies = <String, int>{};

    for (final setId in setIds) {
      final ownershipByCardId = await loadSetOwnershipMap(setId);
      for (final entry in ownershipByCardId.entries) {
        final copies = entry.value.collectionCount;
        if (copies > 0) {
          cardCopies.update(entry.key, (existing) => existing + copies, ifAbsent: () => copies);
        }
      }
    }

    return cardCopies;
  }
}

