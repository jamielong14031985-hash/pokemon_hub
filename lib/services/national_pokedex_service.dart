import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/national_pokedex_species.dart';
import '../models/tcg_card.dart';
import 'local_pokedex_store.dart';
import 'local_custom_binder_store.dart';
import 'national_pokedex_name_matcher.dart';
import 'pokemon_tcg_service.dart';

class NationalPokedexService {
  static const _speciesCacheKey = 'pocketchase_national_species_1_to_1025_v1';
  static const _cardMetaCacheKey = 'pocketchase_national_card_metadata_v1';
  static const int supportedSpeciesCount = 1025;

  static Future<List<NationalPokedexSpecies>> loadSpecies() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_speciesCacheKey);
    if (stored != null) {
      try {
        final saved = (jsonDecode(stored) as List<dynamic>).cast<String>();
        if (saved.length == supportedSpeciesCount) {
          return List<NationalPokedexSpecies>.generate(saved.length,
              (i) => NationalPokedexSpecies(number: i + 1, slug: saved[i]));
        }
      } catch (_) {
        // Retrieve the catalogue again if local data is corrupt.
      }
    }

    final url = Uri.parse(
        'https://pokeapi.co/api/v2/pokemon-species?limit=$supportedSpeciesCount&offset=0');
    final response = await http.get(url).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Pokédex catalogue unavailable (${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (json['results'] as List<dynamic>? ?? <dynamic>[]);
    if (results.length != supportedSpeciesCount) {
      throw StateError('Pokédex catalogue was incomplete. Please retry.');
    }
    final names = <String>[];
    for (var i = 0; i < results.length; i++) {
      final item = Map<String, dynamic>.from(results[i] as Map);
      final name = (item['name'] ?? '').toString();
      final speciesUrl = (item['url'] ?? '').toString();
      final number = int.tryParse(RegExp(r'/pokemon-species/(\d+)/?')
              .firstMatch(speciesUrl)?.group(1) ?? '');
      if (number != i + 1 || name.isEmpty) {
        throw StateError('Pokédex returned an unexpected species order.');
      }
      names.add(name);
    }
    await prefs.setString(_speciesCacheKey, jsonEncode(names));
    return List<NationalPokedexSpecies>.generate(names.length,
        (i) => NationalPokedexSpecies(number: i + 1, slug: names[i]));
  }

  static Future<Map<String, NationalOwnedCard>> _loadMetadataCache() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_cardMetaCacheKey);
      if (raw == null) return <String, NationalOwnedCard>{};
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return decoded.map((id, entry) => MapEntry(
        id, NationalOwnedCard.fromJson(Map<String, dynamic>.from(entry as Map)),
      ));
    } catch (_) {
      return <String, NationalOwnedCard>{};
    }
  }

  static Future<void> _saveMetadataCache(Map<String, NationalOwnedCard> cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cardMetaCacheKey, jsonEncode(cache.map(
      (key, value) => MapEntry(key, value.toJson()),
    )));
  }

  static NationalOwnedCard _fromCard(TcgCard card) => NationalOwnedCard(
    cardId: card.id,
    name: card.name,
    setName: card.setName,
    imageUrl: (card.imageUrl?.trim().isNotEmpty == true)
        ? card.imageUrl : card.largeImageUrl,
  );

  /// Merge owned card printings from set binders and custom binders. A single
  /// catalogue card saved in multiple binders is still one choice.
  static List<NationalOwnedCard> uniqueOwnedPrintings(
    Iterable<NationalOwnedCard> cards,
  ) {
    final printings = <String, NationalOwnedCard>{};
    for (final card in cards) {
      final id = card.cardId.trim();
      if (id.isEmpty) continue;
      final old = printings[id];
      if (old == null ||
          ((old.imageUrl == null || old.imageUrl!.isEmpty) &&
              card.imageUrl?.isNotEmpty == true)) {
        printings[id] = card;
      }
    }
    return printings.values.toList()
      ..sort((a, b) {
        final bySet = a.setName.toLowerCase().compareTo(b.setName.toLowerCase());
        return bySet != 0 ? bySet : a.cardId.compareTo(b.cardId);
      });
  }

  /// Custom binders may hold owned cards not yet marked in their source set.
  /// Their saved names and images let us recognise them without extra API calls.
  static Future<Map<String, NationalOwnedCard>> _loadCustomBinderCards() async {
    final found = <String, NationalOwnedCard>{};
    try {
      final binders = await LocalCustomBinderStore.loadBinders();
      for (final binder in binders) {
        try {
          final entries = await LocalCustomBinderStore.loadCards(binder.id);
          for (final entry in entries) {
            if (entry.copies <= 0 || entry.cardId.trim().isEmpty) continue;
            final card = NationalOwnedCard(
              cardId: entry.cardId,
              name: entry.name,
              setName: entry.setName,
              imageUrl: entry.largeImageUrl?.isNotEmpty == true
                  ? entry.largeImageUrl : entry.imageUrl,
            );
            found.putIfAbsent(card.cardId, () => card);
          }
        } catch (_) {
          // One unreadable custom binder must not stop the whole Pokédex.
        }
      }
    } catch (_) {}
    return found;
  }

  /// A focused catalogue search can recover owned printings that a previous
  /// per-card metadata lookup missed. This only *intersects* the results with
  /// saved ownership; it never adds unowned cards to a National Pokédex.
  static Future<List<NationalOwnedCard>> recheckSpeciesPrintings(
    NationalPokedexSpecies species,
    List<NationalOwnedCard> alreadyRecognised,
  ) async {
    final ownership = await LocalPokedexStore.loadAllOwnershipBySet();
    final ownedIds = <String>{
      for (final set in ownership.values)
        for (final entry in set.entries)
          if (LocalPokedexStore.hasSavedCopies(entry.value)) entry.key,
    };
    final custom = await _loadCustomBinderCards();
    ownedIds.addAll(custom.keys);
    final all = <NationalOwnedCard>[...alreadyRecognised, ...custom.values];
    final speciesIndex = NationalPokedexNameMatcher.index([species]);
    const matcher = NationalPokedexNameMatcher();
    try {
      final candidates = await PokemonTcgService.searchCardsOnly(species.displayName)
          .timeout(const Duration(seconds: 25));
      final metadata = await _loadMetadataCache();
      var cacheChanged = false;
      for (final candidate in candidates) {
        if (!ownedIds.contains(candidate.id)) continue;
        if (matcher.match(candidate.name, speciesIndex) != species.number) continue;
        final recovered = _fromCard(candidate);
        all.add(recovered);
        // Persist identification so a later refresh does not lose the choice.
        if (metadata[candidate.id]?.name != recovered.name ||
            metadata[candidate.id]?.imageUrl != recovered.imageUrl) {
          metadata[candidate.id] = recovered;
          cacheChanged = true;
        }
      }
      if (cacheChanged) {
        try { await _saveMetadataCache(metadata); } catch (_) {}
      }
    } catch (_) {
      // The original local matches remain valid even if search is offline.
    }
    return uniqueOwnedPrintings(all.where(
      (card) => ownedIds.contains(card.cardId) &&
          matcher.match(card.name, speciesIndex) == species.number,
    ));
  }

  /// Stable identity of all currently owned card printings. Reading this uses
  /// only existing local collections, so reopening National Pokédex never
  /// needs a provider request just to decide whether an update is required.
  /// Quantities are deliberately omitted: 1 or 4 copies still counts as one
  /// National Pokédex printing, but adding/removing an ID changes the signature.
  static Future<String> ownershipSignature() async {
    final ownershipBySet = await LocalPokedexStore.loadAllOwnershipBySet();
    final ownedIds = <String>{
      for (final set in ownershipBySet.values)
        for (final entry in set.entries)
          if (LocalPokedexStore.hasSavedCopies(entry.value)) entry.key,
    };
    final customCards = await _loadCustomBinderCards();
    ownedIds.addAll(customCards.keys);
    final sorted = ownedIds.toList()..sort();
    return jsonEncode(sorted);
  }

  /// Reads the existing owned set binders. Never adds copies or modifies ownership.
  /// Network lookups only identify card names; they do not request market prices.
  static Future<NationalPokedexResult> scanOwnedSpecies(
      List<NationalPokedexSpecies> species, {
      void Function(int completed, int total)? onProgress,
    }) async {
    final ownershipBySet = await LocalPokedexStore.loadAllOwnershipBySet();
    final metadata = await _loadMetadataCache();
    final customCards = await _loadCustomBinderCards();
    final ownedIdsBySet = <String, List<String>>{};

    for (final set in ownershipBySet.entries) {
      final ids = set.value.entries
          .where((e) => LocalPokedexStore.hasSavedCopies(e.value))
          .map((e) => e.key).toSet().toList();
      if (ids.isNotEmpty) ownedIdsBySet[set.key] = ids;
    }

    // Custom binders store the card name and image already, so use those
    // local details for any card without a catalogue metadata record.
    for (final entry in customCards.entries) {
      metadata.putIfAbsent(entry.key, () => entry.value);
    }

    final allIdsForProgress = <String>{
      for (final ids in ownedIdsBySet.values) ...ids,
      ...customCards.keys,
    };
    final total = allIdsForProgress.length;
    var completed = allIdsForProgress.where(metadata.containsKey).length;
    onProgress?.call(completed, total);

    var modified = false;
    // Use one catalogue lookup per larger set, rather than hundreds of
    // individual HTTP calls. Small sets use individual card lookups.
    for (final set in ownedIdsBySet.entries) {
      final missing = set.value.where((id) => !metadata.containsKey(id)).toList();
      if (missing.isEmpty) continue;

      if (missing.length >= 7) {
        try {
          final setCards = await PokemonTcgService.fetchCardsBySet(set.key)
              .timeout(const Duration(seconds: 30));
          final byId = <String, TcgCard>{for (final card in setCards) card.id: card};
          for (final cardId in missing) {
            final card = byId[cardId];
            if (card == null) continue;
            metadata[cardId] = _fromCard(card);
            modified = true;
            completed++;
            onProgress?.call(completed, total);
          }
        } catch (_) {
          // Fall back to a direct lookup below for each unresolved ID.
        }
      }

      // Throttle individual lookups to avoid flooding catalogue providers.
      for (final id in missing.where((id) => !metadata.containsKey(id))) {
        try {
          final card = await PokemonTcgService.fetchCardById(id)
              .timeout(const Duration(seconds: 12));
          metadata[id] = _fromCard(card);
          modified = true;
          completed++;
          onProgress?.call(completed, total);
        } catch (_) {
          // The owned card still exists; defer identifying it until later.
        }
      }
      if (modified) {
        try { await _saveMetadataCache(metadata); } catch (_) {}
        modified = false;
      }
    }

    final byKey = NationalPokedexNameMatcher.index(species);
    const matcher = NationalPokedexNameMatcher();
    final matched = <int, List<NationalOwnedCard>>{};
    var pending = 0;
    var unmatched = 0;
    final allOwnedIds = allIdsForProgress;
    for (final id in allOwnedIds) {
      final card = metadata[id];
      if (card == null) {
        pending++;
        continue;
      }
      final speciesNumber = matcher.match(card.name, byKey);
      if (speciesNumber == null) {
        unmatched++;
        continue;
      }
      matched.putIfAbsent(speciesNumber, () => <NationalOwnedCard>[]).add(card);
    }
    return NationalPokedexResult(
      cardsBySpecies: {
        for (final group in matched.entries)
          group.key: uniqueOwnedPrintings(group.value),
      },
      cardsPendingIdentification: pending,
      cardsWithoutSpeciesMatch: unmatched,
    );
  }
}
