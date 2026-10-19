import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/glass_page_header.dart';

import '../models/wishlist_entry.dart';
import '../services/pokemon_tcg_service.dart';
import '../services/currency_settings.dart';
import '../services/wishlist_service.dart';
import '../utils/price_format_helpers.dart';
import 'card_details_page.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({
    super.key,
    required this.ownerUid,
    required this.ownerName,
    this.showAddHint = true,
  });

  final String ownerUid;
  final String ownerName;
  final bool showAddHint;

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final Map<String, ({double amount, String currency})> _resolvedPrices =
      <String, ({double amount, String currency})>{};
  final Set<String> _priceLookupsAttempted = <String>{};
  bool _loadingPrices = false;

  Future<void> _openCard(BuildContext context, WishlistEntry entry) async {
    final returnToWishlistAfterAdd =
        FirebaseAuth.instance.currentUser?.uid == widget.ownerUid;
    try {
      final fullCard = await PokemonTcgService.fetchCardById(entry.cardId);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(
            card: fullCard,
            returnToWishlistAfterAdd: returnToWishlistAfterAdd,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(
            card: entry.toSummaryCard(),
            returnToWishlistAfterAdd: returnToWishlistAfterAdd,
          ),
        ),
      );
    }
  }

  void _scheduleMissingPriceLookup(List<WishlistEntry> entries) {
    final missing = entries
        .where(
          (entry) =>
              (entry.rawPrice == null || entry.rawPrice! <= 0) &&
              !_resolvedPrices.containsKey(entry.cardId) &&
              !_priceLookupsAttempted.contains(entry.cardId),
        )
        .toList();
    if (missing.isEmpty || _loadingPrices) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadingPrices) return;
      _loadMissingPrices(missing);
    });
  }

  Future<void> _loadMissingPrices(List<WishlistEntry> entries) async {
    setState(() {
      _loadingPrices = true;
      _priceLookupsAttempted.addAll(entries.map((entry) => entry.cardId));
    });

    final resolved = <String, ({double amount, String currency})>{};

    // Limit concurrent requests, but do not rebuild after every response. A
    // long wishlist previously caused one full-page redraw per card, making
    // the screen visibly flash and jump while prices were checked.
    const batchSize = 6;
    for (var start = 0; start < entries.length; start += batchSize) {
      final end = start + batchSize < entries.length
          ? start + batchSize
          : entries.length;
      final batch = entries.sublist(start, end);
      final results = await Future.wait(
        batch.map((entry) async {
          try {
            final card = await PokemonTcgService.fetchCardById(entry.cardId);
            final price = card.marketPrice;
            if (price != null && price.isFinite && price > 0) {
              return (
                cardId: entry.cardId,
                amount: price,
                currency: card.marketPriceCurrency,
              );
            }
          } catch (_) {
            // Keep the card in the unavailable count when no price exists.
          }
          return null;
        }),
      );
      for (final result in results) {
        if (result == null) continue;
        resolved[result.cardId] = (
          amount: result.amount,
          currency: result.currency,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _resolvedPrices.addAll(resolved);
      _loadingPrices = false;
    });
  }

  ({double amount, String currency})? _priceFor(WishlistEntry entry) {
    final stored = entry.rawPrice;
    if (stored != null && stored.isFinite && stored > 0) {
      return (amount: stored, currency: entry.rawPriceCurrency);
    }
    return _resolvedPrices[entry.cardId];
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwnWishlist = currentUid == widget.ownerUid;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: GlassPageAppBar(
        title: isOwnWishlist ? 'Wishlist' : "${widget.ownerName}'s Wishlist",
        subtitle: isOwnWishlist ? 'Saved cards' : 'Friend wishlist',
        icon: Icons.favorite_outline_rounded,
      ),
      body: SafeArea(
        child: StreamBuilder<List<WishlistEntry>>(
          stream: WishlistService.wishlistStream(widget.ownerUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load wishlist right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            final entries = snapshot.data ?? const <WishlistEntry>[];
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    isOwnWishlist
                        ? 'Your wishlist is empty. Open a card and tap Add to Wishlist.'
                        : '${widget.ownerName} has not added any wishlist cards yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              );
            }

            _scheduleMissingPriceLookup(entries);
            final setCount = entries
                .map((entry) => entry.setId.trim().isNotEmpty
                    ? entry.setId.trim().toLowerCase()
                    : entry.setName.trim().toLowerCase())
                .where((value) => value.isNotEmpty)
                .toSet()
                .length;
            var estimatedValue = 0.0;
            var pricedCount = 0;
            for (final entry in entries) {
              final price = _priceFor(entry);
              if (price == null) continue;
              estimatedValue += CurrencySettings.convertAmountSync(
                    price.amount,
                    fromCurrency: price.currency,
                  ) ??
                  0;
              pricedCount++;
            }

            final showHint = widget.showAddHint && isOwnWishlist;
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length + (showHint ? 1 : 0) + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _WishlistSummaryCard(
                    cardCount: entries.length,
                    setCount: setCount,
                    estimatedValue: estimatedValue,
                    pricedCount: pricedCount,
                    loadingPrices: _loadingPrices,
                  );
                }

                if (showHint && index == 1) {
                  return Card(
                    color: const Color(0xFF102754),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Tip: open any card from search or a set and tap Add to Wishlist to save it here.',
                        style: TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
                      ),
                    ),
                  );
                }

                final entry = entries[index - 1 - (showHint ? 1 : 0)];
                final resolvedPrice = _priceFor(entry);
                return Card(
                  color: const Color(0xFF102754),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openCard(context, entry),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 72,
                              height: 100,
                              child: entry.imageUrl == null || entry.imageUrl!.isEmpty
                                  ? Container(
                                      color: const Color(0xFF0E2A5E),
                                      child: const Icon(Icons.image_not_supported, color: Colors.white),
                                    )
                                  : Image.network(entry.imageUrl!, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  entry.setName,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Card #${entry.number}',
                                  style: const TextStyle(color: Colors.white60),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  resolvedPrice == null
                                      ? 'Price unavailable'
                                      : 'Est. raw price: ${formatCardPrice(resolvedPrice.amount, fromCurrency: resolvedPrice.currency)}',
                                  style: const TextStyle(
                                    color: Color(0xFFF7DE77),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WishlistSummaryCard extends StatelessWidget {
  const _WishlistSummaryCard({
    required this.cardCount,
    required this.setCount,
    required this.estimatedValue,
    required this.pricedCount,
    required this.loadingPrices,
  });

  final int cardCount;
  final int setCount;
  final double estimatedValue;
  final int pricedCount;
  final bool loadingPrices;

  @override
  Widget build(BuildContext context) {
    final unavailableCount = cardCount - pricedCount;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33F7DE77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wishlist overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _WishlistStat(
                  icon: Icons.style_rounded,
                  value: '$cardCount',
                  label: cardCount == 1 ? 'Card' : 'Cards',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WishlistStat(
                  icon: Icons.collections_bookmark_outlined,
                  value: '$setCount',
                  label: setCount == 1 ? 'Set' : 'Different sets',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WishlistStat(
            icon: Icons.show_chart_rounded,
            value: pricedCount == 0
                ? 'Unavailable'
                : CurrencySettings.formatSelectedAmount(estimatedValue),
            label: 'Estimated wishlist value',
            wide: true,
          ),
          if (loadingPrices || unavailableCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              loadingPrices
                  ? 'Checking missing card prices…'
                  : '$unavailableCount ${unavailableCount == 1 ? 'card has' : 'cards have'} no available price yet.',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _WishlistStat extends StatelessWidget {
  const _WishlistStat({
    required this.icon,
    required this.value,
    required this.label,
    this.wide = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF18366E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF7DE77), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
