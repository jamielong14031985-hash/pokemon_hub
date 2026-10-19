import 'package:flutter/material.dart';
import '../models/tcg_card.dart';
import '../models/app_user_profile.dart';
import '../models/card_ownership.dart';
import '../models/wishlist_entry.dart';
import '../models/friend_trade_match_models.dart';
import '../models/trade_offer.dart';
import '../services/friend_trade_match_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../services/trade_offer_service.dart';
import '../utils/promo_collection_labels.dart';
import '../widgets/glass_page_header.dart';
import 'first_partner_promo_cards_page.dart';

/// Build a multi-card trade, cash purchase/sale, or cards-plus-cash proposal.
/// Offers record an agreement to discuss; they never collect money or move cards.
class TradeOfferComposePage extends StatefulWidget {
  const TradeOfferComposePage({super.key, required this.currentProfile,
    required this.friendUid, required this.friendName,
    this.initialOfferedCardId, this.initialRequestedCardId, this.counterTo});
  final AppUserProfile currentProfile;
  final String friendUid, friendName;
  final String? initialOfferedCardId, initialRequestedCardId;
  final TradeOffer? counterTo;

  @override
  State<TradeOfferComposePage> createState() => _TradeOfferComposePageState();
}

class _TradeOfferComposePageState extends State<TradeOfferComposePage> {
  static const _panel = Color(0xFF16366E);
  static const _gold = Color(0xFFF7DE77);
  static const _muted = Color(0xFFC8D4F0);

  late Future<FriendTradeMatchSnapshot> _future;
  final _noteController = TextEditingController();
  final _cashController = TextEditingController();
  final Map<String, int> _offered = <String, int>{};
  final Map<String, int> _requested = <String, int>{};
  final Map<String, FriendTradeMatchEntry> _extraOffered = <String, FriendTradeMatchEntry>{};
  final Map<String, FriendTradeMatchEntry> _extraRequested = <String, FriendTradeMatchEntry>{};
  String _mode = 'trade'; // trade, cash, mixed
  bool _youPay = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialOfferedCardId != null) { _offered[widget.initialOfferedCardId!] = 1; }
    if (widget.initialRequestedCardId != null) { _requested[widget.initialRequestedCardId!] = 1; }
    final previous = widget.counterTo;
    if (previous != null) {
      _offered.clear();
      _requested.clear();
      for (final card in previous.requestedCards) { _offered[card.cardId] = card.quantity; }
      for (final card in previous.offeredCards) { _requested[card.cardId] = card.quantity; }
      if (previous.hasCash) {
        _cashController.text = (previous.cashAmountPence / 100).toStringAsFixed(2);
        _youPay = previous.cashPayerUid == widget.currentProfile.uid;
        _mode = (_offered.isNotEmpty && _requested.isNotEmpty) ? 'mixed' : 'cash';
      }
    }
    _future = FriendTradeMatchService.loadMatches(
      currentProfile: widget.currentProfile, friendUid: widget.friendUid);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  String _displaySet(FriendTradeMatchEntry item) => PromoCollectionLabels.displaySetName(
    cardId: item.entry.cardId,
    cardName: item.entry.name,
    setId: item.entry.setId,
    number: item.entry.number,
    fallbackSetName: item.entry.setName,
  );

  // A counteroffer must still show the original cards even if the receiver
  // had not wishlisted them. We use the live spare count for those entries.
  void _loadCounterCards(FriendTradeMatchSnapshot snapshot) {
    final previous = widget.counterTo;
    if (previous == null) { return; }
    void addCards(List<TradeOfferCard> cards, Map<String, CardOwnership> owned,
        Map<String, FriendTradeMatchEntry> extras, bool ownerIsFriend) {
      for (final card in cards) {
        if (extras.containsKey(card.cardId)) { continue; }
        final ownership = owned[card.cardId];
        if (ownership == null || ownership.duplicateCopies == 0) { continue; }
        final entry = WishlistEntry(cardId: card.cardId, name: card.name,
          setId: card.cardId.split('-').first,
          setName: card.setName, number: card.number,
          createdAtMs: 0, imageUrl: card.imageUrl);
        extras[card.cardId] = FriendTradeMatchEntry(entry: entry,
          ownerCopies: ownership.effectiveCopies,
          ownerSpareCopies: ownership.duplicateCopies,
          ownerIsFriend: ownerIsFriend);
      }
    }
    addCards(previous.requestedCards, snapshot.yourOwnedCards, _extraOffered, false);
    addCards(previous.offeredCards, snapshot.friendOwnedCards, _extraRequested, true);
  }

  List<TradeOfferCard> _cardsFromSelection(
    List<FriendTradeMatchEntry> available, Map<String, int> picked,
  ) => available.where((item) => (picked[item.entry.cardId] ?? 0) > 0).map(
    (item) => TradeOfferCard.fromWishlist(item.entry, quantity: picked[item.entry.cardId]!),
  ).toList();

  /// Show a card picker that owns and disposes its own TextField controller.
  /// Dismiss the underlying keyboard before opening a new modal route.
  Future<void> _chooseCards(
    List<FriendTradeMatchEntry> entries,
    Map<String, int> selected,
    String heading,
    Map<String, CardOwnership> owned,
    bool ownerIsFriend,
    Map<String, FriendTradeMatchEntry> extras,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _TradeCardPickerSheet(
        entries: entries,
        selected: selected,
        heading: heading,
        owned: owned,
        ownerIsFriend: ownerIsFriend,
        extras: extras,
      ),
    );
    if (!mounted || result == null) { return; }
    setState(() {
      selected
        ..clear()
        ..addAll(result);
    });
  }

  Widget _selectedList(List<FriendTradeMatchEntry> options, Map<String, int> selected,
      String heading, bool enabled, Map<String, CardOwnership> owned,
      bool ownerIsFriend, Map<String, FriendTradeMatchEntry> extras) {
    final chosen = options.where((item) => (selected[item.entry.cardId] ?? 0) > 0).toList();
    final count = chosen.fold<int>(0, (total, item) => total + selected[item.entry.cardId]!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(heading, style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 9),
      OutlinedButton.icon(
          onPressed: enabled ? () => _chooseCards(options, selected, heading,
            owned, ownerIsFriend, extras) : null,
          icon: const Icon(Icons.style_outlined),
          label: Text(count == 0 ? 'Choose cards' : 'Change selection · $count card${count == 1 ? '' : 's'}'),
          style: OutlinedButton.styleFrom(foregroundColor: _gold,
            side: const BorderSide(color: Color(0xFF5775AD)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15)),
        ),
      if (chosen.isNotEmpty) ...[
        const SizedBox(height: 8),
        ...chosen.map((item) => Padding(padding: const EdgeInsets.only(top: 5),
          child: Text('×${selected[item.entry.cardId]} ${item.entry.name} · ${_displaySet(item)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13)))),
      ],
    ]);
  }

  int? _cashPence() {
    final clean = _cashController.text.trim();
    if (!RegExp(r'^\d{1,6}(?:\.\d{1,2})?$').hasMatch(clean)) { return null; }
    final price = double.tryParse(clean);
    if (price == null || !price.isFinite || price <= 0 || price > 100000) { return null; }
    return (price * 100).round();
  }

  Future<void> _send(FriendTradeMatchSnapshot snapshot) async {
    if (_busy) { return; }
    final outgoing = <String, FriendTradeMatchEntry>{
      for (final item in snapshot.youHaveForFriend.where((i) => i.ownerSpareCopies > 0)) item.entry.cardId: item,
      ..._extraOffered,
    }.values.toList();
    final incoming = <String, FriendTradeMatchEntry>{
      for (final item in snapshot.friendHasForYou.where((i) => i.ownerSpareCopies > 0)) item.entry.cardId: item,
      ..._extraRequested,
    }.values.toList();
    final offer = _cardsFromSelection(outgoing, _offered);
    final request = _cardsFromSelection(incoming, _requested);
    if (offer.isEmpty && request.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a card for your deal.')));
      return;
    }
    final cash = _mode == 'trade' ? 0 : _cashPence();
    if (cash == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid cash offer in GBP (for example 25.00).')));
      return;
    }
    if (_mode == 'cash' && (_youPay ? request.isEmpty : offer.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose the card being bought.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await TradeOfferService.sendOffer(
        friendUid: widget.friendUid,
        fromName: widget.currentProfile.displayName,
        toName: widget.friendName,
        offeredCards: _mode == 'cash' && _youPay ? [] : offer,
        requestedCards: _mode == 'cash' && !_youPay ? [] : request,
        cashAmountPence: cash,
        cashPayerUid: cash > 0 ? (_youPay ? widget.currentProfile.uid : widget.friendUid) : '',
        note: _noteController.text,
        counterTo: widget.counterTo,
      );
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Deal proposal sent. No cards or money have been transferred.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send proposal: $error')));
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: GlassPageAppBar(title: widget.counterTo == null ? 'Make a Deal' : 'Counteroffer',
        subtitle: widget.friendName, icon: Icons.handshake_outlined),
      body: SafeArea(child: FutureBuilder<FriendTradeMatchSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text(
                'Could not load trade cards: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final matches = snapshot.data!;
          _loadCounterCards(matches);
          final outgoing = <String, FriendTradeMatchEntry>{
            for (final item in matches.youHaveForFriend.where((i) => i.ownerSpareCopies > 0)) item.entry.cardId: item,
            ..._extraOffered,
          }.values.toList();
          final incoming = <String, FriendTradeMatchEntry>{
            for (final item in matches.friendHasForYou.where((i) => i.ownerSpareCopies > 0)) item.entry.cardId: item,
            ..._extraRequested,
          }.values.toList();
          // Never retain an unavailable selection after inventory has refreshed.
          final canOffer = outgoing.map((e) => e.entry.cardId).toSet();
          final canRequest = incoming.map((e) => e.entry.cardId).toSet();
          final hasOffer = _offered.keys.any(canOffer.contains);
          final hasRequest = _requested.keys.any(canRequest.contains);
          final cashOnly = _mode == 'cash';
          final showOffered = !cashOnly || !_youPay;
          final showRequested = !cashOnly || _youPay;
          return ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 26), children: [
            const Text('Build your deal', style: TextStyle(color: Colors.white,
              fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Select several spare cards, choose quantities and optionally include a cash offer.',
              style: TextStyle(color: _muted, height: 1.4)),
            const SizedBox(height: 18),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _modeChip('trade', 'Trade cards'),
              _modeChip('cash', 'Buy / sell'),
              _modeChip('mixed', 'Cards + cash'),
            ]),
            const SizedBox(height: 20),
            if (_mode != 'trade') ...[
              const Text('Cash offer (GBP)', style: TextStyle(color: _gold,
                fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 8),
              TextField(controller: _cashController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(prefixText: '£ ', prefixStyle: const TextStyle(color: _gold),
                  hintText: '25.00', hintStyle: const TextStyle(color: Colors.white54),
                  filled: true, fillColor: _panel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
              const SizedBox(height: 10),
              Text('Who would pay?', style: const TextStyle(color: _muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('I pay'), selected: _youPay,
                  onSelected: (_) => setState(() => _youPay = true)),
                ChoiceChip(label: Text('${widget.friendName} pays'), selected: !_youPay,
                  onSelected: (_) => setState(() => _youPay = false)),
              ]),
              const SizedBox(height: 22),
            ],
            if (showOffered) ...[
              _selectedList(outgoing, _offered, 'You offer', !_busy,
                matches.yourOwnedCards, false, _extraOffered),
              const SizedBox(height: 22),
            ],
            if (showRequested) ...[
              _selectedList(incoming, _requested, 'You request from ${widget.friendName}', !_busy,
                matches.friendOwnedCards, true, _extraRequested),
              const SizedBox(height: 20),
            ],
            TextField(controller: _noteController, maxLines: 3, maxLength: 400,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Optional message or deal details',
                hintStyle: const TextStyle(color: Colors.white60), filled: true,
                fillColor: _panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
            const Text('This is an offer to discuss a trade or purchase, not a payment. PocketChase does not reserve, transfer or take payment for cards. Agree on a safe exchange in chat.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || (!hasOffer && !hasRequest) ? null : () => _send(matches),
              icon: _busy ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
              label: Text(widget.counterTo == null ? 'Send deal proposal' : 'Send counteroffer'),
              style: FilledButton.styleFrom(backgroundColor: _gold,
                foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16))),
          ]);
        },
      )),
    );
  }

  Widget _modeChip(String mode, String label) {
    final selected = _mode == mode;
    return ChoiceChip(label: Text(label), selected: selected,
      onSelected: (_) => setState(() => _mode = mode),
      selectedColor: _gold, backgroundColor: _panel,
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w800));
  }
}

/// The sheet must own its search controller until its exit animation completes.
/// Disposing the controller in the calling page as soon as Navigator.pop returns
/// can race with teardown of a still-mounted TextField (especially with IME open).
class _TradeCardPickerSheet extends StatefulWidget {
  const _TradeCardPickerSheet({
    required this.entries,
    required this.selected,
    required this.heading,
    required this.owned,
    required this.ownerIsFriend,
    required this.extras,
  });

  final List<FriendTradeMatchEntry> entries;
  final Map<String, int> selected;
  final String heading;
  final Map<String, CardOwnership> owned;
  final bool ownerIsFriend;
  final Map<String, FriendTradeMatchEntry> extras;

  @override
  State<_TradeCardPickerSheet> createState() => _TradeCardPickerSheetState();
}

class _TradeCardPickerSheetState extends State<_TradeCardPickerSheet> {
  static const _panel = Color(0xFF16366E);
  static const _gold = Color(0xFFF7DE77);
  static const _muted = Color(0xFFC8D4F0);

  final TextEditingController _searchController = TextEditingController();
  late final Map<String, int> _working;
  late final Map<String, FriendTradeMatchEntry> _candidates;
  bool _searching = false;
  String _searchFeedback = '';

  @override
  void initState() {
    super.initState();
    _working = Map<String, int>.from(widget.selected);
    _candidates = <String, FriendTradeMatchEntry>{
      for (final item in widget.entries) item.entry.cardId: item,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _displaySet(FriendTradeMatchEntry item) =>
      PromoCollectionLabels.displaySetName(
        cardId: item.entry.cardId,
        cardName: item.entry.name,
        setId: item.entry.setId,
        number: item.entry.number,
        fallbackSetName: item.entry.setName,
      );

  Future<void> _findSpareCards() async {
    if (_searching) { return; }
    final query = _searchController.text.trim();
    if (query.length < 3) {
      setState(() => _searchFeedback = 'Type at least 3 letters.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchFeedback = '';
    });
    try {
      final localPromos = FirstPartnerPromoCardsPage.knownMepPromoCards()
          .where((card) => card.name.toLowerCase().contains(query.toLowerCase()));
      List<TcgCard> remote;
      try {
        remote = await PokemonTcgService.searchCardsOnly(query);
      } catch (_) {
        remote = <TcgCard>[];
      }
      if (!mounted) { return; }
      final found = <String, TcgCard>{
        for (final card in localPromos) card.id: card,
        for (final card in remote) card.id: card,
      };
      int added = 0;
      for (final card in found.values) {
        final ownership = widget.owned[card.id];
        if (ownership == null || ownership.duplicateCopies <= 0) { continue; }
        if (_candidates.containsKey(card.id)) { continue; }
        final wishlist = WishlistEntry(
          cardId: card.id,
          name: card.name,
          setId: card.setId,
          setName: card.setName,
          number: card.number,
          createdAtMs: 0,
          imageUrl: card.imageUrl,
        );
        final match = FriendTradeMatchEntry(
          entry: wishlist,
          ownerCopies: ownership.effectiveCopies,
          ownerSpareCopies: ownership.duplicateCopies,
          ownerIsFriend: widget.ownerIsFriend,
        );
        _candidates[card.id] = match;
        widget.extras[card.id] = match;
        added++;
      }
      if (!mounted) { return; }
      setState(() {
        _searching = false;
        _searchFeedback = added == 0
            ? 'No additional matching spares found. Try a different card name.'
            : 'Found $added additional spare card${added == 1 ? '' : 's'}.';
      });
    } catch (_) {
      if (!mounted) { return; }
      setState(() {
        _searching = false;
        _searchFeedback = 'Card search failed. Try again.';
      });
    }
  }

  void _finish() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(Map<String, int>.from(_working));
  }

  void _close() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates.values.toList(growable: false);
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 12, 8),
              child: Row(children: [
                Expanded(child: Text(widget.heading,
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 19))),
                IconButton(onPressed: _close,
                  icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Choose matching spares below, or search for other cards this person owns in duplicate.',
                style: TextStyle(color: _muted, fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _findSpareCards(),
                  decoration: const InputDecoration(
                    hintText: 'Search more cards by name',
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.search, color: _gold),
                  ),
                )),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: _searching ? null : _findSpareCards,
                  child: const Text('Find', style: TextStyle(color: _gold)),
                ),
              ]),
            ),
            if (_searching) const LinearProgressIndicator(),
            if (_searchFeedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_searchFeedback,
                  style: const TextStyle(color: _muted, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final item = candidates[index];
                  final id = item.entry.cardId;
                  final maxCopies = item.ownerSpareCopies;
                  final count = (_working[id] ?? 0).clamp(0, maxCopies).toInt();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Container(
                      decoration: BoxDecoration(color: _panel,
                        borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          SizedBox(
                            width: 46,
                            height: 65,
                            child: item.entry.imageUrl?.isNotEmpty == true
                              ? Image.network(item.entry.imageUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_outlined, color: Colors.white70))
                              : const Icon(Icons.image_outlined,
                                  color: Colors.white70),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.entry.name,
                                  style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                                Text(_displaySet(item),
                                  style: const TextStyle(color: _muted, fontSize: 12),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text('$maxCopies spare',
                                  style: const TextStyle(color: _gold, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: count == 0 ? null : () => setState(() {
                              if (count == 1) {
                                _working.remove(id);
                              } else {
                                _working[id] = count - 1;
                              }
                            }),
                            icon: const Icon(Icons.remove_circle_outline),
                            color: _gold,
                          ),
                          Text('$count',
                            style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: count >= maxCopies ||
                                (count == 0 && !_working.containsKey(id) && _working.length >= 15)
                                ? null : () => setState(() => _working[id] = count + 1),
                            icon: const Icon(Icons.add_circle_outline),
                            color: _gold,
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: Colors.black),
                  onPressed: _finish,
                  child: Text('Done · ${_working.values.fold<int>(0, (a, b) => a + b)} cards selected'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
