import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_offer.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';

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

  final BusinessProfileService _service = BusinessProfileService();

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _canManage {
    return _currentUid.isNotEmpty && _currentUid == widget.profile.ownerUid;
  }

  bool get _canCreateOffers {
    return _canManage && widget.profile.premiumIsActive;
  }

  Future<void> _openOfferSheet({BusinessOffer? existingOffer}) async {
    if (!_canCreateOffers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business Pro must be active before adding offers.'),
        ),
      );
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete offer?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will permanently delete "${offer.title}".',
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
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _service.deleteBusinessOffer(
        businessId: widget.profile.id,
        offerId: offer.id,
      );

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

  @override
  Widget build(BuildContext context) {
    final businessName = widget.profile.businessName.trim().isEmpty
        ? 'Business offers'
        : widget.profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Offers & deals'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              heroTag: 'add-business-offer',
              backgroundColor: _goldColor,
              foregroundColor: _backgroundColor,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add offer',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () => _openOfferSheet(),
            )
          : null,
      body: StreamBuilder<List<BusinessOffer>>(
        stream: _service.watchBusinessOffers(widget.profile.id),
        builder: (context, snapshot) {
          final offers = snapshot.data ?? const <BusinessOffer>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _OffersHeaderCard(
                businessName: businessName,
                offerCount: offers.length,
                premiumActive: widget.profile.premiumIsActive,
              ),
              if (_canManage && !widget.profile.premiumIsActive) ...[
                const SizedBox(height: 14),
                const _BusinessProRequiredCard(),
              ],
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _goldColor),
                  ),
                )
              else if (offers.isEmpty)
                _EmptyOffersCard(canManage: _canManage)
              else
                ...offers.map(
                  (offer) => _OfferCard(
                    offer: offer,
                    canManage: _canManage,
                    onEdit: () => _openOfferSheet(existingOffer: offer),
                    onDelete: () => _deleteOffer(offer),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OffersHeaderCard extends StatelessWidget {
  const _OffersHeaderCard({
    required this.businessName,
    required this.offerCount,
    required this.premiumActive,
  });

  final String businessName;
  final int offerCount;
  final bool premiumActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BusinessOffersPageState._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: premiumActive
              ? _BusinessOffersPageState._goldColor
              : _BusinessOffersPageState._borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _BusinessOffersPageState._fieldColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _BusinessOffersPageState._borderColor),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              color: _BusinessOffersPageState._goldColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  offerCount == 0
                      ? 'Create Pro offers, discount codes, and new stock updates.'
                      : '$offerCount offer${offerCount == 1 ? '' : 's'} saved.',
                  style: const TextStyle(
                    color: _BusinessOffersPageState._softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
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

class _BusinessProRequiredCard extends StatelessWidget {
  const _BusinessProRequiredCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.55)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offers & deals are a Business Pro feature. Ask an admin to activate Business Pro for this business.',
              style: TextStyle(
                color: _BusinessOffersPageState._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOffersCard extends StatelessWidget {
  const _EmptyOffersCard({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: _BusinessOffersPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessOffersPageState._borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.local_offer_outlined,
            color: _BusinessOffersPageState._goldColor,
            size: 46,
          ),
          const SizedBox(height: 12),
          const Text(
            'No offers yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canManage
                ? 'Tap Add offer to create your first Business Pro promotion.'
                : 'This business has not posted any offers yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _BusinessOffersPageState._softTextColor,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
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

  Future<void> _openWebsite(BuildContext context) async {
    final cleanWebsite = offer.websiteUrl.trim();
    if (cleanWebsite.isEmpty) return;

    final url = cleanWebsite.startsWith('http://') ||
            cleanWebsite.startsWith('https://')
        ? cleanWebsite
        : 'https://$cleanWebsite';

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BusinessOffersPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: visible
              ? _BusinessOffersPageState._goldColor
              : _BusinessOffersPageState._borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OfferBadge(
                icon: Icons.local_offer_outlined,
                label: offer.categoryLabel,
                highlighted: true,
              ),
              _OfferBadge(
                icon: visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                label: visible ? 'Visible' : 'Hidden',
                highlighted: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (offer.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              offer.description.trim(),
              style: const TextStyle(
                color: _BusinessOffersPageState._softTextColor,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (offer.code.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _BusinessOffersPageState._fieldColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _BusinessOffersPageState._borderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    color: _BusinessOffersPageState._goldColor,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: SelectableText(
                      offer.code.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (offer.websiteUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _BusinessOffersPageState._goldColor,
                  side: const BorderSide(color: _BusinessOffersPageState._goldColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text(
                  'Open offer link',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                onPressed: () => _openWebsite(context),
              ),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(
                      color: _BusinessOffersPageState._borderColor,
                    ),
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferBadge extends StatelessWidget {
  const _OfferBadge({
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? _BusinessOffersPageState._goldColor
            : _BusinessOffersPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? _BusinessOffersPageState._goldColor
              : _BusinessOffersPageState._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted
                ? _BusinessOffersPageState._backgroundColor
                : _BusinessOffersPageState._goldColor,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: highlighted
                  ? _BusinessOffersPageState._backgroundColor
                  : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}


class _BusinessOfferEditorPage extends StatefulWidget {
  const _BusinessOfferEditorPage({
    required this.profile,
    this.existingOffer,
  });

  final BusinessProfile profile;
  final BusinessOffer? existingOffer;

  @override
  State<_BusinessOfferEditorPage> createState() =>
      _BusinessOfferEditorPageState();
}

class _BusinessOfferEditorPageState extends State<_BusinessOfferEditorPage> {
  static const Map<String, String> _categoryLabels = <String, String>{
    'discount': 'Discount code',
    'new_stock': 'New stock',
    'event': 'Event',
    'announcement': 'Announcement',
  };

  final BusinessProfileService _service = BusinessProfileService();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _codeController;
  late final TextEditingController _websiteController;

  late String _selectedCategory;
  late bool _active;
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
    if (!_categoryLabels.containsKey(_selectedCategory)) {
      _selectedCategory = 'discount';
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
      labelStyle: const TextStyle(
        color: _BusinessOffersPageState._softTextColor,
      ),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _BusinessOffersPageState._goldColor,
        fontWeight: FontWeight.w900,
      ),
      filled: true,
      fillColor: _BusinessOffersPageState._fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _BusinessOffersPageState._borderColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _BusinessOffersPageState._borderColor,
        ),
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
      await _service.saveBusinessOffer(
        profile: widget.profile,
        offerId: widget.existingOffer?.id,
        title: title,
        description: description,
        category: _selectedCategory,
        code: _codeController.text.trim(),
        websiteUrl: _websiteController.text.trim(),
        active: _active,
      );

      if (!mounted) return;

      Navigator.of(context).pop(
        widget.existingOffer == null ? 'Offer added.' : 'Offer saved.',
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            const Text(
              'Create a Business Pro offer for customers to see.',
              style: TextStyle(
                color: _BusinessOffersPageState._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: _BusinessOffersPageState._fieldColor,
              iconEnabledColor: _BusinessOffersPageState._softTextColor,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              decoration: _inputDecoration('Offer type'),
              items: _categoryLabels.entries
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
              decoration: _inputDecoration('Title'),
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
              decoration: _inputDecoration(
                'Discount code / promo code',
                hintText: 'Optional',
              ),
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
                'Offer website link',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: _BusinessOffersPageState._goldColor,
              activeTrackColor:
                  _BusinessOffersPageState._goldColor.withValues(alpha: 0.35),
              title: const Text(
                'Show this offer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: const Text(
                'Turn this off to hide the offer without deleting it.',
                style: TextStyle(
                  color: _BusinessOffersPageState._softTextColor,
                ),
              ),
              value: _active,
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _active = value);
                    },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _BusinessOffersPageState._goldColor,
                foregroundColor: _BusinessOffersPageState._backgroundColor,
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
                        color: _BusinessOffersPageState._backgroundColor,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _saving ? 'Saving...' : 'Save offer',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: _saving ? null : _saveOffer,
            ),
          ],
        ),
      ),
    );
  }
}

