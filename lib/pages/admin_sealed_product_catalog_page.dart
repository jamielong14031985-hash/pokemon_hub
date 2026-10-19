import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/sealed_product_catalog_service.dart';
import '../services/sealed_product_identity_service.dart';
import '../utils/ebay_sold_search.dart';

class AdminSealedProductCatalogPage extends StatefulWidget {
  const AdminSealedProductCatalogPage({super.key});

  @override
  State<AdminSealedProductCatalogPage> createState() =>
      _AdminSealedProductCatalogPageState();
}

class _AdminSealedProductCatalogPageState
    extends State<AdminSealedProductCatalogPage> {
  static const Color _background = Color(0xFF041B4A);
  static const Color _card = Color(0xFF102754);
  static const Color _field = Color(0xFF16366E);
  static const Color _gold = Color(0xFFF7DE77);

  final _setController = TextEditingController();
  final _imageController = TextEditingController();
  final _sourceController = TextEditingController(text: 'Smyths Toys');
  final _sourceUrlController = TextEditingController();
  SealedProductType _type = SealedProductType.eliteTrainerBox;
  String _edition = 'standard';
  bool _saving = false;

  @override
  void dispose() {
    _setController.dispose();
    _imageController.dispose();
    _sourceController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final setName = _setController.text.trim();
    final imageUrl = _imageController.text.trim();
    final imageUri = Uri.tryParse(imageUrl);
    if (setName.isEmpty ||
        imageUri == null ||
        imageUri.scheme != 'https' ||
        imageUri.host.isEmpty) {
      _message('Enter the set/product name and a valid HTTPS image URL.');
      return;
    }
    setState(() => _saving = true);
    try {
      final identityKey = SealedProductIdentityService.stableProductKey(
        query: setName,
        productType: _type.name,
        etbVariant: _edition,
      );
      final documentId =
          SealedProductCatalogService.catalogueDocumentId(identityKey);
      await FirebaseFirestore.instance
          .collection('sealed_product_catalog')
          .doc(documentId)
          .set(<String, dynamic>{
        'identityKey': identityKey,
        'setName': setName,
        'productType': _type.name,
        'edition': _type == SealedProductType.eliteTrainerBox
            ? _edition
            : 'standard',
        'imageUrl': imageUrl,
        'sourceName': _sourceController.text.trim(),
        'sourceUrl': _sourceUrlController.text.trim(),
        'approved': true,
        'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _message('Approved product picture saved.');
    } catch (error) {
      _message('Could not save the product picture: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  InputDecoration _decoration(String label, {String? helper}) => InputDecoration(
        labelText: label,
        helperText: helper,
        labelStyle: const TextStyle(color: Color(0xFFC8D4F0)),
        helperStyle: const TextStyle(color: Color(0xFF9EB1D7)),
        filled: true,
        fillColor: _field,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3F5C96)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final preview = _imageController.text.trim();
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Sealed Product Pictures'),
        backgroundColor: _background,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _gold),
            ),
            child: const Text(
              'Add one clean product-only picture for each exact product. '
              'Standard and Pokémon Center ETBs must be saved separately. '
              'Use images you have permission to display.',
              style: TextStyle(color: Colors.white, height: 1.45),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _setController,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Set or product name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SealedProductType>(
            initialValue: _type,
            dropdownColor: _field,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Product type'),
            items: SealedProductType.values
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    ))
                .toList(growable: false),
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          if (_type == SealedProductType.eliteTrainerBox) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _edition,
              dropdownColor: _field,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('ETB edition'),
              items: const [
                DropdownMenuItem(value: 'standard', child: Text('Standard ETB')),
                DropdownMenuItem(
                  value: 'pokemonCenter',
                  child: Text('Pokémon Center ETB'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _edition = value ?? _edition),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _imageController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            decoration: _decoration(
              'Direct product image URL',
              helper: 'HTTPS picture only — not the retailer product-page URL',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceController,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Image source name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceUrlController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            decoration: _decoration('Source product-page URL'),
          ),
          if (preview.startsWith('https://')) ...[
            const SizedBox(height: 16),
            Container(
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.network(
                preview,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Picture could not be loaded.'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: const Text('Save approved picture'),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
