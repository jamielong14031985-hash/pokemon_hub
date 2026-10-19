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
import 'custom_binder_page.dart' as custom_binder_page;
import 'japanese_sets_page.dart';
import 'set_pokedex_page.dart';
import 'national_pokedex_page.dart';

class MasterSetsPage extends StatefulWidget {
  const MasterSetsPage({super.key});

  @override
  State<MasterSetsPage> createState() => MasterSetsPageState();
}

class MasterSetsPageState extends State<MasterSetsPage> {
  late Future<_SetCatalogue> _futureSetCatalogue;
  _SetCatalogue? _lastSetCatalogue;
  final Map<String, int> _savedCopyCountsBySetId = <String, int>{};
  bool _loadedCollectionState = false;
  bool _loadingCustomBinders = false;
  List<CustomBinder> _customBinders = <CustomBinder>[];
  final Map<String, int> _customBinderCounts = <String, int>{};
  MasterSetsViewMode _viewMode = MasterSetsViewMode.setPokedex;

  @override
  void initState() {
    super.initState();
    _futureSetCatalogue = _loadSetCatalogue();
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
      _futureSetCatalogue = _loadSetCatalogue(forceRefresh: true);
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


  Future<_SetCatalogue> _loadSetCatalogue({bool forceRefresh = false}) async {
    final previous = _lastSetCatalogue;

    final results = await Future.wait<Object>([
      PokemonTcgService.fetchSets(forceRefresh: forceRefresh)
          .then<Object>((sets) => sets)
          .catchError((_) => previous?.englishSets ?? const <TcgSet>[]),
      JapaneseTcgDexService.fetchSets(forceRefresh: forceRefresh)
          .then<Object>((sets) => sets)
          .catchError(
            (_) => previous?.japaneseSets ?? const <JapaneseTcgSet>[],
          ),
    ]);

    final loaded = _SetCatalogue(
      englishSets: List<TcgSet>.from(results[0] as List),
      japaneseSets: List<JapaneseTcgSet>.from(results[1] as List),
    );
    _lastSetCatalogue = loaded;
    return loaded;
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

  Future<void> _removeSetFromMasterSets({
    required String setId,
    required String setName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove set from Sets?'),
          content: Text(
            'This will clear saved Pokédex data for $setName on this device. '
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

    await LocalPokedexStore.clearSet(setId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(setId);
    await _loadSetCollectionState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$setName removed from Sets')),
    );
  }

  Future<void> _openCollectedSet(_CollectedSetEntry entry) async {
    if (entry.isJapanese) {
      final japaneseSet = entry.japaneseSet;
      if (japaneseSet == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JapaneseSetPokedexPage(set: japaneseSet),
        ),
      );
    } else {
      final englishSet = entry.englishSet;
      if (englishSet == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SetPokedexPage(set: englishSet),
        ),
      );
    }

    await _loadSetCollectionState();
  }

  Widget _buildViewToggle() {
    const gold = Color(0xFFF7DE77);

    Widget buildTab({
      required String label,
      required String imageAsset,
      required IconData fallbackIcon,
      required MasterSetsViewMode mode,
    }) {
      final selected = _viewMode == mode;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: '$label tab',
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () {
                if (_viewMode != mode) {
                  setState(() => _viewMode = mode);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: selected
                        ? const [
                            Color(0xFFFFEB9D),
                            Color(0xFFF7DE77),
                            Color(0xFFF2C45D),
                          ]
                        : const [
                            Color(0xFF17427D),
                            Color(0xFF103266),
                            Color(0xFF081E46),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFEFBB)
                        : const Color(0xFF4685C1),
                    width: selected ? 1.7 : 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? gold.withValues(alpha: 0.27)
                          : Colors.black.withValues(alpha: 0.17),
                      blurRadius: selected ? 15 : 7,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  // Use the original ornate gold wordmarks with their large
                  // binder/ball illustrations removed. The selected tab still
                  // uses the same gold/blue treatment as before.
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    width: double.infinity,
                    height: 68,
                    errorBuilder: (context, error, stackTrace) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          fallbackIcon,
                          color: selected ? const Color(0xFF102448) : gold,
                          size: 25,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF102448)
                                : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Preserve the existing scrolling behaviour on every Sets view.
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
      child: Row(
        children: [
          buildTab(
            label: 'Set Pokédex',
            imageAsset: 'assets/images/pocketchase_set_pokedex_wordmark.png',
            fallbackIcon: Icons.collections_bookmark_rounded,
            mode: MasterSetsViewMode.setPokedex,
          ),
          const SizedBox(width: 9),
          buildTab(
            label: 'National Pokédex',
            imageAsset: 'assets/images/pocketchase_national_pokedex_wordmark.png',
            fallbackIcon: Icons.catching_pokemon,
            mode: MasterSetsViewMode.nationalPokedex,
          ),
          const SizedBox(width: 9),
          buildTab(
            label: 'Custom Binders',
            imageAsset: 'assets/images/pocketchase_custom_binders_wordmark.png',
            fallbackIcon: Icons.auto_stories_rounded,
            mode: MasterSetsViewMode.customBinders,
          ),
        ],
      ),
    );
  }

  List<_CollectedSetEntry> _buildCollectedSetEntries(_SetCatalogue catalogue) {
    final entries = <_CollectedSetEntry>[];
    final matchedSetIds = <String>{};

    for (final set in catalogue.englishSets) {
      final count = _savedCopyCountsBySetId[set.id] ?? 0;
      if (count <= 0) continue;
      matchedSetIds.add(set.id);
      entries.add(
        _CollectedSetEntry.english(
          set: set,
          savedCopies: count,
        ),
      );
    }

    final japaneseSetsByCollectionId = <String, JapaneseTcgSet>{
      for (final set in catalogue.japaneseSets) 'jp_${set.id.trim()}': set,
    };

    for (final entry in _savedCopyCountsBySetId.entries) {
      final setId = entry.key.trim();
      final count = entry.value;
      if (count <= 0 || matchedSetIds.contains(setId)) continue;

      if (setId.startsWith('jp_')) {
        entries.add(
          _CollectedSetEntry.japanese(
            setId: setId,
            set: japaneseSetsByCollectionId[setId],
            savedCopies: count,
          ),
        );
      } else {
        entries.add(
          _CollectedSetEntry.englishFallback(
            setId: setId,
            savedCopies: count,
          ),
        );
      }
    }

    entries.sort((a, b) {
      final dateCompare = b.sortableReleaseDate.compareTo(a.sortableReleaseDate);
      if (dateCompare != 0) return dateCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }

  Widget _buildCollectedSetCard(_CollectedSetEntry entry) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () => _removeSetFromMasterSets(
          setId: entry.setId,
          setName: entry.name,
        ),
        onTap: () => _openCollectedSet(entry),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 128),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 64,
                    width: double.infinity,
                    child: entry.setId.trim().toLowerCase() == 'mep'
                        ? Center(
                            child: Image.asset(
                              'assets/images/first_partner_series_collection_logo.png',
                              height: 64,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text(
                                'First Partner Series Collection 2026',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFF7DE77),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          )
                        : entry.isJapanese
                            ? _JapaneseSetLogoPreview(
                                set: entry.japaneseSet,
                                setId: entry.rawJapaneseSetId,
                              )
                            : ResolvedSetLogo(
                                setId: entry.setId,
                                setName: entry.name,
                                fallbackLogoUrl: entry.logoUrl,
                                height: 64,
                                fit: BoxFit.contain,
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.isJapanese) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFF7DE77).withValues(alpha: 0.36),
                            ),
                          ),
                          child: const Text(
                            'JP',
                            style: TextStyle(
                              color: Color(0xFFF7DE77),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          entry.setId.trim().toLowerCase() == 'mep'
                              ? 'First Partner Series Collection 2026'
                              : entry.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.savedCopies == 1
                        ? '1 saved card'
                        : '${entry.savedCopies} saved cards',
                    style: const TextStyle(
                      color: Color(0xFFC8D4F0),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Tooltip(
                message: 'Remove from Sets',
                child: IconButton(
                  onPressed: () => _removeSetFromMasterSets(
                    setId: entry.setId,
                    setName: entry.name,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetPokedexView() {
    return FutureBuilder<_SetCatalogue>(
      future: _futureSetCatalogue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || !_loadedCollectionState) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalogue = snapshot.data ?? const _SetCatalogue(
          englishSets: <TcgSet>[],
          japaneseSets: <JapaneseTcgSet>[],
        );
        final entries = _buildCollectedSetEntries(catalogue);
        final loadedSetTotal =
            catalogue.englishSets.length + catalogue.japaneseSets.length;
        final totalSets = loadedSetTotal > 0 ? loadedSetTotal : entries.length;

        return RefreshIndicator(
          onRefresh: refreshSets,
          child: entries.isEmpty
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
                            'Only English or Japanese sets with saved cards show here. Add a card to a set and it will appear here.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No set Pokédex entries yet. Add an English or Japanese card first and it will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: entries.length + 1,
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
                                  'English and Japanese sets with saved cards show here together.',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              Text(
                                '${entries.length}/$totalSets',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return _buildCollectedSetCard(entries[index - 1]);
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
                          builder: (_) => custom_binder_page.CustomBinderPage(
                            binder: binder,
                          ),
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
    // The navigation belongs to the scrolling page, not a fixed header.
    // National Pokédex includes it in its own single ListView. For the Set
    // Pokédex and Custom Binders we coordinate the existing lists with a
    // non-pinned sliver, preserving their pull-to-refresh and item layouts.
    if (_viewMode == MasterSetsViewMode.nationalPokedex) {
      return NationalPokedexPage(
        embedded: true,
        scrollHeader: _buildViewToggle(),
      );
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
        SliverToBoxAdapter(child: _buildViewToggle()),
      ],
      body: switch (_viewMode) {
        MasterSetsViewMode.setPokedex => _buildSetPokedexView(),
        MasterSetsViewMode.customBinders => _buildCustomBindersView(),
        MasterSetsViewMode.nationalPokedex => const SizedBox.shrink(),
      },
    );
  }
}

class _SetCatalogue {
  const _SetCatalogue({
    required this.englishSets,
    required this.japaneseSets,
  });

  final List<TcgSet> englishSets;
  final List<JapaneseTcgSet> japaneseSets;
}

class _CollectedSetEntry {
  const _CollectedSetEntry._({
    required this.setId,
    required this.name,
    required this.savedCopies,
    required this.releaseDate,
    this.logoUrl,
    this.englishSet,
    this.japaneseSet,
  });

  factory _CollectedSetEntry.english({
    required TcgSet set,
    required int savedCopies,
  }) {
    return _CollectedSetEntry._(
      setId: set.id,
      name: set.name,
      logoUrl: set.logoUrl,
      savedCopies: savedCopies,
      releaseDate: set.releaseDate,
      englishSet: set,
    );
  }

  factory _CollectedSetEntry.englishFallback({
    required String setId,
    required int savedCopies,
  }) {
    final normalized = setId.trim().toLowerCase();
    final displayName = normalized == '30th'
        ? '30th Celebration'
        : normalized == 'mep'
            ? 'First Partner Series Collection 2026'
            : setId;
    final fallbackSet = TcgSet(
      id: setId,
      name: displayName,
      series: '',
      total: 0,
      releaseDate: '',
    );
    return _CollectedSetEntry._(
      setId: setId,
      name: displayName,
      savedCopies: savedCopies,
      releaseDate: '',
      englishSet: fallbackSet,
    );
  }

  factory _CollectedSetEntry.japanese({
    required String setId,
    required JapaneseTcgSet? set,
    required int savedCopies,
  }) {
    final rawSetId = setId.startsWith('jp_') ? setId.substring(3) : setId;
    final fallbackSet = JapaneseTcgSet(
      id: rawSetId,
      name: rawSetId,
      series: '',
      logoUrl: '',
      symbolUrl: '',
      releaseDate: '',
      cardCount: 0,
    );
    return _CollectedSetEntry._(
      setId: setId,
      name: set?.displayName ?? fallbackSet.displayName,
      logoUrl: set?.logoUrl,
      savedCopies: savedCopies,
      releaseDate: set?.releaseDate ?? '',
      japaneseSet: set ?? fallbackSet,
    );
  }

  final String setId;
  final String name;
  final String? logoUrl;
  final int savedCopies;
  final String releaseDate;
  final TcgSet? englishSet;
  final JapaneseTcgSet? japaneseSet;

  bool get isJapanese => setId.startsWith('jp_');

  String get rawJapaneseSetId => isJapanese ? setId.substring(3) : setId;

  String get sortableReleaseDate => releaseDate.replaceAll('/', '-');
}

class _JapaneseSetLogoPreview extends StatelessWidget {
  const _JapaneseSetLogoPreview({
    required this.set,
    required this.setId,
  });

  final JapaneseTcgSet? set;
  final String setId;

  @override
  Widget build(BuildContext context) {
    final currentSet = set;
    final candidates = <String>[
      ..._englishEquivalentLogoCandidatesForMasterSets(setId),
      if (currentSet != null) ..._masterSetAssetCandidates(currentSet.logoUrl),
      if (currentSet != null) ..._masterSetAssetCandidates(currentSet.symbolUrl),
      ..._masterSetFallbackSetAssetCandidates(setId),
    ];

    return _MasterSetCandidateImage(
      candidates: candidates,
      fallbackText: currentSet?.displayName ?? setId,
    );
  }
}

class _MasterSetCandidateImage extends StatefulWidget {
  const _MasterSetCandidateImage({
    required this.candidates,
    required this.fallbackText,
  });

  final List<String> candidates;
  final String fallbackText;

  @override
  State<_MasterSetCandidateImage> createState() => _MasterSetCandidateImageState();
}

class _MasterSetCandidateImageState extends State<_MasterSetCandidateImage> {
  int _index = 0;

  List<String> get _cleanCandidates {
    final seen = <String>{};
    final results = <String>[];

    for (final candidate in widget.candidates) {
      final clean = candidate.trim();
      if (clean.isEmpty) continue;
      if (seen.add(clean)) results.add(clean);
    }

    return results;
  }

  @override
  void didUpdateWidget(covariant _MasterSetCandidateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidates.join('|') != widget.candidates.join('|')) {
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _cleanCandidates;
    if (candidates.isEmpty || _index >= candidates.length) {
      return Center(
        child: Text(
          widget.fallbackText,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      );
    }

    return Image.network(
      candidates[_index],
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_index < candidates.length) {
            setState(() => _index += 1);
          }
        });

        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFF7DE77),
            ),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFF7DE77),
            ),
          ),
        );
      },
    );
  }
}

List<String> _englishEquivalentLogoCandidatesForMasterSets(String japaneseSetId) {
  final cleanId = japaneseSetId.trim().toLowerCase();
  final englishSetId = _englishLogoSetIdByJapaneseIdForMasterSets[cleanId];
  if (englishSetId == null || englishSetId.isEmpty) return const <String>[];

  final encodedId = Uri.encodeComponent(englishSetId);
  return <String>[
    'https://images.pokemontcg.io/$encodedId/logo.png',
    'https://images.pokemontcg.io/$encodedId/symbol.png',
  ];
}

const Map<String, String> _englishLogoSetIdByJapaneseIdForMasterSets = <String, String>{
  'sv8a': 'sv8pt5',
  'sv8': 'sv8',
  'sv7a': 'sv8',
  'sv7': 'sv7',
  'sv6a': 'sv6pt5',
  'sv6': 'sv6',
  'sv5a': 'sv6',
  'sv5k': 'sv5',
  'sv5m': 'sv5',
  'sv4a': 'sv4pt5',
  'sv4k': 'sv4',
  'sv4m': 'sv4',
  'sv3a': 'sv4',
  'sv3': 'sv3',
  'sv2a': 'sv3pt5',
  'sv2p': 'sv2',
  'sv2d': 'sv2',
  'sv1a': 'sv2',
  'sv1s': 'sv1',
  'sv1v': 'sv1',
  's12a': 'swsh12pt5',
  's12': 'swsh12',
  's11a': 'swsh12',
  's11': 'swsh11',
  's10a': 'swsh11',
  's10d': 'swsh10',
  's10p': 'swsh10',
  's9a': 'swsh10',
  's9': 'swsh9',
  's8b': 'swsh9',
  's8': 'swsh8',
  's7r': 'swsh7',
  's7d': 'swsh7',
  's6a': 'swsh7',
  's6h': 'swsh6',
  's6k': 'swsh6',
  's5a': 'swsh6',
  's5i': 'swsh5',
  's5r': 'swsh5',
  's4a': 'swsh45',
  's4': 'swsh4',
  's3': 'swsh3',
  's2': 'swsh2',
};

List<String> _masterSetAssetCandidates(String url) {
  final clean = _normaliseMasterSetAssetUrl(url);
  if (clean.isEmpty) return const <String>[];

  if (_hasMasterSetImageExtension(clean)) {
    return <String>[clean];
  }

  return <String>[
    '$clean.webp',
    '$clean.png',
    '$clean.jpg',
    '$clean.jpeg',
    clean,
  ];
}

List<String> _masterSetFallbackSetAssetCandidates(String setId) {
  final cleanId = setId.trim();
  if (cleanId.isEmpty) return const <String>[];

  final group = _masterSetAssetGroup(cleanId);
  if (group.isEmpty) return const <String>[];

  final encodedId = Uri.encodeComponent(cleanId);
  final encodedGroup = Uri.encodeComponent(group);

  return <String>[
    'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/logo.webp',
    'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/logo.png',
    'https://assets.tcgdex.net/ja/$encodedGroup/$encodedId/logo.jpg',
    'https://assets.tcgdex.net/univ/$encodedGroup/$encodedId/symbol.webp',
    'https://assets.tcgdex.net/univ/$encodedGroup/$encodedId/symbol.png',
    'https://assets.tcgdex.net/univ/$encodedGroup/$encodedId/symbol.jpg',
  ];
}

String _normaliseMasterSetAssetUrl(String url) {
  final clean = url.trim();
  if (clean.isEmpty) return '';
  if (clean.startsWith('https://') || clean.startsWith('http://')) return clean;
  if (clean.startsWith('//')) return 'https:$clean';
  if (clean.startsWith('/')) return 'https://assets.tcgdex.net$clean';
  return 'https://assets.tcgdex.net/$clean';
}

bool _hasMasterSetImageExtension(String url) {
  final lower = url.toLowerCase().split('?').first;
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp');
}

String _masterSetAssetGroup(String setId) {
  final clean = setId.trim().toLowerCase();
  if (clean.isEmpty) return '';

  if (clean.startsWith('swsh')) return 'swsh';
  if (clean.startsWith('sv')) return 'sv';
  if (clean.startsWith('sm')) return 'sm';
  if (clean.startsWith('xy')) return 'xy';
  if (clean.startsWith('bw')) return 'bw';
  if (clean.startsWith('dp')) return 'dp';
  if (clean.startsWith('pl')) return 'pl';
  if (clean.startsWith('hgss')) return 'hgss';
  if (clean.startsWith('neo')) return 'neo';
  if (clean.startsWith('ex')) return 'ex';
  if (clean.startsWith('base')) return 'base';
  if (clean.startsWith('web')) return 'web';
  if (clean.startsWith('pcg')) return 'pcg';
  if (clean.startsWith('adv')) return 'adv';
  if (clean.startsWith('e')) return 'e';

  final match = RegExp(r'^[a-z]+').firstMatch(clean);
  return match?.group(0) ?? '';
}


