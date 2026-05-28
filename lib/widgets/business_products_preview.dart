import 'package:flutter/material.dart';

import '../models/business_product.dart';
import '../models/business_profile.dart';
import '../pages/business_products_page.dart';
import '../services/business_profile_service.dart';

class BusinessProductsPreview extends StatelessWidget {
  const BusinessProductsPreview({
    super.key,
    required this.profile,
    this.maxItems = 3,
    this.compact = false,
  });

  final BusinessProfile profile;
  final int maxItems;
  final bool compact;

  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  void _openProducts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessProductsPage(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (profile.id.trim().isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<BusinessProduct>>(
      stream: BusinessProfileService().watchBusinessProducts(
        profile.id,
        visibleOnly: true,
      ),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <BusinessProduct>[];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _PreviewShell(
            compact: compact,
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _goldColor,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loading products...',
                    style: TextStyle(
                      color: _softTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (products.isEmpty) return const SizedBox.shrink();

        final visibleProducts = products.take(maxItems).toList();

        return _PreviewShell(
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: _goldColor,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      products.length == 1
                          ? '1 showcased product'
                          : '${products.length} showcased products',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: _goldColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openProducts(context),
                    child: const Text(
                      'View all',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: compact ? 132 : 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visibleProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return _MiniProductCard(
                      product: visibleProducts[index],
                      compact: compact,
                    );
                  },
                ),
              ),
              if (products.length > visibleProducts.length) ...[
                const SizedBox(height: 8),
                Text(
                  '+${products.length - visibleProducts.length} more product${products.length - visibleProducts.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: _softTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PreviewShell extends StatelessWidget {
  const _PreviewShell({
    required this.child,
    required this.compact,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: BusinessProductsPreview._cardColor,
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(color: BusinessProductsPreview._borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: compact ? 0.08 : 0.16),
            blurRadius: compact ? 8 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniProductCard extends StatelessWidget {
  const _MiniProductCard({
    required this.product,
    required this.compact,
  });

  final BusinessProduct product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl.trim();

    return Container(
      width: compact ? 138 : 158,
      decoration: BoxDecoration(
        color: BusinessProductsPreview._fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: product.featured
              ? BusinessProductsPreview._goldColor
              : BusinessProductsPreview._borderColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              width: double.infinity,
              height: compact ? 60 : 72,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const _MiniProductImageFallback();
              },
            )
          else
            const _MiniProductImageFallback(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name.trim().isEmpty ? 'Product' : product.name.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    height: 1.1,
                  ),
                ),
                if (product.price.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.price.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BusinessProductsPreview._goldColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniProductImageFallback extends StatelessWidget {
  const _MiniProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      width: double.infinity,
      color: BusinessProductsPreview._backgroundColor.withValues(alpha: 0.48),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: BusinessProductsPreview._goldColor,
        size: 25,
      ),
    );
  }
}
