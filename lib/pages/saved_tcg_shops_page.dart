import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/saved_tcg_shop.dart';
import '../services/saved_tcg_shop_service.dart';

class SavedTcgShopsPage extends StatelessWidget {
  const SavedTcgShopsPage({super.key});

  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  Future<void> _openMaps(BuildContext context, SavedTcgShop shop) async {
    if (!shop.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No map location saved for this shop.')),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${shop.lat},${shop.lng}',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps.')),
      );
    }
  }

  Future<void> _openWebsite(BuildContext context, SavedTcgShop shop) async {
    final cleanWebsite = shop.website.trim();
    if (cleanWebsite.isEmpty) return;

    final url = cleanWebsite.startsWith('http://') ||
            cleanWebsite.startsWith('https://')
        ? cleanWebsite
        : 'https://$cleanWebsite';

    final uri = Uri.tryParse(url);

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this website.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = SavedTcgShopService();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Saved Shops'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<SavedTcgShop>>(
        stream: service.watchSavedShops(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _goldColor),
            );
          }

          final shops = snapshot.data ?? const <SavedTcgShop>[];

          if (shops.isEmpty) {
            return const _EmptySavedShopsState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final shop = shops[index];

              return _SavedShopCard(
                shop: shop,
                onOpenMaps: () => _openMaps(context, shop),
                onOpenWebsite: shop.hasWebsite
                    ? () => _openWebsite(context, shop)
                    : null,
                onUnsave: () async {
                  await service.unsaveShop(shop.shopId);

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${shop.displayName} removed from saved shops.'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedShopCard extends StatelessWidget {
  const _SavedShopCard({
    required this.shop,
    required this.onOpenMaps,
    required this.onUnsave,
    this.onOpenWebsite,
  });

  final SavedTcgShop shop;
  final VoidCallback onOpenMaps;
  final VoidCallback? onOpenWebsite;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SavedTcgShopsPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SavedTcgShopsPage._borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shop.imageUrl.trim().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(21),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  shop.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const _ShopImageFallback();
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shop.imageUrl.trim().isEmpty) ...[
                  const _ShopIconBox(),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            color: SavedTcgShopsPage._goldColor,
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              shop.displayAddress,
                              style: const TextStyle(
                                color: SavedTcgShopsPage._softTextColor,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (shop.hasPhone) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              color: SavedTcgShopsPage._goldColor,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                shop.phone,
                                style: const TextStyle(
                                  color: SavedTcgShopsPage._softTextColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove saved shop',
                  color: SavedTcgShopsPage._goldColor,
                  icon: const Icon(Icons.bookmark_remove_outlined),
                  onPressed: onUnsave,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SavedTcgShopsPage._goldColor,
                    side: const BorderSide(color: SavedTcgShopsPage._goldColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text(
                    'Open map',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onPressed: onOpenMaps,
                ),
                if (onOpenWebsite != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SavedTcgShopsPage._goldColor,
                      foregroundColor: SavedTcgShopsPage._backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text(
                      'Website',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onPressed: onOpenWebsite,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopIconBox extends StatelessWidget {
  const _ShopIconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: SavedTcgShopsPage._fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SavedTcgShopsPage._borderColor),
      ),
      child: const Icon(
        Icons.storefront_outlined,
        color: SavedTcgShopsPage._goldColor,
      ),
    );
  }
}

class _ShopImageFallback extends StatelessWidget {
  const _ShopImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SavedTcgShopsPage._fieldColor,
      child: const Center(
        child: Icon(
          Icons.storefront_outlined,
          color: SavedTcgShopsPage._goldColor,
          size: 42,
        ),
      ),
    );
  }
}

class _EmptySavedShopsState extends StatelessWidget {
  const _EmptySavedShopsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border,
              color: SavedTcgShopsPage._goldColor,
              size: 54,
            ),
            SizedBox(height: 14),
            Text(
              'No saved shops yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Open a shop on the map and tap Save shop to keep it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SavedTcgShopsPage._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          'Could not load saved shops: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SavedTcgShopsPage._softTextColor,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
