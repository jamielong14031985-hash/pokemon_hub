import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user_profile.dart';
import '../models/community_models.dart';
import '../services/community_safety_service.dart';
import '../services/friend_service.dart';
import '../services/community_unread_private_message_service.dart';
import '../services/pro_status_service.dart';
import '../utils/community_dialog_helpers.dart';
import '../utils/community_market_helpers.dart';
import '../utils/community_private_helpers.dart';
import '../widgets/community_filter_chip.dart';
import '../widgets/community_post_card.dart';
import '../widgets/community_seller_trust_widgets.dart';
import '../widgets/community_user_avatar.dart';
import '../widgets/create_community_post_sheet.dart';
import '../widgets/friend_action_button.dart';
import '../widgets/trade_safety_mini_banner.dart';
import '../widgets/trade_safety_panel.dart';
import 'community_blocked_users_page.dart';
import 'community_post_thread_page.dart';
import 'community_private_inbox_page.dart';
import 'friend_requests_page.dart';
import 'social_pages.dart';

class _CommunityArea {
  const _CommunityArea({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String _section = 'Marketplace';
  String _filter = 'All';
  String _marketStatusFilter = 'All';
  String _areaFilter = 'All';
  StreamSubscription<Set<String>>? _blockedUsersSub;
  Set<String> _blockedUserIds = <String>{};
  int? _lastSeenAtMs;
  bool _loadedLastSeen = false;
  bool _isAdminOrModerator = false;
  final Set<String> _featureBusyPostIds = <String>{};
  bool _savedVisitMarker = false;
  late final int _visitStartedAtMs;
  final TextEditingController _archiveSearchController = TextEditingController();
  final FocusNode _archiveSearchFocusNode = FocusNode();
  Timer? _archiveSearchDebounce;
  String _archiveSearchQuery = '';
  DateTime? _archiveDeletedDateFilter;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream;

  static const List<_CommunityArea> _communityAreaOptions = <_CommunityArea>[
    _CommunityArea(key: 'All', label: 'All counties / areas'),
    _CommunityArea(key: 'bedfordshire', label: 'Bedfordshire'),
    _CommunityArea(key: 'berkshire', label: 'Berkshire'),
    _CommunityArea(key: 'bristol', label: 'Bristol'),
    _CommunityArea(key: 'buckinghamshire', label: 'Buckinghamshire'),
    _CommunityArea(key: 'cambridgeshire', label: 'Cambridgeshire'),
    _CommunityArea(key: 'cheshire', label: 'Cheshire'),
    _CommunityArea(key: 'city_of_london', label: 'City of London'),
    _CommunityArea(key: 'cornwall', label: 'Cornwall'),
    _CommunityArea(key: 'county_durham', label: 'County Durham'),
    _CommunityArea(key: 'cumbria', label: 'Cumbria'),
    _CommunityArea(key: 'derbyshire', label: 'Derbyshire'),
    _CommunityArea(key: 'devon', label: 'Devon'),
    _CommunityArea(key: 'dorset', label: 'Dorset'),
    _CommunityArea(
      key: 'east_riding_of_yorkshire',
      label: 'East Riding of Yorkshire',
    ),
    _CommunityArea(key: 'east_sussex', label: 'East Sussex'),
    _CommunityArea(key: 'essex', label: 'Essex'),
    _CommunityArea(key: 'gloucestershire', label: 'Gloucestershire'),
    _CommunityArea(key: 'greater_london', label: 'Greater London'),
    _CommunityArea(key: 'greater_manchester', label: 'Greater Manchester'),
    _CommunityArea(key: 'hampshire', label: 'Hampshire'),
    _CommunityArea(key: 'herefordshire', label: 'Herefordshire'),
    _CommunityArea(key: 'hertfordshire', label: 'Hertfordshire'),
    _CommunityArea(key: 'isle_of_wight', label: 'Isle of Wight'),
    _CommunityArea(key: 'kent', label: 'Kent'),
    _CommunityArea(key: 'lancashire', label: 'Lancashire'),
    _CommunityArea(key: 'leicestershire', label: 'Leicestershire'),
    _CommunityArea(key: 'lincolnshire', label: 'Lincolnshire'),
    _CommunityArea(key: 'merseyside', label: 'Merseyside'),
    _CommunityArea(key: 'norfolk', label: 'Norfolk'),
    _CommunityArea(key: 'north_yorkshire', label: 'North Yorkshire'),
    _CommunityArea(key: 'northamptonshire', label: 'Northamptonshire'),
    _CommunityArea(key: 'northumberland', label: 'Northumberland'),
    _CommunityArea(key: 'nottinghamshire', label: 'Nottinghamshire'),
    _CommunityArea(key: 'oxfordshire', label: 'Oxfordshire'),
    _CommunityArea(key: 'rutland', label: 'Rutland'),
    _CommunityArea(key: 'shropshire', label: 'Shropshire'),
    _CommunityArea(key: 'somerset', label: 'Somerset'),
    _CommunityArea(key: 'south_yorkshire', label: 'South Yorkshire'),
    _CommunityArea(key: 'staffordshire', label: 'Staffordshire'),
    _CommunityArea(key: 'suffolk', label: 'Suffolk'),
    _CommunityArea(key: 'surrey', label: 'Surrey'),
    _CommunityArea(key: 'tyne_and_wear', label: 'Tyne and Wear'),
    _CommunityArea(key: 'warwickshire', label: 'Warwickshire'),
    _CommunityArea(key: 'west_midlands', label: 'West Midlands'),
    _CommunityArea(key: 'west_sussex', label: 'West Sussex'),
    _CommunityArea(key: 'west_yorkshire', label: 'West Yorkshire'),
    _CommunityArea(key: 'wiltshire', label: 'Wiltshire'),
    _CommunityArea(key: 'worcestershire', label: 'Worcestershire'),
    _CommunityArea(key: 'anglesey', label: 'Anglesey'),
    _CommunityArea(key: 'blaenau_gwent', label: 'Blaenau Gwent'),
    _CommunityArea(key: 'bridgend', label: 'Bridgend'),
    _CommunityArea(key: 'caerphilly', label: 'Caerphilly'),
    _CommunityArea(key: 'cardiff', label: 'Cardiff'),
    _CommunityArea(key: 'carmarthenshire', label: 'Carmarthenshire'),
    _CommunityArea(key: 'ceredigion', label: 'Ceredigion'),
    _CommunityArea(key: 'conwy', label: 'Conwy'),
    _CommunityArea(key: 'denbighshire', label: 'Denbighshire'),
    _CommunityArea(key: 'flintshire', label: 'Flintshire'),
    _CommunityArea(key: 'gwynedd', label: 'Gwynedd'),
    _CommunityArea(key: 'merthyr_tydfil', label: 'Merthyr Tydfil'),
    _CommunityArea(key: 'monmouthshire', label: 'Monmouthshire'),
    _CommunityArea(key: 'neath_port_talbot', label: 'Neath Port Talbot'),
    _CommunityArea(key: 'newport', label: 'Newport'),
    _CommunityArea(key: 'pembrokeshire', label: 'Pembrokeshire'),
    _CommunityArea(key: 'powys', label: 'Powys'),
    _CommunityArea(key: 'rhondda_cynon_taf', label: 'Rhondda Cynon Taf'),
    _CommunityArea(key: 'swansea', label: 'Swansea'),
    _CommunityArea(key: 'torfaen', label: 'Torfaen'),
    _CommunityArea(key: 'vale_of_glamorgan', label: 'Vale of Glamorgan'),
    _CommunityArea(key: 'wrexham', label: 'Wrexham'),
    _CommunityArea(key: 'aberdeen_city', label: 'Aberdeen City'),
    _CommunityArea(key: 'aberdeenshire', label: 'Aberdeenshire'),
    _CommunityArea(key: 'angus', label: 'Angus'),
    _CommunityArea(key: 'argyll_and_bute', label: 'Argyll and Bute'),
    _CommunityArea(key: 'city_of_edinburgh', label: 'City of Edinburgh'),
    _CommunityArea(key: 'clackmannanshire', label: 'Clackmannanshire'),
    _CommunityArea(
      key: 'dumfries_and_galloway',
      label: 'Dumfries and Galloway',
    ),
    _CommunityArea(key: 'dundee_city', label: 'Dundee City'),
    _CommunityArea(key: 'east_ayrshire', label: 'East Ayrshire'),
    _CommunityArea(
      key: 'east_dunbartonshire',
      label: 'East Dunbartonshire',
    ),
    _CommunityArea(key: 'east_lothian', label: 'East Lothian'),
    _CommunityArea(key: 'east_renfrewshire', label: 'East Renfrewshire'),
    _CommunityArea(key: 'falkirk', label: 'Falkirk'),
    _CommunityArea(key: 'fife', label: 'Fife'),
    _CommunityArea(key: 'glasgow_city', label: 'Glasgow City'),
    _CommunityArea(key: 'highland', label: 'Highland'),
    _CommunityArea(key: 'inverclyde', label: 'Inverclyde'),
    _CommunityArea(key: 'midlothian', label: 'Midlothian'),
    _CommunityArea(key: 'moray', label: 'Moray'),
    _CommunityArea(key: 'na_h_eileanan_siar', label: 'Na h-Eileanan Siar'),
    _CommunityArea(key: 'north_ayrshire', label: 'North Ayrshire'),
    _CommunityArea(key: 'north_lanarkshire', label: 'North Lanarkshire'),
    _CommunityArea(key: 'orkney_islands', label: 'Orkney Islands'),
    _CommunityArea(key: 'perth_and_kinross', label: 'Perth and Kinross'),
    _CommunityArea(key: 'renfrewshire', label: 'Renfrewshire'),
    _CommunityArea(key: 'scottish_borders', label: 'Scottish Borders'),
    _CommunityArea(key: 'shetland_islands', label: 'Shetland Islands'),
    _CommunityArea(key: 'south_ayrshire', label: 'South Ayrshire'),
    _CommunityArea(key: 'south_lanarkshire', label: 'South Lanarkshire'),
    _CommunityArea(key: 'stirling', label: 'Stirling'),
    _CommunityArea(
      key: 'west_dunbartonshire',
      label: 'West Dunbartonshire',
    ),
    _CommunityArea(key: 'west_lothian', label: 'West Lothian'),
    _CommunityArea(
      key: 'antrim_and_newtownabbey',
      label: 'Antrim and Newtownabbey',
    ),
    _CommunityArea(
      key: 'ards_and_north_down',
      label: 'Ards and North Down',
    ),
    _CommunityArea(
      key: 'armagh_banbridge_craigavon',
      label: 'Armagh, Banbridge and Craigavon',
    ),
    _CommunityArea(key: 'belfast', label: 'Belfast'),
    _CommunityArea(
      key: 'causeway_coast_and_glens',
      label: 'Causeway Coast and Glens',
    ),
    _CommunityArea(key: 'derry_and_strabane', label: 'Derry and Strabane'),
    _CommunityArea(
      key: 'fermanagh_and_omagh',
      label: 'Fermanagh and Omagh',
    ),
    _CommunityArea(
      key: 'lisburn_and_castlereagh',
      label: 'Lisburn and Castlereagh',
    ),
    _CommunityArea(key: 'mid_and_east_antrim', label: 'Mid and East Antrim'),
    _CommunityArea(key: 'mid_ulster', label: 'Mid Ulster'),
    _CommunityArea(
      key: 'newry_mourne_and_down',
      label: 'Newry, Mourne and Down',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _postsStream = FirebaseFirestore.instance
        .collection('community_posts')
        .orderBy('createdAtMs', descending: true)
        .snapshots();
    _visitStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    _loadLastSeen();
    _loadAdminStatus();

    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;
    _blockedUsersSub = CommunitySafetyService.blockedUserIdsStream(currentUid).listen(
      (blockedUserIds) {
        if (!mounted) return;
        setState(() {
          _blockedUserIds = blockedUserIds;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _blockedUserIds = <String>{};
        });
      },
    );
  }

  @override
  void dispose() {
    _blockedUsersSub?.cancel();
    _archiveSearchDebounce?.cancel();
    _archiveSearchFocusNode.dispose();
    _archiveSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminStatus() async {
    final currentUid =
        (FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid).trim();
    if (currentUid.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app_roles')
          .doc(currentUid)
          .get();

      final data = snapshot.data();
      final role = data?['role']?.toString().trim().toLowerCase() ?? '';
      final isAdminOrModerator = role == 'admin' || role == 'moderator';

      if (!mounted) return;
      setState(() {
        _isAdminOrModerator = isAdminOrModerator;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdminOrModerator = false;
      });
    }
  }

  String _lastSeenPrefsKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;
    return 'community_last_seen_$uid';
  }

  Future<void> _loadLastSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_lastSeenPrefsKey());
      if (!mounted) return;
      setState(() {
        _lastSeenAtMs = saved;
        _loadedLastSeen = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastSeenAtMs = null;
        _loadedLastSeen = true;
      });
    }
  }

  Future<void> _markVisitSeenIfNeeded() async {
    if (_savedVisitMarker) return;
    _savedVisitMarker = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSeenPrefsKey(), _visitStartedAtMs);
    } catch (_) {
      // The community feed should still work if local preferences are unavailable.
    }
  }

  CommunityPost? _safePostFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return CommunityPost.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }


  String _normaliseAreaKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _safeAreaFilterKey(String value) {
    final trimmed = value.trim();
    if (trimmed == 'All') return 'All';

    final normalised = _normaliseAreaKey(trimmed);
    if (normalised.isEmpty) return 'All';

    for (final area in _communityAreaOptions) {
      if (area.key == normalised || _normaliseAreaKey(area.label) == normalised) {
        return area.key;
      }
    }

    return 'All';
  }

  String _areaLabelForKey(String key) {
    final safeKey = _safeAreaFilterKey(key);
    for (final area in _communityAreaOptions) {
      if (area.key == safeKey) return area.label;
    }
    return 'All counties / areas';
  }

  String _postAreaKeyFromData(Map<String, dynamic> data) {
    final areaKey = (data['areaKey'] ?? data['countyKey'] ?? '').toString().trim();
    final normalisedAreaKey = _normaliseAreaKey(areaKey);

    for (final area in _communityAreaOptions) {
      if (area.key != 'All' && area.key == normalisedAreaKey) {
        return area.key;
      }
    }

    final areaText = (data['area'] ?? data['county'] ?? '').toString().trim();
    final normalisedAreaText = _normaliseAreaKey(areaText);

    for (final area in _communityAreaOptions) {
      if (area.key == 'All') continue;
      if (area.key == normalisedAreaText ||
          _normaliseAreaKey(area.label) == normalisedAreaText) {
        return area.key;
      }
    }

    final locationText = (data['locationText'] ?? '').toString().toLowerCase();
    if (locationText.isNotEmpty) {
      for (final area in _communityAreaOptions) {
        if (area.key == 'All') continue;
        if (locationText.contains(area.label.toLowerCase())) {
          return area.key;
        }
      }
    }

    return '';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _postIsArchivedForAdmin(Map<String, dynamic> data) {
    return data['archivedForAdmin'] == true ||
        data['hiddenFromUsers'] == true ||
        data['deletedForUsers'] == true;
  }

  bool get _hasActiveArchiveFilters {
    return _archiveSearchQuery.trim().isNotEmpty ||
        _archiveDeletedDateFilter != null;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatArchiveDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
  }

  int? _deletedAtMsFromArchiveData(Map<String, dynamic>? data) {
    if (data == null) return null;

    final deletedAtMs = data['deletedAtMs'];
    if (deletedAtMs is num) return deletedAtMs.toInt();

    final deletedAt = data['deletedAt'];
    if (deletedAt is Timestamp) {
      return deletedAt.millisecondsSinceEpoch;
    }

    return null;
  }

  bool _matchesArchiveDeletedDate(Map<String, dynamic>? data) {
    final selectedDate = _archiveDeletedDateFilter;
    if (selectedDate == null) return true;

    final deletedAtMs = _deletedAtMsFromArchiveData(data);
    if (deletedAtMs == null || deletedAtMs <= 0) return false;

    final deletedDate = _dateOnly(
      DateTime.fromMillisecondsSinceEpoch(deletedAtMs),
    );
    return deletedDate == _dateOnly(selectedDate);
  }

  bool _matchesArchiveSearch(CommunityPost post, Map<String, dynamic>? data) {
    final query = _archiveSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchableText = <String>[
      post.title,
      post.authorName,
      post.authorId,
      (data?['authorName'] ?? '').toString(),
      (data?['businessName'] ?? '').toString(),
      (data?['shopName'] ?? '').toString(),
      (data?['ownerName'] ?? '').toString(),
      (data?['deletedByName'] ?? '').toString(),
      (data?['deletedByEmail'] ?? '').toString(),
    ].join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  bool _archivePostMatchesFilters(
    CommunityPost post,
    Map<String, dynamic>? data,
  ) {
    return _matchesArchiveSearch(post, data) &&
        _matchesArchiveDeletedDate(data);
  }

  Future<void> _pickArchiveDeletedDateFilter() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _archiveDeletedDateFilter ?? now,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: now,
      helpText: 'Search archive by deleted date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFF7DE77),
              brightness: Brightness.dark,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _archiveDeletedDateFilter = _dateOnly(picked);
    });
  }

  void _clearArchiveFilters() {
    _archiveSearchDebounce?.cancel();
    setState(() {
      _archiveSearchController.clear();
      _archiveSearchQuery = '';
      _archiveDeletedDateFilter = null;
    });
  }

  void _handleArchiveSearchChanged(String value) {
    _archiveSearchDebounce?.cancel();
    _archiveSearchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted || _section != 'Admin archive') return;
      final nextQuery = value.trim();
      if (nextQuery == _archiveSearchQuery) return;
      setState(() {
        _archiveSearchQuery = nextQuery;
      });
    });
  }

  Future<void> _openTradeSafetyGuide() async {
    await showTradeSafetyGuide(context);
  }

  Future<void> _openCreatePostSheet({String? initialPostType}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      builder: (_) => CreateCommunityPostSheet(
        profile: widget.profile,
        initialPostType: initialPostType,
      ),
    );
  }

  Future<void> _openEditPostSheet(CommunityPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      builder: (_) => CreateCommunityPostSheet(
        profile: widget.profile,
        existingPost: post,
      ),
    );
  }

  bool get _hasActiveMarketplaceFilters =>
      _filter != 'All' || _marketStatusFilter != 'All' || _areaFilter != 'All';

  String get _marketplaceFilterSummary {
    final listingType =
        _filter == 'All' ? 'Sale, swap and wanted listings' : '$_filter listings';
    final listingStatus = _marketStatusFilter == 'All'
        ? 'all statuses'
        : '${_marketStatusFilter.toLowerCase()} status';
    final listingArea =
        _areaFilter == 'All' ? 'all areas' : _areaLabelForKey(_areaFilter);
    return '$listingType • $listingStatus • $listingArea';
  }

  InputDecoration _filterSheetDropdownDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      filled: true,
      fillColor: const Color(0xFF16366E),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF3F5C96)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF3F5C96)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _openMarketplaceFiltersSheet() async {
    var selectedType = _filter;
    var selectedStatus = _marketStatusFilter;
    var selectedArea = _areaFilter;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, _) {
                  final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 18,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
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
                          Flexible(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Marketplace filters',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Choose the listing type, status, and county you want to see.',
                                    style: TextStyle(
                                      color: Color(0xFFC8D4F0),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Listing type',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      CommunityFilterChip(
                                        label: 'All',
                                        selected: selectedType == 'All',
                                        minWidth: 82,
                                        onTap: () => setSheetState(
                                          () => selectedType = 'All',
                                        ),
                                      ),
                                      CommunityFilterChip(
                                        label: 'Swap',
                                        selected: selectedType == 'Swap',
                                        minWidth: 94,
                                        onTap: () => setSheetState(
                                          () => selectedType = 'Swap',
                                        ),
                                      ),
                                      CommunityFilterChip(
                                        label: 'For Sale',
                                        selected: selectedType == 'For Sale',
                                        minWidth: 118,
                                        onTap: () => setSheetState(
                                          () => selectedType = 'For Sale',
                                        ),
                                      ),
                                      CommunityFilterChip(
                                        label: 'Wanted',
                                        selected: selectedType == 'Wanted',
                                        minWidth: 112,
                                        onTap: () => setSheetState(
                                          () => selectedType = 'Wanted',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Status',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: communityMarketStatuses.map((status) {
                                      return CommunityFilterChip(
                                        label: status,
                                        selected: selectedStatus == status,
                                        minWidth: status == 'Available' ? 118 : 96,
                                        onTap: () => setSheetState(
                                          () => selectedStatus = status,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'County / area',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: _safeAreaFilterKey(selectedArea),
                                    isExpanded: true,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    iconEnabledColor: const Color(0xFFE4ECFF),
                                    dropdownColor: const Color(0xFF143163),
                                    decoration: _filterSheetDropdownDecoration(
                                      'Choose county / area',
                                    ),
                                    items: _communityAreaOptions
                                        .map(
                                          (area) => DropdownMenuItem(
                                            value: area.key,
                                            child: Text(area.label),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setSheetState(
                                      () => selectedArea =
                                          _safeAreaFilterKey(value ?? 'All'),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setSheetState(() {
                                      selectedType = 'All';
                                      selectedStatus = 'All';
                                      selectedArea = 'All';
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Color(0xFF3F5C96),
                                    ),
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                  child: const Text('Reset'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                  child: const Text('Apply'),
                                ),
                              ),
                            ],
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
      },
    );

    if (applied == true && mounted) {
      setState(() {
        _filter = selectedType;
        _marketStatusFilter = selectedStatus;
        _areaFilter = _safeAreaFilterKey(selectedArea);
      });
    }
  }

  Future<void> _deletePost(CommunityPost post) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = (currentUser?.uid ?? widget.profile.uid).trim();
    final isOwnPost = post.authorId.trim() == currentUid;

    if (currentUid.isEmpty || (!isOwnPost && !_isAdminOrModerator)) {
      _showMessage('Only the post owner or an admin can remove this post.');
      return;
    }

    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102754),
        title: const Text(
          'Delete post?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete the post from the community and move it into the admin archive for review.',
          style: TextStyle(color: Color(0xFFC8D4F0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB13B59),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete post'),
          ),
        ],
      ),
    );

    if (shouldArchive != true) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final postRef =
          FirebaseFirestore.instance.collection('community_posts').doc(post.id);

      await postRef.set(
        <String, dynamic>{
          'archivedForAdmin': true,
          'hiddenFromUsers': true,
          'deletedForUsers': true,
          'deleteReason': post.isMarketplace
              ? 'Completed / removed marketplace post'
              : 'Deleted discussion post',
          'deletedAtMs': now,
          'deletedByUid': currentUid,
          'deletedByName': widget.profile.displayName,
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );

      _showMessage('Post deleted and moved to the admin archive.');
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not delete post.');
    } catch (_) {
      _showMessage('Could not delete post.');
    }
  }

  Future<void> _updateMarketStatus(CommunityPost post, String status) async {
    if (!post.isMarketplace) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await FirebaseFirestore.instance.collection('community_posts').doc(post.id).set(
        <String, dynamic>{
          'marketStatus': normalizeCommunityMarketStatus(status),
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
      _showMessage(
        '${post.title} marked as ${normalizeCommunityMarketStatus(status)}.',
      );
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not update listing status.');
    } catch (_) {
      _showMessage('Could not update listing status.');
    }
  }

  Future<void> _bumpPost(CommunityPost post) async {
    if (!post.isMarketplace) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await FirebaseFirestore.instance.collection('community_posts').doc(post.id).set(
        <String, dynamic>{
          'lastBumpedAtMs': now,
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
      _showMessage('Listing bumped to the top of your latest activity view.');
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not bump listing.');
    } catch (_) {
      _showMessage('Could not bump listing.');
    }
  }

  Future<void> _toggleUserFeaturedPost(CommunityPost post) async {
    final currentUid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (currentUid.isEmpty) {
      _showMessage('Please sign in before featuring a post.');
      return;
    }

    if (post.authorId != currentUid) {
      _showMessage('You can only choose one of your own posts as your Pro featured post.');
      return;
    }

    if (!ProStatusService.isProActive) {
      _showMessage('Featured posts are available with PocketChase Pro.');
      return;
    }

    if (_featureBusyPostIds.contains(post.id)) return;

    final shouldFeature = !post.isUserFeatured;
    if (shouldFeature) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF102754),
          title: const Text(
            'Make featured post?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This will make this your one Pro featured post. If you already have another Pro featured post, it will be changed to this one.',
            style: TextStyle(color: Color(0xFFC8D4F0)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Make featured'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() {
      _featureBusyPostIds.add(post.id);
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('setUserFeaturedCommunityPost');
      await callable.call(<String, dynamic>{
        'postId': post.id,
        'featured': shouldFeature,
      });

      _showMessage(
        shouldFeature
            ? 'Your featured post has been updated.'
            : 'Your featured post has been removed.',
      );
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'Could not update your featured post.');
    } catch (_) {
      _showMessage('Could not update your featured post.');
    } finally {
      if (mounted) {
        setState(() {
          _featureBusyPostIds.remove(post.id);
        });
      }
    }
  }

  Future<void> _toggleAdminFeaturedPost(CommunityPost post) async {
    if (!_isAdminOrModerator) return;
    if (_featureBusyPostIds.contains(post.id)) return;

    final shouldFeature = !post.isAdminFeatured;

    setState(() {
      _featureBusyPostIds.add(post.id);
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('setAdminFeaturedCommunityPost');
      await callable.call(<String, dynamic>{
        'postId': post.id,
        'featured': shouldFeature,
      });

      _showMessage(
        shouldFeature
            ? 'Post has been admin featured.'
            : 'Admin feature removed from post.',
      );
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'Could not update admin featured post.');
    } catch (_) {
      _showMessage('Could not update admin featured post.');
    } finally {
      if (mounted) {
        setState(() {
          _featureBusyPostIds.remove(post.id);
        });
      }
    }
  }

  Future<void> _reportPost(CommunityPost post) async {
    await showCommunityReportSheet(
      context: context,
      currentProfile: widget.profile,
      reportedUid: post.authorId,
      reportedName: post.authorName,
      targetType: 'post',
      targetId: post.id,
      targetTitle: post.title,
    );
  }

  Future<void> _blockCommunityMember({
    required String memberId,
    required String memberName,
  }) async {
    final blocked = await confirmBlockCommunityUser(
      context: context,
      currentProfile: widget.profile,
      blockedUid: memberId,
      blockedName: memberName,
      source: 'community_feed',
    );
    if (blocked && mounted) {
      setState(() {
        _blockedUserIds = <String>{..._blockedUserIds, memberId.trim()};
      });
    }
  }

  Future<void> _openBlockedUsersPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityBlockedUsersPage(currentProfile: widget.profile),
      ),
    );
  }

  List<CommunityPost> _visiblePosts(
    List<CommunityPost> posts,
    Map<String, String> areaKeysByPostId,
  ) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;

    final basePosts = _section == 'Admin archive'
        ? posts
        : posts
            .where(
              (post) =>
                  post.authorId == currentUid ||
                  !_blockedUserIds.contains(post.authorId),
            )
            .toList();

    if (_section == 'Admin archive') {
      final visible = basePosts.toList()
        ..sort((a, b) => b.lastActivityAtMs.compareTo(a.lastActivityAtMs));
      return visible;
    }

    final sectionPosts = _section == 'Discussions'
        ? basePosts.where((post) => post.isDiscussion).toList()
        : basePosts.where((post) => post.isMarketplace).toList();

    Iterable<CommunityPost> filtered = sectionPosts;
    if (_section == 'Marketplace' && _filter != 'All') {
      filtered = filtered.where((post) => post.postType == _filter);
    }
    if (_section == 'Marketplace' && _marketStatusFilter != 'All') {
      filtered = filtered.where(
        (post) => post.normalizedMarketStatus == _marketStatusFilter,
      );
    }
    if (_section == 'Marketplace' && _areaFilter != 'All') {
      filtered = filtered.where(
        (post) => areaKeysByPostId[post.id] == _areaFilter,
      );
    }

    final visible = filtered.toList()
      ..sort((a, b) {
        final featuredCompare =
            (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0);
        if (featuredCompare != 0) return featuredCompare;

        if (a.isFeatured && b.isFeatured) {
          final featuredTimeCompare =
              b.featuredSortAtMs.compareTo(a.featuredSortAtMs);
          if (featuredTimeCompare != 0) return featuredTimeCompare;
        }

        return b.lastActivityAtMs.compareTo(a.lastActivityAtMs);
      });
    return visible;
  }

  Future<void> _openPrivateInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPrivateInboxPage(currentProfile: widget.profile),
      ),
    );
  }

  Future<void> _openFriendRequestsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendRequestsPage(currentProfile: widget.profile),
      ),
    );
  }

  Future<void> _openPrivateMessageForPost(CommunityPost post) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final otherUserId = post.authorId.trim();
    if (otherUserId.isEmpty) {
      _showMessage('This post cannot be messaged right now.');
      return;
    }

    if (otherUserId == currentUser.uid) {
      _showMessage('This is your post. Open your inbox for existing chats.');
      return;
    }

    var isBlocked = false;
    try {
      isBlocked = await CommunitySafetyService.isBlocked(
        ownerUid: currentUser.uid,
        blockedUid: otherUserId,
      );
    } catch (_) {
      isBlocked = false;
    }

    if (isBlocked) {
      _showMessage(
        'You have blocked this member. Unblock them before sending a message.',
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final conversationId = communityConversationIdForPost(
      postId: post.id,
      userAId: currentUser.uid,
      userBId: otherUserId,
    );

    try {
      await syncCommunityPrivateConversation(
        conversationId: conversationId,
        currentUid: currentUser.uid,
        currentUserName: widget.profile.displayName,
        otherUserId: otherUserId,
        otherUserName: post.authorName,
        relatedPostId: post.id,
        relatedPostTitle: post.title,
        createdAtMs: now,
        updatedAtMs: now,
      );
    } catch (_) {
      // The chat screen can still open and retry when the first message is sent.
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPrivateChatPage(
          conversationId: conversationId,
          currentProfile: widget.profile,
          otherUserId: otherUserId,
          otherUserName: post.authorName,
          relatedPostId: post.id,
          relatedPostTitle: post.title,
        ),
      ),
    );
  }

  Future<void> _openPostAuthorRatingSheet(CommunityPost post) async {
    final sellerId = post.authorId.trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;
    if (sellerId.isEmpty) {
      _showMessage('This member cannot be rated right now.');
      return;
    }
    if (sellerId == currentUid) {
      _showMessage('You cannot rate yourself.');
      return;
    }

    final saved = await showCommunityRatingSheet(
      context: context,
      currentProfile: widget.profile,
      sellerId: sellerId,
      sellerName: post.authorName,
      sourcePostId: post.id,
      sourcePostTitle: post.title,
    );
    if (saved == true) {
      _showMessage('Rating saved.');
    }
  }

  Future<void> _openCommunityMemberSheet(CommunityPost post) async {
    final otherUserId = post.authorId.trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;
    if (otherUserId.isEmpty || otherUserId == currentUid) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = MediaQuery.of(context).size.height * 0.88;

              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Center(
                        child: CommunityUserAvatar(
                          userId: post.authorId,
                          displayName: post.authorName,
                          size: 62,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        post.authorName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose an action for this community member.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CommunitySellerTrustPanel(
                        sellerId: post.authorId,
                        sellerName: post.authorName,
                        compact: true,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _openPostAuthorRatingSheet(post);
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: const Color(0xFFF7DE77),
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.star_outline_rounded),
                        label: const Text(
                          'Rate this seller',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _openPrivateMessageForPost(post);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF3F5C96)),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded),
                        label: const Text(
                          'Send message',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FriendActionButton(
                        currentProfile: widget.profile,
                        otherUserId: post.authorId,
                        otherUserName: post.authorName,
                        onOpenFriendProfile: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FriendProfilePage(
                                currentProfile: widget.profile,
                                friendUid: post.authorId,
                                friendName: post.authorName,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _reportPost(post);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF3F5C96)),
                        ),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text(
                          'Report post',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _blockCommunityMember(
                            memberId: post.authorId,
                            memberName: post.authorName,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: const Color(0xFFFFCDD2),
                          side: const BorderSide(color: Color(0xFFB13B59)),
                        ),
                        icon: const Icon(Icons.block_outlined),
                        label: const Text(
                          'Block member',
                          style: TextStyle(fontWeight: FontWeight.w800),
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


  Widget _buildPrivateInboxButton() {
    final currentUid =
        (FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid).trim();

    Widget buildButton({required bool hasUnreadPrivateMessages}) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: hasUnreadPrivateMessages
              ? [
                  BoxShadow(
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.72),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            onPressed: _openPrivateInbox,
            style: OutlinedButton.styleFrom(
              foregroundColor: hasUnreadPrivateMessages
                  ? const Color(0xFFFFF2B3)
                  : Colors.white,
              side: BorderSide(
                color: hasUnreadPrivateMessages
                    ? const Color(0xFFF7DE77)
                    : Colors.white.withValues(alpha: 0.14),
                width: hasUnreadPrivateMessages ? 1.5 : 1,
              ),
              backgroundColor: hasUnreadPrivateMessages
                  ? const Color(0xFFF7DE77).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(vertical: 0),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: Icon(
              hasUnreadPrivateMessages
                  ? Icons.mark_email_unread_rounded
                  : Icons.mail_outline_rounded,
              size: 16,
            ),
            label: Text(hasUnreadPrivateMessages ? 'Inbox • New' : 'Inbox'),
          ),
        ),
      );
    }

    return Expanded(
      child: ValueListenableBuilder<int>(
        valueListenable:
            CommunityUnreadPrivateMessageService.privateInboxSeenVersion,
        builder: (context, _, __) {
          if (currentUid.isEmpty) {
            return buildButton(hasUnreadPrivateMessages: false);
          }

          return StreamBuilder<bool>(
            stream: CommunityUnreadPrivateMessageService
                .hasUnreadPrivateMessagesStream(currentUid),
            builder: (context, snapshot) {
              return buildButton(
                hasUnreadPrivateMessages: snapshot.data == true,
              );
            },
          );
        },
      ),
    );
  }


  Widget _buildFriendRequestsButton() {
    final currentUid =
        (FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid).trim();

    Widget buildButton({required bool hasPendingFriendRequests}) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: hasPendingFriendRequests
              ? [
                  BoxShadow(
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.72),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            onPressed: _openFriendRequestsPage,
            style: OutlinedButton.styleFrom(
              foregroundColor: hasPendingFriendRequests
                  ? const Color(0xFFFFF2B3)
                  : Colors.white,
              side: BorderSide(
                color: hasPendingFriendRequests
                    ? const Color(0xFFF7DE77)
                    : Colors.white.withValues(alpha: 0.14),
                width: hasPendingFriendRequests ? 1.5 : 1,
              ),
              backgroundColor: hasPendingFriendRequests
                  ? const Color(0xFFF7DE77).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(vertical: 0),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: Icon(
              hasPendingFriendRequests
                  ? Icons.person_add_alt_1_rounded
                  : Icons.person_add_alt_1_outlined,
              size: 16,
            ),
            label: Text(hasPendingFriendRequests ? 'Requests • New' : 'Requests'),
          ),
        ),
      );
    }

    return Expanded(
      child: currentUid.isEmpty
          ? buildButton(hasPendingFriendRequests: false)
          : StreamBuilder(
              stream: FriendService.incomingRequestsStream(currentUid),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? const [];
                return buildButton(
                  hasPendingFriendRequests: requests.isNotEmpty,
                );
              },
            ),
    );
  }

  Widget _buildHeaderCard({required bool hasNewPosts}) {
    final showingArchive = _section == 'Admin archive';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF173A78), Color(0xFF0F2759)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF7DE77).withValues(alpha: 0.24),
                    ),
                  ),
                  child: Icon(
                    showingArchive ? Icons.archive_outlined : Icons.forum_rounded,
                    color: const Color(0xFFF7DE77),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    showingArchive ? 'Admin post archive' : 'Community forum',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (hasNewPosts && !showingArchive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7DE77).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Color(0xFFF7DE77),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPrivateInboxButton(),
                const SizedBox(width: 6),
                _buildFriendRequestsButton(),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: showingArchive
                          ? null
                          : () => _openCreatePostSheet(
                                initialPostType: _section == 'Discussions'
                                    ? 'Thread'
                                    : null,
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7DE77),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      icon: Icon(
                        showingArchive
                            ? Icons.archive_outlined
                            : _section == 'Discussions'
                                ? Icons.forum_outlined
                                : Icons.add_comment_outlined,
                        size: 16,
                      ),
                      label: Text(
                        showingArchive
                            ? 'Archive'
                            : _section == 'Discussions'
                                ? 'Start thread'
                                : 'Post',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TradeSafetyMiniBanner(onTap: _openTradeSafetyGuide),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _openBlockedUsersPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: const Icon(Icons.block_outlined, size: 16),
                label: Text(
                  'Blocked users${_blockedUserIds.isEmpty ? '' : ' (${_blockedUserIds.length})'}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CommunitySectionTab(
                    label: 'Marketplace',
                    selected: _section == 'Marketplace',
                    onTap: () => setState(() => _section = 'Marketplace'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CommunitySectionTab(
                    label: 'Discussions',
                    selected: _section == 'Discussions',
                    onTap: () => setState(() => _section = 'Discussions'),
                  ),
                ),
                if (_isAdminOrModerator) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CommunitySectionTab(
                      label: 'Archive',
                      selected: showingArchive,
                      onTap: () => setState(() => _section = 'Admin archive'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_section == 'Marketplace')
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _marketplaceFilterSummary,
                      style: const TextStyle(
                        color: Color(0xFFC8D4F0),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _openMarketplaceFiltersSheet,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF7DE77),
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(42),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text(
                              'Adjust filters',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        if (_hasActiveMarketplaceFilters) ...[
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _filter = 'All';
                              _marketStatusFilter = 'All';
                              _areaFilter = 'All';
                            }),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFFF2B3),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text(
                              'Clear',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              )
            else if (showingArchive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB13B59).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFB13B59).withValues(alpha: 0.36),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Search deleted posts by post title, user or business name, or deleted date.',
                      style: TextStyle(
                        color: Color(0xFFFFCDD2),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _archiveSearchController,
                      focusNode: _archiveSearchFocusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: const Color(0xFFF7DE77),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search title, user or business name',
                        hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFFF7DE77),
                          size: 20,
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _archiveSearchController,
                          builder: (context, value, _) {
                            if (value.text.trim().isEmpty) {
                              return const SizedBox(width: 48, height: 48);
                            }

                            return IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFC8D4F0),
                                size: 20,
                              ),
                              onPressed: () {
                                _archiveSearchDebounce?.cancel();
                                setState(() {
                                  _archiveSearchController.clear();
                                  _archiveSearchQuery = '';
                                });
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!context.mounted) return;
                                  _archiveSearchFocusNode.requestFocus();
                                });
                              },
                            );
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFF102754),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: Color(0xFF3F5C96),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: Color(0xFF3F5C96),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: Color(0xFFF7DE77),
                            width: 1.4,
                          ),
                        ),
                      ),
                      onChanged: _handleArchiveSearchChanged,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickArchiveDeletedDateFilter,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF7DE77),
                              side: const BorderSide(color: Color(0xFFF7DE77)),
                              minimumSize: const Size.fromHeight(42),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(Icons.calendar_month_outlined, size: 18),
                            label: Text(
                              _archiveDeletedDateFilter == null
                                  ? 'Deleted date'
                                  : _formatArchiveDate(_archiveDeletedDateFilter!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        if (_hasActiveArchiveFilters) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _clearArchiveFilters,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            label: const Text(
                              'Clear',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: const Text(
                  'Discussion threads stay separate from sale and swap listings so it is easier to chat, ask questions, and meet new collectors.',
                  style: TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    final areaLabel = _areaFilter == 'All' ? '' : ' in ${_areaLabelForKey(_areaFilter)}';
    final emptyTitle = _section == 'Admin archive'
        ? (_hasActiveArchiveFilters ? 'No archived posts found' : 'No archived posts yet')
        : _section == 'Discussions'
            ? 'No discussion threads yet'
            : _marketStatusFilter == 'All'
                ? 'No listings match this view yet'
                : 'No ${_marketStatusFilter.toLowerCase()} listings yet';
    final emptyMessage = _section == 'Admin archive'
        ? (_hasActiveArchiveFilters
            ? 'Try another title, user/business name, or deleted date.'
            : 'When users delete completed posts, they will disappear from the community feed and appear here for admins.')
        : _section == 'Discussions'
            ? 'Start a thread to chat about cards, collecting, trades, and making friends.'
            : _areaFilter == 'All'
                ? 'Create a professional swap or sale listing with status, condition, and delivery details.'
                : 'No matching listings were found$areaLabel. Try another county or clear the area filter.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(
            _section == 'Admin archive'
                ? Icons.archive_outlined
                : _section == 'Discussions'
                    ? Icons.forum_outlined
                    : Icons.storefront_outlined,
            color: const Color(0xFFF7DE77),
            size: 36,
          ),
          const SizedBox(height: 14),
          Text(
            emptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _postsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                !_loadedLastSeen) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load community posts. Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _markVisitSeenIfNeeded();
            });

            final docs = snapshot.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            final feedDocs = docs
                .where((doc) => !_postIsArchivedForAdmin(doc.data()))
                .toList();
            final archivedDocs = docs
                .where((doc) => _postIsArchivedForAdmin(doc.data()))
                .toList();
            final sourceDocs = _section == 'Admin archive' && _isAdminOrModerator
                ? archivedDocs
                : feedDocs;

            final archiveDataByPostId = <String, Map<String, dynamic>>{
              for (final doc in archivedDocs) doc.id: doc.data(),
            };

            final areaKeysByPostId = <String, String>{
              for (final doc in sourceDocs) doc.id: _postAreaKeyFromData(doc.data()),
            };

            final allPosts = sourceDocs
                .map(_safePostFromDoc)
                .whereType<CommunityPost>()
                .toList();

            final visiblePosts = _visiblePosts(allPosts, areaKeysByPostId);
            final posts = _section == 'Admin archive' && _isAdminOrModerator
                ? visiblePosts
                    .where(
                      (post) => _archivePostMatchesFilters(
                        post,
                        archiveDataByPostId[post.id],
                      ),
                    )
                    .toList()
                : visiblePosts;
            final feedPosts = feedDocs
                .map(_safePostFromDoc)
                .whereType<CommunityPost>()
                .toList();
            final hasNewPosts = _lastSeenAtMs != null &&
                feedPosts.any((post) => post.createdAtMs > (_lastSeenAtMs ?? 0));

            int? deletedAtMsForPost(CommunityPost post) {
              return _deletedAtMsFromArchiveData(archiveDataByPostId[post.id]);
            }

            Future<void> openPost(CommunityPost post) async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CommunityPostThreadPage(
                    post: post,
                    currentProfile: widget.profile,
                  ),
                ),
              );
            }

            Widget buildPostCard(CommunityPost post) {
              final isNew =
                  _lastSeenAtMs != null && post.createdAtMs > (_lastSeenAtMs ?? 0);

              return ValueListenableBuilder<bool>(
                valueListenable: ProStatusService.isProNotifier,
                builder: (context, isProActive, _) {
                  final isOwnPost = post.authorId == currentUid;
                  final isFeatureBusy = _featureBusyPostIds.contains(post.id);
                  final viewingArchive = _section == 'Admin archive';

                  return CommunityPostCard(
                    post: post,
                    currentProfile: widget.profile,
                    canEdit: !viewingArchive && (isOwnPost || _isAdminOrModerator),
                    canMessage: !viewingArchive &&
                        post.authorId.isNotEmpty && post.authorId != currentUid,
                    isNew: isNew,
                    compact: true,
                    canUserFeature:
                        !viewingArchive && isOwnPost && isProActive && !isFeatureBusy,
                    canAdminFeature:
                        !viewingArchive && _isAdminOrModerator && !isFeatureBusy,
                    onToggleUserFeatured:
                        !viewingArchive && isOwnPost && isProActive && !isFeatureBusy
                            ? () => _toggleUserFeaturedPost(post)
                            : null,
                    onToggleAdminFeatured:
                        !viewingArchive && _isAdminOrModerator && !isFeatureBusy
                            ? () => _toggleAdminFeaturedPost(post)
                            : null,
                    onEdit: () => _openEditPostSheet(post),
                    onDelete: () => _deletePost(post),
                    onMessage: () => _openPrivateMessageForPost(post),
                    onReport: viewingArchive || post.authorId == currentUid
                        ? null
                        : () => _reportPost(post),
                    onBlock: viewingArchive || post.authorId == currentUid
                        ? null
                        : () => _blockCommunityMember(
                              memberId: post.authorId,
                              memberName: post.authorName,
                            ),
                    onSetMarketStatus: !viewingArchive && isOwnPost
                        ? (status) => _updateMarketStatus(post, status)
                        : null,
                    onBump: !viewingArchive && isOwnPost && post.isMarketplace
                        ? () => _bumpPost(post)
                        : null,
                    onAuthorTap: post.authorId.trim().isEmpty ||
                            post.authorId == currentUid
                        ? null
                        : () => _openCommunityMemberSheet(post),
                    onOpen: () => openPost(post),
                  );
                },
              );
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _buildHeaderCard(hasNewPosts: hasNewPosts),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                if (posts.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverToBoxAdapter(child: _buildEmptyStateCard()),
                  )
                else if (_section == 'Admin archive' && _isAdminOrModerator)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: EdgeInsets.only(
                            bottom: index == posts.length - 1 ? 0 : 6,
                          ),
                          child: _ArchivePostListTile(
                            post: posts[index],
                            deletedAtMs: deletedAtMsForPost(posts[index]),
                            onOpen: () => openPost(posts[index]),
                          ),
                        ),
                        childCount: posts.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.58,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => buildPostCard(posts[index]),
                        childCount: posts.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}


class _ArchivePostListTile extends StatelessWidget {
  const _ArchivePostListTile({
    required this.post,
    required this.deletedAtMs,
    required this.onOpen,
  });

  final CommunityPost post;
  final int? deletedAtMs;
  final VoidCallback onOpen;

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String get _deletedDateText {
    final deletedMs = deletedAtMs;
    if (deletedMs == null || deletedMs <= 0) {
      return 'Deleted date unavailable';
    }

    return 'Deleted ${_formatDate(DateTime.fromMillisecondsSinceEpoch(deletedMs))}';
  }

  @override
  Widget build(BuildContext context) {
    final authorName = post.authorName.trim().isEmpty
        ? 'Unknown user'
        : post.authorName.trim();

    return Material(
      color: const Color(0xFF102754),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3F5C96)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFB13B59).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFFFCDD2),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'By $authorName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF7DE77),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _deletedDateText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC8D4F0),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFF7DE77),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunitySectionTab extends StatelessWidget {
  const _CommunitySectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected
        ? const Color(0xFFF7DE77)
        : const Color(0xFF102754);
    final foregroundColor = selected ? Colors.black : Colors.white;
    final borderColor = selected
        ? const Color(0xFFF7DE77)
        : const Color(0xFF3F5C96);

    return SizedBox(
      height: 48,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor, width: 1.3),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
