import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/tracked_restock_product_service.dart';
import '../widgets/glass_page_header.dart';

class RestockAlertPreferencesPage extends StatefulWidget {
  const RestockAlertPreferencesPage({super.key});

  @override
  State<RestockAlertPreferencesPage> createState() =>
      _RestockAlertPreferencesPageState();
}

class _RestockAlertPreferencesPageState
    extends State<RestockAlertPreferencesPage> {
  bool _enabled = true;
  bool _loadingInitialPrefs = true;
  bool _saving = false;
  final Set<String> _selectedShops = <String>{};
  final Set<String> _selectedRegions = <String>{};
  final Set<String> _selectedStoreIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: const GlassPageAppBar(
        title: 'Alert Preferences',
        subtitle: 'Choose shops, regions, and stores',
        icon: Icons.notifications_active_outlined,
      ),
      body: StreamBuilder<List<TrackedRestockProduct>>(
        stream: TrackedRestockProductService.watchProducts(),
        builder: (context, productsSnapshot) {
          if (productsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (productsSnapshot.hasError) {
            return _MessageCard(
              title: 'Could not load tracked shops',
              message: productsSnapshot.error.toString(),
              icon: Icons.error_outline,
            );
          }

          final products = productsSnapshot.data ?? const <TrackedRestockProduct>[];

          return StreamBuilder<UserRestockAlertPreferences>(
            stream: TrackedRestockProductService.watchCurrentUserPreferences(),
            builder: (context, preferencesSnapshot) {
              if (_loadingInitialPrefs && preferencesSnapshot.hasData) {
                _loadingInitialPrefs = false;
                final prefs = preferencesSnapshot.data!;
                _enabled = prefs.enabled;
                _selectedShops
                  ..clear()
                  ..addAll(prefs.selectedShops);
                _selectedRegions
                  ..clear()
                  ..addAll(prefs.selectedRegions);
                _selectedStoreIds
                  ..clear()
                  ..addAll(prefs.selectedStoreIds);
              }

              if (preferencesSnapshot.connectionState ==
                      ConnectionState.waiting &&
                  _loadingInitialPrefs) {
                return const Center(child: CircularProgressIndicator());
              }

              if (products.isEmpty) {
                return const _MessageCard(
                  title: 'No tracked products yet',
                  message:
                      'An admin needs to add tracked products before you can choose shop or store alerts.',
                  icon: Icons.store_mall_directory_outlined,
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _IntroCard(enabled: _enabled, onChanged: _setEnabled),
                  const SizedBox(height: 14),
                  ..._buildShopSections(products),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF7DE77),
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save alert preferences'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _setEnabled(bool value) {
    setState(() {
      _enabled = value;
    });
  }

  List<Widget> _buildShopSections(List<TrackedRestockProduct> products) {
    final byShop = <String, List<TrackedRestockProduct>>{};

    for (final product in products.where((product) => product.enabled)) {
      final shop = product.shopName.trim().isEmpty
          ? 'Unknown shop'
          : product.shopName.trim();
      byShop.putIfAbsent(shop, () => <TrackedRestockProduct>[]).add(product);
    }

    final shopNames = byShop.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return shopNames.map((shopName) {
      final shopProducts = byShop[shopName] ?? const <TrackedRestockProduct>[];
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _ShopPreferenceCard(
          shopName: shopName,
          products: shopProducts,
          shopSelected: _selectedShops.contains(shopName),
          selectedRegions: _selectedRegions,
          selectedStoreIds: _selectedStoreIds,
          onShopChanged: (selected) {
            setState(() {
              if (selected) {
                _selectedShops.add(shopName);
              } else {
                _selectedShops.remove(shopName);
              }
            });
          },
          onRegionChanged: (regionKey, selected) {
            setState(() {
              if (selected) {
                _selectedRegions.add(regionKey);
              } else {
                _selectedRegions.remove(regionKey);
              }
            });
          },
          onStoreChanged: (storeId, selected) {
            setState(() {
              if (selected) {
                _selectedStoreIds.add(storeId);
              } else {
                _selectedStoreIds.remove(storeId);
              }
            });
          },
        ),
      );
    }).toList();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
    });

    try {
      await TrackedRestockProductService.saveCurrentUserPreferences(
        enabled: _enabled,
        selectedShops: _selectedShops,
        selectedRegions: _selectedRegions,
        selectedStoreIds: _selectedStoreIds,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Alert preferences saved')),
        );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save preferences: $error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFFF7DE77),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Restock notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: const Text(
                'Choose whole shops, whole regions, or individual stores below.',
                style: TextStyle(color: Color(0xFFC8D4F0), height: 1.35),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Example: choose Smyths → North West England to get alerts for all Smyths stores in that region, or choose only Manchester / Stockport stores.',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopPreferenceCard extends StatelessWidget {
  const _ShopPreferenceCard({
    required this.shopName,
    required this.products,
    required this.shopSelected,
    required this.selectedRegions,
    required this.selectedStoreIds,
    required this.onShopChanged,
    required this.onRegionChanged,
    required this.onStoreChanged,
  });

  final String shopName;
  final List<TrackedRestockProduct> products;
  final bool shopSelected;
  final Set<String> selectedRegions;
  final Set<String> selectedStoreIds;
  final ValueChanged<bool> onShopChanged;
  final void Function(String regionKey, bool selected) onRegionChanged;
  final void Function(String storeId, bool selected) onStoreChanged;

  @override
  Widget build(BuildContext context) {
    final byRegion = <String, List<TrackedRestockProduct>>{};

    for (final product in products) {
      final region = product.region.trim().isEmpty
          ? 'All regions'
          : product.region.trim();
      byRegion.putIfAbsent(region, () => <TrackedRestockProduct>[]).add(product);
    }

    final regionNames = byRegion.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          children: [
            CheckboxListTile(
              value: shopSelected,
              onChanged: (value) => onShopChanged(value ?? false),
              activeColor: const Color(0xFFF7DE77),
              checkColor: Colors.black,
              contentPadding: EdgeInsets.zero,
              title: Text(
                shopName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                shopSelected
                    ? 'All alerts from $shopName'
                    : 'Choose all $shopName alerts, or pick regions/stores below',
                style: const TextStyle(color: Color(0xFFC8D4F0), height: 1.3),
              ),
            ),
            for (final regionName in regionNames)
              _RegionSection(
                shopName: shopName,
                regionName: regionName,
                products: byRegion[regionName] ?? const <TrackedRestockProduct>[],
                selected: selectedRegions.contains(_regionKey(shopName, regionName)),
                selectedStoreIds: selectedStoreIds,
                onRegionChanged: (selected) {
                  onRegionChanged(_regionKey(shopName, regionName), selected);
                },
                onStoreChanged: onStoreChanged,
              ),
          ],
        ),
      ),
    );
  }

  static String _regionKey(String shopName, String regionName) {
    return '${shopName.trim()}|${regionName.trim()}';
  }
}

class _RegionSection extends StatelessWidget {
  const _RegionSection({
    required this.shopName,
    required this.regionName,
    required this.products,
    required this.selected,
    required this.selectedStoreIds,
    required this.onRegionChanged,
    required this.onStoreChanged,
  });

  final String shopName;
  final String regionName;
  final List<TrackedRestockProduct> products;
  final bool selected;
  final Set<String> selectedStoreIds;
  final ValueChanged<bool> onRegionChanged;
  final void Function(String storeId, bool selected) onStoreChanged;

  @override
  Widget build(BuildContext context) {
    final byStore = <String, List<TrackedRestockProduct>>{};

    for (final product in products) {
      final storeId = product.effectiveStoreId;
      byStore.putIfAbsent(storeId, () => <TrackedRestockProduct>[]).add(product);
    }

    final storeIds = byStore.keys.toList()
      ..sort((a, b) {
        final first = byStore[a]!.first.storeDisplayName;
        final second = byStore[b]!.first.storeDisplayName;
        return first.toLowerCase().compareTo(second.toLowerCase());
      });

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2A5E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? const Color(0xFFF7DE77).withValues(alpha: 0.36)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: selected,
            onChanged: (value) => onRegionChanged(value ?? false),
            activeColor: const Color(0xFFF7DE77),
            checkColor: Colors.black,
            title: Text(
              regionName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              selected
                  ? 'All $shopName alerts in this region'
                  : 'Or choose individual stores below',
              style: const TextStyle(color: Color(0xFFC8D4F0), fontSize: 12),
            ),
          ),
          for (final storeId in storeIds)
            _StoreCheckboxTile(
              product: byStore[storeId]!.first,
              selected: selectedStoreIds.contains(storeId),
              onChanged: (value) => onStoreChanged(storeId, value),
            ),
        ],
      ),
    );
  }
}

class _StoreCheckboxTile extends StatelessWidget {
  const _StoreCheckboxTile({
    required this.product,
    required this.selected,
    required this.onChanged,
  });

  final TrackedRestockProduct product;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: (value) => onChanged(value ?? false),
      activeColor: const Color(0xFFF7DE77),
      checkColor: Colors.black,
      dense: true,
      title: Text(
        product.storeDisplayName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        [
          if (product.storeAddress.trim().isNotEmpty) product.storeAddress,
          product.productName,
        ].join(' • '),
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: const Color(0xFF102754),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFF7DE77), size: 38),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFC8D4F0), height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
