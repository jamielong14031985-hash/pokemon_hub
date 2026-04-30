import '../models/app_user_profile.dart';
import '../models/card_ownership.dart';
import '../models/friend_trade_match_models.dart';
import '../models/wishlist_entry.dart';
import 'friend_service.dart';
import 'pokedex_sync_service.dart';
import 'wishlist_service.dart';

class FriendTradeMatchService {
  static Future<FriendTradeMatchSnapshot> loadMatches({
    required AppUserProfile currentProfile,
    required String friendUid,
  }) async {
    final results = await Future.wait<dynamic>([
      WishlistService.fetchWishlist(currentProfile.uid),
      WishlistService.fetchWishlist(friendUid),
      PokedexSyncService.fetchAllOwnedCards(currentProfile.uid),
      PokedexSyncService.fetchAllOwnedCards(friendUid),
    ]);

    final yourWishlist = results[0] as List<WishlistEntry>;
    final friendWishlist = results[1] as List<WishlistEntry>;
    final yourOwnedCards = results[2] as Map<String, CardOwnership>;
    final friendOwnedCards = results[3] as Map<String, CardOwnership>;

    final friendHasForYou = yourWishlist
        .where((entry) => (friendOwnedCards[entry.cardId]?.effectiveCopies ?? 0) > 0)
        .map(
          (entry) => FriendTradeMatchEntry(
            entry: entry,
            ownerCopies: friendOwnedCards[entry.cardId]?.effectiveCopies ?? 0,
            ownerIsFriend: true,
          ),
        )
        .toList()
      ..sort(_sortFriendTradeMatchEntries);

    final youHaveForFriend = friendWishlist
        .where((entry) => (yourOwnedCards[entry.cardId]?.effectiveCopies ?? 0) > 0)
        .map(
          (entry) => FriendTradeMatchEntry(
            entry: entry,
            ownerCopies: yourOwnedCards[entry.cardId]?.effectiveCopies ?? 0,
            ownerIsFriend: false,
          ),
        )
        .toList()
      ..sort(_sortFriendTradeMatchEntries);

    return FriendTradeMatchSnapshot(
      friendHasForYou: friendHasForYou,
      youHaveForFriend: youHaveForFriend,
      yourWishlistCount: yourWishlist.length,
      friendWishlistCount: friendWishlist.length,
      yourOwnedCount: yourOwnedCards.length,
      friendOwnedCount: friendOwnedCards.length,
    );
  }

  static int _sortFriendTradeMatchEntries(FriendTradeMatchEntry a, FriendTradeMatchEntry b) {
    final aPrice = a.entry.rawPrice ?? -1;
    final bPrice = b.entry.rawPrice ?? -1;
    if (aPrice != bPrice) {
      return bPrice.compareTo(aPrice);
    }
    return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
  }
}

class WishlistTradeMatchCentreService {
  static Future<WishlistTradeMatchCentreSnapshot> load({
    required AppUserProfile currentProfile,
  }) async {
    final friends = await FriendService.fetchFriends(currentProfile.uid);
    final ownResults = await Future.wait<dynamic>([
      WishlistService.fetchWishlist(currentProfile.uid),
      PokedexSyncService.fetchAllOwnedCards(currentProfile.uid),
    ]);

    final yourWishlist = ownResults[0] as List<WishlistEntry>;
    final yourOwnedCards = ownResults[1] as Map<String, CardOwnership>;

    if (friends.isEmpty) {
      return WishlistTradeMatchCentreSnapshot(
        overviews: const <FriendTradeMatchOverview>[],
        friendsScanned: 0,
        yourWishlistCount: yourWishlist.length,
        yourOwnedCount: yourOwnedCards.length,
      );
    }

    final overviewFutures = friends.map((friend) async {
      try {
        final results = await Future.wait<dynamic>([
          WishlistService.fetchWishlist(friend.uid),
          PokedexSyncService.fetchAllOwnedCards(friend.uid),
        ]);

        final friendWishlist = results[0] as List<WishlistEntry>;
        final friendOwnedCards = results[1] as Map<String, CardOwnership>;

        final friendHasForYou = yourWishlist
            .where((entry) => (friendOwnedCards[entry.cardId]?.effectiveCopies ?? 0) > 0)
            .map(
              (entry) => FriendTradeMatchEntry(
                entry: entry,
                ownerCopies: friendOwnedCards[entry.cardId]?.effectiveCopies ?? 0,
                ownerIsFriend: true,
              ),
            )
            .toList()
          ..sort(_sortTradeMatchEntries);

        final youHaveForFriend = friendWishlist
            .where((entry) => (yourOwnedCards[entry.cardId]?.effectiveCopies ?? 0) > 0)
            .map(
              (entry) => FriendTradeMatchEntry(
                entry: entry,
                ownerCopies: yourOwnedCards[entry.cardId]?.effectiveCopies ?? 0,
                ownerIsFriend: false,
              ),
            )
            .toList()
          ..sort(_sortTradeMatchEntries);

        final snapshot = FriendTradeMatchSnapshot(
          friendHasForYou: friendHasForYou,
          youHaveForFriend: youHaveForFriend,
          yourWishlistCount: yourWishlist.length,
          friendWishlistCount: friendWishlist.length,
          yourOwnedCount: yourOwnedCards.length,
          friendOwnedCount: friendOwnedCards.length,
        );

        if (snapshot.totalMatches == 0) return null;
        return FriendTradeMatchOverview(friend: friend, snapshot: snapshot);
      } catch (_) {
        return null;
      }
    }).toList();

    final overviews = (await Future.wait(overviewFutures)).whereType<FriendTradeMatchOverview>().toList();
    overviews.sort((a, b) {
      final matchCompare = b.totalMatches.compareTo(a.totalMatches);
      if (matchCompare != 0) return matchCompare;
      final spareCompare = b.likelySpareMatches.compareTo(a.likelySpareMatches);
      if (spareCompare != 0) return spareCompare;
      return b.estimatedSelectedValue.compareTo(a.estimatedSelectedValue);
    });

    return WishlistTradeMatchCentreSnapshot(
      overviews: overviews,
      friendsScanned: friends.length,
      yourWishlistCount: yourWishlist.length,
      yourOwnedCount: yourOwnedCards.length,
    );
  }

  static int _sortTradeMatchEntries(FriendTradeMatchEntry a, FriendTradeMatchEntry b) {
    final aPrice = a.entry.rawPrice ?? -1;
    final bPrice = b.entry.rawPrice ?? -1;
    if (aPrice != bPrice) {
      return bPrice.compareTo(aPrice);
    }
    return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
  }
}
