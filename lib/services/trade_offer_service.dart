import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trade_offer.dart';
import 'friend_service.dart';
import 'pokedex_sync_service.dart';

/// Trade proposals only; no inventory or money is automatically transferred.
class TradeOfferService {
  static CollectionReference<Map<String, dynamic>> get _offers =>
      FirebaseFirestore.instance.collection('trade_offers');

  static String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static Stream<List<TradeOffer>> watchMyOffers() {
    final uid = currentUid;
    if (uid.isEmpty) { return Stream.value(const <TradeOffer>[]); }
    return _offers.where('participants', arrayContains: uid).snapshots().map((snap) {
      final items = snap.docs.map(TradeOffer.fromDoc).toList();
      items.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return items;
    });
  }

  static Future<void> _checkFriend(String friendUid) async {
    final uid = currentUid;
    if (uid.isEmpty || friendUid.isEmpty || uid == friendUid) {
      throw StateError('Sign in and select a friend to trade with.');
    }
    final friends = await FriendService.fetchFriends(uid);
    if (!friends.any((f) => f.uid == friendUid)) {
      throw StateError('You can only send trade offers to friends.');
    }
  }

  static Future<void> _checkSpares(List<TradeOfferCard> cards, String uid) async {
    if (cards.isEmpty) { return; }
    final owned = await PokedexSyncService.fetchAllOwnedCards(uid);
    for (final card in cards) {
      final spareCount = owned[card.cardId]?.duplicateCopies ?? 0;
      if (spareCount < card.quantity) {
        throw StateError('${card.name} only has $spareCount tradeable spare copies. Refresh the collection.');
      }
    }
  }

  static void _validateCards(List<TradeOfferCard> cards) {
    if (cards.length > 15) { throw StateError('Select no more than 15 different cards per side.'); }
    final unique = <String>{};
    for (final card in cards) {
      if (card.cardId.trim().isEmpty || card.quantity < 1 || card.quantity > 99 ||
          !unique.add(card.cardId)) {
        throw StateError('Invalid or duplicate card selection.');
      }
    }
  }

  static Future<void> sendOffer({
    required String friendUid,
    required String fromName,
    required String toName,
    required List<TradeOfferCard> offeredCards,
    required List<TradeOfferCard> requestedCards,
    int cashAmountPence = 0,
    String cashPayerUid = '',
    String note = '',
    TradeOffer? counterTo,
  }) async {
    await _checkFriend(friendUid);
    _validateCards(offeredCards);
    _validateCards(requestedCards);
    if (cashAmountPence < 0 || cashAmountPence > 10000000) {
      throw StateError('Enter a GBP offer up to £100,000.');
    }
    if (cashAmountPence > 0 && cashPayerUid != currentUid && cashPayerUid != friendUid) {
      throw StateError('Choose who would pay the money.');
    }
    if (offeredCards.isEmpty && requestedCards.isEmpty) {
      throw StateError('Select at least one card for the deal.');
    }
    if (counterTo != null && (counterTo.toUid != currentUid ||
        counterTo.fromUid != friendUid || counterTo.status != 'pending')) {
      throw StateError('This offer can no longer be countered.');
    }

    await _checkSpares(offeredCards, currentUid);
    // Re-check friend-owned cards when the recipient accepts the offer.
    final now = DateTime.now().millisecondsSinceEpoch;
    final doc = _offers.doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(doc, {
      'fromUid': currentUid, 'toUid': friendUid,
      'fromName': fromName.trim(), 'toName': toName.trim(),
      'participants': [currentUid, friendUid],
      'offeredCards': offeredCards.map((c) => c.toMap()).toList(),
      'requestedCards': requestedCards.map((c) => c.toMap()).toList(),
      // Keep old fields available for older client versions reading trade offers.
      'offeredCard': offeredCards.isEmpty ? null : offeredCards.first.toMap(),
      'requestedCard': requestedCards.isEmpty ? null : requestedCards.first.toMap(),
      'cashAmountPence': cashAmountPence,
      'cashPayerUid': cashAmountPence > 0 ? cashPayerUid : '',
      'currency': 'GBP',
      'note': note.trim(), 'parentOfferId': counterTo?.id ?? '',
      'status': 'pending', 'createdAtMs': now, 'updatedAtMs': now,
      'confirmedByFrom': false, 'confirmedByTo': false,
    });
    if (counterTo != null) {
      batch.update(_offers.doc(counterTo.id), {
        'status': 'countered', 'updatedAtMs': now,
      });
    }
    await batch.commit();
  }

  static Future<void> respond(TradeOffer offer, String action) async {
    final uid = currentUid;
    if (uid.isEmpty) { throw StateError('Please sign in.'); }
    // Validate the card quantities again at accept time. No cards are reserved.
    if (action == 'accepted') {
      await _checkSpares(offer.requestedCards, offer.toUid);
      await _checkSpares(offer.offeredCards, offer.fromUid);
    }
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final ref = _offers.doc(offer.id);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) { throw StateError('Trade offer not found.'); }
      final actual = TradeOffer.fromDoc(snapshot);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (action == 'accepted' || action == 'declined') {
        if (uid != actual.toUid || !actual.isPending) {
          throw StateError('This offer can no longer be answered.');
        }
        transaction.update(ref, {'status': action, 'updatedAtMs': now});
      } else if (action == 'cancelled') {
        if (uid != actual.fromUid || !(actual.isPending || actual.isAccepted)) {
          throw StateError('This offer cannot be cancelled.');
        }
        transaction.update(ref, {'status': 'cancelled', 'updatedAtMs': now});
      } else if (action == 'confirm') {
        if (!actual.isAccepted || (uid != actual.fromUid && uid != actual.toUid)) {
          throw StateError('This offer is not ready for exchange confirmation.');
        }
        final fromConfirmed = actual.confirmedByFrom || uid == actual.fromUid;
        final toConfirmed = actual.confirmedByTo || uid == actual.toUid;
        transaction.update(ref, {
          'confirmedByFrom': fromConfirmed, 'confirmedByTo': toConfirmed,
          'status': fromConfirmed && toConfirmed ? 'completed' : 'accepted',
          'updatedAtMs': now,
        });
      } else {
        throw StateError('Unknown trade action.');
      }
    });
  }
}
