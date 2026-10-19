import 'package:flutter/material.dart';

import '../services/sealed_collection_store.dart';
import '../services/sealed_expansion_matcher.dart';
import '../services/sealed_product_price_service.dart';

/// A dedicated valuation view for products the collector owns from one set.
///
/// The legacy `marketPrice` field is never used: it is not verified
/// UK completed-sales data. Incomplete set totals are labelled subtotals.
class SealedSetValuationPage extends StatefulWidget {
  const SealedSetValuationPage({
    super.key,
    required this.expansionName,
    this.logoUrl,
    this.displayName,
    this.displaySubtitle,
    this.seriesNumber,
    this.selectForDeal = false,
  });

  final String expansionName;
  final String? logoUrl;
  final String? displayName;
  final String? displaySubtitle;
  final int? seriesNumber;
  /// Offer selection from the real sealed set page back to Deal Builder.
  final bool selectForDeal;

  @override
  State<SealedSetValuationPage> createState() =>
      _SealedSetValuationPageState();
}

class _SealedSetValuationPageState extends State<SealedSetValuationPage> {
  static const Color _background = Color(0xFF041B4A);
  static const Color _panel = Color(0xFF102754);
  static const Color _dark = Color(0xFF071B3F);
  static const Color _gold = Color(0xFFF7DE77);
  static const Color _muted = Color(0xFFC8D4F0);

  bool _loading = true;
  List<SealedCollectionItem> _products = <SealedCollectionItem>[];
  final Set<String> _updating = <String>{};
  bool _checkingSold = false;
  int _soldChecked = 0;
  int _soldToCheck = 0;
  final Map<String, String> _soldErrors = <String, String>{};

  Future<void> _checkSetSoldPrices() async {
    if (_checkingSold) return;
    final pending = _products.where((item) =>
        SealedProductPriceService.cachedUkSoldPrice(item) == null &&
        !_soldErrors.containsKey(item.id)).take(10).toList();
    if (pending.isEmpty) return;
    setState(() {
      _checkingSold = true;
      _soldChecked = 0;
      _soldToCheck = pending.length;
    });
    for (final item in pending) {
      if (!mounted) break;
      try {
        await SealedProductPriceService.lookupUkSoldPrice(item);
        _soldErrors.remove(item.id);
      } catch (error) {
        _soldErrors[item.id] = SealedProductPriceService.ukSoldError(error);
        final message = _soldErrors[item.id]!.toLowerCase();
        if (message.contains('limit') || message.contains('configuration') ||
            message.contains('temporarily unavailable') || message.contains('sign in')) {
          break;
        }
      }
      if (mounted) setState(() => _soldChecked++);
    }
    if (mounted) setState(() => _checkingSold = false);
  }

  Future<void> _recheckProduct(SealedCollectionItem item) async {
    if (_checkingSold) return;
    setState(() => _checkingSold = true);
    try {
      await SealedProductPriceService.lookupUkSoldPrice(item, refresh: true);
      _soldErrors.remove(item.id);
    } catch (error) {
      _soldErrors[item.id] = SealedProductPriceService.ukSoldError(error);
    } finally {
      if (mounted) setState(() => _checkingSold = false);
    }
  }

  Widget _soldLookupButton() {
    final pending = _products.where((item) =>
        SealedProductPriceService.cachedUkSoldPrice(item) == null &&
        !_soldErrors.containsKey(item.id)).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(children: [
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _checkingSold || pending == 0 ? null : _checkSetSoldPrices,
          icon: _checkingSold
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.price_check_rounded),
          label: Text(_checkingSold
              ? 'Checking UK sales $_soldChecked/$_soldToCheck'
              : pending == 0
                  ? 'No unchecked set products'
                  : 'Check next ${pending < 10 ? pending : 10} UK sold prices'),
        )),
        const Text('Sold prices in GBP, excluding postage. Each lookup may use CompsAPI credits.',
          style: TextStyle(color: _muted, fontSize: 10.5)),
      ]),
    );
  }


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await SealedCollectionStore.load();
    await SealedProductPriceService.loadSavedUkSoldPrices();
    final name = widget.expansionName.trim().toLowerCase();
    final filtered = all.where((item) {
      if (item.expansionName.trim().toLowerCase() != name) return false;
      if (widget.seriesNumber == null) return true;
      return SealedExpansionMatcher.firstPartnerSeriesNumber(item.title) ==
          widget.seriesNumber;
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _products = filtered;
      _loading = false;
    });
  }

  Future<void> _changeQuantity(SealedCollectionItem item, int delta) async {
    if (_updating.contains(item.id)) return;
    final next = (item.quantity + delta).clamp(1, 9999).toInt();
    if (next == item.quantity) return;
    setState(() => _updating.add(item.id));
    try {
      await SealedCollectionStore.upsert(item.copyWith(quantity: next));
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update quantity. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(item.id));
    }
  }

  Future<void> _chooseQuantity(SealedCollectionItem item) async {
    if (_updating.contains(item.id)) return;
    final controller = TextEditingController(text: '${item.quantity}');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(
            dialogContext, int.tryParse(controller.text.trim())),
            child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (result == null || result < 1 || result > 9999 || result == item.quantity) return;
    setState(() => _updating.add(item.id));
    try {
      await SealedCollectionStore.upsert(item.copyWith(quantity: result));
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update quantity.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(item.id));
    }
  }

  Future<void> _editDetails(SealedCollectionItem item) async {
    final setController = TextEditingController(text: item.expansionName);
    final conditionController = TextEditingController(text: item.condition);
    final notesController = TextEditingController(text: item.notes);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sealed product details'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.title),
            const SizedBox(height: 12),
            TextField(controller: setController, decoration: const InputDecoration(
              labelText: 'Pokémon expansion')),
            TextField(controller: conditionController, decoration: const InputDecoration(
              labelText: 'Condition')),
            TextField(controller: notesController, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes')),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) {
      setController.dispose();
      conditionController.dispose();
      notesController.dispose();
      return;
    }
    if (save == true) {
      try {
        await SealedCollectionStore.upsert(item.copyWith(
          expansionName: setController.text.trim(),
          condition: conditionController.text.trim(),
          notes: notesController.text.trim(),
        ));
        await _load();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save product details.')),
          );
        }
      }
    }
    setController.dispose();
    conditionController.dispose();
    notesController.dispose();
  }

  Future<void> _remove(SealedCollectionItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove sealed product?'),
        content: Text(item.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove')),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    try {
      await SealedCollectionStore.remove(item.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove product.')),
        );
      }
    }
  }

  Widget _productActions(SealedCollectionItem item) {
    final busy = _updating.contains(item.id);
    return Row(children: [
      Container(
        decoration: BoxDecoration(color: _dark,
          borderRadius: BorderRadius.circular(100)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Reduce quantity',
            onPressed: busy || item.quantity <= 1
                ? null : () => _changeQuantity(item, -1),
            icon: const Icon(Icons.remove_rounded, size: 18),
            color: Colors.white, visualDensity: VisualDensity.compact),
          InkWell(onTap: busy ? null : () => _chooseQuantity(item),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text('${item.quantity}',
                style: const TextStyle(color: _gold, fontSize: 15,
                  fontWeight: FontWeight.bold)))),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: busy ? null : () => _changeQuantity(item, 1),
            icon: const Icon(Icons.add_rounded, size: 18),
            color: Colors.white, visualDensity: VisualDensity.compact),
        ]),
      ),
      const Spacer(),
      IconButton(tooltip: 'Edit product', onPressed: () => _editDetails(item),
        icon: const Icon(Icons.edit_outlined), color: _gold),
      IconButton(tooltip: 'Remove product', onPressed: () => _remove(item),
        icon: const Icon(Icons.delete_outline_rounded),
        color: const Color(0xFFFF8A9A)),
    ]);
  }

  int get _quantity =>
      _products.fold<int>(0, (sum, item) => sum + item.quantity);

  String get _headerTitle => widget.displayName?.trim().isNotEmpty == true
      ? widget.displayName!.trim()
      : (widget.expansionName.isEmpty ? 'Unassigned set' : widget.expansionName);

  String? get _headerSubtitle {
    if (widget.displaySubtitle?.trim().isNotEmpty == true) {
      final fullRegions = _products.isNotEmpty
          ? SealedExpansionMatcher.firstPartnerRegionGroup(_products.first.title)
          : null;
      if (fullRegions != null && widget.seriesNumber != null) {
        return 'Series ${widget.seriesNumber} — $fullRegions';
      }
      return widget.displaySubtitle!.trim();
    }
    return null;
  }

  String? _firstPartnerAssetPath() {
    switch (widget.seriesNumber) {
      case 1:
        return 'assets/images/first_partner_series_1.png';
      case 2:
        return 'assets/images/first_partner_series_2.png';
      case 3:
        return 'assets/images/first_partner_series_3.png';
      default:
        return null;
    }
  }

  Widget _firstPartnerHeaderArtwork() {
    final assetPath = _firstPartnerAssetPath();
    if (assetPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          assetPath,
          height: 75,
          width: 106,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('First Partner header logo load failed ($assetPath): $error');
            return Container(
              height: 75,
              width: 106,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _dark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('First Partner — Series ${widget.seriesNumber}',
                style: const TextStyle(color: _gold,
                  fontWeight: FontWeight.bold, fontSize: 16)),
            );
          },
        ),
      );
    }
    final primary = _products.isNotEmpty
        ? (SealedExpansionMatcher.firstPartnerPrimaryRegion(_products.first.title) ??
            'Series ${widget.seriesNumber ?? ''}')
        : 'Series ${widget.seriesNumber ?? ''}';
    return Container(
      height: 90,
      width: 230,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0A2B68), Color(0xFF071B3F)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Pokémon',
              style: TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          const Text('First Partner Collection 2026',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(primary,
              style: const TextStyle(color: _gold, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // A bundled image is useful for newer sets that the online set-logo
  // catalogue does not yet recognise. The set list uses this same asset.
  String? _bundledSetLogoAsset() {
    final normalized = widget.expansionName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (normalized == 'delta reign' ||
        normalized == 'mega evolution delta reign') {
      return 'assets/images/delta_reign_logo.png';
    }
    return null;
  }

  // A short, single-panel set summary: artwork, title and totals share one
  // compact area so the collector can reach their products sooner.
  Widget _overview() {
    final isFirstPartner = widget.seriesNumber != null;
    final localLogoAsset = _bundledSetLogoAsset();
    final hasArt = isFirstPartner || localLogoAsset != null ||
        widget.logoUrl?.trim().isNotEmpty == true;

    Widget? logo;
    if (isFirstPartner) {
      logo = _firstPartnerHeaderArtwork();
    } else if (localLogoAsset != null) {
      logo = Image.asset(
        localLogoAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Delta Reign detail logo failed ($localLogoAsset): $error');
          return const Icon(Icons.inventory_2_outlined,
              color: _gold, size: 30);
        },
      );
    } else if (widget.logoUrl?.trim().isNotEmpty == true) {
      logo = Image.network(
        widget.logoUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.inventory_2_outlined, color: _gold, size: 30),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (hasArt) ...[
            SizedBox(
              width: 106,
              height: 75,
              child: Center(child: logo),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isFirstPartner ? 'FIRST PARTNER SERIES' :
                    (widget.expansionName.isEmpty ? 'UNASSIGNED PRODUCTS' : 'SEALED SET'),
                style: const TextStyle(
                  color: _gold, fontSize: 10,
                  letterSpacing: 0.9, fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _headerTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white, fontSize: 18,
                  height: 1.12, fontWeight: FontWeight.w900,
                ),
              ),
              if (_headerSubtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  _headerSubtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted, fontSize: 11.5, height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          )),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: _dark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.trending_up_rounded, color: _gold, size: 19),
            const SizedBox(width: 9),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SealedProductPriceService.pricedProductCount(_products) == _products.length
                    ? (_products.isEmpty ? 'No products in this set' : 'Estimated set value') : 'Priced subtotal (incomplete)',
                    style: const TextStyle(color: _muted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(SealedProductPriceService.pricedProductCount(_products) == 0
                    ? 'No verified GBP price yet'
                    : '${SealedProductPriceService.gbp(SealedProductPriceService.pricedSubtotal(_products))} GBP',
                    style: const TextStyle(color: _gold, fontSize: 16,
                      fontWeight: FontWeight.w800)),
                Text('${SealedProductPriceService.pricedProductCount(_products)}/${_products.length} products priced',
                    style: const TextStyle(color: _muted, fontSize: 10.5)),
              ],
            )),
            const Icon(Icons.trending_up_rounded, color: _muted, size: 17),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _compactCount(
            Icons.inventory_2_outlined, '$_quantity', 'Items owned')),
          const SizedBox(width: 10),
          Expanded(child: _compactCount(
            Icons.category_outlined, '${_products.length}', 'Unique products')),
        ]),
      ]),
    );
  }

  Widget _compactCount(IconData icon, String value, String label) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: _gold, size: 17),
          const SizedBox(width: 7),
          Text(value, style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(width: 6),
          Flexible(child: Text(label,
            maxLines: 2,
            style: const TextStyle(color: _muted, fontSize: 10.5))),
        ]),
      );

  Widget _priceSlot(String label, String amount) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: _muted, fontSize: 10.5)),
          const SizedBox(height: 5),
          Text(amount,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _productCard(SealedCollectionItem item) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 86,
                  width: 78,
                  child: ColoredBox(
                    color: item.imageUrl.isEmpty ? _dark : Colors.white,
                    child: item.imageUrl.isEmpty
                        ? const Icon(Icons.inventory_2_outlined,
                            color: _gold, size: 31)
                        : Image.network(
                            item.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.inventory_2_outlined,
                                color: _gold,
                                size: 31),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.15)),
                    const SizedBox(height: 5),
                    Text(item.productTypeLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _gold,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Owned: ${item.quantity}  •  ${item.condition.isEmpty ? 'Condition not recorded' : item.condition}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _muted, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
          if (widget.selectForDeal) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(item),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Choose for trade'),
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _dark,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            _productActions(item),
          ],
          Row(children: [
            Expanded(child: Text(
              SealedProductPriceService.cachedUkSoldPrice(item)?.hasPrice == true
                  ? 'Saved UK sold price · '
                      '${SealedProductPriceService.cachedUkSoldPrice(item)!.saleCount}/20 sold comps · '
                      '${SealedProductPriceService.cachedUkSoldPrice(item)!.confidence} confidence'
                  : _soldErrors[item.id] ??
                    (SealedProductPriceService.cachedUkSoldPrice(item) == null
                        ? 'UK sold price not checked'
                        : 'No verified GBP sales found'),
              style: TextStyle(color:
                  _soldErrors.containsKey(item.id) &&
                      SealedProductPriceService.cachedUkSoldPrice(item) == null
                      ? const Color(0xFFFF8A9A) : _muted, fontSize: 10.5),
            )),
            TextButton(
              onPressed: _checkingSold ? null : () => _recheckProduct(item),
              child: Text(SealedProductPriceService.cachedUkSoldPrice(item) == null
                  ? 'Check sold' : 'Refresh price'),
            ),
          ]),
          if (_soldErrors.containsKey(item.id) &&
              SealedProductPriceService.cachedUkSoldPrice(item) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('Refresh unsuccessful · ${_soldErrors[item.id]}',
                style: const TextStyle(color: Color(0xFFFF8A9A), fontSize: 10.5)),
            ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _dark, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _priceSlot('Last sold',
                  SealedProductPriceService.gbp(
                      SealedProductPriceService.cachedUkSoldPrice(item)?.lastSoldPrice)),
              _priceSlot('Up to 20 avg',
                  SealedProductPriceService.gbp(
                      SealedProductPriceService.cachedUkSoldPrice(item)?.averageSoldPrice)),
              _priceSlot('Your total',
                  SealedProductPriceService.gbp(
                      SealedProductPriceService.cachedUkSoldPrice(item)
                          ?.valueForQuantity(item.quantity))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _calculationNote() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 3, 16, 24),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 19, color: _gold),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Values use UK completed sales in GBP, excluding postage. Each product estimate is its average sold price × quantity. Unpriced products are excluded; fewer than 5 sales means low confidence. Saved on this device until you refresh the price.',
              style: TextStyle(color: _muted, fontSize: 11.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Sealed products'),
        backgroundColor: _background,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh saved collection',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : RefreshIndicator(
                color: _gold,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _overview(),
                    _soldLookupButton(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Row(children: [
                        const Expanded(
                          child: Text('Your sealed products',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                        ),
                        Text('${_products.length} types',
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                      ]),
                    ),
                    if (_products.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 22, vertical: 28),
                        child: Text(
                          'No products from this set are currently saved. Return to your collection to add or assign products.',
                          style: TextStyle(color: _muted),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._products.map(_productCard),
                    _calculationNote(),
                  ],
                ),
              ),
      ),
    );
  }
}
