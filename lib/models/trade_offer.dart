import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/promo_collection_labels.dart';
import 'wishlist_entry.dart';

/// A proposal only: accepting one does not move cards or money.
class TradeOfferCard {
  const TradeOfferCard({
    required this.cardId,
    required this.name,
    required this.setName,
    required this.number,
    this.imageUrl = '',
    this.quantity = 1,
  });

  final String cardId;
  final String name;
  final String setName;
  final String number;
  final String imageUrl;
  final int quantity;

  String get displaySetName => PromoCollectionLabels.displaySetName(
    cardId: cardId, cardName: name, fallbackSetName: setName, number: number,
  );

  factory TradeOfferCard.fromWishlist(WishlistEntry entry, {int quantity = 1}) => TradeOfferCard(
    cardId: entry.cardId,
    name: entry.name,
    setName: entry.setName,
    number: entry.number,
    imageUrl: entry.imageUrl ?? '',
    quantity: quantity,
  );

  factory TradeOfferCard.fromMap(Map<String, dynamic> data) => TradeOfferCard(
    cardId: (data['cardId'] ?? '').toString(),
    name: (data['name'] ?? '').toString(),
    setName: (data['setName'] ?? '').toString(),
    number: (data['number'] ?? '').toString(),
    imageUrl: (data['imageUrl'] ?? '').toString(),
    quantity: (data['quantity'] as num?)?.toInt() ?? 1,
  );

  Map<String, dynamic> toMap() => {
    'cardId': cardId,
    'name': name,
    'setName': setName,
    'number': number,
    'imageUrl': imageUrl,
    'quantity': quantity,
  };
}

class TradeOffer {
  const TradeOffer({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    required this.toName,
    required this.offeredCards,
    required this.requestedCards,
    required this.note,
    required this.status,
    required this.parentOfferId,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.confirmedByFrom,
    required this.confirmedByTo,
    this.cashAmountPence = 0,
    this.cashPayerUid = '',
  });

  final String id, fromUid, toUid, fromName, toName, note, status, parentOfferId;
  final List<TradeOfferCard> offeredCards, requestedCards;
  final int createdAtMs, updatedAtMs, cashAmountPence;
  final String cashPayerUid;
  final bool confirmedByFrom, confirmedByTo;

  /// Convenience accessors for older single-card screen integrations.
  TradeOfferCard? get offeredCard => offeredCards.isEmpty ? null : offeredCards.first;
  TradeOfferCard? get requestedCard => requestedCards.isEmpty ? null : requestedCards.first;

  factory TradeOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    List<TradeOfferCard> readCards(String pluralKey, String oldKey) {
      final plural = d[pluralKey];
      if (plural is List) {
        return plural.whereType<Map>().map((e) => TradeOfferCard.fromMap(Map<String, dynamic>.from(e))).toList();
      }
      final legacy = d[oldKey];
      return legacy is Map
          ? [TradeOfferCard.fromMap(Map<String, dynamic>.from(legacy))]
          : <TradeOfferCard>[];
    }

    return TradeOffer(
      id: doc.id,
      fromUid: (d['fromUid'] ?? '').toString(),
      toUid: (d['toUid'] ?? '').toString(),
      fromName: (d['fromName'] ?? '').toString(),
      toName: (d['toName'] ?? '').toString(),
      offeredCards: readCards('offeredCards', 'offeredCard'),
      requestedCards: readCards('requestedCards', 'requestedCard'),
      note: (d['note'] ?? '').toString(),
      status: (d['status'] ?? 'pending').toString(),
      parentOfferId: (d['parentOfferId'] ?? '').toString(),
      createdAtMs: (d['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (d['updatedAtMs'] as num?)?.toInt() ?? 0,
      confirmedByFrom: d['confirmedByFrom'] == true,
      confirmedByTo: d['confirmedByTo'] == true,
      cashAmountPence: (d['cashAmountPence'] as num?)?.toInt() ?? 0,
      cashPayerUid: (d['cashPayerUid'] ?? '').toString(),
    );
  }

  bool isIncoming(String uid) => uid == toUid;
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get hasCash => cashAmountPence > 0;
  bool get hasCards => offeredCards.isNotEmpty || requestedCards.isNotEmpty;
  String get cashLabel => '£${(cashAmountPence / 100).toStringAsFixed(2)}';
  String cashPayerName() => cashPayerUid == fromUid ? fromName : toName;
  String otherName(String uid) => uid == fromUid ? toName : fromName;

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Pending response';
      case 'accepted': return 'Agreed — awaiting exchange';
      case 'declined': return 'Declined';
      case 'cancelled': return 'Cancelled';
      case 'countered': return 'Counteroffer sent';
      case 'completed': return 'Exchange confirmed';
      default: return status;
    }
  }
}
