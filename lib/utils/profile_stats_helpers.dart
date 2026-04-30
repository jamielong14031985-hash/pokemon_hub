import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/profile_stats.dart';
import '../models/tcg_card.dart';
import '../services/community_image_services.dart';
import '../services/currency_settings.dart';
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

Future<ProfileStats> loadProfileStatsForOwner(
  String ownerUid, {
  bool preferCurrentUserLocalCache = false,
}) async {
  final trimmedOwnerUid = ownerUid.trim();
  if (trimmedOwnerUid.isEmpty) return emptyProfileStats();

  Map<String, int> cardCopies;
  if (preferCurrentUserLocalCache && FirebaseAuth.instance.currentUser?.uid == trimmedOwnerUid) {
    cardCopies = await PokedexSyncService.loadCurrentUserAllCardCopies();
  } else {
    final ownershipByCardId = await PokedexSyncService.fetchAllOwnedCards(trimmedOwnerUid);
    cardCopies = <String, int>{
      for (final entry in ownershipByCardId.entries)
        if (entry.value.collectionCount > 0) entry.key: entry.value.collectionCount,
    };
  }

  if (cardCopies.isEmpty) return emptyProfileStats();

  final fetchedCards = <TcgCard>[];
  for (final cardId in cardCopies.keys) {
    try {
      fetchedCards.add(await PokemonTcgService.fetchCardById(cardId));
    } catch (_) {}
  }

  if (fetchedCards.isEmpty) return emptyProfileStats();

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

    final convertedUnitPrice = CurrencySettings.convertAmountSync(
          card.marketPrice,
          fromCurrency: card.rawPriceCurrency,
        ) ??
        0;
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

    if (convertedUnitPrice > mostExpensivePrice) {
      mostExpensivePrice = convertedUnitPrice;
      mostExpensiveCard = card;
      mostExpensiveCardCopies = copies;
    }
  }

  topValueCards.sort((a, b) {
    final aCopies = cardCopies[a.id] ?? 0;
    final bCopies = cardCopies[b.id] ?? 0;
    final aUnitPrice = CurrencySettings.convertAmountSync(
          a.marketPrice,
          fromCurrency: a.rawPriceCurrency,
        ) ??
        0;
    final bUnitPrice = CurrencySettings.convertAmountSync(
          b.marketPrice,
          fromCurrency: b.rawPriceCurrency,
        ) ??
        0;
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
