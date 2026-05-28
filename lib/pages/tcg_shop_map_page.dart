import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_profile.dart';
import '../models/tcg_shop.dart';
import '../services/business_profile_service.dart';
import '../services/tcg_shop_service.dart';
import 'add_tcg_shop_page.dart';
import 'edit_tcg_shop_page.dart';
import '../widgets/business_offers_preview.dart';
import '../widgets/business_products_preview.dart';
import '../widgets/business_rating_summary.dart';
import 'business_deals_page.dart';
import 'business_events_directory_page.dart';
import 'business_reviews_page.dart';
import 'online_shops_page.dart';

class TcgShopMapPage extends StatefulWidget {
  const TcgShopMapPage({super.key});

  @override
  State<TcgShopMapPage> createState() => _TcgShopMapPageState();
}

class _TcgShopMapPageState extends State<TcgShopMapPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _pinRedColor = Color(0xFFD62828);

  static const double _initialZoom = 5.5;
  static const double _showIndividualPinsZoom = 14.0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TcgShopService _shopService = TcgShopService();
  final BusinessProfileService _businessProfileService =
      BusinessProfileService();
  final TextEditingController _areaController = TextEditingController();

  double _currentZoom = _initialZoom;
  String _selectedGame = 'all';
  String _selectedService = 'all';

  static const List<String> _games = <String>[
    'all',
    'pokemon',
    'yugioh',
    'mtg',
    'lorcana',
    'one piece',
    'other',
  ];

  static const List<String> _services = <String>[
    'all',
    'sealed',
    'singles',
    'tournaments',
    'trade nights',
    'buys cards',
    'grading',
    'online shop',
  ];

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  List<TcgShop> _applyFilters(List<TcgShop> shops) {
    final areaSearch = _areaController.text.trim().toLowerCase();

    return shops.where((shop) {
      final matchesArea =
          areaSearch.isEmpty || shop.searchText.contains(areaSearch);

      final matchesGame =
          _selectedGame == 'all' || shop.games.contains(_selectedGame);

      final matchesService =
          _selectedService == 'all' || shop.services.contains(_selectedService);

      return matchesArea && matchesGame && matchesService;
    }).toList();
  }

  String _label(String value) {
    if (value == 'all') return 'All';

    return value
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  InputDecoration _filterDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: _softTextColor),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _goldColor,
        fontWeight: FontWeight.w800,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              color: _softTextColor,
            ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _goldColor, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      isDense: true,
    );
  }

  Widget _buildMapError(Object error) {
    return Container(
      color: _backgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: _goldColor,
            size: 42,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load TCG shops.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _softTextColor,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }


  void _openBusinessReviews(
    BuildContext bottomSheetContext,
    BusinessProfile profile,
  ) {
    Navigator.of(bottomSheetContext).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessReviewsPage(profile: profile),
      ),
    );
  }

  Future<void> _openEventsDirectoryPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BusinessEventsDirectoryPage(),
      ),
    );
  }

  Future<void> _openDealsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BusinessDealsPage(),
      ),
    );
  }

  Future<void> _openOnlineShopsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const OnlineShopsPage(),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      color: _backgroundColor,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            TextField(
              controller: _areaController,
              style: const TextStyle(color: Colors.white),
              cursorColor: _goldColor,
              decoration: _filterDecoration(
                labelText: 'Area',
                hintText: 'Filter by town, county or postcode',
                prefixIcon: Icons.search,
                suffixIcon: _areaController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear area filter',
                        icon: const Icon(
                          Icons.clear,
                          color: _softTextColor,
                        ),
                        onPressed: () {
                          _areaController.clear();
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGame,
                    dropdownColor: _fieldColor,
                    iconEnabledColor: _softTextColor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _filterDecoration(labelText: 'Game'),
                    items: _games
                        .map(
                          (game) => DropdownMenuItem<String>(
                            value: game,
                            child: Text(_label(game)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedGame = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedService,
                    dropdownColor: _fieldColor,
                    iconEnabledColor: _softTextColor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _filterDecoration(labelText: 'Service'),
                    items: _services
                        .map(
                          (service) => DropdownMenuItem<String>(
                            value: service,
                            child: Text(_label(service)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedService = value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Chip(
      backgroundColor: _fieldColor,
      side: const BorderSide(color: _borderColor),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFeaturedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _goldColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            color: _backgroundColor,
            size: 16,
          ),
          SizedBox(width: 5),
          Text(
            'Featured',
            style: TextStyle(
              color: _backgroundColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  double _clusterCellSizeDegrees() {
    if (_currentZoom >= _showIndividualPinsZoom) return 0;

    // Keep close shops grouped until the user is much closer in.
    // This makes city areas feel cleaner and avoids several pins sitting on top
    // of each other when zooming in.
    if (_currentZoom < 5.5) return 2.0;
    if (_currentZoom < 7) return 1.0;
    if (_currentZoom < 8.5) return 0.50;
    if (_currentZoom < 10) return 0.24;
    if (_currentZoom < 11.5) return 0.12;
    if (_currentZoom < 12.75) return 0.06;
    return 0.025;
  }

  double _clusterMarkerSize() {
    if (_currentZoom < 7) return 34;
    if (_currentZoom < 9) return 38;
    if (_currentZoom < 11) return 42;
    return 44;
  }

  List<_ShopMapMarkerCluster> _buildClusters(
    List<TcgShop> shops,
    Map<String, BusinessProfile> featuredProfilesByShopId,
  ) {
    final cellSize = _clusterCellSizeDegrees();

    if (cellSize <= 0) {
      return shops
          .map(
            (shop) => _ShopMapMarkerCluster(
              shops: [shop],
              center: LatLng(shop.lat, shop.lng),
              hasFeaturedShop: featuredProfilesByShopId.containsKey(shop.id),
            ),
          )
          .toList();
    }

    final groups = <String, List<TcgShop>>{};

    for (final shop in shops) {
      final latKey = (shop.lat / cellSize).floor();
      final lngKey = (shop.lng / cellSize).floor();
      final key = '$latKey:$lngKey';
      groups.putIfAbsent(key, () => <TcgShop>[]).add(shop);
    }

    return groups.values.map((groupedShops) {
      final latTotal = groupedShops.fold<double>(
        0,
        (total, shop) => total + shop.lat,
      );
      final lngTotal = groupedShops.fold<double>(
        0,
        (total, shop) => total + shop.lng,
      );

      return _ShopMapMarkerCluster(
        shops: groupedShops,
        center: LatLng(
          latTotal / groupedShops.length,
          lngTotal / groupedShops.length,
        ),
        hasFeaturedShop: groupedShops.any(
          (shop) => featuredProfilesByShopId.containsKey(shop.id),
        ),
      );
    }).toList()
      ..sort((a, b) {
        if (a.hasFeaturedShop != b.hasFeaturedShop) {
          return a.hasFeaturedShop ? -1 : 1;
        }
        return b.count.compareTo(a.count);
      });
  }

  List<Marker> _buildMapMarkers(
    List<TcgShop> shops,
    Map<String, BusinessProfile> featuredProfilesByShopId,
  ) {
    final clusters = _buildClusters(shops, featuredProfilesByShopId);

    return clusters.map((cluster) {
      if (cluster.count == 1) {
        final shop = cluster.shops.first;
        final featuredProfile = featuredProfilesByShopId[shop.id];
        final isFeatured = featuredProfile != null;

        return Marker(
          point: cluster.center,
          width: isFeatured ? 66 : 46,
          height: isFeatured ? 66 : 46,
          child: GestureDetector(
            onTap: () => _showShopDetails(shop, featuredProfile),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: isFeatured ? 58 : 44,
                  color: Colors.black.withValues(alpha: 0.30),
                ),
                Icon(
                  Icons.location_on,
                  size: isFeatured ? 50 : 38,
                  color: isFeatured ? _goldColor : _pinRedColor,
                ),
                if (isFeatured)
                  const Positioned(
                    top: 7,
                    child: Icon(
                      Icons.star,
                      color: _backgroundColor,
                      size: 15,
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      final markerSize = _clusterMarkerSize();
      final circleSize = markerSize - 6;
      final shadowSize = markerSize - 2;
      final fontSize = markerSize <= 40 ? 13.0 : 15.0;
      final markerColor = cluster.hasFeaturedShop ? _goldColor : _pinRedColor;
      final textColor = cluster.hasFeaturedShop ? _backgroundColor : Colors.white;

      return Marker(
        point: cluster.center,
        width: markerSize,
        height: markerSize,
        child: GestureDetector(
          onTap: () => _showClusterDetails(cluster, featuredProfilesByShopId),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: shadowSize,
                height: shadowSize,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: _goldColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    cluster.count > 99 ? '99+' : '${cluster.count}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (cluster.hasFeaturedShop)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.star,
                    color: _backgroundColor,
                    size: 15,
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _clusterTitle(_ShopMapMarkerCluster cluster) {
    final towns = cluster.shops
        .map((shop) => shop.town.trim())
        .where((town) => town.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (towns.length == 1) {
      return '${cluster.count} shops in ${towns.first}';
    }

    if (towns.length > 1 && towns.length <= 3) {
      return '${cluster.count} shops in ${towns.join(', ')}';
    }

    return '${cluster.count} shops in this area';
  }

  Map<String, BusinessProfile> _profilesByLinkedShopId(
    List<BusinessProfile> profiles,
  ) {
    return <String, BusinessProfile>{
      for (final profile in profiles)
        if (profile.canFeatureShop) profile.linkedShopId: profile,
    };
  }

  List<TcgShop> _sortFeaturedFirst(
    List<TcgShop> shops,
    Map<String, BusinessProfile> featuredProfilesByShopId,
  ) {
    final sortedShops = List<TcgShop>.from(shops);

    sortedShops.sort((a, b) {
      final aFeatured = featuredProfilesByShopId.containsKey(a.id);
      final bFeatured = featuredProfilesByShopId.containsKey(b.id);

      if (aFeatured != bFeatured) {
        return aFeatured ? -1 : 1;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return sortedShops;
  }

  List<BusinessProfile> _onlineFeaturedProfiles(
    List<BusinessProfile> profiles,
  ) {
    final onlineProfiles = profiles
        .where((profile) {
          return profile.status == 'approved' &&
              profile.premiumIsActive &&
              profile.hasPhysicalShop == false;
        })
        .toList();

    onlineProfiles.sort((a, b) {
      return a.businessName.toLowerCase().compareTo(
            b.businessName.toLowerCase(),
          );
    });

    return onlineProfiles;
  }

  List<BusinessProfile> _physicalFeaturedProfiles(
    List<BusinessProfile> profiles,
  ) {
    final physicalProfiles = profiles
        .where((profile) {
          return profile.canFeatureShop && profile.hasPhysicalShop == true;
        })
        .toList();

    physicalProfiles.sort((a, b) {
      return a.businessName.toLowerCase().compareTo(
            b.businessName.toLowerCase(),
          );
    });

    return physicalProfiles;
  }

  TcgShop? _shopForFeaturedProfile(
    BusinessProfile profile,
    List<TcgShop> shops,
  ) {
    final linkedShopId = profile.linkedShopId.trim();
    if (linkedShopId.isEmpty) return null;

    for (final shop in shops) {
      if (shop.id == linkedShopId) return shop;
    }

    return null;
  }


  String _featuredBannerImageForProfile(
    BusinessProfile profile, {
    String fallbackImageUrl = '',
  }) {
    final bannerUrl = profile.bannerUrl.trim();
    if (bannerUrl.isNotEmpty) return bannerUrl;

    final logoUrl = profile.logoUrl.trim();
    if (logoUrl.isNotEmpty) return logoUrl;

    return fallbackImageUrl.trim();
  }


  Widget _buildEventsDirectoryButton() {
    return Container(
      color: _backgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openEventsDirectoryPage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: _goldColor,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Browse upcoming shop events',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _goldColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDealsDirectoryButton() {
    return Container(
      color: _backgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openDealsPage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _goldColor),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  color: _goldColor,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Browse latest deals and offers',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _goldColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineShopsDirectoryButton() {
    return Container(
      color: _backgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openOnlineShopsPage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.language,
                  color: _goldColor,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'View and search online shops',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _goldColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBanners({
    required List<TcgShop> shops,
    required List<BusinessProfile> featuredProfiles,
  }) {
    final physicalProfiles = _physicalFeaturedProfiles(featuredProfiles);
    final onlineProfiles = _onlineFeaturedProfiles(featuredProfiles);
    final premiumProfiles = <_PremiumMarqueeItem>[
      ...physicalProfiles.map((profile) {
        final linkedShop = _shopForFeaturedProfile(profile, shops);
        return _PremiumMarqueeItem(
          title: profile.businessName.trim().isEmpty
              ? (linkedShop?.name ?? 'Featured TCG Shop')
              : profile.businessName.trim(),
          subtitle: linkedShop?.town.trim().isNotEmpty == true
              ? linkedShop!.town.trim()
              : 'Featured map shop',
          icon: Icons.storefront_outlined,
          imageUrl: _featuredBannerImageForProfile(
            profile,
            fallbackImageUrl: linkedShop?.imageUrl ?? '',
          ),
          isOnline: false,
          onTap: () {
            if (linkedShop != null) {
              _showShopDetails(linkedShop, profile);
            } else {
              _showOnlineBusinessDetails(profile);
            }
          },
        );
      }),
      ...onlineProfiles.map((profile) {
        return _PremiumMarqueeItem(
          title: profile.businessName.trim().isEmpty
              ? 'Online TCG Shop'
              : profile.businessName.trim(),
          subtitle: profile.website.trim().isEmpty
              ? 'Featured online shop'
              : profile.website.trim(),
          icon: Icons.language,
          imageUrl: _featuredBannerImageForProfile(profile),
          isOnline: true,
          onTap: () => _showOnlineBusinessDetails(profile),
        );
      }),
    ];

    if (premiumProfiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: _backgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: _PremiumMarqueeBanner(items: premiumProfiles),
    );
  }


  void _showOnlineBusinessDetails(BusinessProfile profile) {
    unawaited(
      _businessProfileService.incrementBusinessAnalyticsMetric(
        businessId: profile.id,
        metric: 'mapViews',
      ),
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        final website = profile.website.trim();
        final phone = profile.phone.trim();
        final location = profile.displayLocation;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeaturedBadge(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 29,
                        backgroundColor: _fieldColor,
                        child: profile.logoUrl.trim().isEmpty
                            ? const Icon(
                                Icons.language,
                                color: _goldColor,
                                size: 30,
                              )
                            : ClipOval(
                                child: Image.network(
                                  profile.logoUrl.trim(),
                                  width: 58,
                                  height: 58,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.language,
                                      color: _goldColor,
                                      size: 30,
                                    );
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          profile.businessName.trim().isEmpty
                              ? 'Online TCG Shop'
                              : profile.businessName.trim(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BusinessRatingSummary(
                    businessId: profile.id,
                    starColor: _goldColor,
                    textColor: Colors.white,
                    mutedTextColor: _softTextColor,
                    onTap: () => _openBusinessReviews(bottomSheetContext, profile),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _goldColor,
                        side: const BorderSide(color: _goldColor),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.star_rate_rounded),
                      label: const Text(
                        'Reviews',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () =>
                          _openBusinessReviews(bottomSheetContext, profile),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BusinessOffersPreview(
                    profile: profile,
                    compact: true,
                    maxItems: 2,
                  ),
                  const SizedBox(height: 12),
                  BusinessProductsPreview(
                    profile: profile,
                    compact: true,
                    maxItems: 3,
                  ),
                  if (profile.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      profile.description.trim(),
                      style: const TextStyle(
                        color: _softTextColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip('Online Shop'),
                      if (location.isNotEmpty) _buildChip(location),
                      if (profile.autoFeaturePosts) _buildChip('Featured Posts'),
                    ],
                  ),
                  if (website.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _goldColor,
                          foregroundColor: _backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text(
                          'Open website',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        onPressed: () async {
                          await _businessProfileService
                              .incrementBusinessAnalyticsMetric(
                            businessId: profile.id,
                            metric: 'websiteClicks',
                          );
                          await _openWebsite(website);
                        },
                      ),
                    ),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _fieldColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            color: _goldColor,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: SelectableText(
                              phone,
                              style: const TextStyle(
                                color: _softTextColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('TCG Shop Map'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Shop events',
            icon: const Icon(Icons.event_available_outlined),
            color: _goldColor,
            onPressed: _openEventsDirectoryPage,
          ),
          IconButton(
            tooltip: 'Deals & offers',
            icon: const Icon(Icons.local_offer_outlined),
            color: _goldColor,
            onPressed: _openDealsPage,
          ),
          IconButton(
            tooltip: 'Online shops',
            icon: const Icon(Icons.language),
            color: _goldColor,
            onPressed: _openOnlineShopsPage,
          ),
          IconButton(
            tooltip: 'Add TCG shop',
            icon: const Icon(Icons.add_location_alt_outlined),
            color: _goldColor,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AddTcgShopPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<TcgShop>>(
        stream: _shopService.watchApprovedShops(),
        builder: (context, shopSnapshot) {
          if (shopSnapshot.hasError) {
            return _buildMapError(shopSnapshot.error!);
          }

          if (!shopSnapshot.hasData) {
            return const ColoredBox(
              color: _backgroundColor,
              child: Center(
                child: CircularProgressIndicator(color: _goldColor),
              ),
            );
          }

          final approvedShops = shopSnapshot.data ?? const <TcgShop>[];

          return StreamBuilder<List<BusinessProfile>>(
            stream: _businessProfileService.watchMapPremiumBusinessProfiles(),
            builder: (context, profileSnapshot) {
              final featuredProfiles =
                  profileSnapshot.data ?? const <BusinessProfile>[];
              final featuredProfilesByShopId = _profilesByLinkedShopId(
                featuredProfiles,
              );

              final filteredShops = _applyFilters(approvedShops);
              final shops = _sortFeaturedFirst(
                filteredShops,
                featuredProfilesByShopId,
              );
              final markers = _buildMapMarkers(
                shops,
                featuredProfilesByShopId,
              );

              return Column(
                children: [
                  _buildFilterPanel(),
                  _buildEventsDirectoryButton(),
                  _buildDealsDirectoryButton(),
                  _buildOnlineShopsDirectoryButton(),
                  _buildPremiumBanners(
                    shops: approvedShops,
                    featuredProfiles: featuredProfiles,
                  ),
                  Expanded(
                    child: Container(
                      color: _backgroundColor,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        child: Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: const LatLng(54.5, -2.5),
                                initialZoom: _initialZoom,
                                minZoom: 4,
                                maxZoom: 18,
                                onPositionChanged: (camera, hasGesture) {
                                  if ((camera.zoom - _currentZoom).abs() <
                                      0.05) {
                                    return;
                                  }

                                  if (!mounted) return;
                                  setState(() {
                                    _currentZoom = camera.zoom;
                                  });
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.jamielong.pocketchase',
                                ),
                                MarkerLayer(markers: markers),
                                const RichAttributionWidget(
                                  attributions: [
                                    TextSourceAttribution(
                                      'OpenStreetMap contributors',
                                    ),

                                  ],
                                ),
                              ],
                            ),
                            Positioned(
                              top: 10,
                              left: 12,
                              right: 12,
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: _currentZoom < _showIndividualPinsZoom
                                      ? 1
                                      : 0,
                                  duration: const Duration(milliseconds: 220),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _backgroundColor.withValues(
                                          alpha: 0.82,
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: _goldColor.withValues(
                                            alpha: 0.55,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Zoom in to separate nearby shops',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _goldColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-tcg-shop',
        backgroundColor: _goldColor,
        foregroundColor: _backgroundColor,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text(
          'Add shop',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AddTcgShopPage(),
            ),
          );
        },
      ),
    );
  }

  void _showClusterDetails(
    _ShopMapMarkerCluster cluster,
    Map<String, BusinessProfile> featuredProfilesByShopId,
  ) {
    final shops = _sortFeaturedFirst(cluster.shops, featuredProfilesByShopId);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _clusterTitle(cluster),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Zoom in to separate the pins, or tap a shop below.',
                    style: TextStyle(
                      color: _softTextColor,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...shops.map((shop) {
                    final address = shop.singleLineAddress;
                    final featuredProfile = featuredProfilesByShopId[shop.id];
                    final isFeatured = featuredProfile != null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(bottomSheetContext).pop();
                          _showShopDetails(shop, featuredProfile);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _fieldColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isFeatured ? _goldColor : _borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isFeatured
                                    ? Icons.workspace_premium
                                    : Icons.location_on,
                                color: isFeatured ? _goldColor : _pinRedColor,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            shop.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        if (isFeatured) _buildFeaturedBadge(),
                                      ],
                                    ),
                                    if (address.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        address,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _softTextColor,
                                          fontSize: 12,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: _goldColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _confirmDeleteShop(
    BuildContext bottomSheetContext,
    TcgShop shop,
  ) async {
    final shopName = shop.name.trim().isEmpty ? 'this shop' : shop.name.trim();

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete shop from map?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will permanently remove "$shopName" from the TCG Shop Map. '
            'Any business profile linked to this map listing will be unlinked and will need to choose online-only or link another map shop.',
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
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _deleteShopCompletely(shop.id);

      if (!mounted) return;

      if (bottomSheetContext.mounted) {
        Navigator.of(bottomSheetContext).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$shopName" was deleted from the map.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete shop: $error')),
      );
    }
  }

  Future<void> _deleteShopCompletely(String shopId) async {
    final cleanShopId = shopId.trim();
    if (cleanShopId.isEmpty) {
      throw ArgumentError('Missing shop id.');
    }

    final linkedBusinessProfiles = await _firestore
        .collection('business_profiles')
        .where('linkedShopId', isEqualTo: cleanShopId)
        .get();

    final operations = <void Function(WriteBatch)>[
      (batch) {
        batch.delete(_firestore.collection('tcg_shops').doc(cleanShopId));
      },
      (batch) {
        // If the approved shop was created from a submission using the same
        // document id, remove that old submission record too. Deleting a
        // non-existing doc is safe.
        batch.delete(
          _firestore.collection('tcg_shop_submissions').doc(cleanShopId),
        );
      },
      for (final profile in linkedBusinessProfiles.docs)
        (batch) {
          batch.update(profile.reference, <String, Object?>{
            'linkedShopId': '',
            'linkedShopName': '',
            'hasPhysicalShop': false,
            'featuredShopEnabled': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
    ];

    for (var start = 0; start < operations.length; start += 450) {
      final batch = _firestore.batch();
      final end = (start + 450) > operations.length
          ? operations.length
          : start + 450;

      for (final operation in operations.sublist(start, end)) {
        operation(batch);
      }

      await batch.commit();
    }
  }

  void _showShopDetails(TcgShop shop, BusinessProfile? featuredProfile) {
    if (featuredProfile != null) {
      unawaited(
        _businessProfileService.incrementBusinessAnalyticsMetric(
          businessId: featuredProfile.id,
          metric: 'mapViews',
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        final address = shop.singleLineAddress;
        final isFeatured = featuredProfile != null;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shop.hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          shop.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: _fieldColor,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: _softTextColor,
                                  size: 42,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (isFeatured) ...[
                    _buildFeaturedBadge(),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          shop.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StreamBuilder<bool>(
                        stream: _shopService.watchCurrentUserIsAdminOrModerator(),
                        builder: (context, snapshot) {
                          final canEdit = snapshot.data == true;
                          if (!canEdit) return const SizedBox.shrink();

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit shop',
                                color: _goldColor,
                                icon: const Icon(
                                  Icons.edit_location_alt_outlined,
                                ),
                                onPressed: () {
                                  Navigator.of(bottomSheetContext).pop();
                                  Navigator.of(this.context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          EditTcgShopPage(shop: shop),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete shop',
                                color: Colors.redAccent,
                                icon: const Icon(Icons.delete_forever_outlined),
                                onPressed: () =>
                                    _confirmDeleteShop(bottomSheetContext, shop),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  if (featuredProfile != null &&
                      featuredProfile.businessName != shop.name) ...[
                    const SizedBox(height: 6),
                    Text(
                      featuredProfile.businessName,
                      style: const TextStyle(
                        color: _goldColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  if (featuredProfile != null) ...[
                    const SizedBox(height: 8),
                    BusinessRatingSummary(
                      businessId: featuredProfile.id,
                      starColor: _goldColor,
                      textColor: Colors.white,
                      mutedTextColor: _softTextColor,
                      onTap: () =>
                          _openBusinessReviews(bottomSheetContext, featuredProfile),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _goldColor,
                        side: const BorderSide(color: _goldColor),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.star_rate_rounded),
                      label: const Text(
                        'Reviews',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () =>
                          _openBusinessReviews(bottomSheetContext, featuredProfile),
                    ),
                    const SizedBox(height: 12),
                    BusinessOffersPreview(
                      profile: featuredProfile,
                      compact: true,
                      maxItems: 2,
                    ),
                    const SizedBox(height: 12),
                    BusinessProductsPreview(
                      profile: featuredProfile,
                      compact: true,
                      maxItems: 3,
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (address.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openMapsForShop(shop),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _fieldColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _borderColor),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 18,
                              color: _goldColor,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _AddressText(),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.open_in_new,
                              size: 18,
                              color: _goldColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 38, top: 6),
                      child: Text(
                        address,
                        style: const TextStyle(
                          color: _softTextColor,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ),
                  if (shop.website.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openWebsite(shop.website),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _fieldColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.language,
                              size: 18,
                              color: _goldColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                shop.website,
                                style: const TextStyle(
                                  color: _goldColor,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _goldColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.open_in_new,
                              size: 18,
                              color: _goldColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (shop.phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 18,
                          color: _goldColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            shop.phone,
                            style: const TextStyle(color: _softTextColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (shop.games.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shop.games
                          .map((game) => _buildChip(_label(game)))
                          .toList(),
                    ),
                  ],
                  if (shop.services.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shop.services
                          .map((service) => _buildChip(_label(service)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMapsForShop(TcgShop shop) async {
    final query = shop.singleLineAddress.trim().isNotEmpty
        ? shop.singleLineAddress.trim()
        : '${shop.lat},${shop.lng}';

    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': query,
      },
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your maps app.')),
      );
    }
  }

  Future<void> _openWebsite(String website) async {
    final cleanWebsite = website.trim();
    if (cleanWebsite.isEmpty) return;

    final url = cleanWebsite.startsWith('http://') ||
            cleanWebsite.startsWith('https://')
        ? cleanWebsite
        : 'https://$cleanWebsite';

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this website.')),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this website.')),
      );
    }
  }
}

class _PremiumMarqueeItem {
  const _PremiumMarqueeItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.imageUrl,
    required this.isOnline,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String imageUrl;
  final bool isOnline;
  final VoidCallback onTap;
}

class _PremiumMarqueeBanner extends StatefulWidget {
  const _PremiumMarqueeBanner({
    required this.items,
  });

  final List<_PremiumMarqueeItem> items;

  @override
  State<_PremiumMarqueeBanner> createState() => _PremiumMarqueeBannerState();
}

class _PremiumMarqueeBannerState extends State<_PremiumMarqueeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _cardWidth = 160;
  static const double _cardHeight = 40;
  static const double _gap = 8;
  static const double _bannerHeight = 48;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: widget.items.length <= 1 ? 11 : 9 + (widget.items.length * 3),
      ),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _PremiumMarqueeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.items.length != widget.items.length) {
      _controller.duration = Duration(
        seconds: widget.items.length <= 1 ? 11 : 9 + (widget.items.length * 3),
      );
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_PremiumMarqueeItem> _repeatedItemsForWidth(double width) {
    if (widget.items.isEmpty) return const <_PremiumMarqueeItem>[];

    final itemWidth = _cardWidth + _gap;
    final minimumItemsNeeded = ((width / itemWidth).ceil() + widget.items.length + 2)
        .clamp(widget.items.length * 3, widget.items.length * 8);

    return List<_PremiumMarqueeItem>.generate(
      minimumItemsNeeded,
      (index) => widget.items[index % widget.items.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final singleSetWidth = widget.items.length * (_cardWidth + _gap);

    return SizedBox(
      height: _bannerHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _TcgShopMapPageState._cardColor.withValues(alpha: 0.98),
            border: Border.all(
              color: _TcgShopMapPageState._goldColor.withValues(alpha: 0.24),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final repeatedItems = _repeatedItemsForWidth(constraints.maxWidth);

              return ClipRect(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final offset = singleSetWidth * _controller.value;

                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (var index = 0; index < repeatedItems.length; index++)
                          Positioned(
                            left: (index * (_cardWidth + _gap)) - offset,
                            top: (_bannerHeight - _cardHeight) / 2,
                            width: _cardWidth,
                            height: _cardHeight,
                            child: _PremiumMarqueeCard(
                              item: repeatedItems[index],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PremiumMarqueeCard extends StatelessWidget {
  const _PremiumMarqueeCard({
    required this.item,
  });

  final _PremiumMarqueeItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(13),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _PremiumMarqueeCardBackground(
                imageUrl: item.imageUrl,
                fallbackIcon: item.icon,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.60),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 9,
                right: 9,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.title.trim().isEmpty ? 'Featured shop' : item.title.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
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

class _PremiumMarqueeCardBackground extends StatelessWidget {
  const _PremiumMarqueeCardBackground({
    required this.imageUrl,
    required this.fallbackIcon,
  });

  final String imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final cleanImageUrl = imageUrl.trim();

    if (cleanImageUrl.isEmpty) {
      return Container(
        color: _TcgShopMapPageState._fieldColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 10),
        child: Icon(
          fallbackIcon,
          color: _TcgShopMapPageState._goldColor.withValues(alpha: 0.85),
          size: 21,
        ),
      );
    }

    return Image.network(
      cleanImageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: _TcgShopMapPageState._fieldColor,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 10),
          child: Icon(
            fallbackIcon,
            color: _TcgShopMapPageState._goldColor.withValues(alpha: 0.85),
            size: 21,
          ),
        );
      },
    );
  }
}

class _ShopMapMarkerCluster {
  const _ShopMapMarkerCluster({
    required this.shops,
    required this.center,
    required this.hasFeaturedShop,
  });

  final List<TcgShop> shops;
  final LatLng center;
  final bool hasFeaturedShop;

  int get count => shops.length;
}

class _AddressText extends StatelessWidget {
  const _AddressText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Open address in Maps',
      style: TextStyle(
        color: _TcgShopMapPageState._goldColor,
        decoration: TextDecoration.underline,
        decorationColor: _TcgShopMapPageState._goldColor,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
