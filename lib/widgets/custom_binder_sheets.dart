import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/custom_binder_editor_value.dart';
import '../models/custom_binder_models.dart';
import '../models/tcg_card.dart';
import '../services/community_image_services.dart';
import '../services/custom_binder_sync_service.dart';
import '../utils/app_helpers.dart';
import 'custom_binder_cover.dart';

class CustomBinderEditorSheet extends StatefulWidget {
  const CustomBinderEditorSheet({super.key, this.binder});

  final CustomBinder? binder;

  @override
  State<CustomBinderEditorSheet> createState() => _CustomBinderEditorSheetState();
}

class _CustomBinderEditorSheetState extends State<CustomBinderEditorSheet> {
  late final TextEditingController _nameController;
  String? _imageBase64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.binder?.name ?? '');
    _imageBase64 = widget.binder?.imageBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final encoded = await CommunityImageCodec.pickAndEncodeSingle(
        ImageSource.gallery,
        storageFolder: 'binder_covers',
      );
      if (encoded == null || !mounted) return;
      setState(() {
        _imageBase64 = encoded;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a binder name')),
      );
      return;
    }

    if (_saving) return;
    setState(() {
      _saving = true;
    });
    Navigator.of(context).pop(
      CustomBinderEditorValue(
        name: name,
        imageBase64: _imageBase64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: const Color(0xFF102754),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.binder == null ? 'Create Custom Binder' : 'Edit Custom Binder',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Give your binder a custom name and optionally upload a cover image, just like a real set page.',
                  style: TextStyle(
                    color: Color(0xFFD8E3FB),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: CustomBinderCover(
                    imageBase64: _imageBase64,
                    size: 136,
                    borderRadius: 24,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.upload_outlined),
                        label: const Text('Upload Cover'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _imageBase64 == null
                            ? null
                            : () {
                                setState(() {
                                  _imageBase64 = null;
                                });
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove Image'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Binder name',
                    labelStyle: const TextStyle(color: Color(0xFFC8D4F0)),
                    hintText: 'Every Charizard',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    filled: true,
                    fillColor: const Color(0xFF16366E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.binder == null ? 'Create Binder' : 'Save Binder'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomBinderPickerSheet extends StatefulWidget {
  const CustomBinderPickerSheet({super.key, required this.card});

  final TcgCard card;

  @override
  State<CustomBinderPickerSheet> createState() => _CustomBinderPickerSheetState();
}

class _CustomBinderPickerSheetState extends State<CustomBinderPickerSheet> {
  List<CustomBinder> _binders = const <CustomBinder>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final binders = await CustomBinderSyncService.loadCurrentUserBinders();
    if (!mounted) return;
    setState(() {
      _binders = binders;
      _loading = false;
    });
  }

  Future<void> _createBinder() async {
    final value = await showModalBottomSheet<CustomBinderEditorValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomBinderEditorSheet(),
    );
    if (value == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final binder = CustomBinder(
      id: generateLocalDocumentId(),
      name: value.name,
      imageBase64: value.imageBase64,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await CustomBinderSyncService.saveCurrentUserBinder(binder);
    if (!mounted) return;
    Navigator.of(context).pop(binder);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: const Color(0xFF102754),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add ${widget.card.name} to a Custom Binder',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick one of your custom binders, or create a new one now.',
                style: TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _createBinder,
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Binder'),
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_binders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No custom binders yet. Create one above to get started.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.48,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _binders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final binder = _binders[index];
                      return Card(
                        color: const Color(0xFF16366E),
                        child: ListTile(
                          onTap: () => Navigator.of(context).pop(binder),
                          leading: CustomBinderCover(
                            imageBase64: binder.imageBase64,
                            size: 52,
                            borderRadius: 14,
                          ),
                          title: Text(
                            binder.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Tap to add this card',
                            style: TextStyle(color: Color(0xFFD8E3FB)),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> addCardToCustomBinderFlow(BuildContext context, TcgCard card) async {
  final binder = await showModalBottomSheet<CustomBinder>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CustomBinderPickerSheet(card: card),
  );
  if (binder == null) return;

  await CustomBinderSyncService.addCardToBinder(
    binderId: binder.id,
    card: card,
  );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Added ${card.name} to ${binder.name}')),
  );
}

