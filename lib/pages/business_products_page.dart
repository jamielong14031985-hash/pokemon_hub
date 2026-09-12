import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_product.dart';
import '../models/business_profile.dart';
import '../services/business_post_service.dart';
import '../widgets/business_enquiry_button.dart';

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
  static const Color _dangerColor = Color(0xFFFB7185);
  static const Color _successColor = Color(0xFF4ADE80);

  static const Map<String, String> _categoryLabels = <String, String>{
    'sealed': 'Sealed product',
    'singles': 'Singles',
    'accessories': 'Accessories',
    'pre_order': 'Pre-order',
    'new_arrival': 'New arrival',
    'deal': 'Deal',
    'other': 'Other product',
  };

  final BusinessPostService _service = BusinessPostService();

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _canManage {
    return _currentUid.isNotEmpty && _currentUid == widget.profile.ownerUid;
  }

  bool get _canCreateProducts {
    return _canManage && widget.profile.premiumIsActive;
  }

  void _showProRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business Pro must be active before adding products.'),
      ),
    );
  }

  Future<void> _openEditor({BusinessProduct? existingProduct}) async {
    if (!_canCreateProducts) {
      _showProRequiredMessage();
      return;
    }

    final savedMessage = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _BusinessProductEditorPage(
          profile: widget.profile,
          existingProduct: existingProduct,
        ),
      ),
    );

    if (!mounted || savedMessage == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(savedMessage)),
    );
  }

  Future<void> _deleteProduct(BusinessProduct product) async {
    final confirmed = await _confirmDelete(
      title: 'Delete product?',
      message: 'This will permanently delete "${product.name}".',
    );

    if (confirmed != true) return;

    try {
      await _service.deleteBusinessProduct(product);

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

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(
            message,
            style: const TextStyle(color: _softTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _dangerColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Products'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_canManage)
            IconButton(
              tooltip: 'Add product',
              onPressed: _canCreateProducts ? () => _openEditor() : _showProRequiredMessage,
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              backgroundColor: _goldColor,
              foregroundColor: _backgroundColor,
              onPressed: _canCreateProducts ? () => _openEditor() : _showProRequiredMessage,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add product',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : null,
      body: StreamBuilder<List<BusinessProduct>>(
        stream: _service.watchBusinessProducts(
          widget.profile.id,
          visibleOnly: !_canManage,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline,
              title: 'Could not load products',
              message: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _goldColor),
            );
          }

          final products = snapshot.data ?? const <BusinessProduct>[];
          if (products.isEmpty) {
            return _MessageState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              message: _canManage
                  ? 'Tap Add product to create your first product post with one picture.'
                  : 'This business has not added any products yet.',
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 276,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _ProductCard(
                product: product,
                canManage: _canManage,
                onView: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _BusinessProductDetailsPage(
                        product: product,
                        profile: widget.profile,
                        canManage: _canManage,
                        onEdit: () => _openEditor(existingProduct: product),
                      ),
                    ),
                  );
                },
                onEdit: () => _openEditor(existingProduct: product),
                onDelete: () => _deleteProduct(product),
              );
            },
          );
        },
      ),
    );
  }
}

class _BusinessProductEditorPage extends StatefulWidget {
  const _BusinessProductEditorPage({
    required this.profile,
    required this.existingProduct,
  });

  final BusinessProfile profile;
  final BusinessProduct? existingProduct;

  @override
  State<_BusinessProductEditorPage> createState() =>
      _BusinessProductEditorPageState();
}

class _BusinessProductEditorPageState extends State<_BusinessProductEditorPage> {
  final BusinessPostService _service = BusinessPostService();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _buyUrlController;

  late String _selectedCategory;
  late bool _active;
  late bool _featured;

  XFile? _pickedImage;
  bool _removeImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final existingProduct = widget.existingProduct;
    _nameController = TextEditingController(text: existingProduct?.name ?? '');
    _descriptionController = TextEditingController(
      text: existingProduct?.description ?? '',
    );
    _priceController = TextEditingController(text: existingProduct?.price ?? '');
    _buyUrlController = TextEditingController(
      text: existingProduct?.buyUrl ?? widget.profile.website,
    );

    _selectedCategory = existingProduct?.category ?? 'sealed';
    if (!_BusinessProductsPageState._categoryLabels.containsKey(_selectedCategory)) {
      _selectedCategory = 'other';
    }

    _active = existingProduct?.active ?? true;
    _featured = existingProduct?.featured ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _buyUrlController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String labelText, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(
        color: _BusinessProductsPageState._softTextColor,
      ),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _BusinessProductsPageState._goldColor,
        fontWeight: FontWeight.w900,
      ),
      filled: true,
      fillColor: _BusinessProductsPageState._fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _BusinessProductsPageState._borderColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _BusinessProductsPageState._borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _BusinessProductsPageState._goldColor,
          width: 1.6,
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );

    if (image == null || !mounted) return;

    setState(() {
      _pickedImage = image;
      _removeImage = false;
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImage = null;
      _removeImage = true;
    });
  }

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

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

    setState(() => _saving = true);

    try {
      final existingProduct = widget.existingProduct;
      await _service.saveBusinessProduct(
        profile: widget.profile,
        productId: existingProduct?.id,
        name: name,
        description: description,
        category: _selectedCategory,
        price: _priceController.text.trim(),
        buyUrl: _buyUrlController.text.trim(),
        active: _active,
        featured: _featured,
        pickedImage: _pickedImage,
        existingImageUrl: existingProduct?.imageUrl ?? '',
        existingImagePath: existingProduct?.imagePath ?? '',
        removeImage: _removeImage,
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        existingProduct == null ? 'Product added.' : 'Product saved.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save product: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingProduct = widget.existingProduct;

    return Scaffold(
      backgroundColor: _BusinessProductsPageState._backgroundColor,
      appBar: AppBar(
        title: Text(existingProduct == null ? 'Add product' : 'Edit product'),
        backgroundColor: _BusinessProductsPageState._backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const _EditorHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Product post',
            subtitle: 'Add one picture for this product. The post stays inside the app.',
          ),
          const SizedBox(height: 14),
          _SingleImagePickerCard(
            existingImageUrl: existingProduct?.imageUrl ?? '',
            pickedImage: _pickedImage,
            removeImage: _removeImage,
            enabled: !_saving,
            fallbackIcon: Icons.inventory_2_outlined,
            onPickImage: _pickImage,
            onClearImage: _clearImage,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            dropdownColor: _BusinessProductsPageState._fieldColor,
            iconEnabledColor: _BusinessProductsPageState._softTextColor,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            decoration: _inputDecoration('Product category'),
            items: _BusinessProductsPageState._categoryLabels.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _selectedCategory = value);
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            enabled: !_saving,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            cursorColor: _BusinessProductsPageState._goldColor,
            decoration: _inputDecoration('Product name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: !_saving,
            minLines: 3,
            maxLines: 5,
            maxLength: 700,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            cursorColor: _BusinessProductsPageState._goldColor,
            decoration: _inputDecoration('Description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            enabled: !_saving,
            maxLength: 40,
            keyboardType: TextInputType.text,
            style: const TextStyle(color: Colors.white),
            cursorColor: _BusinessProductsPageState._goldColor,
            decoration: _inputDecoration(
              'Price',
              hintText: 'Optional, example £39.99',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buyUrlController,
            enabled: !_saving,
            maxLength: 500,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white),
            cursorColor: _BusinessProductsPageState._goldColor,
            decoration: _inputDecoration(
              'Product link',
              hintText: 'Optional. Shown as a button inside the app.',
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _BusinessProductsPageState._goldColor,
            title: const Text(
              'Visible to customers',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Turn this off to save the product without showing it publicly.',
              style: TextStyle(color: _BusinessProductsPageState._softTextColor),
            ),
            value: _active,
            onChanged: _saving ? null : (value) => setState(() => _active = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _BusinessProductsPageState._goldColor,
            title: const Text(
              'Featured product',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Show this product near the top of your list.',
              style: TextStyle(color: _BusinessProductsPageState._softTextColor),
            ),
            value: _featured,
            onChanged:
                _saving ? null : (value) => setState(() => _featured = value),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _BusinessProductsPageState._goldColor,
              foregroundColor: _BusinessProductsPageState._backgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving
                  ? 'Saving...'
                  : existingProduct == null
                      ? 'Add product'
                      : 'Save product',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: _saving ? null : _saveProduct,
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
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final BusinessProduct product;
  final bool canManage;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl.trim();
    final price = product.price.trim();
    final description = product.description.trim();

    return Material(
      color: _BusinessProductsPageState._cardColor,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: product.featured
                  ? _BusinessProductsPageState._goldColor
                  : _BusinessProductsPageState._borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 98,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const _PostImageFallback(
                            icon: Icons.inventory_2_outlined,
                          );
                        },
                      )
                    : const _PostImageFallback(
                        icon: Icons.inventory_2_outlined,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            color: _BusinessProductsPageState._goldColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product.categoryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _BusinessProductsPageState._softTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (product.featured)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.star_rounded,
                                color: _BusinessProductsPageState._goldColor,
                                size: 16,
                              ),
                            ),
                          if (canManage)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                product.active
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: product.active
                                    ? _BusinessProductsPageState._successColor
                                    : _BusinessProductsPageState._softTextColor,
                                size: 15,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (price.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _BusinessProductsPageState._goldColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _BusinessProductsPageState._softTextColor,
                            fontSize: 11.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.touch_app_outlined,
                            color: _BusinessProductsPageState._goldColor,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Tap to view',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _BusinessProductsPageState._goldColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (canManage) ...[
                            _CompactCardAction(
                              icon: Icons.edit_outlined,
                              tooltip: 'Edit product',
                              color: Colors.white,
                              onPressed: onEdit,
                            ),
                            const SizedBox(width: 6),
                            _CompactCardAction(
                              icon: Icons.delete_outline,
                              tooltip: 'Delete product',
                              color: _BusinessProductsPageState._dangerColor,
                              onPressed: onDelete,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessProductDetailsPage extends StatelessWidget {
  const _BusinessProductDetailsPage({
    required this.product,
    required this.profile,
    required this.canManage,
    required this.onEdit,
  });

  final BusinessProduct product;
  final BusinessProfile profile;
  final bool canManage;
  final VoidCallback onEdit;

  String _productEnquirySubject() {
    final title = product.name.trim().isEmpty ? 'Product enquiry' : product.name.trim();
    return 'Product enquiry: $title';
  }

  String _productEnquiryMessage() {
    final businessName = profile.businessName.trim();
    final productName = product.name.trim().isEmpty ? 'this product' : product.name.trim();
    final price = product.price.trim();
    final description = product.description.trim();

    final lines = <String>[
      businessName.isEmpty ? 'Hi,' : 'Hi $businessName,',
      '',
      'I am interested in this product:',
      'Product: $productName',
      'Category: ${product.categoryLabel}',
      if (price.isNotEmpty) 'Price: $price',
      if (description.isNotEmpty) '',
      if (description.isNotEmpty) 'Product details: $description',
      '',
      'Please could you let me know if this is still available?',
    ];

    return lines.join('\n');
  }

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
    final title = product.name.trim().isEmpty ? 'Product details' : product.name.trim();
    final price = product.price.trim();
    final description = product.description.trim();
    final businessName = profile.businessName.trim();
    final buyUrl = product.buyUrl.trim();

    return Scaffold(
      backgroundColor: _BusinessProductsPageState._backgroundColor,
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: _BusinessProductsPageState._backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Edit product',
              onPressed: () {
                Navigator.of(context).pop();
                onEdit();
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _ProductImageHero(imageUrl: imageUrl),
          const SizedBox(height: 14),
          _ProductSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DetailBadge(
                      icon: Icons.category_outlined,
                      label: product.categoryLabel,
                    ),
                    if (product.featured)
                      const _DetailBadge(
                        icon: Icons.star_rounded,
                        label: 'Featured',
                      ),
                    if (canManage)
                      _DetailBadge(
                        icon: product.active
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        label: product.active ? 'Visible' : 'Hidden',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                if (businessName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    businessName,
                    style: const TextStyle(
                      color: _BusinessProductsPageState._softTextColor,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (price.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    price,
                    style: const TextStyle(
                      color: _BusinessProductsPageState._goldColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ProductSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProductSectionTitle(
                  icon: Icons.description_outlined,
                  title: 'Description',
                ),
                const SizedBox(height: 10),
                Text(
                  description.isEmpty
                      ? 'This business has not added any extra product details yet.'
                      : description,
                  style: const TextStyle(
                    color: _BusinessProductsPageState._softTextColor,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ProductSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProductSectionTitle(
                  icon: Icons.chat_bubble_outline,
                  title: 'Ask about this product',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Send the business a product enquiry without leaving PocketChase.',
                  style: TextStyle(
                    color: _BusinessProductsPageState._softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                BusinessEnquiryButton(
                  profile: profile,
                  buttonLabel: 'Message about this product',
                  initialEnquiryType: 'product',
                  initialSubject: _productEnquirySubject(),
                  initialMessage: _productEnquiryMessage(),
                ),
              ],
            ),
          ),
          if (buyUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ProductSectionCard(
              child: _ProductActionButton(
                icon: Icons.open_in_new,
                label: 'Open product website',
                onPressed: () => _openBuyLink(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductImageHero extends StatelessWidget {
  const _ProductImageHero({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: imageUrl.isEmpty ? 165 : 220,
      decoration: BoxDecoration(
        color: _BusinessProductsPageState._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _BusinessProductsPageState._borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const _ProductImageFallback();
              },
            )
          : const _ProductImageFallback(),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _BusinessProductsPageState._fieldColor,
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: _BusinessProductsPageState._goldColor,
          size: 52,
        ),
      ),
    );
  }
}

class _ProductSectionCard extends StatelessWidget {
  const _ProductSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BusinessProductsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessProductsPageState._borderColor),
      ),
      child: child,
    );
  }
}

class _ProductSectionTitle extends StatelessWidget {
  const _ProductSectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _BusinessProductsPageState._goldColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductActionButton extends StatelessWidget {
  const _ProductActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _BusinessProductsPageState._goldColor,
          side: const BorderSide(color: _BusinessProductsPageState._goldColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _BusinessProductsPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _BusinessProductsPageState._borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _BusinessProductsPageState._goldColor,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCardAction extends StatelessWidget {
  const _CompactCardAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: _BusinessProductsPageState._fieldColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _BusinessProductsPageState._borderColor),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}

class _SingleImagePickerCard extends StatelessWidget {
  const _SingleImagePickerCard({
    required this.existingImageUrl,
    required this.pickedImage,
    required this.removeImage,
    required this.enabled,
    required this.fallbackIcon,
    required this.onPickImage,
    required this.onClearImage,
  });

  final String existingImageUrl;
  final XFile? pickedImage;
  final bool removeImage;
  final bool enabled;
  final IconData fallbackIcon;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  bool get _hasImage {
    return pickedImage != null || (existingImageUrl.trim().isNotEmpty && !removeImage);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _BusinessProductsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessProductsPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            child: SizedBox(
              height: 190,
              child: _ImagePreview(
                existingImageUrl: existingImageUrl,
                pickedImage: pickedImage,
                removeImage: removeImage,
                fallbackIcon: fallbackIcon,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _BusinessProductsPageState._goldColor,
                    foregroundColor: _BusinessProductsPageState._backgroundColor,
                  ),
                  onPressed: enabled ? onPickImage : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_hasImage ? 'Change picture' : 'Choose picture'),
                ),
                if (_hasImage)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _BusinessProductsPageState._dangerColor,
                      side: const BorderSide(
                        color: _BusinessProductsPageState._dangerColor,
                      ),
                    ),
                    onPressed: enabled ? onClearImage : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.existingImageUrl,
    required this.pickedImage,
    required this.removeImage,
    required this.fallbackIcon,
  });

  final String existingImageUrl;
  final XFile? pickedImage;
  final bool removeImage;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final picked = pickedImage;
    if (picked != null) {
      return FutureBuilder<Uint8List>(
        future: picked.readAsBytes(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(
              child: CircularProgressIndicator(
                color: _BusinessProductsPageState._goldColor,
              ),
            );
          }
          return Image.memory(
            bytes,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        },
      );
    }

    if (existingImageUrl.trim().isNotEmpty && !removeImage) {
      return Image.network(
        existingImageUrl.trim(),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _PostImageFallback(icon: fallbackIcon);
        },
      );
    }

    return _PostImageFallback(icon: fallbackIcon);
  }
}

class _PostImageFallback extends StatelessWidget {
  const _PostImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _BusinessProductsPageState._fieldColor,
      ),
      child: Center(
        child: Icon(
          icon,
          color: _BusinessProductsPageState._goldColor,
          size: 48,
        ),
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BusinessProductsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessProductsPageState._borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _BusinessProductsPageState._goldColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _BusinessProductsPageState._softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _BusinessProductsPageState._goldColor, size: 50),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _BusinessProductsPageState._softTextColor,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
