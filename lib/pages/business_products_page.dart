import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_product.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';

class BusinessProductsPage extends StatefulWidget {
  const BusinessProductsPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  @override
  State<BusinessProductsPage> createState() => _BusinessProductsPageState();
}

class _BusinessProductsPageState extends State<BusinessProductsPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  static const Map<String, String> _categoryLabels = <String, String>{
    'sealed': 'Sealed product',
    'singles': 'Singles',
    'accessories': 'Accessories',
    'pre_order': 'Pre-order',
    'new_arrival': 'New arrival',
    'deal': 'Deal',
    'other': 'Other product',
  };

  final BusinessProfileService _service = BusinessProfileService();

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _canManage {
    return _currentUid.isNotEmpty && _currentUid == widget.profile.ownerUid;
  }

  bool get _canCreateProducts {
    return _canManage && widget.profile.premiumIsActive;
  }

  InputDecoration _inputDecoration(String labelText, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: _softTextColor),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _goldColor,
        fontWeight: FontWeight.w900,
      ),
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _goldColor, width: 1.6),
      ),
    );
  }

  Future<void> _openProductSheet({BusinessProduct? existingProduct}) async {
    if (!_canCreateProducts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business Pro must be active before adding products.'),
        ),
      );
      return;
    }

    final nameController = TextEditingController(
      text: existingProduct?.name ?? '',
    );
    final descriptionController = TextEditingController(
      text: existingProduct?.description ?? '',
    );
    final priceController = TextEditingController(
      text: existingProduct?.price ?? '',
    );
    final imageUrlController = TextEditingController(
      text: existingProduct?.imageUrl ?? '',
    );
    final buyUrlController = TextEditingController(
      text: existingProduct?.buyUrl ?? widget.profile.website,
    );

    var selectedCategory = existingProduct?.category ?? 'sealed';
    if (!_categoryLabels.containsKey(selectedCategory)) {
      selectedCategory = 'other';
    }

    var active = existingProduct?.active ?? true;
    var featured = existingProduct?.featured ?? false;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        var saving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveProduct() async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product name is required.')),
                );
                return;
              }

              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product description is required.')),
                );
                return;
              }

              setModalState(() => saving = true);

              try {
                await _service.saveBusinessProduct(
                  profile: widget.profile,
                  productId: existingProduct?.id,
                  name: name,
                  description: description,
                  category: selectedCategory,
                  price: priceController.text.trim(),
                  imageUrl: imageUrlController.text.trim(),
                  buyUrl: buyUrlController.text.trim(),
                  active: active,
                  featured: featured,
                );

                if (!bottomSheetContext.mounted) return;
                Navigator.of(bottomSheetContext).pop();

                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      existingProduct == null ? 'Product added.' : 'Product saved.',
                    ),
                  ),
                );

                return;
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not save product: $error')),
                );

                if (context.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existingProduct == null ? 'Add product' : 'Edit product',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Showcase a product, pre-order, accessory, single or new arrival.',
                        style: TextStyle(
                          color: _softTextColor,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        dropdownColor: _fieldColor,
                        iconEnabledColor: _softTextColor,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration('Product category'),
                        items: _categoryLabels.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setModalState(() => selectedCategory = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        enabled: !saving,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration('Product name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        enabled: !saving,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 700,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration('Description'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        enabled: !saving,
                        maxLength: 40,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration(
                          'Price',
                          hintText: 'Optional, example £39.99',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageUrlController,
                        enabled: !saving,
                        maxLength: 500,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration(
                          'Product image URL',
                          hintText: 'Optional image link',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: buyUrlController,
                        enabled: !saving,
                        maxLength: 500,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration(
                          'Buy / product page link',
                          hintText: 'Optional',
                        ),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: _goldColor,
                        activeTrackColor: _goldColor.withValues(alpha: 0.35),
                        title: const Text(
                          'Show this product',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: const Text(
                          'Turn this off to hide the product without deleting it.',
                          style: TextStyle(color: _softTextColor),
                        ),
                        value: active,
                        onChanged: saving
                            ? null
                            : (value) {
                                setModalState(() => active = value);
                              },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: _goldColor,
                        activeTrackColor: _goldColor.withValues(alpha: 0.35),
                        title: const Text(
                          'Feature this product',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: const Text(
                          'Featured products appear first in the showcase.',
                          style: TextStyle(color: _softTextColor),
                        ),
                        value: featured,
                        onChanged: saving
                            ? null
                            : (value) {
                                setModalState(() => featured = value);
                              },
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _goldColor,
                          foregroundColor: _backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _backgroundColor,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          saving ? 'Saving...' : 'Save product',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        onPressed: saving ? null : saveProduct,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    imageUrlController.dispose();
    buyUrlController.dispose();
  }

  Future<void> _deleteProduct(BusinessProduct product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete product?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will permanently delete "${product.name}".',
            style: const TextStyle(
              color: _softTextColor,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _service.deleteBusinessProduct(
        businessId: widget.profile.id,
        productId: product.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete product: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName = widget.profile.businessName.trim().isEmpty
        ? 'Product showcase'
        : widget.profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Product Showcase'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              heroTag: 'add-business-product',
              backgroundColor: _goldColor,
              foregroundColor: _backgroundColor,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add product',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () => _openProductSheet(),
            )
          : null,
      body: StreamBuilder<List<BusinessProduct>>(
        stream: _service.watchBusinessProducts(widget.profile.id),
        builder: (context, snapshot) {
          final products = snapshot.data ?? const <BusinessProduct>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _ProductsHeaderCard(
                businessName: businessName,
                productCount: products.length,
                premiumActive: widget.profile.premiumIsActive,
              ),
              if (_canManage && !widget.profile.premiumIsActive) ...[
                const SizedBox(height: 14),
                const _BusinessProRequiredCard(),
              ],
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _goldColor),
                  ),
                )
              else if (products.isEmpty)
                _EmptyProductsCard(canManage: _canManage)
              else
                ...products.map(
                  (product) => _ProductCard(
                    product: product,
                    canManage: _canManage,
                    onEdit: () => _openProductSheet(existingProduct: product),
                    onDelete: () => _deleteProduct(product),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductsHeaderCard extends StatelessWidget {
  const _ProductsHeaderCard({
    required this.businessName,
    required this.productCount,
    required this.premiumActive,
  });

  final String businessName;
  final int productCount;
  final bool premiumActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BusinessProductsPageState._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: premiumActive
              ? _BusinessProductsPageState._goldColor
              : _BusinessProductsPageState._borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _BusinessProductsPageState._fieldColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _BusinessProductsPageState._borderColor,
              ),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _BusinessProductsPageState._goldColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  productCount == 0
                      ? 'Showcase products, pre-orders, singles and new arrivals.'
                      : '$productCount product${productCount == 1 ? '' : 's'} saved.',
                  style: const TextStyle(
                    color: _BusinessProductsPageState._softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessProRequiredCard extends StatelessWidget {
  const _BusinessProRequiredCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.55)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Product Showcase is a Business Pro feature. Ask an admin to activate Business Pro for this business.',
              style: TextStyle(
                color: _BusinessProductsPageState._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProductsCard extends StatelessWidget {
  const _EmptyProductsCard({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: _BusinessProductsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessProductsPageState._borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: _BusinessProductsPageState._goldColor,
            size: 46,
          ),
          const SizedBox(height: 12),
          const Text(
            'No products yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canManage
                ? 'Tap Add product to create your first Product Showcase item.'
                : 'This business has not added products yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _BusinessProductsPageState._softTextColor,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final BusinessProduct product;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _openBuyLink(BuildContext context) async {
    final cleanUrl = product.buyUrl.trim();
    if (cleanUrl.isEmpty) return;

    final url = cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')
        ? cleanUrl
        : 'https://$cleanUrl';

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this product link.')),
      );
      return;
    }

    await BusinessProfileService().incrementBusinessAnalyticsMetric(
      businessId: product.businessId,
      metric: 'productViews',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this product link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _BusinessProductsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: product.featured
              ? _BusinessProductsPageState._goldColor
              : _BusinessProductsPageState._borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(21),
              ),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const _ProductImageFallback();
                },
              ),
            )
          else
            const _ProductImageFallback(),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProductBadge(
                      icon: Icons.category_outlined,
                      label: product.categoryLabel,
                      highlighted: true,
                    ),
                    if (product.featured)
                      const _ProductBadge(
                        icon: Icons.star_rounded,
                        label: 'Featured',
                        highlighted: false,
                      ),
                    _ProductBadge(
                      icon: product.active
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      label: product.active ? 'Visible' : 'Hidden',
                      highlighted: false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  product.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (product.price.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    product.price.trim(),
                    style: const TextStyle(
                      color: _BusinessProductsPageState._goldColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (product.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    product.description.trim(),
                    style: const TextStyle(
                      color: _BusinessProductsPageState._softTextColor,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (product.buyUrl.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _BusinessProductsPageState._goldColor,
                        side: const BorderSide(
                          color: _BusinessProductsPageState._goldColor,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text(
                        'Open product link',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () => _openBuyLink(context),
                    ),
                  ),
                ],
                if (canManage) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                            color: _BusinessProductsPageState._borderColor,
                          ),
                        ),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
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

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _BusinessProductsPageState._fieldColor,
      ),
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: _BusinessProductsPageState._goldColor,
          size: 46,
        ),
      ),
    );
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? _BusinessProductsPageState._goldColor
            : _BusinessProductsPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? _BusinessProductsPageState._goldColor
              : _BusinessProductsPageState._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted
                ? _BusinessProductsPageState._backgroundColor
                : _BusinessProductsPageState._goldColor,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: highlighted
                  ? _BusinessProductsPageState._backgroundColor
                  : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
