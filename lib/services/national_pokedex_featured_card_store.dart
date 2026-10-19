import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/national_pokedex_species.dart';

/// Remembers which of the user's *already owned* cards should appear for each
/// Pokémon species. This never changes collection ownership or Pokédex totals.
/// Choices are local to the current Firebase user on this device.
class NationalPokedexFeaturedCardStore {
  const NationalPokedexFeaturedCardStore._();

  static String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'device';
    return 'pocketchase_national_featured_cards_v1_$uid';
  }

  static Future<Map<int, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <int, String>{};
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final choices = <int, String>{};
      for (final entry in decoded.entries) {
        final speciesNumber = int.tryParse(entry.key);
        final cardId = entry.value?.toString().trim() ?? '';
        if (speciesNumber != null && speciesNumber > 0 && cardId.isNotEmpty) {
          choices[speciesNumber] = cardId;
        }
      }
      return choices;
    } catch (_) {
      // Corrupt preferences cannot prevent the Pokédex from opening.
      return <int, String>{};
    }
  }

  static Future<void> save(Map<int, String> selections) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, String>{
      for (final entry in selections.entries) '${entry.key}': entry.value,
    };
    final saved = await prefs.setString(_storageKey, jsonEncode(data));
    if (!saved) throw StateError('Could not save selected Pokédex artwork');
  }

  /// Falls back to the first *currently owned* match when a chosen card has
  /// been removed or its metadata is temporarily unavailable.
  static NationalOwnedCard? selectedCard(
    List<NationalOwnedCard> ownedCards,
    String? preferredCardId,
  ) {
    if (ownedCards.isEmpty) return null;
    if (preferredCardId != null) {
      for (final card in ownedCards) {
        if (card.cardId == preferredCardId) return card;
      }
    }
    return ownedCards.first;
  }
}
