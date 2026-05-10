import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../services/tcg_shop_service.dart';

class AddTcgShopPage extends StatefulWidget {
  const AddTcgShopPage({super.key});

  @override
  State<AddTcgShopPage> createState() => _AddTcgShopPageState();
}

class _AddTcgShopPageState extends State<AddTcgShopPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TcgShopService _shopService = TcgShopService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _townController = TextEditingController();
  final TextEditingController _countyController = TextEditingController();
  final TextEditingController _countryController =
      TextEditingController(text: 'United Kingdom');
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  LatLng? _pickedPoint;
  Uint8List? _pickedImageBytes;
  String _pickedImageName = 'shop_photo.jpg';
  bool _saving = false;
  bool _pickingImage = false;

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

  final Set<String> _selectedGames = <String>{'pokemon'};
  final Set<String> _selectedServices = <String>{'sealed'};

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
        title: const Text('Add TCG Shop'),
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
                        Icons.info_outline,
                        color: _goldColor,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Submit a real TCG shop for review. It will only appear on the public map after an admin or moderator approves it.',
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
                'Shop photo optional',
                style: _sectionTitleStyle,
              ),
              const SizedBox(height: 8),
              Text(
                'Add a photo of the shop front or shop logo. Photos must be 5MB or smaller.',
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 10),
              _buildPhotoPicker(),
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
                'Tap the map where the shop is. This keeps the feature free because we are not paying for address lookup.',
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 280,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _pickedPoint ?? const LatLng(54.5, -2.5),
                      initialZoom: _pickedPoint == null ? 5.5 : 15,
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
                      if (_pickedPoint != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _pickedPoint!,
                              width: 48,
                              height: 48,
                              child: const Icon(
                                Icons.location_on,
                                color: _goldColor,
                                size: 42,
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
                _pickedPoint == null
                    ? 'No location selected yet.'
                    : 'Selected: ${_pickedPoint!.latitude.toStringAsFixed(6)}, ${_pickedPoint!.longitude.toStringAsFixed(6)}',
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
                    : const Icon(Icons.send_outlined),
                label: Text(_saving ? 'Submitting...' : 'Submit for review'),
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    final hasPhoto = _pickedImageBytes != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: hasPhoto
                ? Image.memory(
                    _pickedImageBytes!,
                    height: 180,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 150,
                    color: _fieldColor,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: _goldColor,
                          size: 42,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No photo selected',
                          style: TextStyle(
                            color: _softTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _pickingImage ? null : _pickPhoto,
                  style: FilledButton.styleFrom(
                    backgroundColor: _goldColor,
                    foregroundColor: _backgroundColor,
                  ),
                  icon: _pickingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(hasPhoto ? 'Change photo' : 'Upload photo'),
                ),
                if (hasPhoto)
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _clearPhoto,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: _borderColor),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    setState(() => _pickingImage = true);

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > TcgShopService.maxShopImageBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a photo under 5MB.')),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = picked.name.trim().isEmpty ? 'shop_photo.jpg' : picked.name;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not choose photo: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _pickingImage = false);
      }
    }
  }

  void _clearPhoto() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageName = 'shop_photo.jpg';
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_pickedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap the map to choose the shop location.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _shopService.submitShop(
        name: _nameController.text,
        address: _addressController.text,
        town: _townController.text,
        county: _countyController.text,
        country: _countryController.text,
        postcode: _postcodeController.text,
        lat: _pickedPoint!.latitude,
        lng: _pickedPoint!.longitude,
        games: _selectedGames.toList(),
        services: _selectedServices.toList(),
        website: _websiteController.text,
        phone: _phoneController.text,
        imageBytes: _pickedImageBytes,
        imageFileName: _pickedImageName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop submitted for admin review.')),
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
