import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/wishlist_service.dart';
import '../utils/ebay_sold_search.dart';
import '../widgets/custom_binder_sheets.dart';
import '../widgets/graded_prices_button.dart';
import '../widgets/price_lookup_card.dart';
import '../widgets/set_logo_widgets.dart';
import 'graded_prices_page.dart';
import 'set_card_details_page.dart';

class CardDetailsPage extends StatefulWidget {
  const CardDetailsPage({super.key, required this.card});

  final TcgCard card;

  @override
  State<CardDetailsPage> createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends State<CardDetailsPage> {
  late CardOwnership _ownership;
  bool _loadingOwnership = true;
  bool _wishlistBusy = false;
  bool _searchCardActionsVisible = true;

  Future<void> _addToCustomBinder() async {
    await addCardToCustomBinderFlow(context, widget.card);
  }


  @override
  void initState() {
    super.initState();
    _loadOwnership();
  }

  Future<void> _loadOwnership() async {
    final ownershipByCardId = await PokedexSyncService.loadCurrentUserSetOwnership(widget.card.setId);
    final ownership = ownershipByCardId[widget.card.id] ?? const CardOwnership();

    if (mounted) {
      setState(() {
        _ownership = ownership;
        _loadingOwnership = false;
      });
    }
  }

  Future<void> _saveOwnership(CardOwnership ownership) async {
    final ownershipByCardId = await PokedexSyncService.loadCurrentUserSetOwnership(widget.card.setId);
    ownershipByCardId[widget.card.id] = ownership;
    await LocalPokedexStore.saveSetOwnershipMap(widget.card.setId, ownershipByCardId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(widget.card.setId);

    if (mounted) {
      setState(() {
        _ownership = ownership;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card saved to Set Pokédex')),
      );
    }
  }

  Future<void> _removeFromPokedex() async {
    await LocalPokedexStore.removeCard(widget.card.setId, widget.card.id);
    await PokedexSyncService.syncCurrentSetForCurrentUser(widget.card.setId);

    if (mounted) {
      setState(() {
        _ownership = const CardOwnership();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card removed from Set Pokédex')),
      );
    }
  }

  void _toggleSearchCardActionsPanel() {
    setState(() {
      _searchCardActionsVisible = !_searchCardActionsVisible;
    });
  }

  Future<void> _toggleWishlist(bool isInWishlist) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || _wishlistBusy) return;

    setState(() {
      _wishlistBusy = true;
    });

    try {
      if (isInWishlist) {
        await WishlistService.removeCard(ownerUid: ownerUid, cardId: widget.card.id);
      } else {
        await WishlistService.addCard(ownerUid: ownerUid, card: widget.card);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isInWishlist ? 'Removed from wishlist' : 'Added to wishlist')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not update wishlist right now')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update wishlist right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _wishlistBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final hasSavedCopies = !_loadingOwnership && _ownership.effectiveCopies > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(card.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SetLogoTile(setId: card.setId, setName: card.setName, logoUrl: card.setLogoUrl),
                  if (card.largeImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(card.largeImageUrl!, height: 320),
                    ),
                  const SizedBox(height: 16),
                  PriceLookupCard(
                    card: card,
                    onOpenRawSold: () => openEbaySoldSearch(context: context, card: card),
                  ),
                  GradedPricesButton(
                    card: card,
                    onOpenGradedPrices: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GradedPricesPage(card: card),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _loadingOwnership
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                Text(
                                  hasSavedCopies
                                      ? 'Saved to Set Pokédex: x${_ownership.effectiveCopies}'
                                      : 'This card is not in your Set Pokédex yet.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (hasSavedCopies && _ownership.hasConditionDetails) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _ownership.conditionSummary,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFF7DE77),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                const Text(
                                  'Use the buttons below to add this card straight from search results.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_loadingOwnership)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: !_searchCardActionsVisible ? _toggleSearchCardActionsPanel : null,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _searchCardActionsVisible
                      ? Container(
                          key: const ValueKey('search_card_actions_open'),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF041B4A),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 12,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: _toggleSearchCardActionsPanel,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(28, 2, 28, 10),
                                  child: Container(
                                    width: 44,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                              if (hasSavedCopies)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _removeFromPokedex,
                                    child: const Text('Remove from Set Pokédex'),
                                  ),
                                ),
                              if (hasSavedCopies) const SizedBox(height: 8),
                              StreamBuilder<bool>(
                                stream: WishlistService.cardInWishlistStream(
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                                  card.id,
                                ),
                                builder: (context, snapshot) {
                                  final isInWishlist = snapshot.data ?? false;
                                  return SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _wishlistBusy ? null : () => _toggleWishlist(isInWishlist),
                                      icon: Icon(
                                        isInWishlist
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_outline_rounded,
                                      ),
                                      label: Text(
                                        isInWishlist ? 'Remove from Wishlist' : 'Add to Wishlist',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _addToCustomBinder,
                                  icon: const Icon(Icons.photo_album_outlined),
                                  label: const Text('Add to Custom Binder'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () async {
                                    final updatedOwnership =
                                        await Navigator.of(context).push<CardOwnership>(
                                      MaterialPageRoute(
                                        builder: (_) => SetCardDetailsPage(
                                          card: card,
                                          ownership: _ownership,
                                        ),
                                      ),
                                    );
                                    if (updatedOwnership != null) {
                                      await _saveOwnership(updatedOwnership);
                                    }
                                  },
                                  child: Text(
                                    hasSavedCopies
                                        ? 'Edit Set Pokédex Count'
                                        : 'Add to Set Pokédex',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap the handle to hide actions',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('search_card_actions_closed'),
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF041B4A),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7DE77),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap to show wishlist, binder and Pokédex actions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
