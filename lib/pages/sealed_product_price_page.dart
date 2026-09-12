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
  SealedProductListing? _listing;
  bool _loading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  int? _lastUpdatedMs;
  bool _resultsFromCache = false;
  int _requestVersion = 0;

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

  Future<void> _loadListing() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _hasSearched = false;
        _listing = null;
        _errorMessage = null;
        _lastUpdatedMs = null;
        _resultsFromCache = false;
      });
      _searchFocusNode.requestFocus();
      return;
    }

    final requestVersion = ++_requestVersion;
    final marketplaceCode = CurrencySettings.selectedMarketplaceCode;

    setState(() {
      _hasSearched = true;
      _loading = true;
      _listing = null;
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
        // The Cloud Function already removes non-sealed components and sorts
        // matching listings. PocketChase presents just the first best match.
        _listing = result.items.isEmpty ? null : result.items.first;
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
    final uri = Uri.tryParse(rawUrl);
    if (rawUrl.isEmpty || uri == null) {
      _showMessage('This eBay search link is unavailable.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Could not open eBay search.');
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
              if (_hasSearched) {
                _loadListing();
              }
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
                      'Find a sealed product',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'A clean product card with a live eBay price.',
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
            onSubmitted: (_) => _loadListing(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Example: Charizard UPC',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFF7DE77),
              ),
              suffixIcon: IconButton(
                tooltip: 'Search sealed products',
                onPressed: _loading ? null : _loadListing,
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
                  label: SealedProductType.boosterBox.shortLabel,
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
                  'Catalogue image with a live price from ${marketplace.label}.',
                  style: const TextStyle(
                    color: Color(0xFFD8E3FB),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh result',
                onPressed: _loading || !_hasSearched ? null : _loadListing,
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

  Widget _buildIntroCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_rounded,
            color: Color(0xFFF7DE77),
            size: 42,
          ),
          SizedBox(height: 12),
          Text(
            'Search the sealed product catalogue',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try “Charizard UPC”, “Prismatic Evolutions ETB” or “Surging Sparks Booster Box”. You will see one clean product card, not a seller listing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFC8D4F0),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(height: 12),
            Text(
              'Finding the product and checking its live price...',
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

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF5B1D28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _errorMessage ?? 'Could not load this product.',
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading ? null : _loadListing,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(22),
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
            size: 40,
          ),
          SizedBox(height: 10),
          Text(
            'No matching sealed product found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Use the full product name and choose a product type to narrow it down.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFC8D4F0),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedListingCard(SealedProductListing listing) {
    final currency = listing.currencyCode.isEmpty
        ? CurrencySettings.selectedCode
        : listing.currencyCode;
    final currentPrice = CurrencySettings.formatAmount(
      listing.priceAmount,
      fromCurrency: currency,
    );
    final updatedAt = _formatUpdatedAt();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF7DE77).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFF7DE77).withValues(alpha: 0.32),
                    ),
                  ),
                  child: Text(
                    listing.productTypeLabel,
                    style: const TextStyle(
                      color: Color(0xFFF7DE77),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFFF7DE77),
                  size: 21,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 218,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: listing.imageUrl.isEmpty
                    ? const _CatalogueImageUnavailable()
                    : Image.network(
                        listing.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const _CatalogueImageUnavailable(),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              listing.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                height: 1.18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Current lowest eBay price',
              style: TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              currentPrice,
              style: const TextStyle(
                color: Color(0xFFF7DE77),
                fontSize: 31,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Calculated from current matching sealed listings on eBay.',
              style: TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openListing(listing),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('View on eBay'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF7DE77),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (updatedAt.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '${_resultsFromCache ? 'Last checked' : 'Price checked'} $updatedAt',
                style: const TextStyle(
                  color: Color(0xFFAFC0E6),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }



  Widget _buildResultArea() {
    if (!_hasSearched) return _buildIntroCard();
    if (_loading) return _buildLoadingCard();
    if (_errorMessage != null) return _buildErrorCard();
    if (_listing == null) return _buildNoResultCard();
    return _buildSelectedListingCard(_listing!);
  }

  Widget _buildListingsBody() {
    return RefreshIndicator(
      onRefresh: _hasSearched ? _loadListing : () async {},
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildSearchAndFilters()),
          SliverToBoxAdapter(child: _buildResultArea()),
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


class _CatalogueImageUnavailable extends StatelessWidget {
  const _CatalogueImageUnavailable();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF8FAFF),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF16366E),
              size: 52,
            ),
            SizedBox(height: 10),
            Text(
              'Catalogue image coming soon',
              style: TextStyle(
                color: Color(0xFF16366E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
