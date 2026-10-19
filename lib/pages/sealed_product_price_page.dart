import 'package:flutter/material.dart';

import '../services/currency_settings.dart';
import '../services/sealed_collection_store.dart';
import '../services/sealed_product_catalog_service.dart';
import '../utils/ebay_sold_search.dart';
import 'sealed_collection_page.dart';

/// Catalogue-only sealed products. No marketplace pricing or seller photos.
class SealedProductPricePage extends StatefulWidget {
  const SealedProductPricePage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SealedProductPricePage> createState() =>
      _SealedProductPricePageState();
}

class _SealedProductPricePageState extends State<SealedProductPricePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  SealedProductType? _selectedType;
  List<SealedCatalogProduct> _products = const [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;
  int _requestVersion = 0;

  List<SealedProductType> get _alphabeticalProductTypes =>
      SealedProductType.values.toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _message('Enter the set or sealed product name.');
      _searchFocusNode.requestFocus();
      return;
    }
    if (_selectedType == null) {
      _message('Choose the sealed product type first.');
      return;
    }
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _hasSearched = true;
      _error = null;
    });
    try {
      final products = await SealedProductCatalogService.searchProducts(
        query: query,
        productType: _selectedType!.name,
      );
      if (!mounted || version != _requestVersion) return;
      final alphabeticalProducts = products.toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      setState(() => _products = alphabeticalProducts);
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _products = const [];
        _error = 'The sealed-product catalogue could not be loaded. '
            'Check the internet connection and try again.';
      });
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCollection() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SealedCollectionPage()),
    );
  }

  Future<void> _addToCollection(SealedCatalogProduct product) async {
    final proposed = SealedCollectionItem.fromAverageProduct(
      title: product.title,
      imageUrl: product.imageUrl,
      catalogueImageApproved: true,
      imageSource: 'approvedCatalog',
      productTypeLabel: product.productTypeLabel,
      currencyCode: CurrencySettings.selectedCode,
      averageMarketPrice: 0,
      productIdentityKey: product.identityKey,
    );
    final saved = await SealedCollectionStore.load();
    SealedCollectionItem? existing;
    for (final item in saved) {
      if (item.id == proposed.id) {
        existing = item;
        break;
      }
    }
    final updated = existing == null
        ? proposed
        : existing.copyWith(
            quantity: existing.quantity + 1,
            imageUrl: product.imageUrl,
            catalogueImageApproved: true,
            imageSource: 'approvedCatalog',
          );
    await SealedCollectionStore.upsert(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(existing == null
              ? 'Added to My Sealed Collection.'
              : 'Quantity updated to ${updated.quantity}.'),
          action: SnackBarAction(label: 'VIEW', onPressed: _openCollection),
        ),
      );
  }

  InputDecoration _fieldDecoration() => InputDecoration(
        filled: true,
        fillColor: const Color(0xFF071D42),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 44,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF315B92)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFF7DE77),
            width: 1.5,
          ),
        ),
      );

  Widget _productTypeSelector() => DropdownButtonFormField<SealedProductType?>(
        key: ValueKey<SealedProductType?>(_selectedType),
        initialValue: _selectedType,
        isExpanded: true,
        dropdownColor: const Color(0xFF102754),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFFB2C9EB),
        ),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        decoration: _fieldDecoration().copyWith(
          prefixIcon: const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xFFF7DE77),
            size: 19,
          ),
        ),
        items: <DropdownMenuItem<SealedProductType?>>[
          const DropdownMenuItem(
            value: null,
            child: Text('Choose type'),
          ),
          ..._alphabeticalProductTypes.map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(type.label, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: _loading
            ? null
            : (value) {
                setState(() {
                  _selectedType = value;
                  _hasSearched = false;
                  _products = const [];
                });
              },
      );

  Widget _searchProductsButton({bool compact = false}) => SizedBox(
        height: 47,
        width: compact ? 108 : double.infinity,
        child: FilledButton.icon(
          onPressed: _loading ? null : _loadProducts,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded, size: 19),
          label: Text(
            _loading ? 'Wait...' : (compact ? 'Search' : 'Search products'),
            maxLines: 1,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF7DE77),
            foregroundColor: const Color(0xFF081D3F),
            disabledBackgroundColor: const Color(0xFF947D3D),
            disabledForegroundColor: const Color(0xFF081D3F),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );

  Widget _searchPanel() => Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123B70), Color(0xFF0B2857)],
          ),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFF326DA7), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Find sealed products',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _openCollection,
                  icon: const Icon(Icons.inventory_2_outlined, size: 17),
                  label: const Text('My collection'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF7DE77),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadProducts(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _fieldDecoration().copyWith(
                hintText: 'Search a set or product',
                hintStyle: const TextStyle(color: Color(0xFFADBEDC)),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFF7DE77),
                  size: 21,
                ),
              ),
            ),
            const SizedBox(height: 11),
            const Padding(
              padding: EdgeInsets.only(left: 3, bottom: 6),
              child: Text(
                'PRODUCT TYPE',
                style: TextStyle(
                  color: Color(0xFFB9CEEA),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 307) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _productTypeSelector(),
                      const SizedBox(height: 9),
                      _searchProductsButton(),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: _productTypeSelector()),
                    const SizedBox(width: 9),
                    _searchProductsButton(compact: true),
                  ],
                );
              },
            ),
          ],
        ),
      );

  Widget _productTile(SealedCatalogProduct product) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF102754),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: 90,
                  height: 106,
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFFF7DE77),
                      size: 38,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.productTypeLabel,
                    style: const TextStyle(
                      color: Color(0xFFF7DE77),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    height: 35,
                    child: FilledButton.icon(
                      onPressed: () => _addToCollection(product),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add to collection',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7DE77),
                        foregroundColor: Colors.black,
                        textStyle:
                            const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _status() {
    if (_error != null) return Text(_error!, textAlign: TextAlign.center);
    if (!_hasSearched) return const SizedBox.shrink();
    if (!_loading && _products.isEmpty) {
      return const Text(
        'No matching real product was found for this set and product type.',
        textAlign: TextAlign.center,
      );
    }
    return const SizedBox.shrink();
  }

  /// Exact Sealed illustration from the approved mockup. No extra Flutter
  /// backgrounds are drawn over it, so the Poké Ball stays authentic.
  Widget _emptyStateBadgeShowcase() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 280,
          child: Image.asset(
            'assets/images/pc_hero_sealed.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.inventory_2_outlined,
                size: 106,
                color: Color(0xFFF7DE77),
              ),
            ),
          ),
        ),
      );

  Widget _body() => RefreshIndicator(
        onRefresh: _loadProducts,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _searchPanel()),
            if (!_hasSearched && !_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyStateBadgeShowcase(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Color(0xFFC8D4F0)),
                    child: Column(
                      children: [
                        _status(),
                        ..._products.map(_productTile),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Sealed Products'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: body),
    );
  }
}
