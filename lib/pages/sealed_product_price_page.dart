import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/currency_settings.dart';
import '../services/sealed_product_price_service.dart';
import '../utils/ebay_sold_search.dart';

class SealedProductPricePage extends StatefulWidget {
  const SealedProductPricePage({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<SealedProductPricePage> createState() =>
      _SealedProductPricePageState();
}

class _SealedProductPricePageState extends State<SealedProductPricePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  SealedProductType? _selectedType;
  List<SealedProductListing> _listings = const <SealedProductListing>[];
  bool _loading = false;
  String? _errorMessage;
  int? _lastUpdatedMs;
  bool _resultsFromCache = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadListings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String get _selectedTypeKey {
    switch (_selectedType) {
      case SealedProductType.boosterBox:
        return 'boosterBox';
      case SealedProductType.eliteTrainerBox:
        return 'eliteTrainerBox';
      case SealedProductType.boosterBundle:
        return 'boosterBundle';
      case SealedProductType.ultraPremiumCollection:
        return 'ultraPremiumCollection';
      case null:
        return 'all';
    }
  }

  Future<void> _loadListings() async {
    final requestVersion = ++_requestVersion;
    final marketplaceCode = CurrencySettings.selectedMarketplaceCode;
    final query = _searchController.text.trim();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await SealedProductPriceService.lookupCurrentListings(
        marketplaceCode: marketplaceCode,
        query: query,
        productType: _selectedTypeKey,
      );

      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _listings = result.items;
        _lastUpdatedMs = result.lastUpdatedMs;
        _resultsFromCache = result.cached;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _errorMessage = SealedProductPriceService.friendlyErrorMessage(error);
      });
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openListing(SealedProductListing listing) async {
    final rawUrl = listing.listingUrl.trim();
    if (rawUrl.isEmpty) {
      _showMessage('This eBay listing link is unavailable.');
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      _showMessage('This eBay listing link is unavailable.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Could not open this eBay listing.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatUpdatedAt() {
    final milliseconds = _lastUpdatedMs;
    if (milliseconds == null || milliseconds <= 0) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  Widget _buildTypeChip({
    required String label,
    required SealedProductType? type,
  }) {
    final selected = _selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _loading
          ? null
          : (_) {
              setState(() {
                _selectedType = type;
              });
              _loadListings();
            },
      selectedColor: const Color(0xFFF7DE77),
      backgroundColor: const Color(0xFF16366E),
      side: BorderSide(
        color: selected
            ? const Color(0xFFF7DE77)
            : Colors.white.withValues(alpha: 0.14),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final marketplace = CurrencySettings.selectedMarketplace;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7DE77),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '10 sealed products for sale',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Current Booster Boxes, Bundles, ETBs and UPCs on eBay.',
                      style: TextStyle(
                        color: Color(0xFFD8E3FB),
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadListings(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search a set, for example Surging Sparks',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFF7DE77),
              ),
              suffixIcon: IconButton(
                tooltip: 'Search sealed products',
                onPressed: _loading ? null : _loadListings,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFFF7DE77),
                      ),
              ),
              filled: true,
              fillColor: const Color(0xFF071B3F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFF7DE77),
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Product type',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeChip(label: 'All', type: null),
                const SizedBox(width: 8),
                _buildTypeChip(
                  label: SealedProductType.boosterBox.label,
                  type: SealedProductType.boosterBox,
                ),
                const SizedBox(width: 8),
                _buildTypeChip(
                  label: SealedProductType.eliteTrainerBox.shortLabel,
                  type: SealedProductType.eliteTrainerBox,
                ),
                const SizedBox(width: 8),
                _buildTypeChip(
                  label: SealedProductType.boosterBundle.shortLabel,
                  type: SealedProductType.boosterBundle,
                ),
                const SizedBox(width: 8),
                _buildTypeChip(
                  label: SealedProductType.ultraPremiumCollection.shortLabel,
                  type: SealedProductType.ultraPremiumCollection,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.public_rounded,
                color: Color(0xFFF7DE77),
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Showing current listings from ${marketplace.label}.',
                  style: const TextStyle(
                    color: Color(0xFFD8E3FB),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh listings',
                onPressed: _loading ? null : _loadListings,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFF7DE77),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    if (_loading && _listings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
        child: Center(
          child: Column(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 10),
              Text(
                'Loading products for sale...',
                style: TextStyle(
                  color: Color(0xFFD8E3FB),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF5B1D28),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadListings,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_listings.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF102754),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Color(0xFFF7DE77),
              size: 38,
            ),
            SizedBox(height: 10),
            Text(
              'No matching products found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Try another set name or product-type filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFC8D4F0), height: 1.3),
            ),
          ],
        ),
      );
    }

    final updatedAt = _formatUpdatedAt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          if (_loading)
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(
              Icons.local_offer_outlined,
              color: Color(0xFFF7DE77),
              size: 17,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_listings.length} ${_listings.length == 1 ? 'listing' : 'listings'}'
              '${updatedAt.isEmpty ? '' : ' • updated $updatedAt'}'
              '${_resultsFromCache ? ' • cached' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD8E3FB),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingTile(SealedProductListing listing) {
    final currency = listing.currencyCode.isEmpty
        ? CurrencySettings.selectedCode
        : listing.currencyCode;
    final priceText = CurrencySettings.formatAmount(
      listing.priceAmount,
      fromCurrency: currency,
    );
    final listingDateText = listing.listingDateText.isEmpty
        ? 'Available now'
        : 'Listed ${listing.listingDateText}';
    final shippingText = listing.hasShippingCost
        ? ' + ${CurrencySettings.formatAmount(listing.shippingAmount, fromCurrency: currency)} shipping'
        : ' + shipping not shown';

    return Material(
      color: const Color(0xFF102754),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openListing(listing),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 118,
                height: 142,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF071B3F),
                    child: listing.imageUrl.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFFF7DE77),
                              size: 38,
                            ),
                          )
                        : Image.network(
                            listing.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFFF7DE77),
                                size: 36,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      listing.productTypeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF7DE77),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      priceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listingDateText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF7DE77),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shippingText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC8D4F0),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () => _openListing(listing),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Open eBay'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingsBody() {
    return RefreshIndicator(
      onRefresh: _loadListings,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(child: _buildSearchAndFilters()),
          SliverToBoxAdapter(child: _buildStatusRow()),
          if (_listings.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _listings.length - 1 ? 0 : 12,
                    ),
                    child: _buildListingTile(_listings[index]),
                  ),
                  childCount: _listings.length,
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildListingsBody();

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Sealed Prices'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: body),
    );
  }
}
