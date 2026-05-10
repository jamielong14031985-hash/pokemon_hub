import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/tcg_shop.dart';
import '../services/tcg_shop_service.dart';

class EditTcgShopPage extends StatefulWidget {
  const EditTcgShopPage({
    super.key,
    required this.shop,
  });

  final TcgShop shop;

  @override
  State<EditTcgShopPage> createState() => _EditTcgShopPageState();
}

class _EditTcgShopPageState extends State<EditTcgShopPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _pinRedColor = Color(0xFFD62828);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TcgShopService _shopService = TcgShopService();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _townController;
  late final TextEditingController _countyController;
  late final TextEditingController _countryController;
  late final TextEditingController _postcodeController;
  late final TextEditingController _websiteController;
  late final TextEditingController _phoneController;

  late LatLng _pickedPoint;
  bool _saving = false;

  static const List<String> _gameOptions = <String>[
    'pokemon',
    'yugioh',
    'mtg',
    'lorcana',
    'one piece',
    'other',
  ];

  static const List<String> _serviceOptions = <String>[
    'sealed',
    'singles',
    'tournaments',
    'trade nights',
    'buys cards',
    'grading',
    'online shop',
  ];

  late final Set<String> _selectedGames;
  late final Set<String> _selectedServices;

  @override
  void initState() {
    super.initState();

    final shop = widget.shop;
    _nameController = TextEditingController(text: shop.name);
    _addressController = TextEditingController(text: shop.address);
    _townController = TextEditingController(text: shop.town);
    _countyController = TextEditingController(text: shop.county);
    _countryController = TextEditingController(
      text: shop.country.trim().isEmpty ? 'United Kingdom' : shop.country,
    );
    _postcodeController = TextEditingController(text: shop.postcode);
    _websiteController = TextEditingController(text: shop.website);
    _phoneController = TextEditingController(text: shop.phone);
    _pickedPoint = LatLng(shop.lat, shop.lng);
    _selectedGames = shop.games.toSet();
    _selectedServices = shop.services.toSet();

    if (_selectedGames.isEmpty) {
      _selectedGames.add('pokemon');
    }
    if (_selectedServices.isEmpty) {
      _selectedServices.add('sealed');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _townController.dispose();
    _countyController.dispose();
    _countryController.dispose();
    _postcodeController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _label(String value) {
    return value
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  InputDecoration _inputDecoration({
    required String labelText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: _softTextColor),
      floatingLabelStyle: const TextStyle(
        color: _goldColor,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              color: _softTextColor,
            ),
      filled: true,
      fillColor: _fieldColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _goldColor, width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.7),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFFB4AB)),
    );
  }

  Widget _buildOptionChip({
    required String value,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(_label(value)),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      selected: selected,
      onSelected: onSelected,
      checkmarkColor: Colors.white,
      backgroundColor: _fieldColor,
      selectedColor: const Color(0xFF1E4B95),
      side: BorderSide(
        color: selected ? _goldColor : _borderColor,
        width: selected ? 1.6 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  TextStyle get _sectionTitleStyle {
    return const TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w900,
    );
  }

  TextStyle get _bodyTextStyle {
    return const TextStyle(
      color: _softTextColor,
      fontSize: 14,
      height: 1.4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Edit TCG Shop'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: _cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: _borderColor),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        color: _goldColor,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Admin edit mode. Changes are saved directly to the live public shop pin.',
                          style: TextStyle(
                            color: _softTextColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                cursorColor: _goldColor,
                decoration: _inputDecoration(
                  labelText: 'Shop name',
                  prefixIcon: Icons.storefront_outlined,
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter the shop name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                style: const TextStyle(color: Colors.white),
                cursorColor: _goldColor,
                decoration: _inputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icons.home_outlined,
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _townController,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: _goldColor,
                      decoration: _inputDecoration(
                        labelText: 'Town / city',
                        prefixIcon: Icons.location_city_outlined,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _countyController,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: _goldColor,
                      decoration: _inputDecoration(
                        labelText: 'County / area',
                        prefixIcon: Icons.map_outlined,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _postcodeController,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: _goldColor,
                      decoration: _inputDecoration(
                        labelText: 'Postcode',
                        prefixIcon: Icons.local_post_office_outlined,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _countryController,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: _goldColor,
                      decoration: _inputDecoration(
                        labelText: 'Country',
                        prefixIcon: Icons.public_outlined,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _websiteController,
                style: const TextStyle(color: Colors.white),
                cursorColor: _goldColor,
                decoration: _inputDecoration(
                  labelText: 'Website or social link optional',
                  prefixIcon: Icons.language_outlined,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                cursorColor: _goldColor,
                decoration: _inputDecoration(
                  labelText: 'Phone optional',
                  prefixIcon: Icons.phone_outlined,
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 18),
              Text(
                'Games sold',
                style: _sectionTitleStyle,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _gameOptions.map((game) {
                  final selected = _selectedGames.contains(game);
                  return _buildOptionChip(
                    value: game,
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedGames.add(game);
                        } else {
                          _selectedGames.remove(game);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'Shop services',
                style: _sectionTitleStyle,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _serviceOptions.map((service) {
                  final selected = _selectedServices.contains(service);
                  return _buildOptionChip(
                    value: service,
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedServices.add(service);
                        } else {
                          _selectedServices.remove(service);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'Shop location',
                style: _sectionTitleStyle,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the map to move the shop pin.',
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 280,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _pickedPoint,
                      initialZoom: 15,
                      minZoom: 4,
                      maxZoom: 18,
                      onTap: (tapPosition, point) {
                        setState(() => _pickedPoint = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.jamielong.pocketchase',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pickedPoint,
                            width: 52,
                            height: 52,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.black.withValues(alpha: 0.30),
                                  size: 50,
                                ),
                                const Icon(
                                  Icons.location_on,
                                  color: _pinRedColor,
                                  size: 44,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selected: ${_pickedPoint.latitude.toStringAsFixed(6)}, ${_pickedPoint.longitude.toStringAsFixed(6)}',
                style: const TextStyle(color: _softTextColor),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _goldColor,
                  foregroundColor: _backgroundColor,
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save shop changes'),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _saving = true);

    try {
      await _shopService.updateShop(
        shopId: widget.shop.id,
        name: _nameController.text,
        address: _addressController.text,
        town: _townController.text,
        county: _countyController.text,
        country: _countryController.text,
        postcode: _postcodeController.text,
        lat: _pickedPoint.latitude,
        lng: _pickedPoint.longitude,
        games: _selectedGames.toList(),
        services: _selectedServices.toList(),
        website: _websiteController.text,
        phone: _phoneController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop updated.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
