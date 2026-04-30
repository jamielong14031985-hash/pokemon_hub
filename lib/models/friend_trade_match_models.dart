import '../services/currency_settings.dart';
import 'friend_models.dart';
import 'wishlist_entry.dart';

class FriendTradeMatchEntry {
  const FriendTradeMatchEntry({
    required this.entry,
    required this.ownerCopies,
    required this.ownerIsFriend,
  });

  final WishlistEntry entry;
  final int ownerCopies;
  final bool ownerIsFriend;

  bool get hasLikelySpare => ownerCopies > 1;

  String get copiesLabel => '${ownerIsFriend ? 'They own' : 'You own'} x$ownerCopies';
}

class FriendTradeMatchSnapshot {
  const FriendTradeMatchSnapshot({
    required this.friendHasForYou,
    required this.youHaveForFriend,
    required this.yourWishlistCount,
    required this.friendWishlistCount,
    required this.yourOwnedCount,
    required this.friendOwnedCount,
  });

  final List<FriendTradeMatchEntry> friendHasForYou;
  final List<FriendTradeMatchEntry> youHaveForFriend;
  final int yourWishlistCount;
  final int friendWishlistCount;
  final int yourOwnedCount;
  final int friendOwnedCount;

  int get totalMatches => friendHasForYou.length + youHaveForFriend.length;
}

class FriendTradeMatchOverview {
  const FriendTradeMatchOverview({
    required this.friend,
    required this.snapshot,
  });

  final FriendSummary friend;
  final FriendTradeMatchSnapshot snapshot;

  int get totalMatches => snapshot.totalMatches;

  int get likelySpareMatches {
    return snapshot.friendHasForYou.where((item) => item.hasLikelySpare).length +
        snapshot.youHaveForFriend.where((item) => item.hasLikelySpare).length;
  }

  double get estimatedSelectedValue {
    double total = 0;
    for (final item in allEntries) {
      total += CurrencySettings.convertAmountSync(
            item.entry.rawPrice,
            fromCurrency: item.entry.rawPriceCurrency,
          ) ??
          0;
    }
    return total;
  }

  List<FriendTradeMatchEntry> get allEntries => <FriendTradeMatchEntry>[
        ...snapshot.friendHasForYou,
        ...snapshot.youHaveForFriend,
      ];

  List<FriendTradeMatchEntry> topEntries({bool likelySpareOnly = false}) {
    final items = allEntries.where((item) => !likelySpareOnly || item.hasLikelySpare).toList();
    items.sort((a, b) {
      final aValue = CurrencySettings.convertAmountSync(
            a.entry.rawPrice,
            fromCurrency: a.entry.rawPriceCurrency,
          ) ??
          0;
      final bValue = CurrencySettings.convertAmountSync(
            b.entry.rawPrice,
            fromCurrency: b.entry.rawPriceCurrency,
          ) ??
          0;
      if (aValue != bValue) {
        return bValue.compareTo(aValue);
      }
      return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
    });
    return items.take(3).toList();
  }
}

class WishlistTradeMatchCentreSnapshot {
  const WishlistTradeMatchCentreSnapshot({
    required this.overviews,
    required this.friendsScanned,
    required this.yourWishlistCount,
    required this.yourOwnedCount,
  });

  final List<FriendTradeMatchOverview> overviews;
  final int friendsScanned;
  final int yourWishlistCount;
  final int yourOwnedCount;

  int get totalMatches => overviews.fold<int>(0, (runningTotal, overview) => runningTotal + overview.totalMatches);

  int get friendHasForYouCount => overviews.fold<int>(
        0,
        (runningTotal, overview) => runningTotal + overview.snapshot.friendHasForYou.length,
      );

  int get youHaveForFriendCount => overviews.fold<int>(
        0,
        (runningTotal, overview) => runningTotal + overview.snapshot.youHaveForFriend.length,
      );

  int get likelySpareMatches => overviews.fold<int>(
        0,
        (runningTotal, overview) => runningTotal + overview.likelySpareMatches,
      );

  double get estimatedSelectedValue => overviews.fold<double>(
        0,
        (runningTotal, overview) => runningTotal + overview.estimatedSelectedValue,
      );
}
