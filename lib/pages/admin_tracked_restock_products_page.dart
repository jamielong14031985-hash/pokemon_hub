import 'package:flutter/material.dart';

import '../services/tracked_restock_product_service.dart';
import '../services/user_feature_flags_service.dart';

class AdminTrackedRestockProductsPage extends StatelessWidget {
  const AdminTrackedRestockProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Tracked Products'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductDialog(context),
        icon: const Icon(Icons.add_link),
        label: const Text('Add product'),
      ),
      body: StreamBuilder<bool>(
        stream: UserFeatureFlagsService.watchCurrentUserCanManageFeatureFlags(),
        builder: (context, permissionSnapshot) {
          if (permissionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (permissionSnapshot.data != true) {
            return const _NoPermissionMessage();
          }

          return StreamBuilder<List<TrackedRestockProduct>>(
            stream: TrackedRestockProductService.watchProducts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorMessage(error: snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data ?? const <TrackedRestockProduct>[];

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const _IntroCard(),
                  const SizedBox(height: 16),
                  if (products.isEmpty)
                    const _EmptyProductsCard()
                  else
                    ...products.map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TrackedProductCard(product: product),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static Future<void> _showAddProductDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _AddTrackedProductDialog(),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'Add Pokémon product pages here once. Firebase will check them automatically in the background. '
          'When a tracked product changes from out of stock to in stock, a global Restock Alert is created and enabled users get a push notification.',
          style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
        ),
      ),
    );
  }
}

class _EmptyProductsCard extends StatelessWidget {
  const _EmptyProductsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.link_outlined, color: Colors.white70, size: 42),
            SizedBox(height: 12),
            Text(
              'No tracked products yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tap Add product to add a shop product page for automatic checks.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD8E3FB)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackedProductCard extends StatelessWidget {
  const _TrackedProductCard({
    required this.product,
  });

  final TrackedRestockProduct product;

  @override
  Widget build(BuildContext context) {
    final statusText = product.inStock ? 'In stock' : 'Not in stock';
    final checkedText = _formatDate(product.lastCheckedAt);
    final statusColor = product.inStock
        ? const Color(0xFF54D39A)
        : const Color(0xFFFFB3C7);

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF0E2A5E),
              child: Icon(
                product.enabled ? Icons.link : Icons.link_off,
                color: product.enabled
                    ? const Color(0xFFF7DE77)
                    : Colors.white54,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.shopName,
                      style: const TextStyle(color: Color(0xFFD8E3FB)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      checkedText.isEmpty
                          ? 'Not checked yet'
                          : 'Last checked: $checkedText',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    if ((product.lastCheckError ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.lastCheckError!,
                        style: const TextStyle(
                          color: Color(0xFFFFB3C7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Switch(
                  value: product.enabled,
                  onChanged: (enabled) async {
                    try {
                      await TrackedRestockProductService.setProductEnabled(
                        productId: product.id,
                        enabled: enabled,
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      _showSnackBar(context, error.toString());
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFFFB3C7),
                  ),
                  onPressed: () => _confirmDelete(context, product.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';

    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month $hour:$minute';
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    String productId,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete tracked product?'),
        content: const Text('Firebase will stop checking this product page.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await TrackedRestockProductService.deleteProduct(productId);
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(context, error.toString());
    }
  }
}

class _AddTrackedProductDialog extends StatefulWidget {
  const _AddTrackedProductDialog();

  @override
  State<_AddTrackedProductDialog> createState() =>
      _AddTrackedProductDialogState();
}

class _AddTrackedProductDialogState extends State<_AddTrackedProductDialog> {
  final TextEditingController _shopController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _inKeywordsController = TextEditingController(
    text: 'add to basket, add to cart, in stock, buy now, preorder, pre-order',
  );
  final TextEditingController _outKeywordsController = TextEditingController(
    text: 'out of stock, sold out, unavailable, notify me, coming soon',
  );

  bool _isSaving = false;

  @override
  void dispose() {
    _shopController.dispose();
    _productController.dispose();
    _urlController.dispose();
    _imageUrlController.dispose();
    _notesController.dispose();
    _inKeywordsController.dispose();
    _outKeywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add tracked product'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                controller: _shopController,
                label: 'Shop name',
                hint: 'Example: Pokemon Center UK',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _productController,
                label: 'Product name',
                hint: 'Example: 151 Booster Bundle',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _urlController,
                label: 'Product page URL',
                hint: 'https://...',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _imageUrlController,
                label: 'Image URL',
                hint: 'Optional',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _notesController,
                label: 'Notes',
                hint: 'Optional',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _inKeywordsController,
                label: 'In-stock keywords',
                hint: 'Separate with commas',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _outKeywordsController,
                label: 'Out-of-stock keywords',
                hint: 'Separate with commas',
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_link),
          label: const Text('Save'),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isSaving,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      await TrackedRestockProductService.createProduct(
        shopName: _shopController.text,
        productName: _productController.text,
        productUrl: _urlController.text,
        imageUrl: _imageUrlController.text,
        notes: _notesController.text,
        inStockKeywords: _splitKeywords(_inKeywordsController.text),
        outOfStockKeywords: _splitKeywords(_outKeywordsController.text),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(context, error.toString());
      setState(() => _isSaving = false);
    }
  }

  List<String> _splitKeywords(String value) {
    return value
        .split(',')
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toList();
  }
}

class _NoPermissionMessage extends StatelessWidget {
  const _NoPermissionMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        color: Color(0xFF102754),
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'You do not have permission to manage tracked products.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.error,
  });

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: const Color(0xFF102754),
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Could not load tracked products.\n\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
