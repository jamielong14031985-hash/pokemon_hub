import 'package:flutter/material.dart';

import '../models/custom_binder_editor_value.dart';
import '../models/custom_binder_models.dart';
import '../services/custom_binder_sync_service.dart';
import '../widgets/binder_card_tile.dart';
import '../widgets/custom_binder_cover.dart';
import '../widgets/custom_binder_sheets.dart';
import 'custom_binder_card_page.dart';

class CustomBinderPage extends StatefulWidget {
  const CustomBinderPage({super.key, required this.binder});

  final CustomBinder binder;

  @override
  State<CustomBinderPage> createState() => _CustomBinderPageState();
}

class _CustomBinderPageState extends State<CustomBinderPage> {
  late CustomBinder _binder;
  bool _loading = true;
  List<CustomBinderCardEntry> _cards = const <CustomBinderCardEntry>[];

  @override
  void initState() {
    super.initState();
    _binder = widget.binder;
    _load();
  }

  Future<void> _load() async {
    final binder = await CustomBinderSyncService.loadCurrentUserBinder(_binder.id) ?? _binder;
    final cards = await CustomBinderSyncService.loadCurrentUserCards(_binder.id);
    if (!mounted) return;
    setState(() {
      _binder = binder;
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _editBinder() async {
    final value = await showModalBottomSheet<CustomBinderEditorValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomBinderEditorSheet(binder: _binder),
    );
    if (value == null) return;

    await CustomBinderSyncService.saveCurrentUserBinder(
      _binder.copyWith(
        name: value.name,
        imageBase64: value.imageBase64,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _load();
  }

  Future<void> _deleteBinder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete binder?'),
          content: Text('Delete ${_binder.name} and every card saved in it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await CustomBinderSyncService.deleteCurrentUserBinder(_binder.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(_binder.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _editBinder,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _deleteBinder,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _cards.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Center(
                            child: CustomBinderCover(
                              imageBase64: _binder.imageBase64,
                              size: 150,
                              borderRadius: 28,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _binder.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No cards saved in this binder yet. Open any card and use Add to Custom Binder to start filling it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              color: const Color(0xFF102754),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    CustomBinderCover(
                                      imageBase64: _binder.imageBase64,
                                      size: 80,
                                      borderRadius: 18,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _binder.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _cards.length == 1
                                                ? '1 card in this binder'
                                                : '${_cards.length} cards in this binder',
                                            style: const TextStyle(
                                              color: Color(0xFFD8E3FB),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cards.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio: 0.76,
                            ),
                            itemBuilder: (context, index) {
                              final entry = _cards[index];
                              final card = entry.toSummaryCard();
                              return GestureDetector(
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CustomBinderCardPage(
                                        binder: _binder,
                                        entry: entry,
                                      ),
                                    ),
                                  );
                                  await _load();
                                },
                                child: BinderCardTile(
                                  card: card,
                                  ownership: entry.ownership,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ),
    );
  }
}
