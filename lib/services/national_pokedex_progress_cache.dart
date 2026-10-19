import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/national_pokedex_species.dart';

/// A device-local snapshot of the National Pokédex, separate from ownership.
/// The user's set/custom-binder collection remains the source of truth.
class NationalPokedexProgressSnapshot {
  const NationalPokedexProgressSnapshot({
    required this.ownershipSignature,
    required this.result,
  });

  final String ownershipSignature;
  final NationalPokedexResult result;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'ownershipSignature': ownershipSignature,
        'pending': result.cardsPendingIdentification,
        'unmatched': result.cardsWithoutSpeciesMatch,
        'cards': <String, dynamic>{
          for (final group in result.cardsBySpecies.entries)
            '${group.key}': group.value.map((card) => card.toJson()).toList(),
        },
      };

  static NationalPokedexProgressSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final value = Map<String, dynamic>.from(json);
      if (value['version'] != 1 || value['ownershipSignature'] is! String) {
        return null;
      }
      final rawCards = Map<String, dynamic>.from(value['cards'] as Map);
      final cards = <int, List<NationalOwnedCard>>{};
      for (final entry in rawCards.entries) {
        final number = int.tryParse(entry.key);
        if (number == null || number < 1 || number > 1025 ||
            entry.value is! List) {
          continue;
        }
        final owned = <NationalOwnedCard>[];
        for (final item in entry.value as List) {
          if (item is! Map) continue;
          final card = NationalOwnedCard.fromJson(
              Map<String, dynamic>.from(item));
          if (card.cardId.trim().isNotEmpty) owned.add(card);
        }
        if (owned.isNotEmpty) cards[number] = owned;
      }
      return NationalPokedexProgressSnapshot(
        ownershipSignature: value['ownershipSignature'] as String,
        result: NationalPokedexResult(
          cardsBySpecies: cards,
          cardsPendingIdentification: (value['pending'] as num?)?.toInt() ?? 0,
          cardsWithoutSpeciesMatch: (value['unmatched'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Persistent, account-scoped snapshot. Only card IDs/names/images and species
/// associations are stored; no prices, quantities or unrelated account data.
class NationalPokedexProgressCache {
  const NationalPokedexProgressCache._();

  static String get _storageKey {
    String uid = 'device';
    try {
      uid = FirebaseAuth.instance.currentUser?.uid ?? uid;
    } catch (_) {
      // Standalone tests and signed-out sessions can use the device scope.
    }
    return 'pocketchase_national_progress_snapshot_v1_$uid';
  }

  static Future<NationalPokedexProgressSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return NationalPokedexProgressSnapshot.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(
    String ownershipSignature,
    NationalPokedexResult result,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = NationalPokedexProgressSnapshot(
      ownershipSignature: ownershipSignature,
      result: result,
    );
    final ok = await prefs.setString(_storageKey, jsonEncode(snapshot.toJson()));
    if (!ok) throw StateError('Could not save National Pokédex progress');
  }
}
