import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/profile_stats.dart';
import '../models/tcg_card.dart';
import '../services/community_image_services.dart';
import '../services/currency_settings.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/pokemon_tcg_service.dart';

String profileRarityLabel(TcgCard card) {
  final rarity = (card.rarity ?? '').trim();
  if (rarity.isEmpty) return 'Unknown rarity';
  return rarity;
}

int profileRarityRank(String rarity) {
  final value = rarity.toLowerCase();
  if (value.contains('special illustration')) return 110;
  if (value.contains('illustration')) return 100;
  if (value.contains('secret') || value.contains('hyper') || value.contains('rainbow')) return 95;
  if (value.contains('ultra')) return 90;
  if (value.contains('ace spec')) return 85;
  if (value.contains('amazing') || value.contains('radiant')) return 80;
  if (value.contains('double rare')) return 75;
  if (value.contains('rare holo')) return 70;
  if (value == 'rare' || value.contains('rare')) return 60;
  if (value.contains('uncommon')) return 40;
  if (value.contains('common')) return 30;
  if (value.contains('unknown')) return 0;
  return 50;
}

String formatProfilePercent(double value) {
  if (!value.isFinite || value <= 0) return '0%';
  if (value >= 99.5) return '100%';
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}%';
}

bool isLocalPromoFallbackCardId(String cardId) {
  final value = cardId.trim().toLowerCase();
  return value.startsWith('mep-');
}

Map<String, int> normalPokedexCardCopiesOnly(Map<String, int> cardCopies) {
  return <String, int>{
    for (final entry in cardCopies.entries)
      if (!isLocalPromoFallbackCardId(entry.key) && entry.value > 0)
        entry.key: entry.value,
  };
}


ProfileStats emptyProfileStats() {
  return const ProfileStats(
    totalCards: 0,
    uniqueCards: 0,
    totalEstimatedPrice: 0,
    mostExpensiveCard: null,
    mostExpensiveCardCopies: 0,
    favouriteSetName: null,
    favouriteSetCopies: 0,
    rarityCopies: <String, int>{},
    rarityValues: <String, double>{},
    topValueCards: <TcgCard>[],
  );
}

ProfileStats basicProfileStatsFromCopies(Map<String, int> cardCopies) {
  if (cardCopies.isEmpty) return emptyProfileStats();

  final totalCards = cardCopies.values.fold<int>(
    0,
    (runningTotal, value) => runningTotal + value,
  );

  return ProfileStats(
    totalCards: totalCards,
    uniqueCards: cardCopies.length,
    totalEstimatedPrice: 0,
    mostExpensiveCard: null,
    mostExpensiveCardCopies: 0,
    favouriteSetName: null,
    favouriteSetCopies: 0,
    rarityCopies: const <String, int>{},
    rarityValues: const <String, double>{},
    topValueCards: const <TcgCard>[],
  );
}

Future<List<TcgCard>> fetchProfileCardsFast(Iterable<String> cardIds) async {
  final ids = cardIds
      .map((cardId) => cardId.trim())
      .where((cardId) => cardId.isNotEmpty)
      .toList();

  if (ids.isEmpty) return const <TcgCard>[];

  const chunkSize = 8;
  final fetchedCards = <TcgCard>[];

  for (var start = 0; start < ids.length; start += chunkSize) {
    final end = (start + chunkSize) > ids.length ? ids.length : start + chunkSize;
    final chunk = ids.sublist(start, end);

    final results = await Future.wait<TcgCard?>(
      chunk.map((cardId) async {
        try {
          final cachedCard = await PokemonTcgService.fetchCardById(cardId).timeout(
            const Duration(seconds: 8),
          );
          if ((cachedCard.marketPrice ?? 0) > 0) {
            return cachedCard;
          }

          final freshCard = await PokemonTcgService.fetchCardById(
            cardId,
            forceRefresh: true,
          ).timeout(
            const Duration(seconds: 12),
          );
          if ((freshCard.marketPrice ?? 0) > 0) {
            return freshCard;
          }

          // Do not call JustTCG while loading profile stats. A profile can contain
          // lots of cards, and JustTCG is rate limited. Manual refresh on the
          // card details screen still uses JustTCG and the Cloud Function cache.
          return freshCard;
        } catch (_) {
          return null;
        }
      }),
    );

    fetchedCards.addAll(results.whereType<TcgCard>());
  }

  return fetchedCards;
}

ImageProvider? profileImageProviderFromRef(String? imageRef) {
  final trimmed = imageRef?.trim() ?? '';
  if (trimmed.isEmpty) return null;

  if (FirebaseImageStorageService.isRemoteRef(trimmed)) {
    return NetworkImage(trimmed);
  }

  final bytes = CommunityImageCodec.decode(trimmed);
  if (bytes == null) return null;
  return MemoryImage(bytes);
}

double profileRawUnitPriceInSelectedCurrency(TcgCard card) {
  return CurrencySettings.convertAmountSync(
        card.marketPrice,
        fromCurrency: card.marketPriceCurrency,
      ) ??
      0;
}

Future<ProfileStats> loadProfileStatsForOwner(
  String ownerUid, {
  bool preferCurrentUserLocalCache = false,
}) async {
  final trimmedOwnerUid = ownerUid.trim();
  if (trimmedOwnerUid.isEmpty) return emptyProfileStats();

  Map<String, int> cardCopies;

  if (FirebaseAuth.instance.currentUser?.uid == trimmedOwnerUid) {
    // For your own profile, use the same local Pokédex source that the
    // Pokédex screens use. This prevents old cloud data from showing deleted
    // cards on the profile when the local Pokédex is empty.
    cardCopies = await LocalPokedexStore.loadAllCardCopies();
  } else {
    // For friends/other users, local storage is not available, so use cloud.
    final ownershipByCardId = await PokedexSyncService.fetchAllOwnedCards(
      trimmedOwnerUid,
    );

    cardCopies = <String, int>{
      for (final entry in ownershipByCardId.entries)
        if (entry.value.collectionCount > 0)
          entry.key: entry.value.collectionCount,
    };
  }

  cardCopies = normalPokedexCardCopiesOnly(cardCopies);

  if (cardCopies.isEmpty) return emptyProfileStats();

  final fallbackBasicStats = basicProfileStatsFromCopies(cardCopies);
  final fetchedCards = await fetchProfileCardsFast(cardCopies.keys);

  if (fetchedCards.isEmpty) return fallbackBasicStats;

  double totalEstimatedPrice = 0;
  TcgCard? mostExpensiveCard;
  int mostExpensiveCardCopies = 0;
  double mostExpensivePrice = -1;
  final setCopies = <String, int>{};
  final rarityCopies = <String, int>{};
  final rarityValues = <String, double>{};
  final topValueCards = <TcgCard>[];

  for (final card in fetchedCards) {
    final copies = cardCopies[card.id] ?? 0;
    if (copies <= 0) continue;

    final convertedUnitPrice = profileRawUnitPriceInSelectedCurrency(card);
    final cardTotalValue = convertedUnitPrice * copies;
    totalEstimatedPrice += cardTotalValue;

    final rarityLabel = profileRarityLabel(card);
    rarityCopies.update(rarityLabel, (existing) => existing + copies, ifAbsent: () => copies);
    rarityValues.update(rarityLabel, (existing) => existing + cardTotalValue, ifAbsent: () => cardTotalValue);
    if (convertedUnitPrice > 0) {
      topValueCards.add(card);
    }

    if (card.setName.trim().isNotEmpty) {
      setCopies.update(card.setName, (existing) => existing + copies, ifAbsent: () => copies);
    }

    if (convertedUnitPrice > 0 && convertedUnitPrice > mostExpensivePrice) {
      mostExpensivePrice = convertedUnitPrice;
      mostExpensiveCard = card;
      mostExpensiveCardCopies = copies;
    }
  }

  topValueCards.sort((a, b) {
    final aCopies = cardCopies[a.id] ?? 0;
    final bCopies = cardCopies[b.id] ?? 0;
    final aUnitPrice = profileRawUnitPriceInSelectedCurrency(a);
    final bUnitPrice = profileRawUnitPriceInSelectedCurrency(b);
    final valueCompare = (bUnitPrice * bCopies).compareTo(aUnitPrice * aCopies);
    if (valueCompare != 0) return valueCompare;
    return bUnitPrice.compareTo(aUnitPrice);
  });

  final totalCards = cardCopies.values.fold<int>(0, (runningTotal, value) => runningTotal + value);
  String? favouriteSetName;
  var favouriteSetCopies = 0;
  for (final entry in setCopies.entries) {
    if (entry.value > favouriteSetCopies) {
      favouriteSetName = entry.key;
      favouriteSetCopies = entry.value;
    }
  }

  return ProfileStats(
    totalCards: totalCards,
    uniqueCards: cardCopies.length,
    totalEstimatedPrice: totalEstimatedPrice,
    mostExpensiveCard: mostExpensiveCard,
    mostExpensiveCardCopies: mostExpensiveCardCopies,
    favouriteSetName: favouriteSetName,
    favouriteSetCopies: favouriteSetCopies,
    rarityCopies: rarityCopies,
    rarityValues: rarityValues,
    topValueCards: topValueCards.take(50).toList(),
  );
}
