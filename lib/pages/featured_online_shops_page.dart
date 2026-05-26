import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_profile.dart';
import '../services/business_profile_service.dart';

class FeaturedOnlineShopsPage extends StatelessWidget {
  const FeaturedOnlineShopsPage({super.key});

  static const Color backgroundColor = Color(0xFF041B4A);
  static const Color cardColor = Color(0xFF102754);
  static const Color fieldColor = Color(0xFF16366E);
  static const Color borderColor = Color(0xFF3F5C96);
  static const Color goldColor = Color(0xFFF7DE77);
  static const Color softTextColor = Color(0xFFC8D4F0);

  @override
  Widget build(BuildContext context) {
    final service = BusinessProfileService();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Featured Online Shops'),
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BusinessProfile>>(
        stream: service.watchFeaturedOnlineBusinessProfiles(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: goldColor),
            );
          }

          final shops = snapshot.data ?? const <BusinessProfile>[];

          if (shops.isEmpty) {
            return const _EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
            itemCount: shops.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _IntroCard();
              }

              final shop = shops[index - 1];
              return _OnlineShopCard(shop: shop);
            },
          );
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FeaturedOnlineShopsPage.goldColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FeaturedOnlineShopsPage.goldColor),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.language,
            color: FeaturedOnlineShopsPage.goldColor,
            size: 26,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Discover featured online TCG businesses. These shops do not have a physical map pin, but they can still promote their online store with Business Pro.',
              style: TextStyle(
                color: Colors.white,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineShopCard extends StatelessWidget {
  const _OnlineShopCard({required this.shop});

  final BusinessProfile shop;

  @override
  Widget build(BuildContext context) {
    final location = shop.displayLocation;
    final website = shop.website.trim();
    final phone = shop.phone.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: FeaturedOnlineShopsPage.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FeaturedOnlineShopsPage.goldColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: FeaturedOnlineShopsPage.fieldColor,
                child: shop.logoUrl.isEmpty
                    ? const Icon(
                        Icons.storefront_outlined,
                        color: FeaturedOnlineShopsPage.goldColor,
                        size: 30,
                      )
                    : ClipOval(
                        child: Image.network(
                          shop.logoUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.storefront_outlined,
                              color: FeaturedOnlineShopsPage.goldColor,
                              size: 30,
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.businessName.isEmpty
                          ? 'Online TCG Shop'
                          : shop.businessName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _BusinessProBadge(),
                  ],
                ),
              ),
            ],
          ),
          if (shop.description.trim().isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(
              shop.description.trim(),
              style: const TextStyle(
                color: FeaturedOnlineShopsPage.softTextColor,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _InfoChip(
                icon: Icons.language,
                label: 'Online shop',
              ),
              if (location.isNotEmpty)
                _InfoChip(
                  icon: Icons.place_outlined,
                  label: location,
                ),
              if (shop.autoFeaturePosts)
                const _InfoChip(
                  icon: Icons.campaign_outlined,
                  label: 'Featured posts',
                ),
            ],
          ),
          if (website.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (website.isNotEmpty)
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: FeaturedOnlineShopsPage.goldColor,
                        foregroundColor: FeaturedOnlineShopsPage.backgroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text(
                        'Open website',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () => _openWebsite(context, website),
                    ),
                  ),
                if (website.isNotEmpty && phone.isNotEmpty)
                  const SizedBox(width: 10),
                if (phone.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FeaturedOnlineShopsPage.goldColor,
                        side: const BorderSide(
                          color: FeaturedOnlineShopsPage.goldColor,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text(
                        'Contact',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () => _showContact(context, phone),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context, String website) async {
    final cleanWebsite = website.trim();
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

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this website.')),
      );
    }
  }

  void _showContact(BuildContext context, String phone) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: FeaturedOnlineShopsPage.cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phone_outlined,
                  color: FeaturedOnlineShopsPage.goldColor,
                  size: 36,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Contact business',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: FeaturedOnlineShopsPage.softTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: FeaturedOnlineShopsPage.goldColor,
                      foregroundColor:
                          FeaturedOnlineShopsPage.backgroundColor,
                    ),
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BusinessProBadge extends StatelessWidget {
  const _BusinessProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: FeaturedOnlineShopsPage.goldColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            color: FeaturedOnlineShopsPage.backgroundColor,
            size: 16,
          ),
          SizedBox(width: 5),
          Text(
            'Business Pro',
            style: TextStyle(
              color: FeaturedOnlineShopsPage.backgroundColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: FeaturedOnlineShopsPage.fieldColor,
      side: const BorderSide(color: FeaturedOnlineShopsPage.borderColor),
      avatar: Icon(
        icon,
        color: FeaturedOnlineShopsPage.goldColor,
        size: 17,
      ),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language,
              color: FeaturedOnlineShopsPage.goldColor,
              size: 46,
            ),
            SizedBox(height: 12),
            Text(
              'No featured online shops yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Online-only shops will appear here when Business Pro premium is enabled for them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FeaturedOnlineShopsPage.softTextColor,
                height: 1.35,
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
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load featured online shops: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: FeaturedOnlineShopsPage.softTextColor,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
