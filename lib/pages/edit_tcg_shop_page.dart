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

  static const List<String> _availableGames = <String>[
    'pokemon',
    'yugioh',
    'mtg',
    'lorcana',
    'one piece',
    'other',
  ];

  static const List<String> _availableServices = <String>[
    'sealed',
    'singles',
    'tournaments',
    'trade nights',
    'buys cards',
    'grading',
    'online shop',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TcgShopService _shopService = TcgShopService();
  final MapController _mapController = MapController();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _townController;
  late final TextEditingController _countyController;
  late final TextEditingController _countryController;
  late final TextEditingController _postcodeController;
  late final TextEditingController _websiteController;
  late final TextEditingController _phoneController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  late LatLng _selectedPoint;
  late Set<String> _selectedGames;
  late Set<String> _selectedServices;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final shop = widget.shop;
    _selectedPoint = LatLng(shop.lat, shop.lng);
    _selectedGames = shop.games.toSet();
    _selectedServices = shop.services.toSet();

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
    _latController = TextEditingController(text: _formatCoordinate(shop.lat));
    _lngController = TextEditingController(text: _formatCoordinate(shop.lng));
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
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  String _formatCoordinate(double value) {
    return value.toStringAsFixed(6);
  }

  String _label(String value) {
    return value
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: _goldColor),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: _softTextColor,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 12);

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      cursorColor: _goldColor,
      validator: (value) {
        final cleanValue = (value ?? '').trim();
        if (requiredField && cleanValue.isEmpty) {
          return '$label is required.';
        }
        return null;
      },
      decoration: _inputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon,
      ),
    );
  }

  Widget _buildCoordinateField({
    required TextEditingController controller,
    required String label,
    required bool isLatitude,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      style: const TextStyle(color: Colors.white),
      cursorColor: _goldColor,
      validator: (value) {
        final coordinate = double.tryParse((value ?? '').trim());

        if (coordinate == null) {
          return 'Enter a valid number.';
        }

        if (isLatitude && (coordinate < -90 || coordinate > 90)) {
          return 'Latitude must be between -90 and 90.';
        }

        if (!isLatitude && (coordinate < -180 || coordinate > 180)) {
          return 'Longitude must be between -180 and 180.';
        }

        return null;
      },
      decoration: _inputDecoration(
        labelText: label,
        prefixIcon: isLatitude ? Icons.north_outlined : Icons.east_outlined,
      ),
    );
  }

  Widget _buildMultiSelect({
    required String title,
    required List<String> values,
    required Set<String> selectedValues,
    required ValueChanged<Set<String>> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _softTextColor,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: values.map((value) {
              final selected = selectedValues.contains(value);

              return CheckboxListTile(
                value: selected,
                dense: true,
                visualDensity: VisualDensity.compact,
                activeColor: _goldColor,
                checkColor: _backgroundColor,
                side: const BorderSide(color: _softTextColor),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  _label(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onChanged: (checked) {
                  final nextValues = Set<String>.from(selectedValues);
                  if (checked == true) {
                    nextValues.add(value);
                  } else {
                    nextValues.remove(value);
                  }
                  onChanged(nextValues);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint,
              initialZoom: 16,
              minZoom: 4,
              maxZoom: 18,
              onTap: (tapPosition, point) {
                _setSelectedPoint(point, moveMap: false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jamielong.pocketchase',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPoint,
                    width: 54,
                    height: 54,
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
        const SizedBox(height: 8),
        const Text(
          'Tap the map to move the shop pin. You can also type exact latitude and longitude below, then press “Update pin from coordinates”.',
          style: TextStyle(
            color: _softTextColor,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCoordinateField(
                controller: _latController,
                label: 'Latitude',
                isLatitude: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCoordinateField(
                controller: _lngController,
                label: 'Longitude',
                isLatitude: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _goldColor,
              side: const BorderSide(color: _goldColor),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.my_location_outlined),
            label: const Text(
              'Update pin from coordinates',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: _updatePinFromCoordinates,
          ),
        ),
      ],
    );
  }

  void _setSelectedPoint(LatLng point, {required bool moveMap}) {
    setState(() {
      _selectedPoint = point;
      _latController.text = _formatCoordinate(point.latitude);
      _lngController.text = _formatCoordinate(point.longitude);
    });

    if (moveMap) {
      _mapController.move(point, 16);
    }
  }

  void _updatePinFromCoordinates() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid latitude and longitude.')),
      );
      return;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The coordinates are outside the valid range.')),
      );
      return;
    }

    _setSelectedPoint(LatLng(lat, lng), moveMap: true);
  }

  Future<void> _saveShop() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid shop location.')),
      );
      return;
    }

    if (lat == 0 && lng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose the real shop location.')),
      );
      return;
    }

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
        lat: lat,
        lng: lng,
        games: _selectedGames.toList(),
        services: _selectedServices.toList(),
        website: _websiteController.text,
        phone: _phoneController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TCG shop updated.')),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update shop: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _goldColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _goldColor),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.admin_panel_settings_outlined, color: _goldColor),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Admin edit mode. Changes save straight to the approved shop shown on the public map.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _sectionCard(
                title: 'Shop details',
                icon: Icons.storefront_outlined,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Shop name',
                    icon: Icons.storefront_outlined,
                    requiredField: true,
                  ),
                  _gap(),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Address',
                    icon: Icons.location_city_outlined,
                    maxLines: 2,
                  ),
                  _gap(),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _townController,
                          label: 'Town',
                          requiredField: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _countyController,
                          label: 'County',
                        ),
                      ),
                    ],
                  ),
                  _gap(),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _postcodeController,
                          label: 'Postcode',
                          requiredField: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _countryController,
                          label: 'Country',
                          requiredField: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _sectionCard(
                title: 'Map location',
                icon: Icons.edit_location_alt_outlined,
                subtitle:
                    'Use this to fix shops that appear in the wrong place on the map.',
                children: [
                  _buildLocationMap(),
                ],
              ),
              _sectionCard(
                title: 'Contact',
                icon: Icons.contact_phone_outlined,
                children: [
                  _buildTextField(
                    controller: _websiteController,
                    label: 'Website',
                    icon: Icons.language,
                    keyboardType: TextInputType.url,
                  ),
                  _gap(),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              _sectionCard(
                title: 'Games and services',
                icon: Icons.category_outlined,
                children: [
                  _buildMultiSelect(
                    title: 'Games',
                    values: _availableGames,
                    selectedValues: _selectedGames,
                    onChanged: (values) {
                      setState(() => _selectedGames = values);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMultiSelect(
                    title: 'Services',
                    values: _availableServices,
                    selectedValues: _selectedServices,
                    onChanged: (values) {
                      setState(() => _selectedServices = values);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: _backgroundColor,
            border: Border(
              top: BorderSide(color: _borderColor.withValues(alpha: 0.7)),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _goldColor,
                foregroundColor: _backgroundColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _backgroundColor,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _saving ? 'Saving...' : 'Save shop changes',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              onPressed: _saving ? null : _saveShop,
            ),
          ),
        ),
      ),
    );
  }
}
