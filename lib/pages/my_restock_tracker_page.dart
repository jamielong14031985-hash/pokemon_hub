import 'package:flutter/material.dart';

import '../services/tracked_restock_product_service.dart';
import '../widgets/glass_page_header.dart';

class MyRestockTrackerPage extends StatelessWidget {
  const MyRestockTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: const GlassPageAppBar(
        title: 'My Restock Tracker',
        subtitle: 'Track products you care about',
        icon: Icons.notifications_active_outlined,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context),
        backgroundColor: const Color(0xFFF7DE77),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Add product'),
      ),
      body: StreamBuilder<List<TrackedRestockProduct>>(
        stream: TrackedRestockProductService.watchCurrentUserTrackedProducts(),
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
      ),
    );
  }

  static Future<void> _showProductDialog(
    BuildContext context, {
    TrackedRestockProduct? product,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _MyTrackedProductDialog(product: product),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFFF7DE77),
              size: 30,
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Add products you want PocketChase to watch. '
                'When one changes from out of stock to in stock, you will get a push notification.',
                style: TextStyle(
                  color: Color(0xFFD8E3FB),
                  height: 1.35,
                ),
              ),
            ),
          ],
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
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: Colors.white60,
              size: 54,
            ),
            SizedBox(height: 14),
            Text(
              'No products tracked yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Press Add product to track a shop page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFC8D4F0), height: 1.35),
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
    final statusColor =
        product.inStock ? const Color(0xFF54D39A) : const Color(0xFFFFB3C7);

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
                product.enabled ? Icons.link_rounded : Icons.link_off_rounded,
                color: product.enabled ? const Color(0xFFF7DE77) : Colors.white54,
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
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.shopName,
                      style: const TextStyle(color: Color(0xFFD8E3FB)),
                    ),
                    if (product.region.trim().isNotEmpty ||
                        product.storeName.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (product.region.trim().isNotEmpty) product.region,
                          if (product.storeName.trim().isNotEmpty) product.storeName,
                        ].join(' • '),
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      checkedText.isEmpty ? 'Not checked yet' : 'Last checked: $checkedText',
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
                        fontWeight: FontWeight.w900,
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
                      await TrackedRestockProductService
                          .setCurrentUserTrackedProductEnabled(
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
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFFF7DE77)),
                  onPressed: () => MyRestockTrackerPage._showProductDialog(
                    context,
                    product: product,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFFFB3C7)),
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

  static Future<void> _confirmDelete(BuildContext context, String productId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102754),
          title: const Text(
            'Delete tracked product?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'PocketChase will stop watching this product for you.',
            style: TextStyle(color: Color(0xFFD8E3FB)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB13B59),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await TrackedRestockProductService.deleteCurrentUserTrackedProduct(productId);
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(context, error.toString());
    }
  }
}

class _MyTrackedProductDialog extends StatefulWidget {
  const _MyTrackedProductDialog({
    this.product,
  });

  final TrackedRestockProduct? product;

  @override
  State<_MyTrackedProductDialog> createState() => _MyTrackedProductDialogState();
}

class _MyTrackedProductDialogState extends State<_MyTrackedProductDialog> {
  final TextEditingController _shopController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
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

  static const List<String> _shopOptions = <String>[
    'Smyths',
    'GAME',
    'Pokémon Center UK',
    'Amazon UK',
    'Argos',
    'Very',
    'Magic Madhouse',
    'Total Cards',
    'Chaos Cards',
    'Zavvi',
  ];

  static const List<String> _regionOptions = <String>[
    'All regions',
    'North West England',
    'North East England',
    'Yorkshire and the Humber',
    'West Midlands',
    'East Midlands',
    'East of England',
    'South East England',
    'South West England',
    'London',
    'Scotland',
    'Wales',
    'Northern Ireland',
  ];

  static const Map<String, List<String>> _storesByRegion = <String, List<String>>{
    'North West England': <String>[
      'All stores',
      'Manchester',
      'Stockport',
      'Bolton',
      'Preston',
      'Liverpool',
      'Warrington',
      'Blackpool',
      'Wigan',
      'Oldham',
      'Bury',
      'Birkenhead',
      'Chester',
    ],
    'North East England': <String>[
      'All stores',
      'Newcastle',
      'Gateshead',
      'Sunderland',
      'Middlesbrough',
    ],
    'Yorkshire and the Humber': <String>[
      'All stores',
      'Leeds',
      'Sheffield',
      'Bradford',
      'Hull',
      'York',
    ],
    'West Midlands': <String>[
      'All stores',
      'Birmingham',
      'Wolverhampton',
      'Coventry',
      'Walsall',
    ],
    'East Midlands': <String>[
      'All stores',
      'Nottingham',
      'Derby',
      'Leicester',
      'Lincoln',
    ],
    'East of England': <String>[
      'All stores',
      'Norwich',
      'Cambridge',
      'Peterborough',
      'Ipswich',
    ],
    'South East England': <String>[
      'All stores',
      'Reading',
      'Milton Keynes',
      'Oxford',
      'Southampton',
      'Portsmouth',
    ],
    'South West England': <String>[
      'All stores',
      'Bristol',
      'Plymouth',
      'Exeter',
      'Swindon',
    ],
    'London': <String>[
      'All stores',
      'London',
      'Croydon',
      'Enfield',
      'Romford',
    ],
    'Scotland': <String>[
      'All stores',
      'Glasgow',
      'Edinburgh',
      'Aberdeen',
      'Dundee',
    ],
    'Wales': <String>[
      'All stores',
      'Cardiff',
      'Swansea',
      'Newport',
      'Wrexham',
    ],
    'Northern Ireland': <String>[
      'All stores',
      'Belfast',
      'Derry/Londonderry',
    ],
  };

  @override
  void initState() {
    super.initState();

    final product = widget.product;
    if (product == null) return;

    _shopController.text = product.shopName;
    _regionController.text = _normalisedRegionValue(product.region);
    _storeNameController.text =
        product.storeName.trim().isEmpty ? 'All stores' : product.storeName;
    _storeAddressController.text = product.storeAddress;
    _productController.text = product.productName;
    _urlController.text = product.productUrl;
    _imageUrlController.text = product.imageUrl;
    _notesController.text = product.notes;
    _inKeywordsController.text = product.inStockKeywords.join(', ');
    _outKeywordsController.text = product.outOfStockKeywords.join(', ');
  }

  @override
  void dispose() {
    _shopController.dispose();
    _regionController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
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
      title: Text(widget.product == null ? 'Add tracked product' : 'Edit tracked product'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dropdownField(
                controller: _shopController,
                label: 'Shop name',
                hint: 'Choose a shop',
                options: _optionsWithCurrentValue(_shopOptions, _shopController.text),
              ),
              const SizedBox(height: 12),
              _dropdownField(
                controller: _regionController,
                label: 'Region',
                hint: 'Choose a region',
                options: _optionsWithCurrentValue(
                  _regionOptions,
                  _normalisedRegionValue(_regionController.text),
                ),
                onChanged: (_) {
                  final stores = _storeOptionsForCurrentRegion();
                  _storeNameController.text =
                      stores.contains(_storeNameController.text)
                          ? _storeNameController.text
                          : stores.first;
                },
              ),
              const SizedBox(height: 12),
              _dropdownField(
                controller: _storeNameController,
                label: 'Store / location',
                hint: 'Choose a store',
                options: _storeOptionsForCurrentRegion(),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _storeAddressController,
                label: 'Store address / postcode',
                hint: 'Optional',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _productController,
                label: 'Product name',
                hint: 'Example: Ascended Heroes Booster Bundle',
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

  Widget _dropdownField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> options,
    ValueChanged<String?>? onChanged,
  }) {
    final cleanOptions = _optionsWithCurrentValue(options, controller.text);
    final currentValue = controller.text.trim();
    final selectedValue = cleanOptions.any(
      (option) => option.toLowerCase() == currentValue.toLowerCase(),
    )
        ? cleanOptions.firstWhere(
            (option) => option.toLowerCase() == currentValue.toLowerCase(),
          )
        : null;

    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      isExpanded: true,
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      items: cleanOptions
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) return;

              setState(() {
                controller.text = value == 'All regions' || value == 'All stores'
                    ? ''
                    : value;
                onChanged?.call(value);
              });
            },
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
      final existingProduct = widget.product;

      if (existingProduct == null) {
        await TrackedRestockProductService.createCurrentUserTrackedProduct(
          shopName: _shopController.text,
          region: _saveableRegionValue(),
          storeName: _saveableStoreValue(),
          storeAddress: _storeAddressController.text,
          productName: _productController.text,
          productUrl: _urlController.text,
          imageUrl: _imageUrlController.text,
          notes: _notesController.text,
          inStockKeywords: _splitKeywords(_inKeywordsController.text),
          outOfStockKeywords: _splitKeywords(_outKeywordsController.text),
        );
      } else {
        await TrackedRestockProductService.updateCurrentUserTrackedProduct(
          productId: existingProduct.id,
          shopName: _shopController.text,
          region: _saveableRegionValue(),
          storeName: _saveableStoreValue(),
          storeAddress: _storeAddressController.text,
          productName: _productController.text,
          productUrl: _urlController.text,
          imageUrl: _imageUrlController.text,
          notes: _notesController.text,
          inStockKeywords: _splitKeywords(_inKeywordsController.text),
          outOfStockKeywords: _splitKeywords(_outKeywordsController.text),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(context, error.toString());
      setState(() => _isSaving = false);
    }
  }

  String _saveableRegionValue() {
    final value = _normalisedRegionValue(_regionController.text);
    return value == 'All regions' ? '' : value;
  }

  String _saveableStoreValue() {
    final value = _storeNameController.text.trim();
    return value == 'All stores' ? '' : value;
  }

  List<String> _splitKeywords(String value) {
    return value
        .split(',')
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toList();
  }

  List<String> _optionsWithCurrentValue(
    List<String> options,
    String currentValue,
  ) {
    final cleanCurrentValue = currentValue.trim();
    final values = <String>[
      ...options,
      if (cleanCurrentValue.isNotEmpty &&
          !options.any(
            (option) => option.toLowerCase() == cleanCurrentValue.toLowerCase(),
          ))
        cleanCurrentValue,
    ];

    final seen = <String>{};
    final cleaned = <String>[];

    for (final value in values) {
      final cleanValue = value.trim();
      final lookupValue = cleanValue.toLowerCase();

      if (cleanValue.isEmpty || seen.contains(lookupValue)) continue;

      seen.add(lookupValue);
      cleaned.add(cleanValue);
    }

    return cleaned;
  }

  List<String> _storeOptionsForCurrentRegion() {
    final region = _normalisedRegionValue(_regionController.text);
    final stores = _storesByRegion[region] ?? const <String>['All stores'];

    return _optionsWithCurrentValue(stores, _storeNameController.text);
  }

  String _normalisedRegionValue(String value) {
    final cleanValue = value.trim();

    if (cleanValue.isEmpty) return 'All regions';

    if (cleanValue.toLowerCase() == 'northwest') {
      return 'North West England';
    }

    return cleanValue;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Could not load your tracked products.\n\n$error',
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
