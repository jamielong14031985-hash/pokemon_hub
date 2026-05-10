import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user_profile.dart';
import '../models/community_models.dart';
import '../services/community_image_services.dart';
import '../services/community_safety_service.dart';
import '../services/friend_service.dart';
import '../services/community_unread_private_message_service.dart';
import '../services/pro_status_service.dart';
import '../utils/community_dialog_helpers.dart';
import '../utils/community_market_helpers.dart';
import '../utils/community_private_helpers.dart';
import '../widgets/community_active_filter_pill.dart';
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

  Stream<QuerySnapshot<Map<String, dynamic>>> get _postsStream =>
      FirebaseFirestore.instance
          .collection('community_posts')
          .orderBy('createdAtMs', descending: true)
          .snapshots();

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

  CommunityReply? _safeReplyFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return CommunityReply.fromDoc(doc);
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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102754),
        title: const Text('Delete post', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove the post and all replies from the community forum.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final postRef =
          FirebaseFirestore.instance.collection('community_posts').doc(post.id);
      final replies = await postRef.collection('replies').get();
      final replyImageRefs = replies.docs
          .map(_safeReplyFromDoc)
          .whereType<CommunityReply>()
          .map((reply) => reply.imageBase64)
          .whereType<String>()
          .toList();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in replies.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(postRef);
      await batch.commit();

      for (final imageRef in <String>[...post.imageBase64List, ...replyImageRefs]) {
        unawaited(FirebaseImageStorageService.deleteByDownloadUrl(imageRef));
      }

      _showMessage('Post deleted.');
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
    final unblockedPosts = posts
        .where(
          (post) =>
              post.authorId == currentUid || !_blockedUserIds.contains(post.authorId),
        )
        .toList();

    final sectionPosts = _section == 'Discussions'
        ? unblockedPosts.where((post) => post.isDiscussion).toList()
        : unblockedPosts.where((post) => post.isMarketplace).toList();

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
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Color(0xFFF7DE77),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Community forum',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (hasNewPosts)
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
                      onPressed: () => _openCreatePostSheet(
                        initialPostType:
                            _section == 'Discussions' ? 'Thread' : null,
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
                        _section == 'Discussions'
                            ? Icons.forum_outlined
                            : Icons.add_comment_outlined,
                        size: 16,
                      ),
                      label:
                          Text(_section == 'Discussions' ? 'Start thread' : 'Post'),
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
                  child: CommunityFilterChip(
                    label: 'Marketplace',
                    selected: _section == 'Marketplace',
                    minWidth: 140,
                    onTap: () => setState(() {
                      _section = 'Marketplace';
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CommunityFilterChip(
                    label: 'Discussions',
                    selected: _section == 'Discussions',
                    minWidth: 140,
                    onTap: () => setState(() => _section = 'Discussions'),
                  ),
                ),
              ],
            ),
            if (_section == 'Marketplace') ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF183A78),
                      Color(0xFF102754),
                      Color(0xFF0B214F),
                    ],
                  ),
                  border: Border.all(
                    color: _hasActiveMarketplaceFilters
                        ? const Color(0xFFF7DE77).withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF7DE77)
                                .withValues(alpha: 0.14),
                            border: Border.all(
                              color: const Color(0xFFF7DE77)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            _hasActiveMarketplaceFilters
                                ? Icons.filter_alt_rounded
                                : Icons.tune_rounded,
                            color: const Color(0xFFF7DE77),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Marketplace filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _marketplaceFilterSummary,
                                style: const TextStyle(
                                  color: Color(0xFFC8D4F0),
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _hasActiveMarketplaceFilters
                                ? const Color(0xFFF7DE77)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _hasActiveMarketplaceFilters
                                  ? const Color(0xFFF7DE77)
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            _hasActiveMarketplaceFilters ? 'Active' : 'All',
                            style: TextStyle(
                              color: _hasActiveMarketplaceFilters
                                  ? Colors.black
                                  : const Color(0xFFE4ECFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_hasActiveMarketplaceFilters) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_filter != 'All')
                            CommunityActiveFilterPill(
                              label: _filter,
                              onRemove: () => setState(() => _filter = 'All'),
                            ),
                          if (_marketStatusFilter != 'All')
                            CommunityActiveFilterPill(
                              label: _marketStatusFilter,
                              onRemove: () => setState(
                                () => _marketStatusFilter = 'All',
                              ),
                            ),
                          if (_areaFilter != 'All')
                            CommunityActiveFilterPill(
                              label: _areaLabelForKey(_areaFilter),
                              onRemove: () => setState(() => _areaFilter = 'All'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      const Text(
                        'Use filters to quickly find swaps, sales, wanted posts, available listings, pending deals, sold items, or local county listings.',
                        style: TextStyle(
                          color: Color(0xFFAFC0E6),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _openMarketplaceFiltersSheet,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF7DE77),
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
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
                          SizedBox(
                            height: 46,
                            child: TextButton.icon(
                              onPressed: () => setState(() {
                                _filter = 'All';
                                _marketStatusFilter = 'All';
                                _areaFilter = 'All';
                              }),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFFF2B3),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text(
                                'Clear',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    final areaLabel = _areaFilter == 'All' ? '' : ' in ${_areaLabelForKey(_areaFilter)}';
    final emptyTitle = _section == 'Discussions'
        ? 'No discussion threads yet'
        : _marketStatusFilter == 'All'
            ? 'No listings match this view yet'
            : 'No ${_marketStatusFilter.toLowerCase()} listings yet';
    final emptyMessage = _section == 'Discussions'
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
            _section == 'Discussions'
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

            final areaKeysByPostId = <String, String>{
              for (final doc in docs) doc.id: _postAreaKeyFromData(doc.data()),
            };

            final allPosts = docs
                .map(_safePostFromDoc)
                .whereType<CommunityPost>()
                .toList();

            final posts = _visiblePosts(allPosts, areaKeysByPostId);
            final hasNewPosts = _lastSeenAtMs != null &&
                allPosts.any((post) => post.createdAtMs > (_lastSeenAtMs ?? 0));

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              itemCount: posts.isEmpty ? 2 : posts.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeaderCard(hasNewPosts: hasNewPosts);
                }

                if (posts.isEmpty) {
                  return _buildEmptyStateCard();
                }

                final post = posts[index - 1];
                final isNew =
                    _lastSeenAtMs != null && post.createdAtMs > (_lastSeenAtMs ?? 0);

                return ValueListenableBuilder<bool>(
                  valueListenable: ProStatusService.isProNotifier,
                  builder: (context, isProActive, _) {
                    final isOwnPost = post.authorId == currentUid;
                    final isFeatureBusy = _featureBusyPostIds.contains(post.id);

                    return CommunityPostCard(
                      post: post,
                      currentProfile: widget.profile,
                      canEdit: isOwnPost || _isAdminOrModerator,
                      canMessage:
                          post.authorId.isNotEmpty && post.authorId != currentUid,
                      isNew: isNew,
                      canUserFeature: isOwnPost && isProActive && !isFeatureBusy,
                      canAdminFeature: _isAdminOrModerator && !isFeatureBusy,
                      onToggleUserFeatured:
                          isOwnPost && isProActive && !isFeatureBusy
                              ? () => _toggleUserFeaturedPost(post)
                              : null,
                      onToggleAdminFeatured: _isAdminOrModerator && !isFeatureBusy
                          ? () => _toggleAdminFeaturedPost(post)
                          : null,
                      onEdit: () => _openEditPostSheet(post),
                      onDelete: () => _deletePost(post),
                      onMessage: () => _openPrivateMessageForPost(post),
                      onReport: post.authorId == currentUid
                          ? null
                          : () => _reportPost(post),
                      onBlock: post.authorId == currentUid
                          ? null
                          : () => _blockCommunityMember(
                                memberId: post.authorId,
                                memberName: post.authorName,
                              ),
                      onSetMarketStatus: isOwnPost
                          ? (status) => _updateMarketStatus(post, status)
                          : null,
                      onBump: isOwnPost && post.isMarketplace
                          ? () => _bumpPost(post)
                          : null,
                      onAuthorTap: post.authorId.trim().isEmpty ||
                              post.authorId == currentUid
                          ? null
                          : () => _openCommunityMemberSheet(post),
                      onOpen: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CommunityPostThreadPage(
                              post: post,
                              currentProfile: widget.profile,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
