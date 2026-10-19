import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tcg_set.dart';
import '../services/pokemon_tcg_service.dart';
import '../services/sealed_expansion_matcher.dart';
import '../services/sealed_collection_store.dart';
import '../services/sealed_product_price_service.dart';
import 'sealed_set_valuation_page.dart';
import 'deal_builder_page.dart';

class _SetGroupViewData {
  const _SetGroupViewData({
    required this.key,
    required this.expansionName,
    required this.displayName,
    required this.items,
    this.displaySubtitle,
    this.seriesNumber,
  });

  final String key;
  final String expansionName;
  final String displayName;
  final String? displaySubtitle;
  final List<SealedCollectionItem> items;
  final int? seriesNumber;

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);
}

class SealedCollectionPage extends StatefulWidget {
  const SealedCollectionPage({super.key, this.selectForDeal = false});

  /// When opened from Trade Builder, browse the same Pokémon set groups and
  /// return a selected sealed product instead of changing collection items.
  final bool selectForDeal;

  @override
  State<SealedCollectionPage> createState() => _SealedCollectionPageState();
}

class _SealedCollectionPageState extends State<SealedCollectionPage> {
  List<SealedCollectionItem> _items = <SealedCollectionItem>[];
  bool _loading = true;
  String _query = '';
  String _category = 'All types';
  String _sort = 'Name A–Z';
  bool _groupByExpansion = true;
  bool _showAllProducts = false;
  late final Future<List<TcgSet>> _setLogoCatalogue;
  bool _checkingSold = false;
  int _soldCheckedCount = 0;
  int _soldBatchCount = 0;
  final Map<String, String> _soldErrors = <String, String>{};

  // This is an explicit, rate-controlled operation: no hidden CompsAPI calls
  // when the collector opens the page, scrolls, or refreshes the collection.
  Future<void> _checkCollectionSoldPrices() async {
    if (_checkingSold) return;
    final pending = _items.where((item) =>
        SealedProductPriceService.cachedUkSoldPrice(item) == null &&
        !_soldErrors.containsKey(item.id)).take(10).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No unchecked products remain. Failed lookups can be retried individually.'),
      ));
      return;
    }
    setState(() {
      _checkingSold = true;
      _soldCheckedCount = 0;
      _soldBatchCount = pending.length;
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
      if (mounted) setState(() => _soldCheckedCount++);
    }
    if (mounted) setState(() => _checkingSold = false);
  }

  Future<void> _checkOneSoldPrice(SealedCollectionItem item) async {
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

  Widget _soldPricingAction() {
    final remaining = _items.where((item) =>
        SealedProductPriceService.cachedUkSoldPrice(item) == null &&
        !_soldErrors.containsKey(item.id)).length;
    final checkCount = remaining < 10 ? remaining : 10;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2854),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF426CA3).withValues(alpha: 0.50)),
        ),
        child: Row(
          children: [
            const Icon(Icons.price_check_rounded,
                color: Color(0xFFF7DE77), size: 23),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('UK sold-price checks',
                      style: TextStyle(color: Colors.white,
                          fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    _checkingSold
                        ? 'Checking $_soldCheckedCount of $_soldBatchCount products'
                        : remaining == 0
                            ? 'No bulk checks left · retry in All products'
                            : 'CompsAPI · GBP excluding postage · uses credits',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFBDCCE7),
                        fontSize: 10.5, height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            if (_checkingSold)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Color(0xFFF7DE77)),
              )
            else if (remaining > 0)
              OutlinedButton(
                onPressed: _checkCollectionSoldPrices,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF7DE77),
                  side: const BorderSide(color: Color(0xFF597AB0)),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  minimumSize: const Size(0, 36),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text('Check $checkCount',
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w800)),
              )
            else
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF96B1D9), size: 20),
          ],
        ),
      ),
    );
  }


  List<SealedCollectionItem> get _visibleItems {
    final query = _query.trim().toLowerCase();
    final result = _items.where((item) {
      final matchesText = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.productTypeLabel.toLowerCase().contains(query) ||
          item.notes.toLowerCase().contains(query) ||
          item.expansionName.toLowerCase().contains(query);
      return matchesText &&
          (_category == 'All types' || item.productTypeLabel == _category);
    }).toList();
    switch (_sort) {
      case 'Name Z–A':
        result.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'Quantity (highest)':
        result.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'Recently updated':
        result.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
        break;
      default:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }
    return result;
  }

  List<String> get _categories => <String>[
    'All types',
    ...(_items.map((e) => e.productTypeLabel).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
  ];

  Widget _browseControls() {
    InputDecoration filterDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9FB6D7), fontSize: 12),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF0D2B5B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFF365E94)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFF7DE77), width: 1.3),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search your sealed collection',
              hintStyle: const TextStyle(color: Color(0xFFAFC2DD), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFFF7DE77), size: 22),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF0D2B5B),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF365E94)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFF7DE77), width: 1.4),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 5),
                    child: Text('Product type', style: TextStyle(
                        color: Color(0xFFBDCCE7), fontSize: 11,
                        fontWeight: FontWeight.w700)),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    dropdownColor: const Color(0xFF102754),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more_rounded,
                        color: Color(0xFFB6CBE5)),
                    decoration: filterDecoration('All types'),
                    items: _categories.map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _category = v ?? 'All types'),
                  ),
                ],
              )),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 5),
                    child: Text('Sort by', style: TextStyle(
                        color: Color(0xFFBDCCE7), fontSize: 11,
                        fontWeight: FontWeight.w700)),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _sort,
                    dropdownColor: const Color(0xFF102754),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more_rounded,
                        color: Color(0xFFB6CBE5)),
                    decoration: filterDecoration('Name A–Z'),
                    items: const [
                      'Name A–Z', 'Name Z–A',
                      'Quantity (highest)', 'Recently updated',
                    ].map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _sort = v ?? 'Name A–Z'),
                  ),
                ],
              )),
            ],
          ),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(child: _modeButton('Set logos', Icons.grid_view_rounded, false)),
            const SizedBox(width: 9),
            Expanded(child: _modeButton('All products', Icons.view_list_rounded, true)),
          ]),
          if (_showAllProducts)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Group product list by set',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _groupByExpansion,
              onChanged: (v) => setState(() => _groupByExpansion = v),
            ),
        ],
      ),
    );
  }

  Widget _modeButton(String text, IconData icon, bool allProducts) {
    final selected = _showAllProducts == allProducts;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? const [Color(0xFFFFEF9B), Color(0xFFFFD950)]
                : const [Color(0xFF174278), Color(0xFF0C2956)],
          ),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? const Color(0xFFFFF2AF) : const Color(0xFF3974AE),
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => setState(() => _showAllProducts = allProducts),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  color: selected ? const Color(0xFF081E43) : const Color(0xFFC5DBF5),
                  size: 18),
              const SizedBox(width: 7),
              Flexible(child: Text(text, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? const Color(0xFF081E43) : Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 12))),
            ]),
          ),
        ),
      ),
    );
  }

  String _normalizedSetName(String value) => value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  TcgSet? _matchSetLogo(String expansion, List<TcgSet> catalogue) {
    final name = _normalizedSetName(expansion);
    if (name.isEmpty) return null;
    for (final set in catalogue) {
      if (_normalizedSetName(set.name) == name) return set;
    }
    // A few releases have slightly different names between catalogue
    // providers. Only use a very specific match so the wrong logo is never
    // displayed (particularly for short names such as "151").
    if (name.length >= 10) {
      for (final set in catalogue) {
        final candidate = _normalizedSetName(set.name);
        if (candidate.endsWith(' $name') &&
            candidate.length - name.length <= 22 &&
            !candidate.contains('promo')) {
          return set;
        }
      }
    }
    return null;
  }

  String? _firstPartnerAssetPath(int? seriesNumber) {
    switch (seriesNumber) {
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

  Widget _setLogoArtwork(_SetGroupViewData group, TcgSet? set) {
    if (group.key == 'unassigned') {
      return const Icon(Icons.folder_outlined, size: 48,
        color: Color(0xFFF7DE77));
    }

    // Delta Reign has an official expansion logo that is not yet available
    // in every TCG catalogue. Use the bundled set artwork rather than
    // substituting plain text or a different expansion's logo.
    final normalizedExpansion = _normalizedSetName(group.expansionName);
    if (normalizedExpansion == 'delta reign' ||
        normalizedExpansion == 'mega evolution delta reign') {
      return Image.asset(
        'assets/images/delta_reign_logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(group.displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF7DE77),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    if (group.seriesNumber != null) {
      final assetPath = _firstPartnerAssetPath(group.seriesNumber);
      if (assetPath != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('First Partner logo load failed ($assetPath): $error');
              return Center(
                child: Text('Series ${group.seriesNumber}',
                  style: const TextStyle(color: Color(0xFFF7DE77),
                    fontSize: 13, fontWeight: FontWeight.bold)),
              );
            },
          ),
        );
      }
    }

    final logo = set?.logoUrl?.trim() ?? '';
    if (logo.isEmpty) {
      return Center(child: Text(group.displayName, textAlign: TextAlign.center,
        maxLines: 3, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFF7DE77),
          fontWeight: FontWeight.w900, fontSize: 13)));
    }
    return Image.network(logo, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Center(child: Text(group.displayName,
        textAlign: TextAlign.center, maxLines: 3,
        style: const TextStyle(color: Color(0xFFF7DE77),
          fontWeight: FontWeight.bold, fontSize: 12))));
  }

  // Sort set names A–Z by default; keep First Partner series 1, 2, 3
  // together in numeric order even when they share the same set name.
  int _compareSetGroupNames(_SetGroupViewData a, _SetGroupViewData b) {
    final nameOrder = a.displayName.toLowerCase()
        .compareTo(b.displayName.toLowerCase());
    if (nameOrder != 0) return nameOrder;

    if (a.seriesNumber != null && b.seriesNumber != null) {
      return a.seriesNumber!.compareTo(b.seriesNumber!);
    }
    final subtitleOrder = (a.displaySubtitle ?? '').toLowerCase()
        .compareTo((b.displaySubtitle ?? '').toLowerCase());
    if (subtitleOrder != 0) return subtitleOrder;
    return a.key.compareTo(b.key);
  }

  List<_SetGroupViewData> _buildSetGroups(List<SealedCollectionItem> items) {
    final Map<String, _SetGroupViewData> groups = <String, _SetGroupViewData>{};
    for (final item in items) {
      final rawExpansion = item.expansionName.trim();
      if (rawExpansion == SealedExpansionMatcher.firstPartnerCollectionGroup) {
        final series = SealedExpansionMatcher.firstPartnerSeriesNumber(item.title);
        if (series != null) {
          final region = SealedExpansionMatcher.firstPartnerPrimaryRegion(item.title) ?? 'Series $series';
          final key = 'first-partner-$series';
          final current = groups[key];
          if (current == null) {
            groups[key] = _SetGroupViewData(
              key: key,
              expansionName: SealedExpansionMatcher.firstPartnerCollectionGroup,
              displayName: 'First Partner Collection 2026',
              displaySubtitle: 'Series $series — $region',
              seriesNumber: series,
              items: <SealedCollectionItem>[item],
            );
          } else {
            current.items.add(item);
          }
          continue;
        }
      }

      final display = rawExpansion.isEmpty ? 'Unassigned set' : rawExpansion;
      final key = rawExpansion.isEmpty ? 'unassigned' : rawExpansion.toLowerCase();
      final current = groups[key];
      if (current == null) {
        groups[key] = _SetGroupViewData(
          key: key,
          expansionName: rawExpansion,
          displayName: display,
          items: <SealedCollectionItem>[item],
        );
      } else {
        current.items.add(item);
      }
    }
    final entries = groups.values.toList();
    switch (_sort) {
      case 'Name Z–A':
        entries.sort((a, b) => _compareSetGroupNames(b, a));
        break;
      case 'Quantity (highest)':
        entries.sort((a, b) {
          final result = b.totalQuantity.compareTo(a.totalQuantity);
          return result == 0 ? _compareSetGroupNames(a, b) : result;
        });
        break;
      case 'Recently updated':
        int latest(_SetGroupViewData e) =>
            e.items.fold<int>(0, (time, item) => item.updatedAtMs > time ? item.updatedAtMs : time);
        entries.sort((a, b) {
          final result = latest(b).compareTo(latest(a));
          return result == 0 ? _compareSetGroupNames(a, b) : result;
        });
        break;
      default:
        entries.sort(_compareSetGroupNames);
    }
    return entries;
  }

  Widget _setLogoTiles() {
    final entries = _buildSetGroups(_visibleItems);
    if (entries.isEmpty) {
      return const Padding(padding: EdgeInsets.all(28), child: Text(
        'No matching sets. Try another search or product type.',
        textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)));
    }

    return FutureBuilder<List<TcgSet>>(
      future: _setLogoCatalogue,
      builder: (context, snapshot) {
        final catalogue = snapshot.data ?? <TcgSet>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 3, 18, 5),
            child: Row(children: [
              const Expanded(child: Text('Your Pokémon sets',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF17376B),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${entries.length} sets', style: const TextStyle(
                  color: Color(0xFFE1EAFE), fontSize: 11,
                  fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 11),
            child: Text(widget.selectForDeal
                ? 'Choose a set, then select a product for the trade.'
                : 'Tap a set to see its products and value.',
              style: const TextStyle(color: Color(0xFFBDCCE7), fontSize: 11.5)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0xFF102D5A),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          final logoSet = entry.seriesNumber == null
                              ? _matchSetLogo(entry.expansionName.isEmpty
                                  ? entry.displayName : entry.expansionName, catalogue)
                              : null;
                          _showSetValuation(
                            entry.expansionName,
                            logoUrl: logoSet?.logoUrl,
                            displayName: entry.displayName,
                            displaySubtitle: entry.displaySubtitle,
                            seriesNumber: entry.seriesNumber,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF5B81B2).withValues(alpha: 0.44),
                            ),
                          ),
                          child: Row(children: [
                            SizedBox(
                              width: 82,
                              height: 60,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: _setLogoArtwork(
                                  entry,
                                  entry.seriesNumber == null
                                      ? _matchSetLogo(entry.expansionName.isEmpty
                                          ? entry.displayName : entry.expansionName, catalogue)
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (entry.displaySubtitle != null) ...[
                                    const SizedBox(height: 3),
                                    Text(entry.displaySubtitle!,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFF7DE77),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 3),
                                  Text(
                                    '${entry.totalQuantity} items · ${entry.items.length} products',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFC8D4F0), fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFFF7DE77), size: 24),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ]);
      },
    );
  }

  List<Widget> _productRows() {
    final visible = _visibleItems;
    if (visible.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(28), child: Text('No matching products.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)))];
    }
    if (!_groupByExpansion) return visible.map(_itemCard).toList();
    final groups = _buildSetGroups(visible);
    return [
      for (final entry in groups) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 9),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.displayName,
                    style: const TextStyle(color: Color(0xFFF7DE77), fontWeight: FontWeight.bold, fontSize: 15)),
                  if (entry.displaySubtitle != null)
                    Text(entry.displaySubtitle!,
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            Text('${entry.totalQuantity} items',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 10),
            TextButton(
              onPressed: entry.key == 'unassigned'
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(
                          'Tap the pencil on a product to assign its Pokémon set.',
                        )),
                      )
                  : () => _showSetValuation(
                        entry.expansionName,
                        displayName: entry.displayName,
                        displaySubtitle: entry.displaySubtitle,
                        seriesNumber: entry.seriesNumber,
                      ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF7DE77),
                visualDensity: VisualDensity.compact,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(entry.key == 'unassigned' ? 'Assign sets' : 'View value'),
                if (entry.key != 'unassigned')
                  const Icon(Icons.chevron_right_rounded, size: 18),
              ]),
            ),
          ]),
        ),
        ...entry.items.map(_itemCard),
      ],
    ];
  }

  Future<void> _editDetails(SealedCollectionItem item) async {
    final notesController = TextEditingController(text: item.notes);
    final conditionController = TextEditingController(text: item.condition);
    final expansionController = TextEditingController(text: item.expansionName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product details'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(item.title),
          const SizedBox(height: 12),
          TextField(controller: expansionController, decoration: const InputDecoration(labelText: 'Pokémon set / expansion', hintText: 'e.g. Surging Sparks')),
          TextField(controller: conditionController, decoration: const InputDecoration(labelText: 'Condition (e.g. factory sealed)')),
          TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Purchase location / notes')),
          const SizedBox(height: 10),
          const Text('Only verified CompsAPI UK sold prices appear in valuations.', style: TextStyle(fontSize: 12)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) {
      await SealedCollectionStore.upsert(item.copyWith(
        condition: conditionController.text.trim(),
        notes: notesController.text.trim(),
        expansionName: expansionController.text.trim(),
      ));
      if (mounted) await _load();
    }
    conditionController.dispose();
    notesController.dispose();
  }

  String _csvValue(String value) => '"${value.replaceAll('"', '""')}"';

  Future<void> _copyExport() async {
    final lines = <String>['Product,Set,Type,Quantity,Condition,Notes'];
    for (final item in _items) {
      lines.add([item.title, item.expansionName, item.productTypeLabel, '${item.quantity}', item.condition, item.notes]
          .map(_csvValue).join(','));
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\r\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copied. Paste into a spreadsheet and save as CSV.')),
      );
    }
  }

  final Set<String> _updating = <String>{};

  @override
  void initState() {
    super.initState();
    // Load the existing Pokémon set/logo catalogue once. The logo tiles
    // themselves remain tappable while artwork is still loading.
    _setLogoCatalogue = PokemonTcgService.fetchSets().catchError(
      (Object _) => <TcgSet>[],
    );
    _load();
  }

  Future<void> _load() async {
    final items = await SealedCollectionStore.load();
    await SealedProductPriceService.loadSavedUkSoldPrices();
    items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  int get _totalQuantity =>
      _items.fold<int>(0, (total, item) => total + item.quantity);

  Widget _summaryStat({
    required String label,
    required String value,
    required IconData icon,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2A57),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF416A9C).withValues(alpha: 0.38)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFF7DE77), size: 20),
        const SizedBox(width: 9),
        Flexible(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, maxLines: 1, style: const TextStyle(
              color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFC8D4F0), fontSize: 10)),
          ],
        )),
      ]),
    ),
  );

  Widget _collectionSummary() {
    final pricedCount = SealedProductPriceService.pricedProductCount(_items);
    final pricedTotal = SealedProductPriceService.pricedSubtotal(_items);
    final allPriced = pricedCount == _items.length;
    final priceText = pricedCount == 0
        ? 'No verified UK sold prices yet'
        : allPriced
            ? 'Estimated value: ${SealedProductPriceService.gbp(pricedTotal)} GBP'
            : 'Priced subtotal: ${SealedProductPriceService.gbp(pricedTotal)} GBP';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF153766), Color(0xFF102754)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF5377A4).withValues(alpha: 0.48)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.inventory_2_outlined, color: Color(0xFFF7DE77), size: 19),
          SizedBox(width: 8),
          Expanded(child: Text('Collection overview', style: TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _summaryStat(label: 'Items owned', value: '$_totalQuantity',
              icon: Icons.inventory_2_outlined),
          const SizedBox(width: 9),
          _summaryStat(label: 'Unique products', value: '${_items.length}',
              icon: Icons.category_outlined),
        ]),
        const SizedBox(height: 9),
        Row(children: [
          const Icon(Icons.show_chart_rounded,
              color: Color(0xFFF7DE77), size: 17),
          const SizedBox(width: 6),
          Expanded(child: Text(priceText, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFF7DE77),
                fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          Text('$pricedCount/${_items.length} priced',
            style: const TextStyle(color: Color(0xFFC8D4F0),
                fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Future<void> _showSetValuation(
    String name, {
    String? logoUrl,
    String? displayName,
    String? displaySubtitle,
    int? seriesNumber,
  }) async {
    final selected = await Navigator.of(context).push<SealedCollectionItem>(
      MaterialPageRoute<SealedCollectionItem>(
        builder: (_) => SealedSetValuationPage(
          expansionName: name,
          logoUrl: logoUrl,
          displayName: displayName,
          displaySubtitle: displaySubtitle,
          seriesNumber: seriesNumber,
          selectForDeal: widget.selectForDeal,
        ),
      ),
    );
    if (!mounted) return;
    if (widget.selectForDeal && selected != null) {
      // Return directly to the active collector tab; Deal Builder will
      // confirm quantity, unit price and the correct trade side.
      Navigator.of(context).pop(selected);
      return;
    }
    // Normal collection mode keeps its refresh behaviour.
    if (!widget.selectForDeal) await _load();
  }

  Future<void> _changeQuantity(
    SealedCollectionItem item,
    int change,
  ) async {
    if (_updating.contains(item.id)) return;
    final nextQuantity = (item.quantity + change).clamp(1, 9999).toInt();
    if (nextQuantity == item.quantity) return;

    setState(() => _updating.add(item.id));
    await SealedCollectionStore.upsert(
      item.copyWith(quantity: nextQuantity),
    );
    if (!mounted) return;
    setState(() {
      final index = _items.indexWhere((saved) => saved.id == item.id);
      if (index >= 0) {
        _items[index] = item.copyWith(quantity: nextQuantity);
      }
      _updating.remove(item.id);
    });
  }

  Future<void> _chooseQuantity(SealedCollectionItem item) async {
    final controller = TextEditingController(text: '${item.quantity}');
    final quantity = await showDialog<int>(
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(
                dialogContext,
                value?.clamp(1, 9999).toInt(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null || quantity == item.quantity) return;
    await SealedCollectionStore.upsert(item.copyWith(quantity: quantity));
    await _load();
  }

  Future<void> _remove(SealedCollectionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove sealed product?'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SealedCollectionStore.remove(item.id);
    await _load();
  }

  Widget _quantityControl(SealedCollectionItem item) {
    final busy = _updating.contains(item.id);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071B3F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Reduce quantity',
            onPressed: busy || item.quantity <= 1
                ? null
                : () => _changeQuantity(item, -1),
            icon: const Icon(Icons.remove_rounded, size: 19),
            color: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: busy ? null : () => _chooseQuantity(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: Color(0xFFF7DE77),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: busy ? null : () => _changeQuantity(item, 1),
            icon: const Icon(Icons.add_rounded, size: 19),
            color: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(SealedCollectionItem item) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 88,
              height: 104,
              child: ColoredBox(
                color: item.imageUrl.isEmpty
                    ? const Color(0xFF071B3F)
                    : Colors.white,
                child: item.imageUrl.isEmpty
                    ? const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFFF7DE77),
                        size: 32,
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFFF7DE77),
                          size: 32,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.productTypeLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF7DE77),
                    fontSize: 11.5,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.expansionName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Set: ${item.expansionName}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
                if (item.condition.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.condition, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
                const SizedBox(height: 5),
                Builder(builder: (context) {
                  final sold = SealedProductPriceService.cachedUkSoldPrice(item);
                  final error = _soldErrors[item.id];
                  return Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sold == null
                          ? (error ?? 'UK sold price not checked')
                          : sold.hasPrice
                              ? 'Saved UK sold avg: ${SealedProductPriceService.gbp(sold.averageSoldPrice)}  ·  ${sold.saleCount}/20 comps${sold.lowConfidence ? '  ·  LOW CONFIDENCE' : ''}'
                              : 'No matching GBP sold sales found',
                        style: TextStyle(color: error != null && sold == null
                            ? const Color(0xFFFF8A9A) : Colors.white70,
                          fontSize: 10.5)),
                      if (error != null && sold != null)
                        Text('Refresh unsuccessful · $error',
                          style: const TextStyle(color: Color(0xFFFF8A9A),
                              fontSize: 10.5)),
                      TextButton.icon(
                        onPressed: _checkingSold ? null : () => _checkOneSoldPrice(item),
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: Text(sold == null ? 'Check UK sold price' : 'Refresh price'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFF7DE77),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.selectForDeal
                        ? () => Navigator.of(context).pop(item)
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => DealBuilderPage(
                              initialSealedProduct: item,
                            )),
                          ),
                    icon: const Icon(Icons.handshake_outlined, size: 18),
                    label: Text(widget.selectForDeal ? 'Choose for trade' : 'Add to Deal'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF7DE77),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _quantityControl(item),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Edit condition and notes',
                      onPressed: () => _editDetails(item),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: const Color(0xFFF7DE77),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    ),
                    IconButton(
                      tooltip: 'Remove product',
                      onPressed: () => _remove(item),
                      icon: const Icon(Icons.delete_outline_rounded, size: 21),
                      color: const Color(0xFFFF8A9A),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('My Sealed Collection'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        actions: [IconButton(
          tooltip: 'Copy collection as CSV',
          onPressed: _items.isEmpty ? null : _copyExport,
          icon: const Icon(Icons.file_download_outlined),
        )],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Your sealed collection is empty. Add a product from Sealed search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      children: [
                        _collectionSummary(),
                        _soldPricingAction(),
                        _browseControls(),
                        if (_showAllProducts) ..._productRows()
                        else _setLogoTiles(),
                      ],
                    ),
                  ),
      ),
    );
  }
}
