import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import '../models/tcg_set.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../utils/app_helpers.dart';
import '../utils/card_number_sorter.dart';
import '../widgets/binder_card_tile.dart';
import '../widgets/set_logo_widgets.dart';
import 'set_card_details_page.dart';

class FriendPokedexSetsPage extends StatelessWidget {
  const FriendPokedexSetsPage({
    super.key,
    required this.currentProfile,
    required this.friendUid,
    required this.friendName,
  });

  final AppUserProfile currentProfile;
  final String friendUid;
  final String friendName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(friendPokedexLabel(friendName)),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<List<String>>(
          stream: PokedexSyncService.ownedSetIdsStream(friendUid),
          builder: (context, idsSnapshot) {
            final setIds = idsSnapshot.data ?? const <String>[];
            return FutureBuilder<List<TcgSet>>(
              future: PokemonTcgService.fetchSets(),
              builder: (context, setsSnapshot) {
                if (setsSnapshot.connectionState == ConnectionState.waiting ||
                    idsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (setsSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load Pokédex sets: ${setsSnapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                final allSets = setsSnapshot.data ?? const <TcgSet>[];
                final setIdLookup = setIds.toSet();
                final visibleSets = allSets.where((set) => setIdLookup.contains(set.id)).toList();

                if (visibleSets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${friendName.trim().isEmpty ? 'This trainer' : friendName} has not synced any Pokédex sets yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: visibleSets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final set = visibleSets[index];
                    return Card(
                      color: const Color(0xFF102754),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FriendSetPokedexPage(
                                friendUid: friendUid,
                                friendName: friendName,
                                set: set,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          constraints: const BoxConstraints(minHeight: 110),
                          child: ResolvedSetLogo(
                            setId: set.id,
                            setName: set.name,
                            fallbackLogoUrl: set.logoUrl,
                            height: 64,
                            fit: BoxFit.contain,
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class FriendSetPokedexPage extends StatelessWidget {
  const FriendSetPokedexPage({
    super.key,
    required this.friendUid,
    required this.friendName,
    required this.set,
  });

  final String friendUid;
  final String friendName;
  final TcgSet set;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(friendPokedexLabel(friendName)),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<TcgCard>>(
        future: PokemonTcgService.fetchCardsBySet(set.id),
        builder: (context, cardsSnapshot) {
          if (cardsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cardsSnapshot.hasError) {
            return Center(
              child: Text(
                'Could not load cards: ${cardsSnapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final cards = cardsSnapshot.data ?? const <TcgCard>[];
          cards.sort((a, b) => compareCardNumbers(a.number, b.number));

          return StreamBuilder<Map<String, CardOwnership>>(
            stream: PokedexSyncService.setOwnershipStream(ownerUid: friendUid, setId: set.id),
            builder: (context, ownershipSnapshot) {
              final ownershipByCardId = ownershipSnapshot.data ?? const <String, CardOwnership>{};
              final ownedCards = cards
                  .where((card) => LocalPokedexStore.isOwned(ownershipByCardId[card.id] ?? const CardOwnership()))
                  .toList();

              if (ownedCards.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No saved cards found in this set yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: ResolvedSetLogo(
                        setId: set.id,
                        setName: set.name,
                        fallbackLogoUrl: set.logoUrl,
                        height: 64,
                        fit: BoxFit.contain,
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  Card(
                    color: const Color(0xFF102754),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        '${ownedCards.length} card${ownedCards.length == 1 ? '' : 's'} saved in this set.',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ownedCards.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 0.76,
                    ),
                    itemBuilder: (context, index) {
                      final card = ownedCards[index];
                      final ownership = ownershipByCardId[card.id] ?? const CardOwnership();
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SetCardDetailsPage(
                                card: card,
                                ownership: ownership,
                                readOnly: true,
                                ownerLabel: friendPokedexLabel(friendName),
                              ),
                            ),
                          );
                        },
                        child: BinderCardTile(
                          card: card,
                          ownership: ownership,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

