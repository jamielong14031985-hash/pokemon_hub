import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_offer.dart';
import '../models/business_profile.dart';
import '../services/business_post_service.dart';

class BusinessOffersPage extends StatefulWidget {
  const BusinessOffersPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  @override
  State<BusinessOffersPage> createState() => _BusinessOffersPageState();
}

class _BusinessOffersPageState extends State<BusinessOffersPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);
  static const Color _dangerColor = Color(0xFFFB7185);

  static const Map<String, String> _categoryLabels = <String, String>{
    'discount': 'Discount code',
    'new_stock': 'New stock',
    'event': 'Event',
    'announcement': 'Announcement',
  };

  final BusinessPostService _service = BusinessPostService();

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _canManage {
    return _currentUid.isNotEmpty && _currentUid == widget.profile.ownerUid;
  }

  bool get _canCreateOffers {
    return _canManage && widget.profile.premiumIsActive;
  }

  void _showProRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business Pro must be active before adding offers.'),
      ),
    );
  }

  Future<void> _openEditor({BusinessOffer? existingOffer}) async {
    if (!_canCreateOffers) {
      _showProRequiredMessage();
      return;
    }

    final savedMessage = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _BusinessOfferEditorPage(
          profile: widget.profile,
          existingOffer: existingOffer,
        ),
      ),
    );

    if (!mounted || savedMessage == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(savedMessage)),
    );
  }

  Future<void> _deleteOffer(BusinessOffer offer) async {
    final confirmed = await _confirmDelete(
      title: 'Delete offer?',
      message: 'This will permanently delete "${offer.title}".',
    );

    if (confirmed != true) return;

    try {
      await _service.deleteBusinessOffer(offer);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete offer: $error')),
      );
    }
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(
            message,
            style: const TextStyle(color: _softTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _dangerColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Offers'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_canManage)
            IconButton(
              tooltip: 'Add offer',
              onPressed: _canCreateOffers ? () => _openEditor() : _showProRequiredMessage,
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              backgroundColor: _goldColor,
              foregroundColor: _backgroundColor,
              onPressed: _canCreateOffers ? () => _openEditor() : _showProRequiredMessage,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add offer',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : null,
      body: StreamBuilder<List<BusinessOffer>>(
        stream: _service.watchBusinessOffers(
          widget.profile.id,
          visibleOnly: !_canManage,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline,
              title: 'Could not load offers',
              message: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _goldColor),
            );
          }

          final offers = snapshot.data ?? const <BusinessOffer>[];
          if (offers.isEmpty) {
            return _MessageState(
              icon: Icons.local_offer_outlined,
              title: 'No offers yet',
              message: _canManage
                  ? 'Tap Add offer to create your first offer post with one picture.'
                  : 'This business has not added any offers yet.',
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 276,
            ),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return _OfferCard(
                offer: offer,
                canManage: _canManage,
                onEdit: () => _openEditor(existingOffer: offer),
                onDelete: () => _deleteOffer(offer),
              );
            },
          );
        },
      ),
    );
  }
}

class _BusinessOfferEditorPage extends StatefulWidget {
  const _BusinessOfferEditorPage({
    required this.profile,
    required this.existingOffer,
  });

  final BusinessProfile profile;
  final BusinessOffer? existingOffer;

  @override
  State<_BusinessOfferEditorPage> createState() => _BusinessOfferEditorPageState();
}

class _BusinessOfferEditorPageState extends State<_BusinessOfferEditorPage> {
  final BusinessPostService _service = BusinessPostService();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _codeController;
  late final TextEditingController _websiteController;

  late String _selectedCategory;
  late bool _active;

  XFile? _pickedImage;
  bool _removeImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final existingOffer = widget.existingOffer;
    _titleController = TextEditingController(text: existingOffer?.title ?? '');
    _descriptionController = TextEditingController(
      text: existingOffer?.description ?? '',
    );
    _codeController = TextEditingController(text: existingOffer?.code ?? '');
    _websiteController = TextEditingController(
      text: existingOffer?.websiteUrl ?? widget.profile.website,
    );

    _selectedCategory = existingOffer?.category ?? 'discount';
    if (!_BusinessOffersPageState._categoryLabels.containsKey(_selectedCategory)) {
      _selectedCategory = 'announcement';
    }

    _active = existingOffer?.active ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String labelText, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: _BusinessOffersPageState._softTextColor),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _BusinessOffersPageState._goldColor,
        fontWeight: FontWeight.w900,
      ),
      filled: true,
      fillColor: _BusinessOffersPageState._fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _BusinessOffersPageState._borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _BusinessOffersPageState._borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _BusinessOffersPageState._goldColor,
          width: 1.6,
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );

    if (image == null || !mounted) return;

    setState(() {
      _pickedImage = image;
      _removeImage = false;
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImage = null;
      _removeImage = true;
    });
  }

  Future<void> _saveOffer() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer title is required.')),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer description is required.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final existingOffer = widget.existingOffer;
      await _service.saveBusinessOffer(
        profile: widget.profile,
        offerId: existingOffer?.id,
        title: title,
        description: description,
        category: _selectedCategory,
        code: _codeController.text.trim(),
        websiteUrl: _websiteController.text.trim(),
        active: _active,
        pickedImage: _pickedImage,
        existingImageUrl: existingOffer?.imageUrl ?? '',
        existingImagePath: existingOffer?.imagePath ?? '',
        removeImage: _removeImage,
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        existingOffer == null ? 'Offer added.' : 'Offer saved.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save offer: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingOffer = widget.existingOffer;

    return Scaffold(
      backgroundColor: _BusinessOffersPageState._backgroundColor,
      appBar: AppBar(
        title: Text(existingOffer == null ? 'Add offer' : 'Edit offer'),
        backgroundColor: _BusinessOffersPageState._backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const _EditorHeader(
            icon: Icons.local_offer_outlined,
            title: 'Offer post',
            subtitle: 'Add one picture for this offer. Tapping the offer opens it inside the app.',
          ),
          const SizedBox(height: 14),
          _SingleImagePickerCard(
            existingImageUrl: existingOffer?.imageUrl ?? '',
            pickedImage: _pickedImage,
            removeImage: _removeImage,
            enabled: !_saving,
            fallbackIcon: Icons.local_offer_outlined,
            onPickImage: _pickImage,
            onClearImage: _clearImage,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            dropdownColor: _BusinessOffersPageState._fieldColor,
            iconEnabledColor: _BusinessOffersPageState._softTextColor,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            decoration: _inputDecoration('Offer type'),
            items: _BusinessOffersPageState._categoryLabels.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _selectedCategory = value);
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            enabled: !_saving,
            maxLength: 90,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            cursorColor: _BusinessOffersPageState._goldColor,
            decoration: _inputDecoration('Offer title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: !_saving,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            cursorColor: _BusinessOffersPageState._goldColor,
            decoration: _inputDecoration('Description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            enabled: !_saving,
            maxLength: 40,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white),
            cursorColor: _BusinessOffersPageState._goldColor,
            decoration: _inputDecoration('Offer code', hintText: 'Optional'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _websiteController,
            enabled: !_saving,
            maxLength: 300,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white),
            cursorColor: _BusinessOffersPageState._goldColor,
            decoration: _inputDecoration(
              'Website / offer link',
              hintText: 'Optional. Shown as a button inside the app.',
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            activeThumbColor: _BusinessOffersPageState._successColor,
            title: const Text(
              'Visible to customers',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Turn this off to save the offer without showing it publicly.',
              style: TextStyle(color: _BusinessOffersPageState._softTextColor),
            ),
            onChanged: _saving ? null : (value) => setState(() => _active = value),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _BusinessOffersPageState._goldColor,
              foregroundColor: _BusinessOffersPageState._backgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving
                  ? 'Saving...'
                  : existingOffer == null
                      ? 'Add offer'
                      : 'Save offer',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: _saving ? null : _saveOffer,
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final BusinessOffer offer;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _openOfferLink(BuildContext context) async {
    final cleanUrl = offer.websiteUrl.trim();
    if (cleanUrl.isEmpty) return;

    final url = cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')
        ? cleanUrl
        : 'https://$cleanUrl';

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this offer link.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this offer link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = offer.isCurrentlyVisible;
    final imageUrl = offer.imageUrl.trim();
    final description = offer.description.trim();
    final code = offer.code.trim();

    return Material(
      color: _BusinessOffersPageState._cardColor,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: visible
                ? _BusinessOffersPageState._goldColor
                : _BusinessOffersPageState._borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 98,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const _PostImageFallback(
                          icon: Icons.local_offer_outlined,
                        );
                      },
                    )
                  : const _PostImageFallback(
                      icon: Icons.local_offer_outlined,
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          color: _BusinessOffersPageState._goldColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            offer.categoryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _BusinessOffersPageState._softTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            visible ? Icons.visibility_outlined : Icons.visibility_off,
                            color: visible
                                ? _BusinessOffersPageState._successColor
                                : _BusinessOffersPageState._softTextColor,
                            size: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (code.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.confirmation_number_outlined,
                            color: _BusinessOffersPageState._goldColor,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _BusinessOffersPageState._goldColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _BusinessOffersPageState._softTextColor,
                          fontSize: 11.5,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (offer.websiteUrl.trim().isNotEmpty)
                          _CompactCardAction(
                            icon: Icons.open_in_new,
                            tooltip: 'Open offer link',
                            color: _BusinessOffersPageState._goldColor,
                            onPressed: () => _openOfferLink(context),
                          ),
                        if (canManage) ...[
                          const SizedBox(width: 6),
                          _CompactCardAction(
                            icon: Icons.edit_outlined,
                            tooltip: 'Edit offer',
                            color: Colors.white,
                            onPressed: onEdit,
                          ),
                          const SizedBox(width: 6),
                          _CompactCardAction(
                            icon: Icons.delete_outline,
                            tooltip: 'Delete offer',
                            color: _BusinessOffersPageState._dangerColor,
                            onPressed: onDelete,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactCardAction extends StatelessWidget {
  const _CompactCardAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: _BusinessOffersPageState._fieldColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _BusinessOffersPageState._borderColor),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}

class _SingleImagePickerCard extends StatelessWidget {
  const _SingleImagePickerCard({
    required this.existingImageUrl,
    required this.pickedImage,
    required this.removeImage,
    required this.enabled,
    required this.fallbackIcon,
    required this.onPickImage,
    required this.onClearImage,
  });

  final String existingImageUrl;
  final XFile? pickedImage;
  final bool removeImage;
  final bool enabled;
  final IconData fallbackIcon;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  bool get _hasImage {
    return pickedImage != null || (existingImageUrl.trim().isNotEmpty && !removeImage);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _BusinessOffersPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessOffersPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            child: SizedBox(
              height: 190,
              child: _ImagePreview(
                existingImageUrl: existingImageUrl,
                pickedImage: pickedImage,
                removeImage: removeImage,
                fallbackIcon: fallbackIcon,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _BusinessOffersPageState._goldColor,
                    foregroundColor: _BusinessOffersPageState._backgroundColor,
                  ),
                  onPressed: enabled ? onPickImage : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_hasImage ? 'Change picture' : 'Choose picture'),
                ),
                if (_hasImage)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _BusinessOffersPageState._dangerColor,
                      side: const BorderSide(color: _BusinessOffersPageState._dangerColor),
                    ),
                    onPressed: enabled ? onClearImage : null,
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
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.existingImageUrl,
    required this.pickedImage,
    required this.removeImage,
    required this.fallbackIcon,
  });

  final String existingImageUrl;
  final XFile? pickedImage;
  final bool removeImage;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final picked = pickedImage;
    if (picked != null) {
      return FutureBuilder<Uint8List>(
        future: picked.readAsBytes(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(
              child: CircularProgressIndicator(color: _BusinessOffersPageState._goldColor),
            );
          }
          return Image.memory(bytes, width: double.infinity, fit: BoxFit.cover);
        },
      );
    }

    if (existingImageUrl.trim().isNotEmpty && !removeImage) {
      return Image.network(
        existingImageUrl.trim(),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _PostImageFallback(icon: fallbackIcon);
        },
      );
    }

    return _PostImageFallback(icon: fallbackIcon);
  }
}

class _PostImageFallback extends StatelessWidget {
  const _PostImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      width: double.infinity,
      decoration: const BoxDecoration(color: _BusinessOffersPageState._fieldColor),
      child: Center(
        child: Icon(icon, color: _BusinessOffersPageState._goldColor, size: 48),
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BusinessOffersPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessOffersPageState._borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _BusinessOffersPageState._goldColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _BusinessOffersPageState._softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _BusinessOffersPageState._goldColor, size: 50),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _BusinessOffersPageState._softTextColor,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
