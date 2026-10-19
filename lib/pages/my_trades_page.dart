import 'package:flutter/material.dart';
import '../models/app_user_profile.dart';
import '../models/trade_offer.dart';
import '../services/trade_offer_service.dart';
import '../utils/community_private_helpers.dart';
import '../widgets/glass_page_header.dart';
import 'social_pages.dart';
import 'trade_offer_compose_page.dart';

class MyTradesPage extends StatefulWidget {
  const MyTradesPage({super.key, required this.currentProfile});
  final AppUserProfile currentProfile;
  @override
  State<MyTradesPage> createState() => _MyTradesPageState();
}

class _MyTradesPageState extends State<MyTradesPage> {
  bool _busy = false;
  String get _uid => TradeOfferService.currentUid;

  Future<void> _respond(TradeOffer offer, String action) async {
    if (_busy) { return; }
    if (action == 'confirm') {
      final confirmed = await showDialog<bool>(context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm the deal is completed?'),
          content: const Text('Only confirm once every agreed card and any money have actually been exchanged. PocketChase does not process payment or change either Pokédex automatically.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I confirm'))]));
      if (confirmed != true || !mounted) { return; }
    }
    setState(() => _busy = true);
    try {
      await TradeOfferService.respond(offer, action);
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trade updated. Collection quantities were not changed.')));
    } catch (error) {
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update trade: $error')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _openChat(TradeOffer offer) async {
    final otherUid = offer.fromUid == _uid ? offer.toUid : offer.fromUid;
    final name = offer.otherName(_uid);
    final id = communityConversationIdForPost(postId: 'wishlist_trade_matches', userAId: _uid, userBId: otherUid);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityPrivateChatPage(
      conversationId: id, currentProfile: widget.currentProfile,
      otherUserId: otherUid, otherUserName: name,
      relatedPostId: 'wishlist_trade_matches', relatedPostTitle: 'Wishlist trade matches',
      initialDraft: 'About our deal (${offer.offeredCards.length} offered, ${offer.requestedCards.length} requested${offer.hasCash ? ', ${offer.cashLabel} cash' : ''}): ',
    )));
  }

  Future<void> _counter(TradeOffer offer) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TradeOfferComposePage(
      currentProfile: widget.currentProfile, friendUid: offer.fromUid, friendName: offer.fromName,
      counterTo: offer,
    )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF041B4A),
    appBar: const GlassPageAppBar(title: 'My Trades', subtitle: 'Offers and agreements', icon: Icons.handshake_outlined),
    body: SafeArea(child: StreamBuilder<List<TradeOffer>>(
      stream: TradeOfferService.watchMyOffers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) { return Center(child: Text('Could not load trades: ${snapshot.error}', style: const TextStyle(color: Colors.white70))); }
        if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); }
        final offers = snapshot.data!;
        if (offers.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24),
            child: Text('No offers yet. Open Trade Matches and tap Make a Deal to propose a swap.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))));
        }
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: offers.length,
          itemBuilder: (context, index) => _buildOffer(offers[index]));
      },
    )),
  );

  Widget _buildOffer(TradeOffer offer) {
    final incoming = offer.isIncoming(_uid);
    final confirmed = incoming ? offer.confirmedByTo : offer.confirmedByFrom;
    return Card(color: const Color(0xFF102754), margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${incoming ? 'From' : 'To'} ${offer.otherName(_uid)}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(offer.statusLabel, style: const TextStyle(color: Color(0xFFF7DE77), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (offer.offeredCards.isNotEmpty) ...[
            Text('Offered by ${offer.fromName}', style: const TextStyle(color: Color(0xFFF7DE77), fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...offer.offeredCards.map((card) => _cardLine(card)),
          ],
          if (offer.requestedCards.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Requested from ${offer.toName}', style: const TextStyle(color: Color(0xFFF7DE77), fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...offer.requestedCards.map((card) => _cardLine(card)),
          ],
          if (offer.hasCash) ...[
            const SizedBox(height: 10),
            Text('${offer.cashPayerName()} offers ${offer.cashLabel} (GBP)',
              style: const TextStyle(color: Color(0xFFF7DE77), fontWeight: FontWeight.w800)),
          ],
          if (offer.offeredCards.isEmpty || offer.requestedCards.isEmpty)
            const Text('One side has no cards selected; discuss the terms in Messages.',
              style: TextStyle(color: Colors.white70)),
          if (offer.note.isNotEmpty) ...[
            const SizedBox(height: 10), Text(offer.note, style: const TextStyle(color: Colors.white70)),
          ],
          if (offer.isAccepted) ...[
            const SizedBox(height: 10),
            Text('Exchange confirmations: ${offer.confirmedByFrom ? '✓' : '○'} ${offer.fromName}   ${offer.confirmedByTo ? '✓' : '○'} ${offer.toName}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _openChat(offer), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Message')),
            if (incoming && offer.isPending) ...[
              FilledButton(onPressed: _busy ? null : () => _respond(offer, 'accepted'), child: const Text('Accept')),
              OutlinedButton(onPressed: _busy ? null : () => _respond(offer, 'declined'), child: const Text('Decline')),
              OutlinedButton(onPressed: _busy ? null : () => _counter(offer), child: const Text('Counter')),
            ],
            if (!incoming && (offer.isPending || offer.isAccepted))
              OutlinedButton(onPressed: _busy ? null : () => _respond(offer, 'cancelled'), child: const Text('Cancel offer')),
            if (offer.isAccepted && !confirmed)
              FilledButton(onPressed: _busy ? null : () => _respond(offer, 'confirm'), child: const Text('Confirm exchanged')),
          ]),
        ],
      )),
    );
  }

  Widget _cardLine(TradeOfferCard card) => Padding(
    padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
    if (card.imageUrl.isNotEmpty)
      Padding(padding: const EdgeInsets.only(right: 10), child: SizedBox(width: 42, height: 58,
        child: Image.network(card.imageUrl, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.white70)))),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('×${card.quantity} ${card.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      Text(card.displaySetName, style: const TextStyle(color: Color(0xFFC8D4F0), fontSize: 12)),
    ])),
  ]));
}
