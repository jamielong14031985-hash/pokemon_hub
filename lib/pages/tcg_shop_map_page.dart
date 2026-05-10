import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tcg_shop.dart';
import '../services/tcg_shop_service.dart';
import 'add_tcg_shop_page.dart';

class TcgShopMapPage extends StatefulWidget {
  const TcgShopMapPage({super.key});

  @override
  State<TcgShopMapPage> createState() => _TcgShopMapPageState();
}

class _TcgShopMapPageState extends State<TcgShopMapPage> {
  final TcgShopService _shopService = TcgShopService();
  final TextEditingController _areaController = TextEditingController();

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

  Widget _buildMapError(Object error) {
    return Container(
      color: const Color(0xFF041B4A),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFFF7DE77),
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
              color: Color(0xFFC8D4F0),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TCG Shop Map'),
        actions: [
          IconButton(
            tooltip: 'Add TCG shop',
            icon: const Icon(Icons.add_location_alt_outlined),
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
          Material(
            color: theme.colorScheme.surface,
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _areaController,
                    decoration: InputDecoration(
                      hintText: 'Filter by town, county or postcode',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _areaController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear area filter',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _areaController.clear();
                                setState(() {});
                              },
                            ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedGame,
                          decoration: const InputDecoration(
                            labelText: 'Game',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
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
                          decoration: const InputDecoration(
                            labelText: 'Service',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
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
          ),
          Expanded(
            child: StreamBuilder<List<TcgShop>>(
              stream: _shopService.watchApprovedShops(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildMapError(snapshot.error!);
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final shops = _applyFilters(snapshot.data ?? const <TcgShop>[]);

                return Stack(
                  children: [
                    FlutterMap(
                      options: const MapOptions(
                        initialCenter: LatLng(54.5, -2.5),
                        initialZoom: 5.5,
                        minZoom: 4,
                        maxZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.jamielong.pocketchase',
                        ),
                        MarkerLayer(
                          markers: shops
                              .map(
                                (shop) => Marker(
                                  point: LatLng(shop.lat, shop.lng),
                                  width: 52,
                                  height: 52,
                                  child: GestureDetector(
                                    onTap: () => _showShopDetails(shop),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 50,
                                          color: Colors.black.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                        Icon(
                                          Icons.location_on,
                                          size: 44,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
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
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            '${shops.length} approved TCG shop${shops.length == 1 ? '' : 's'} shown',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-tcg-shop',
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add shop'),
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

  void _showShopDetails(TcgShop shop) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
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
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined, size: 42),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    shop.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (address.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openMapsForShop(shop),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.open_in_new,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (shop.website.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.language, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(shop.website)),
                      ],
                    ),
                  ],
                  if (shop.phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.phone_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(shop.phone)),
                      ],
                    ),
                  ],
                  if (shop.games.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shop.games
                          .map(
                            (game) => Chip(
                              label: Text(_label(game)),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (shop.services.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shop.services
                          .map(
                            (service) => Chip(
                              label: Text(_label(service)),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
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
}
