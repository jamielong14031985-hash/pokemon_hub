import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/glass_page_header.dart';

import '../models/wishlist_entry.dart';
import '../services/pokemon_tcg_service.dart';
import '../services/wishlist_service.dart';
import '../utils/price_format_helpers.dart';
import 'card_details_page.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({
    super.key,
    required this.ownerUid,
    required this.ownerName,
    this.showAddHint = true,
  });

  final String ownerUid;
  final String ownerName;
  final bool showAddHint;

  Future<void> _openCard(BuildContext context, WishlistEntry entry) async {
    try {
      final fullCard = await PokemonTcgService.fetchCardById(entry.cardId);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(card: fullCard),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(card: entry.toSummaryCard()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwnWishlist = currentUid == ownerUid;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: GlassPageAppBar(
        title: isOwnWishlist ? 'Wishlist' : "$ownerName's Wishlist",
        subtitle: isOwnWishlist ? 'Saved cards' : 'Friend wishlist',
        icon: Icons.favorite_outline_rounded,
      ),
      body: SafeArea(
        child: StreamBuilder<List<WishlistEntry>>(
          stream: WishlistService.wishlistStream(ownerUid),
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
                        : '$ownerName has not added any wishlist cards yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length + (showAddHint && isOwnWishlist ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (showAddHint && isOwnWishlist && index == 0) {
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

                final entry = entries[index - (showAddHint && isOwnWishlist ? 1 : 0)];
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
                                  entry.rawPrice == null
                                      ? 'Price unavailable'
                                      : 'Est. raw price: ${formatCardPrice(entry.rawPrice, fromCurrency: entry.rawPriceCurrency)}',
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
