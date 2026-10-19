import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/profile_stats.dart';
import '../models/tcg_card.dart';
import '../services/community_image_services.dart';
import '../services/currency_settings.dart';
import '../services/external_card_price_service.dart';
import '../services/local_card_price_store.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/pokemon_tcg_service.dart';
import 'card_price_confidence.dart';

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

Future<List<TcgCard>> fetchCurrentUserProfileCardsBySet(
  Map<String, int> cardCopies,
) async {
  if (cardCopies.isEmpty) return const <TcgCard>[];

  final ownedIds = cardCopies.keys.toSet();
  final setIds = (await LocalPokedexStore.allNonEmptySetIds()).toList();
  final cardsById = <String, TcgCard>{};

  // Loading whole sets is dramatically faster than making one request for
  // every owned card, and it reuses the same cache as the Set Pokédex pages.
  const setChunkSize = 3;
  for (var start = 0; start < setIds.length; start += setChunkSize) {
    final end = (start + setChunkSize) > setIds.length
        ? setIds.length
        : start + setChunkSize;
    final chunk = setIds.sublist(start, end);
    final results = await Future.wait<List<TcgCard>>(
      chunk.map((setId) async {
        try {
          return await PokemonTcgService.fetchCardsBySet(setId).timeout(
            const Duration(seconds: 30),
          );
        } catch (_) {
          return const <TcgCard>[];
        }
      }),
    );

    for (final cards in results) {
      for (final card in cards) {
        if (ownedIds.contains(card.id)) cardsById[card.id] = card;
      }
    }
  }

  // A set feed can occasionally omit a promo or newly released card. Only
  // fall back to individual lookups for those missing records.
  final missingIds = ownedIds.where((id) => !cardsById.containsKey(id));
  final missingCards = await fetchProfileCardsFast(missingIds);
  for (final card in missingCards) {
    cardsById[card.id] = card;
  }

  return cardsById.values.toList();
}

class CollectionPriceSyncResult {
  const CollectionPriceSyncResult({required this.attempted, required this.priced});

  final int attempted;
  final int priced;
}

Future<CollectionPriceSyncResult> refreshMissingCollectionPrices({
  int limit = 20,
}) async {
  final cardCopies = normalPokedexCardCopiesOnly(
    await LocalPokedexStore.loadAllCardCopies(),
  );
  if (cardCopies.isEmpty) {
    return const CollectionPriceSyncResult(attempted: 0, priced: 0);
  }

  final cards = await fetchCurrentUserProfileCardsBySet(cardCopies);
  final cachedPrices = await LocalCardPriceStore.loadAll();
  final missing = cards
      .map((card) => cachedPrices[card.id]?.applyTo(card) ?? card)
      .where((card) => (card.marketPrice ?? 0) <= 0)
      .take(limit)
      .toList();

  var priced = 0;
  const chunkSize = 4;
  for (var start = 0; start < missing.length; start += chunkSize) {
    final end = (start + chunkSize) > missing.length
        ? missing.length
        : start + chunkSize;
    final results = await Future.wait<TcgCard>(
      missing.sublist(start, end).map(
            (card) => ExternalCardPriceService.enrichCardWithExternalPrice(card),
          ),
    );
    priced += results.where((card) => (card.marketPrice ?? 0) > 0).length;
  }

  return CollectionPriceSyncResult(attempted: missing.length, priced: priced);
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

  final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == trimmedOwnerUid;
  if (isCurrentUser) {
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
  var fetchedCards = isCurrentUser
      ? await fetchCurrentUserProfileCardsBySet(cardCopies)
      : await fetchProfileCardsFast(cardCopies.keys);

  if (isCurrentUser && fetchedCards.isNotEmpty) {
    final cachedPrices = await LocalCardPriceStore.loadAll();
    fetchedCards = fetchedCards
        .map((card) => cachedPrices[card.id]?.applyTo(card) ?? card)
        .toList();
  }

  if (fetchedCards.isEmpty) return fallbackBasicStats;

  double totalEstimatedPrice = 0;
  double salesSupportedValue = 0;
  double guideOnlyValue = 0;
  var highValueUnverifiedCards = 0;
  var salesSupportedUniqueCards = 0;
  TcgCard? mostExpensiveCard;
  int mostExpensiveCardCopies = 0;
  double mostExpensivePrice = -1;
  final setCopies = <String, int>{};
  final rarityCopies = <String, int>{};
  final rarityValues = <String, double>{};
  final topValueCards = <TcgCard>[];
  var pricedUniqueCards = 0;
  var lowConfidencePricedCards = 0;

  for (final card in fetchedCards) {
    final copies = cardCopies[card.id] ?? 0;
    if (copies <= 0) continue;

    final convertedUnitPrice = profileRawUnitPriceInSelectedCurrency(card);
    final cardTotalValue = convertedUnitPrice * copies;
    totalEstimatedPrice += cardTotalValue;
    if (convertedUnitPrice > 0) {
      if (CardPriceConfidence.isSalesSupported(card)) {
        salesSupportedValue += cardTotalValue;
        salesSupportedUniqueCards++;
      } else {
        guideOnlyValue += cardTotalValue;
        if (CardPriceConfidence.isHighValueWithoutSales(card)) {
          highValueUnverifiedCards++;
        }
      }
    }

    final rarityLabel = profileRarityLabel(card);
    rarityCopies.update(rarityLabel, (existing) => existing + copies, ifAbsent: () => copies);
    rarityValues.update(rarityLabel, (existing) => existing + cardTotalValue, ifAbsent: () => cardTotalValue);
    if (convertedUnitPrice > 0) {
      pricedUniqueCards++;
      topValueCards.add(card);
      final confidence = card.externalRawPriceConfidence.toLowerCase();
      if (confidence == 'low' || confidence == 'reference') {
        lowConfidencePricedCards++;
      }
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
    pricedUniqueCards: pricedUniqueCards,
    setsCollected: setCopies.length,
    lowConfidencePricedCards: lowConfidencePricedCards,
    salesSupportedValue: salesSupportedValue,
    guideOnlyValue: guideOnlyValue,
    highValueUnverifiedCards: highValueUnverifiedCards,
    salesSupportedUniqueCards: salesSupportedUniqueCards,
  );
}
