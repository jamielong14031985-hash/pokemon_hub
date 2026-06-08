import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/wishlist_service.dart';
import '../services/external_card_price_service.dart';
import '../utils/ebay_sold_search.dart';
import '../widgets/card_image_with_fallback.dart';
import '../widgets/custom_binder_sheets.dart';
import '../widgets/graded_prices_button.dart';
import '../widgets/price_lookup_card.dart';
import '../widgets/set_logo_widgets.dart';
import 'graded_prices_page.dart';
import 'set_card_details_page.dart';

class CardDetailsPage extends StatefulWidget {
  const CardDetailsPage({
    super.key,
    required this.card,
    this.addAsNormal = true,
    this.addAsReverseHolo = false,
    this.addAsHolo = false,
  });

  final TcgCard card;

  /// These flags let the Pokédex grid open this same card screen for the exact
  /// slot the user tapped. For example, tapping the reverse holo slot makes the
  /// Add Card button add the reverse holo flag instead of the normal flag.
  final bool addAsNormal;
  final bool addAsReverseHolo;
  final bool addAsHolo;

  @override
  State<CardDetailsPage> createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends State<CardDetailsPage> {
  late CardOwnership _ownership;
  bool _loadingOwnership = true;
  bool _wishlistBusy = false;
  bool _addCardBusy = false;
  bool _refreshingPrice = false;
  bool _searchCardActionsVisible = true;
  late TcgCard _pricedCard;

  Future<void> _addToCustomBinder() async {
    await addCardToCustomBinderFlow(context, widget.card);
  }


  @override
  void initState() {
    super.initState();
    _pricedCard = widget.card;
    _loadOwnership();
    _refreshExternalPriceIfMissing();
  }


  Future<void> _refreshExternalPriceIfMissing() async {
    // Do not call JustTCG automatically when a card screen opens.
    // The JustTCG free tier is rate limited, so external pricing is now
    // checked only when the user presses Refresh Raw Price.
    return;
  }

  Future<void> _refreshExternalPrice({bool showMessageWhenMissing = true}) async {
    if (_refreshingPrice) return;

    setState(() {
      _refreshingPrice = true;
    });

    try {
      final enrichedCard = await ExternalCardPriceService.enrichCardWithExternalPrice(
        _pricedCard,
        rethrowErrors: showMessageWhenMissing,
      );
      if (!mounted) return;
      setState(() {
        _pricedCard = enrichedCard;
      });
      if (showMessageWhenMissing) {
        final hasPrice = (enrichedCard.marketPrice ?? 0) > 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasPrice
                  ? 'Raw price updated from ${enrichedCard.marketPriceSource}'
                  : 'No raw price found from JustTCG yet',
            ),
          ),
        );
      }
    } catch (error) {
      if (showMessageWhenMissing && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ExternalCardPriceService.friendlyErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshingPrice = false;
        });
      }
    }
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

  Future<void> _saveOwnership(
    CardOwnership ownership, {
    String successMessage = 'Card saved to Set Pokédex',
  }) async {
    final ownershipByCardId = await PokedexSyncService.loadCurrentUserSetOwnership(widget.card.setId);
    ownershipByCardId[widget.card.id] = ownership;
    await LocalPokedexStore.saveSetOwnershipMap(widget.card.setId, ownershipByCardId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(widget.card.setId);

    if (mounted) {
      setState(() {
        _ownership = ownership;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }
  }

  Future<void> _addCardToPokedex() async {
    if (_loadingOwnership || _addCardBusy) return;

    setState(() {
      _addCardBusy = true;
    });

    try {
      // Reload first so repeated opens/screens do not overwrite a newer count.
      final ownershipByCardId = await PokedexSyncService.loadCurrentUserSetOwnership(widget.card.setId);
      final currentOwnership = ownershipByCardId[widget.card.id] ?? _ownership;

      final addReverseHolo = widget.addAsReverseHolo;
      final addHolo = widget.addAsHolo;
      late final CardOwnership updatedOwnership;
      late final int selectedVersionCount;
      late final String selectedVersionLabel;

      if (addReverseHolo) {
        selectedVersionCount = currentOwnership.reverseHoloCount + 1;
        selectedVersionLabel = 'Reverse Holo';
        updatedOwnership = currentOwnership.copyWith(
          reverseHolo: true,
          reverseHoloCopies: selectedVersionCount,
        );
      } else if (addHolo) {
        selectedVersionCount = currentOwnership.holoCount + 1;
        selectedVersionLabel = 'Holo';
        updatedOwnership = currentOwnership.copyWith(
          holo: true,
          holoCopies: selectedVersionCount,
        );
      } else {
        selectedVersionCount = currentOwnership.normalCount + 1;
        selectedVersionLabel = 'Normal';
        updatedOwnership = currentOwnership.copyWith(
          normal: true,
          normalCopies: selectedVersionCount,
        );
      }

      await _saveOwnership(
        updatedOwnership,
        successMessage: selectedVersionCount == 1
            ? '$selectedVersionLabel card added to Set Pokédex'
            : '$selectedVersionLabel now x$selectedVersionCount',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add card: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addCardBusy = false;
        });
      }
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
    final card = _pricedCard;
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
                  CardImageWithFallback(
                    imageUrls: card.largeImageUrlCandidates,
                    height: 320,
                    fit: BoxFit.contain,
                    backgroundColor: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  const SizedBox(height: 16),
                  PriceLookupCard(
                    card: card,
                    onOpenRawSold: () => openEbaySoldSearch(context: context, card: card),
                    onRefreshPrice: () => _refreshExternalPrice(),
                    refreshingPrice: _refreshingPrice,
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
                                  'Tap Add Card each time you want to save another copy.',
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
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _addCardBusy ? null : _addCardToPokedex,
                                  icon: _addCardBusy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.add_circle_outline_rounded),
                                  label: Text(
                                    _addCardBusy ? 'Adding...' : 'Add Card',
                                  ),
                                ),
                              ),
                              if (hasSavedCopies) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _removeFromPokedex,
                                    child: const Text('Remove from Set Pokédex'),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
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
                                child: OutlinedButton(
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
                                        ? 'Edit Count / Variant'
                                        : 'Choose Variant / Count',
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
                                'Tap to show Add Card, wishlist, binder and Pokédex actions',
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
