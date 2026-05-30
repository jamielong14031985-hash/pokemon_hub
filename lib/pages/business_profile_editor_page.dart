import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/business_profile.dart';
import '../models/tcg_shop.dart';
import '../services/business_profile_service.dart';
import '../services/tcg_shop_service.dart';
import 'add_tcg_shop_page.dart';

class BusinessProfileEditorPage extends StatefulWidget {
  const BusinessProfileEditorPage({
    super.key,
    this.profile,
    this.forceCompleteSetup = false,
  });

  final BusinessProfile? profile;
  final bool forceCompleteSetup;

  @override
  State<BusinessProfileEditorPage> createState() =>
      _BusinessProfileEditorPageState();
}


class _OpeningStatusOption {
  const _OpeningStatusOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.description,
  });

  final String value;
  final String label;
  final IconData icon;
  final String description;
}

class _BusinessProfileEditorPageState extends State<BusinessProfileEditorPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final BusinessProfileService _businessProfileService =
      BusinessProfileService();
  final TcgShopService _shopService = TcgShopService();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _businessNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _websiteController;
  late final TextEditingController _phoneController;
  late final TextEditingController _townController;
  late final TextEditingController _countyController;

  String _linkedShopId = '';
  String _linkedShopName = '';
  Uint8List? _featuredImageBytes;
  String _featuredImageFileName = 'featured_banner.jpg';
  bool _removeFeaturedImage = false;
  bool? _hasPhysicalShop;
  String _openingStatus = 'auto';
  final Map<String, bool> _openingClosed = <String, bool>{};
  final Map<String, TextEditingController> _openingOpenControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _openingCloseControllers =
      <String, TextEditingController>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final profile = widget.profile;

    _businessNameController = TextEditingController(
      text: profile?.businessName ?? '',
    );
    _descriptionController = TextEditingController(
      text: profile?.description ?? '',
    );
    _websiteController = TextEditingController(
      text: profile?.website ?? '',
    );
    _phoneController = TextEditingController(
      text: profile?.phone ?? '',
    );
    _townController = TextEditingController(
      text: profile?.town ?? '',
    );
    _countyController = TextEditingController(
      text: profile?.county ?? '',
    );

    _linkedShopId = profile?.linkedShopId ?? '';
    _linkedShopName = profile?.linkedShopName ?? '';
    _hasPhysicalShop = profile?.hasPhysicalShop;
    _openingStatus = profile?.openingStatus ?? 'auto';

    for (final dayKey in BusinessOpeningHours.dayKeys) {
      final hours = profile?.openingHoursForDay(dayKey) ??
          BusinessOpeningHours.defaultForDay(dayKey);

      _openingClosed[dayKey] = hours.closed;
      _openingOpenControllers[dayKey] = TextEditingController(
        text: hours.open,
      );
      _openingCloseControllers[dayKey] = TextEditingController(
        text: hours.close,
      );
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _townController.dispose();
    _countyController.dispose();

    for (final controller in _openingOpenControllers.values) {
      controller.dispose();
    }
    for (final controller in _openingCloseControllers.values) {
      controller.dispose();
    }

    super.dispose();
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = false,
    int maxLines = 1,
    int maxLength = 300,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
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

  Widget _buildSection({
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

  Widget _buildLinkedShopDropdown() {
    return StreamBuilder<List<TcgShop>>(
      stream: _shopService.watchApprovedShops(),
      builder: (context, snapshot) {
        final shops = snapshot.data ?? const <TcgShop>[];
        final items = <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(
            value: '',
            child: Text('No linked shop yet'),
          ),
          ...shops.map(
            (shop) => DropdownMenuItem<String>(
              value: shop.id,
              child: Text(
                shop.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ];

        final shopIds = shops.map((shop) => shop.id).toSet();
        final safeSelectedShopId =
            _linkedShopId.isNotEmpty && shopIds.contains(_linkedShopId)
                ? _linkedShopId
                : '';

        if (_linkedShopId.isNotEmpty && safeSelectedShopId.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _linkedShopId = '';
              _linkedShopName = '';
            });
          });
        }

        return DropdownButtonFormField<String>(
          initialValue: safeSelectedShopId,
          isExpanded: true,
          dropdownColor: _fieldColor,
          iconEnabledColor: _softTextColor,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          decoration: _inputDecoration(
            labelText: 'Linked TCG shop',
            prefixIcon: Icons.store_mall_directory_outlined,
          ),
          items: items,
          onChanged: (value) {
            final selectedShopId = value ?? '';
            TcgShop? selectedShop;

            for (final shop in shops) {
              if (shop.id == selectedShopId) {
                selectedShop = shop;
                break;
              }
            }

            setState(() {
              _linkedShopId = selectedShopId;
              _linkedShopName = selectedShop?.name ?? '';
            });
          },
        );
      },
    );
  }



  bool get _hasExistingFeaturedImage {
    return !_removeFeaturedImage &&
        widget.profile?.bannerUrl.trim().isNotEmpty == true;
  }

  Widget _buildFeaturedBannerImagePicker() {
    final hasNewImage = _featuredImageBytes != null;
    final existingImageUrl = widget.profile?.bannerUrl.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasNewImage)
                Image.memory(
                  _featuredImageBytes!,
                  fit: BoxFit.cover,
                )
              else if (_hasExistingFeaturedImage)
                Image.network(
                  existingImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFeaturedImagePlaceholder();
                  },
                )
              else
                _buildFeaturedImagePlaceholder(),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.58),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Text(
                  'This image is used on the moving featured banner on the TCG Shop Map when Business Pro is active.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _goldColor,
                  side: const BorderSide(color: _goldColor),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  hasNewImage || _hasExistingFeaturedImage
                      ? 'Change image'
                      : 'Upload image',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                onPressed: _saving ? null : _pickFeaturedBannerImage,
              ),
            ),
            if (hasNewImage || _hasExistingFeaturedImage) ...[
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Remove featured image',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                ),
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _featuredImageBytes = null;
                          _featuredImageFileName = 'featured_banner.jpg';
                          _removeFeaturedImage = true;
                        });
                      },
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Recommended: a wide landscape image. Maximum upload size: 5MB.',
          style: TextStyle(
            color: _softTextColor,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedImagePlaceholder() {
    return Container(
      color: _fieldColor,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              color: _goldColor,
              size: 38,
            ),
            SizedBox(height: 8),
            Text(
              'No featured banner image yet',
              style: TextStyle(
                color: _softTextColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFeaturedBannerImage() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );

    if (pickedImage == null) return;

    final bytes = await pickedImage.readAsBytes();

    if (!mounted) return;

    setState(() {
      _featuredImageBytes = bytes;
      _featuredImageFileName = pickedImage.name;
      _removeFeaturedImage = false;
    });
  }

  Widget _buildPhysicalShopSelector() {
    return Column(
      children: [
        _PhysicalShopOption(
          title: 'I have a physical shop',
          subtitle:
              'You must link your business profile to a shop listing on the TCG Shop Map.',
          icon: Icons.store_mall_directory_outlined,
          selected: _hasPhysicalShop == true,
          onTap: () {
            setState(() {
              _hasPhysicalShop = true;
            });
          },
        ),
        const SizedBox(height: 10),
        _PhysicalShopOption(
          title: 'Online-only / no physical shop',
          subtitle:
              'You can create a business profile without linking to the map.',
          icon: Icons.language,
          selected: _hasPhysicalShop == false,
          onTap: () {
            setState(() {
              _hasPhysicalShop = false;
              _linkedShopId = '';
              _linkedShopName = '';
            });
          },
        ),
      ],
    );
  }

  Widget _buildShopMapRequirementCard() {
    if (_hasPhysicalShop == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _goldColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _goldColor),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.touch_app_outlined, color: _goldColor, size: 20),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Choose whether this business has a physical shop or is online-only before continuing.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasPhysicalShop == false) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: _goldColor, size: 20),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'No map listing is needed because you selected online-only / no physical shop.',
                style: TextStyle(
                  color: _softTextColor,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLinkedShopDropdown(),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _linkedShopId.isEmpty
                ? Colors.redAccent.withValues(alpha: 0.10)
                : _goldColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _linkedShopId.isEmpty ? Colors.redAccent : _goldColor,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _linkedShopId.isEmpty
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: _linkedShopId.isEmpty ? Colors.redAccent : _goldColor,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _linkedShopId.isEmpty
                      ? 'Because this business has a physical shop, you must select the shop if it is already on the map, or add it to the map first.'
                      : 'This business is linked to "$_linkedShopName" on the TCG Shop Map.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _goldColor,
            side: const BorderSide(color: _goldColor),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text(
            'My shop is not on the map yet',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AddTcgShopPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),
        const SizedBox(height: 6),
        const Text(
          'If your shop has already been submitted and approved by another user, select it from the dropdown instead of adding it again.',
          style: TextStyle(
            color: _softTextColor,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }


  bool _validOpeningTime(String value) {
    final cleanValue = value.trim();
    final match = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').firstMatch(cleanValue);
    return match != null;
  }

  TimeOfDay _timeOfDayFromText(
    String value, {
    required TimeOfDay fallback,
  }) {
    final cleanValue = value.trim();
    final parts = cleanValue.split(':');

    if (parts.length != 2) return fallback;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _pickOpeningTime({
    required TextEditingController controller,
  }) async {
    FocusScope.of(context).unfocus();

    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromText(
        controller.text,
        fallback: now,
      ),
      initialEntryMode: TimePickerEntryMode.dial,
    );

    if (picked == null || !mounted) return;

    setState(() {
      controller.text = _formatTimeOfDay(picked);
    });
  }

  Widget _buildOpeningTimePicker({
    required TextEditingController controller,
    required TextEditingController pairedController,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      showCursor: false,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon,
      ).copyWith(
        suffixIcon: const Icon(
          Icons.expand_more,
          color: _softTextColor,
        ),
      ),
      onTap: () {
        _pickOpeningTime(controller: controller);
      },
      validator: (value) {
        final cleanValue = (value ?? '').trim();
        final pairedValue = pairedController.text.trim();

        if (cleanValue.isEmpty && pairedValue.isEmpty) return null;

        if (!_validOpeningTime(cleanValue)) {
          return 'Tap to choose';
        }

        return null;
      },
    );
  }

  Map<String, Map<String, dynamic>> _openingHoursPayload() {
    return <String, Map<String, dynamic>>{
      for (final dayKey in BusinessOpeningHours.dayKeys)
        dayKey: <String, dynamic>{
          'closed': _openingClosed[dayKey] == true,
          'open': _openingClosed[dayKey] == true
              ? ''
              : (_openingOpenControllers[dayKey]?.text.trim() ?? ''),
          'close': _openingClosed[dayKey] == true
              ? ''
              : (_openingCloseControllers[dayKey]?.text.trim() ?? ''),
        },
    };
  }

  bool _validateOpeningHours() {
    for (final dayKey in BusinessOpeningHours.dayKeys) {
      if (_openingClosed[dayKey] == true) continue;

      final open = _openingOpenControllers[dayKey]?.text.trim() ?? '';
      final close = _openingCloseControllers[dayKey]?.text.trim() ?? '';
      final label = BusinessOpeningHours.dayLabels[dayKey] ?? dayKey;

      if (open.isEmpty && close.isEmpty) {
        continue;
      }

      if (!_validOpeningTime(open) || !_validOpeningTime(close)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please choose both an opening and closing time for $label, or leave both blank.',
            ),
          ),
        );
        return false;
      }
    }

    return true;
  }


  Widget _buildOpeningStatusSelector() {
    const options = <_OpeningStatusOption>[
      _OpeningStatusOption(
        value: 'auto',
        label: 'Use times',
        icon: Icons.schedule_outlined,
        description: 'Open or closed is worked out from the weekly times below.',
      ),
      _OpeningStatusOption(
        value: 'open',
        label: 'Open now',
        icon: Icons.lock_open_outlined,
        description: 'Show this business as open until you change it.',
      ),
      _OpeningStatusOption(
        value: 'closed',
        label: 'Closed now',
        icon: Icons.lock_outline,
        description: 'Show this business as closed until you change it.',
      ),
    ];

    return Column(
      children: options.map((option) {
        final selected = _openingStatus == option.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: selected ? _goldColor : _fieldColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() => _openingStatus = option.value);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? _goldColor : _borderColor,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      option.icon,
                      color: selected ? _backgroundColor : _goldColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: TextStyle(
                              color:
                                  selected ? _backgroundColor : Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            option.description,
                            style: TextStyle(
                              color: selected
                                  ? _backgroundColor.withValues(alpha: 0.82)
                                  : _softTextColor,
                              height: 1.3,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? _backgroundColor : _softTextColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOpeningHoursEditor() {
    return Column(
      children: BusinessOpeningHours.dayKeys.map((dayKey) {
        final label = BusinessOpeningHours.dayLabels[dayKey] ?? dayKey;
        final closed = _openingClosed[dayKey] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    closed
                        ? 'Closed'
                        : ((_openingOpenControllers[dayKey]?.text.trim().isEmpty ?? true) &&
                                (_openingCloseControllers[dayKey]?.text.trim().isEmpty ?? true))
                            ? 'Not set'
                            : 'Open',
                    style: const TextStyle(
                      color: _softTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: !closed,
                    activeThumbColor: _goldColor,
                    onChanged: (value) {
                      setState(() {
                        _openingClosed[dayKey] = !value;
                      });
                    },
                  ),
                ],
              ),
              if (!closed) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildOpeningTimePicker(
                        controller: _openingOpenControllers[dayKey]!,
                        pairedController: _openingCloseControllers[dayKey]!,
                        label: 'Opens',
                        hint: 'Choose',
                        icon: Icons.access_time,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildOpeningTimePicker(
                        controller: _openingCloseControllers[dayKey]!,
                        pairedController: _openingOpenControllers[dayKey]!,
                        label: 'Closes',
                        hint: 'Choose',
                        icon: Icons.access_time_filled_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!_validateOpeningHours()) return;

    if (_hasPhysicalShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose whether this business has a physical shop or is online-only.',
          ),
        ),
      );
      return;
    }

    if (_hasPhysicalShop == true && _linkedShopId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Physical shops must be linked to a TCG Shop Map listing first.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _businessProfileService.saveMyBusinessProfile(
        businessProfileId: widget.profile?.id,
        businessName: _businessNameController.text,
        description: _descriptionController.text,
        linkedShopId: _linkedShopId,
        linkedShopName: _linkedShopName,
        hasPhysicalShop: _hasPhysicalShop == true,
        website: _websiteController.text,
        phone: _phoneController.text,
        town: _townController.text,
        county: _countyController.text,
        featuredImageBytes: _featuredImageBytes,
        featuredImageFileName: _featuredImageFileName,
        removeFeaturedImage: _removeFeaturedImage,
        openingHours: _openingHoursPayload(),
        openingStatus: _openingStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business profile saved.')),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.profile != null;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Business Profile' : 'Create Business Profile'),
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
                    Icon(Icons.storefront_outlined, color: _goldColor),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Business accounts can create an active business profile straight away. If you have a physical shop, link it to the TCG Shop Map.',
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
              _buildSection(
                title: 'Business details',
                icon: Icons.business_outlined,
                children: [
                  _buildTextField(
                    controller: _businessNameController,
                    label: 'Business name',
                    icon: Icons.storefront_outlined,
                    requiredField: true,
                    maxLength: 120,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Tell collectors what your shop offers',
                    icon: Icons.notes_outlined,
                    maxLines: 4,
                    maxLength: 500,
                  ),
                ],
              ),
              _buildSection(
                title: 'Featured banner image',
                icon: Icons.image_outlined,
                subtitle:
                    'Premium businesses can use this image in the moving featured banner on the map page.',
                children: [
                  _buildFeaturedBannerImagePicker(),
                ],
              ),
              _buildSection(
                title: 'Physical shop',
                icon: Icons.storefront_outlined,
                subtitle:
                    'Tell us whether this business has a physical shop. Physical shops must be linked to the TCG Shop Map.',
                children: [
                  _buildPhysicalShopSelector(),
                ],
              ),
              _buildSection(
                title: 'TCG Shop Map listing',
                icon: Icons.map_outlined,
                subtitle:
                    'If your shop is already on the map, select it here. If not, add it to the map first.',
                children: [
                  _buildShopMapRequirementCard(),
                ],
              ),
              _buildSection(
                title: 'Contact and area',
                icon: Icons.contact_phone_outlined,
                children: [
                  _buildTextField(
                    controller: _websiteController,
                    label: 'Website',
                    icon: Icons.language,
                    keyboardType: TextInputType.url,
                    maxLength: 300,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 40,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _townController,
                          label: 'Town',
                          maxLength: 120,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _countyController,
                          label: 'County',
                          maxLength: 120,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildSection(
                title: 'Current open / closed status',
                icon: Icons.storefront_outlined,
                subtitle:
                    'Choose whether the business should follow the weekly times or be shown as open/closed manually.',
                children: [
                  _buildOpeningStatusSelector(),
                ],
              ),
              _buildSection(
                title: 'Opening hours',
                icon: Icons.schedule_outlined,
                subtitle:
                    'Set public opening hours users will see. Leave a day blank if you do not want to show times.',
                children: [
                  _buildOpeningHoursEditor(),
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
                _saving ? 'Saving...' : 'Save business profile',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              onPressed: _saving ? null : _save,
            ),
          ),
        ),
      ),
    );
  }
}


class _PhysicalShopOption extends StatelessWidget {
  const _PhysicalShopOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _goldColor.withValues(alpha: 0.13) : _fieldColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _goldColor : _borderColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? _goldColor : _softTextColor,
              ),
              const SizedBox(width: 10),
              Icon(
                icon,
                color: selected ? _goldColor : _softTextColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _softTextColor,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
