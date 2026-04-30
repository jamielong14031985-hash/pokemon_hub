import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_ownership.dart';
import '../models/custom_binder_models.dart';
import '../models/tcg_card.dart';
import '../utils/card_number_sorter.dart';
import 'collection_refresh_notifier.dart';

class LocalCustomBinderStore {
  static const String bindersKey = 'custom_binders_v1';

  static String cardsStorageKeyForBinder(String binderId) => 'custom_binder_cards_$binderId';

  static Future<List<CustomBinder>> loadBinders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(bindersKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <CustomBinder>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final binders = decoded
            .whereType<Map>()
            .map((item) => CustomBinder.fromJson(Map<String, dynamic>.from(item)))
            .where((binder) => binder.id.trim().isNotEmpty)
            .toList();
        binders.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
        return binders;
      }
    } catch (_) {}

    return const <CustomBinder>[];
  }

  static Future<CustomBinder?> loadBinder(String binderId) async {
    final binders = await loadBinders();
    for (final binder in binders) {
      if (binder.id == binderId) return binder;
    }
    return null;
  }

  static Future<void> _saveBinders(
    List<CustomBinder> binders, {
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = binders.where((binder) => binder.id.trim().isNotEmpty).toList()
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    if (cleaned.isEmpty) {
      await prefs.remove(bindersKey);
    } else {
      await prefs.setString(
        bindersKey,
        jsonEncode(cleaned.map((binder) => binder.toJson()).toList()),
      );
    }
    if (notify) {
      collectionRefreshNotifier.value++;
    }
  }

  static Future<void> saveBinder(
    CustomBinder binder, {
    bool notify = true,
  }) async {
    final binders = await loadBinders();
    final next = <CustomBinder>[];
    var replaced = false;
    for (final existing in binders) {
      if (existing.id == binder.id) {
        next.add(binder);
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) {
      next.add(binder);
    }
    await _saveBinders(next, notify: notify);
  }

  static Future<void> deleteBinder(
    String binderId, {
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final binders = await loadBinders();
    await _saveBinders(
      binders.where((binder) => binder.id != binderId).toList(),
      notify: notify,
    );
    await prefs.remove(cardsStorageKeyForBinder(binderId));
    if (notify) {
      collectionRefreshNotifier.value++;
    }
  }

  static Future<List<CustomBinderCardEntry>> loadCards(String binderId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cardsStorageKeyForBinder(binderId));
    if (raw == null || raw.trim().isEmpty) {
      return const <CustomBinderCardEntry>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final cards = decoded
            .whereType<Map>()
            .map((item) => CustomBinderCardEntry.fromJson(Map<String, dynamic>.from(item)))
            .where((entry) => entry.cardId.trim().isNotEmpty && entry.copies > 0)
            .toList();
        cards.sort((a, b) {
          final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (nameCompare != 0) return nameCompare;
          return compareCardNumbers(a.number, b.number);
        });
        return cards;
      }
    } catch (_) {}

    return const <CustomBinderCardEntry>[];
  }

  static Future<Map<String, CustomBinderCardEntry>> loadCardMap(String binderId) async {
    final cards = await loadCards(binderId);
    return {
      for (final entry in cards) entry.cardId: entry,
    };
  }

  static Future<void> saveCardMap(
    String binderId,
    Map<String, CustomBinderCardEntry> cardMap, {
    bool touchBinder = true,
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = cardMap.values
        .where((entry) => entry.cardId.trim().isNotEmpty && entry.copies > 0)
        .toList()
      ..sort((a, b) {
        final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (nameCompare != 0) return nameCompare;
        return compareCardNumbers(a.number, b.number);
      });

    if (cleaned.isEmpty) {
      await prefs.remove(cardsStorageKeyForBinder(binderId));
    } else {
      await prefs.setString(
        cardsStorageKeyForBinder(binderId),
        jsonEncode(cleaned.map((entry) => entry.toJson()).toList()),
      );
    }

    final binder = await loadBinder(binderId);
    if (binder != null && touchBinder) {
      await saveBinder(
        binder.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch),
        notify: notify,
      );
    } else if (notify) {
      collectionRefreshNotifier.value++;
    }
  }

  static Future<int> cardCount(String binderId) async {
    final cards = await loadCards(binderId);
    return cards.length;
  }

  static Future<void> addCardToBinder({
    required String binderId,
    required TcgCard card,
    CardOwnership ownership = const CardOwnership(normal: true, copies: 1),
    bool notify = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cardMap = await loadCardMap(binderId);
    final existing = cardMap[card.id];
    if (existing != null) {
      final existingOwnership = existing.ownership;
      cardMap[card.id] = existing.copyWith(
        normal: existingOwnership.normal || ownership.normal || (!ownership.reverseHolo && !ownership.holo),
        reverseHolo: existingOwnership.reverseHolo || ownership.reverseHolo,
        holo: existingOwnership.holo || ownership.holo,
        copies: existingOwnership.effectiveCopies + math.max(1, ownership.effectiveCopies).toInt(),
        updatedAtMs: now,
      );
    } else {
      cardMap[card.id] = CustomBinderCardEntry.fromCard(
        card,
        ownership: ownership.effectiveCopies > 0
            ? ownership
            : const CardOwnership(normal: true, copies: 1),
        updatedAtMs: now,
      );
    }
    await saveCardMap(binderId, cardMap, notify: notify);
  }

  static Future<void> saveCardEntry({
    required String binderId,
    required CustomBinderCardEntry entry,
    bool notify = true,
  }) async {
    final cardMap = await loadCardMap(binderId);
    if (entry.copies <= 0) {
      cardMap.remove(entry.cardId);
    } else {
      cardMap[entry.cardId] = entry;
    }
    await saveCardMap(binderId, cardMap, notify: notify);
  }

  static Future<void> removeCardFromBinder({
    required String binderId,
    required String cardId,
    bool notify = true,
  }) async {
    final cardMap = await loadCardMap(binderId);
    cardMap.remove(cardId);
    await saveCardMap(binderId, cardMap, notify: notify);
  }
}
