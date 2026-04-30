import 'package:flutter/material.dart';

import '../models/custom_binder_editor_value.dart';
import '../models/custom_binder_models.dart';
import '../models/master_sets_view_mode.dart';
import '../models/tcg_set.dart';
import '../services/collection_refresh_notifier.dart';
import '../services/custom_binder_sync_service.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../utils/app_helpers.dart';
import '../widgets/custom_binder_cover.dart';
import '../widgets/custom_binder_sheets.dart';
import '../widgets/set_logo_widgets.dart';
import 'custom_binder_page.dart';
import 'set_pokedex_page.dart';

class MasterSetsPage extends StatefulWidget {
  const MasterSetsPage({super.key});

  @override
  State<MasterSetsPage> createState() => MasterSetsPageState();
}

class MasterSetsPageState extends State<MasterSetsPage> {
  late Future<List<TcgSet>> _futureSets;
  final Map<String, int> _savedCopyCountsBySetId = <String, int>{};
  bool _loadedCollectionState = false;
  bool _loadingCustomBinders = false;
  List<CustomBinder> _customBinders = <CustomBinder>[];
  final Map<String, int> _customBinderCounts = <String, int>{};
  MasterSetsViewMode _viewMode = MasterSetsViewMode.setPokedex;

  @override
  void initState() {
    super.initState();
    _futureSets = PokemonTcgService.fetchSets();
    _loadSetCollectionState();
    _loadCustomBinderState();
    collectionRefreshNotifier.addListener(_handleCollectionRefresh);
  }

  void _handleCollectionRefresh() {
    refreshSets();
  }

  @override
  void dispose() {
    collectionRefreshNotifier.removeListener(_handleCollectionRefresh);
    super.dispose();
  }

  Future<void> refreshSets() async {
    setState(() {
      _loadedCollectionState = false;
      _futureSets = PokemonTcgService.fetchSets();
    });

    try {
      await Future.wait<void>([
        _loadSetCollectionState(),
        _loadCustomBinderState(),
      ]).timeout(const Duration(seconds: 8));
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadedCollectionState = true;
          _loadingCustomBinders = false;
        });
      }
    }
  }

  Future<void> _loadSetCollectionState() async {
    final savedCopyCounts = await PokedexSyncService.loadCurrentUserCopyCountsBySetId(
      cleanEmptySets: true,
    );
    _savedCopyCountsBySetId
      ..clear()
      ..addAll(savedCopyCounts);

    if (mounted) {
      setState(() {
        _loadedCollectionState = true;
      });
    }
  }

  Future<void> _loadCustomBinderState() async {
    if (mounted) {
      setState(() {
        _loadingCustomBinders = true;
      });
    }

    final binders = await CustomBinderSyncService.loadCurrentUserBinders();
    final counts = <String, int>{};
    for (final binder in binders) {
      counts[binder.id] = await CustomBinderSyncService.cardCount(binder.id);
    }

    if (!mounted) return;
    setState(() {
      _customBinders = binders;
      _customBinderCounts
        ..clear()
        ..addAll(counts);
      _loadingCustomBinders = false;
    });
  }


  Future<CustomBinderEditorValue?> _showBinderEditor({CustomBinder? binder}) {
    return showModalBottomSheet<CustomBinderEditorValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomBinderEditorSheet(binder: binder),
    );
  }

  Future<void> _createBinder() async {
    final value = await _showBinderEditor();
    if (value == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await CustomBinderSyncService.saveCurrentUserBinder(
      CustomBinder(
        id: generateLocalDocumentId(),
        name: value.name,
        imageBase64: value.imageBase64,
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    await _loadCustomBinderState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${value.name} created')),
    );
  }

  Future<void> _editBinder(CustomBinder binder) async {
    final value = await _showBinderEditor(binder: binder);
    if (value == null) return;

    await CustomBinderSyncService.saveCurrentUserBinder(
      binder.copyWith(
        name: value.name,
        imageBase64: value.imageBase64,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _loadCustomBinderState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${value.name} updated')),
    );
  }

  Future<void> _deleteBinder(CustomBinder binder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete binder?'),
          content: Text('Delete ${binder.name} and all cards inside it?'),
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

    await CustomBinderSyncService.deleteCurrentUserBinder(binder.id);
    await _loadCustomBinderState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${binder.name} deleted')),
    );
  }

  Future<void> _removeSetFromMasterSets(TcgSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove set from Master Sets?'),
          content: Text(
            'This will clear saved Pokédex data for ${set.name} on this device. '
            'Use this if the set is showing even though you have no cards saved in it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await LocalPokedexStore.clearSet(set.id);
    await PokedexSyncService.syncCurrentSetForCurrentUser(set.id);
    await _loadSetCollectionState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${set.name} removed from Master Sets')),
    );
  }

  Widget _buildViewToggle() {
    Widget buildChip({
      required String label,
      required IconData icon,
      required MasterSetsViewMode mode,
    }) {
      final selected = _viewMode == mode;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _viewMode = mode;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF7DE77) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? const Color(0xFFF7DE77) : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          buildChip(
            label: 'Set Pokédex',
            icon: Icons.collections_bookmark_outlined,
            mode: MasterSetsViewMode.setPokedex,
          ),
          const SizedBox(width: 10),
          buildChip(
            label: 'Custom Binders',
            icon: Icons.photo_album_outlined,
            mode: MasterSetsViewMode.customBinders,
          ),
        ],
      ),
    );
  }

  Widget _buildSetPokedexView() {
    return FutureBuilder<List<TcgSet>>(
      future: _futureSets,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || !_loadedCollectionState) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load sets: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final allSets = snapshot.data ?? const <TcgSet>[];
        if (allSets.isEmpty) {
          return const Center(
            child: Text('No sets found.', style: TextStyle(color: Colors.white)),
          );
        }

        final visibleSets = allSets
            .where((set) => (_savedCopyCountsBySetId[set.id] ?? 0) > 0)
            .toList();

        return RefreshIndicator(
          onRefresh: refreshSets,
          child: visibleSets.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Card(
                        color: Color(0xFF102754),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Only sets with saved cards show here. Add a card to a set and it will appear here.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No set Pokédex entries yet. Add a card to a set first and it will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: visibleSets.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Card(
                        color: const Color(0xFF102754),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Only sets with saved cards show here. Add a card to a set and it will appear here.',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              Text(
                                '${visibleSets.length}/${allSets.length}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final set = visibleSets[index - 1];
                    return Card(
                      color: const Color(0xFF102754),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onLongPress: () => _removeSetFromMasterSets(set),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SetPokedexPage(set: set),
                            ),
                          );
                          await _loadSetCollectionState();
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              constraints: const BoxConstraints(minHeight: 110),
                              child: ResolvedSetLogo(
                                setId: set.id,
                                setName: set.name,
                                fallbackLogoUrl: set.logoUrl,
                                height: 64,
                                fit: BoxFit.contain,
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Tooltip(
                                message: 'Remove from Master Sets',
                                child: IconButton(
                                  onPressed: () => _removeSetFromMasterSets(set),
                                  icon: const Icon(Icons.close_rounded),
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildCustomBindersView() {
    if (_loadingCustomBinders) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadCustomBinderState,
      child: _customBinders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Card(
                  color: const Color(0xFF102754),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create your own themed binders',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Make custom Pokédex binders for cards like every Charizard, all Pikachu cards, favourite promos, or any theme you want. You can rename each binder and upload a cover image too.',
                          style: TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _createBinder,
                            icon: const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Create Custom Binder'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No custom binders yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _customBinders.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Custom binders let you group cards however you like, with your own name and cover image.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _createBinder,
                            icon: const Icon(Icons.add),
                            label: const Text('New'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final binder = _customBinders[index - 1];
                final count = _customBinderCounts[binder.id] ?? 0;
                return Card(
                  color: const Color(0xFF102754),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomBinderPage(binder: binder),
                        ),
                      );
                      await _loadCustomBinderState();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CustomBinderCover(
                            imageBase64: binder.imageBase64,
                            size: 88,
                            borderRadius: 18,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  binder.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  count == 1 ? '1 card saved' : '$count cards saved',
                                  style: const TextStyle(
                                    color: Color(0xFFD8E3FB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap to open this custom binder.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.60),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            color: const Color(0xFF102754),
                            iconColor: Colors.white,
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _editBinder(binder);
                              } else if (value == 'delete') {
                                await _deleteBinder(binder);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit binder', style: TextStyle(color: Colors.white)),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete binder', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildViewToggle(),
        Expanded(
          child: _viewMode == MasterSetsViewMode.setPokedex
              ? _buildSetPokedexView()
              : _buildCustomBindersView(),
        ),
      ],
    );
  }
}
