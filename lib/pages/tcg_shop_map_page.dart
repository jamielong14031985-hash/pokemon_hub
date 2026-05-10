import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tcg_shop.dart';
import '../services/tcg_shop_service.dart';
import 'add_tcg_shop_page.dart';
import 'edit_tcg_shop_page.dart';

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
  static const double _showIndividualPinsZoom = 12.5;

  final TcgShopService _shopService = TcgShopService();
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

  Widget _buildFilterPanel() {
    return Container(
      color: _backgroundColor,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        padding: const EdgeInsets.all(12),
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

  double _clusterCellSizeDegrees() {
    if (_currentZoom >= _showIndividualPinsZoom) return 0;

    if (_currentZoom < 5.5) return 2.2;
    if (_currentZoom < 7) return 1.2;
    if (_currentZoom < 8.5) return 0.65;
    if (_currentZoom < 10) return 0.32;
    if (_currentZoom < 11.25) return 0.18;
    return 0.09;
  }

  double _clusterMarkerSize() {
    if (_currentZoom < 7) return 36;
    if (_currentZoom < 9) return 40;
    if (_currentZoom < 11) return 44;
    return 48;
  }

  List<_ShopMapMarkerCluster> _buildClusters(List<TcgShop> shops) {
    final cellSize = _clusterCellSizeDegrees();

    if (cellSize <= 0) {
      return shops
          .map(
            (shop) => _ShopMapMarkerCluster(
              shops: [shop],
              center: LatLng(shop.lat, shop.lng),
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
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  List<Marker> _buildMapMarkers(List<TcgShop> shops) {
    final clusters = _buildClusters(shops);

    return clusters.map((cluster) {
      if (cluster.count == 1) {
        final shop = cluster.shops.first;

        return Marker(
          point: cluster.center,
          width: 54,
          height: 54,
          child: GestureDetector(
            onTap: () => _showShopDetails(shop),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 52,
                  color: Colors.black.withValues(alpha: 0.30),
                ),
                const Icon(
                  Icons.location_on,
                  size: 46,
                  color: _pinRedColor,
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

      return Marker(
        point: cluster.center,
        width: markerSize,
        height: markerSize,
        child: GestureDetector(
          onTap: () => _showClusterDetails(cluster),
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
                  color: _pinRedColor,
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
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
      body: Column(
        children: [
          _buildFilterPanel(),
          Expanded(
            child: StreamBuilder<List<TcgShop>>(
              stream: _shopService.watchApprovedShops(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildMapError(snapshot.error!);
                }

                if (!snapshot.hasData) {
                  return const ColoredBox(
                    color: _backgroundColor,
                    child: Center(
                      child: CircularProgressIndicator(color: _goldColor),
                    ),
                  );
                }

                final shops = _applyFilters(snapshot.data ?? const <TcgShop>[]);
                final markers = _buildMapMarkers(shops);

                return Container(
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
                              if ((camera.zoom - _currentZoom).abs() < 0.05) {
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
                              userAgentPackageName: 'com.jamielong.pocketchase',
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
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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

  void _showClusterDetails(_ShopMapMarkerCluster cluster) {
    final shops = List<TcgShop>.from(cluster.shops)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(bottomSheetContext).pop();
                          _showShopDetails(shop);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _fieldColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: _pinRedColor,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shop.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
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

  void _showShopDetails(TcgShop shop) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        final address = shop.singleLineAddress;

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

                          return IconButton(
                            tooltip: 'Edit shop',
                            color: _goldColor,
                            icon: const Icon(Icons.edit_location_alt_outlined),
                            onPressed: () {
                              Navigator.of(bottomSheetContext).pop();
                              Navigator.of(this.context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EditTcgShopPage(shop: shop),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
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
                              size: 20,
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
                              size: 20,
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
                          size: 20,
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

class _ShopMapMarkerCluster {
  const _ShopMapMarkerCluster({
    required this.shops,
    required this.center,
  });

  final List<TcgShop> shops;
  final LatLng center;

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
