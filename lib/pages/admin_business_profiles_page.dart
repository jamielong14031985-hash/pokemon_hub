import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/business_pro_request.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import 'admin_business_pro_requests_page.dart';
import 'business_profile_editor_page.dart';

class AdminBusinessProfilesPage extends StatefulWidget {
  const AdminBusinessProfilesPage({super.key});

  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);
  static const Color _warningColor = Color(0xFFFBBF24);
  static const Color _dangerColor = Color(0xFFFB7185);

  @override
  State<AdminBusinessProfilesPage> createState() =>
      _AdminBusinessProfilesPageState();
}

class _AdminBusinessProfilesPageState extends State<AdminBusinessProfilesPage> {
  final TextEditingController _searchController = TextEditingController();

  static const Color _backgroundColor = AdminBusinessProfilesPage._backgroundColor;
  static const Color _cardColor = AdminBusinessProfilesPage._cardColor;
  static const Color _fieldColor = AdminBusinessProfilesPage._fieldColor;
  static const Color _borderColor = AdminBusinessProfilesPage._borderColor;
  static const Color _goldColor = AdminBusinessProfilesPage._goldColor;
  static const Color _softTextColor = AdminBusinessProfilesPage._softTextColor;
  static const Color _dangerColor = AdminBusinessProfilesPage._dangerColor;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _searchTextForProfile(BusinessProfile profile) {
    return [
      profile.businessName,
      profile.linkedShopName,
      profile.town,
      profile.county,
      profile.ownerUid,
      profile.website,
      profile.phone,
      profile.status,
    ].join(' ').toLowerCase();
  }

  List<BusinessProfile> _filterProfiles(List<BusinessProfile> profiles) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return profiles;

    return profiles.where((profile) {
      return _searchTextForProfile(profile).contains(query);
    }).toList();
  }


  Widget _buildProRequestsCard(BusinessProfileService service) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StreamBuilder<List<BusinessProRequest>>(
        stream: service.watchAllBusinessProRequests(),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? const <BusinessProRequest>[];
          final pendingCount =
              requests.where((request) => request.isPending).length;

          final subtitle = snapshot.hasError
              ? 'Could not load requests: ${snapshot.error}'
              : requests.isEmpty
                  ? 'No Business Pro requests yet. Tap to open the inbox.'
                  : '${requests.length} total request${requests.length == 1 ? '' : 's'} • $pendingCount pending';

          return Material(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminBusinessProRequestsPage(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: pendingCount > 0 ? _goldColor : _borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _fieldColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _borderColor),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            color: _goldColor,
                            size: 27,
                          ),
                        ),
                        if (pendingCount > 0)
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _dangerColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                pendingCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Business Pro Requests',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: _softTextColor,
                              height: 1.35,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: _goldColor,
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

  Widget _buildSearchBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: _goldColor,
        decoration: InputDecoration(
          labelText: 'Search businesses',
          hintText: 'Search by business name, shop, town, county or owner',
          labelStyle: const TextStyle(color: _softTextColor),
          hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
          floatingLabelStyle: const TextStyle(
            color: _goldColor,
            fontWeight: FontWeight.w900,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: _softTextColor,
          ),
          suffixIcon: _searchController.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear, color: _softTextColor),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
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
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = BusinessProfileService();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Business Admin'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Business Pro requests',
            icon: const Icon(Icons.mark_email_unread_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminBusinessProRequestsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<bool>(
        stream: service.watchCurrentUserIsAdminOrModerator(),
        builder: (context, adminSnapshot) {
          if (adminSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _goldColor),
            );
          }

          if (adminSnapshot.data != true) {
            return const _NoAccessState();
          }

          return StreamBuilder<List<BusinessProfile>>(
            stream: service.watchAllBusinessProfiles(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorState(error: snapshot.error.toString());
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _goldColor),
                );
              }

              final allProfiles = snapshot.data ?? const <BusinessProfile>[];
              final profiles = _filterProfiles(allProfiles);
              final query = _searchController.text.trim();

              if (allProfiles.isEmpty) {
                return const _EmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                itemCount: profiles.length + 3,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildSearchBox();
                  }

                  if (index == 1) {
                    return _buildProRequestsCard(service);
                  }

                  if (index == 2) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _goldColor.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _goldColor),
                        ),
                        child: Text(
                          query.isEmpty
                              ? '${allProfiles.length} business profile${allProfiles.length == 1 ? '' : 's'} found. Admins can edit, delete, and toggle Business Pro premium access here.'
                              : '${profiles.length} result${profiles.length == 1 ? '' : 's'} for "$query".',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    );
                  }

                  if (profiles.isEmpty) {
                    return const _NoSearchResultsState();
                  }

                  final profile = profiles[index - 3];
                  return _BusinessAdminCard(profile: profile);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _BusinessAdminCard extends StatelessWidget {
  const _BusinessAdminCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final isApproved = profile.status == 'approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminBusinessProfilesPage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: profile.premiumActive
              ? AdminBusinessProfilesPage._goldColor
              : AdminBusinessProfilesPage._borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BusinessHeader(profile: profile, isApproved: isApproved),
          const SizedBox(height: 12),
          _DetailLine(
            icon: Icons.email_outlined,
            text: profile.ownerUid.isEmpty
                ? 'Owner not saved'
                : 'Owner UID: ${profile.ownerUid}',
          ),
          if (profile.displayLocation.isNotEmpty)
            _DetailLine(
              icon: Icons.place_outlined,
              text: profile.displayLocation,
            ),
          _DetailLine(
            icon: Icons.map_outlined,
            text: profile.linkedShopName.isEmpty
                ? 'No linked TCG shop'
                : 'Linked shop: ${profile.linkedShopName}',
          ),
          const SizedBox(height: 12),
          _PremiumControls(profile: profile),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminBusinessProfilesPage._goldColor,
                    side: const BorderSide(
                      color: AdminBusinessProfilesPage._goldColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BusinessProfileEditorPage(
                          profile: profile,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminBusinessProfilesPage._dangerColor,
                    side: const BorderSide(
                      color: AdminBusinessProfilesPage._dangerColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onPressed: () => _confirmDelete(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AdminBusinessProfilesPage._cardColor,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          contentTextStyle: const TextStyle(
            color: AdminBusinessProfilesPage._softTextColor,
            height: 1.35,
          ),
          title: const Text('Delete business profile?'),
          content: Text(
            'This will permanently delete "${profile.businessName}". This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AdminBusinessProfilesPage._dangerColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await BusinessProfileService().deleteBusinessProfile(profile.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Business profile deleted.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete profile: $error')),
      );
    }
  }
}

class _BusinessHeader extends StatelessWidget {
  const _BusinessHeader({
    required this.profile,
    required this.isApproved,
  });

  final BusinessProfile profile;
  final bool isApproved;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AdminBusinessProfilesPage._fieldColor,
          child: profile.logoUrl.isEmpty
              ? const Icon(
                  Icons.storefront_outlined,
                  color: AdminBusinessProfilesPage._goldColor,
                )
              : ClipOval(
                  child: Image.network(
                    profile.logoUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.storefront_outlined,
                        color: AdminBusinessProfilesPage._goldColor,
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.businessName.isEmpty
                    ? 'Unnamed business'
                    : profile.businessName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _Pill(
                    text: isApproved ? 'Active business' : profile.status,
                    color: isApproved
                        ? AdminBusinessProfilesPage._successColor
                        : AdminBusinessProfilesPage._warningColor,
                    textColor: Colors.black,
                  ),
                  if (profile.verified)
                    const _Pill(
                      text: 'Verified',
                      color: AdminBusinessProfilesPage._goldColor,
                      textColor: AdminBusinessProfilesPage._backgroundColor,
                    ),
                  if (profile.premiumIsActive)
                    const _Pill(
                      text: 'Business Pro',
                      color: AdminBusinessProfilesPage._goldColor,
                      textColor: AdminBusinessProfilesPage._backgroundColor,
                    ),
                  if (profile.featuredShopEnabled)
                    const _Pill(
                      text: 'Featured shop',
                      color: AdminBusinessProfilesPage._goldColor,
                      textColor: AdminBusinessProfilesPage._backgroundColor,
                    ),
                  if (profile.autoFeaturePosts)
                    const _Pill(
                      text: 'Featured posts',
                      color: AdminBusinessProfilesPage._goldColor,
                      textColor: AdminBusinessProfilesPage._backgroundColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumControls extends StatelessWidget {
  const _PremiumControls({
    required this.profile,
  });

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final premiumEnabled = profile.premiumActive;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminBusinessProfilesPage._fieldColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: premiumEnabled
              ? AdminBusinessProfilesPage._goldColor
              : AdminBusinessProfilesPage._borderColor,
        ),
      ),
      child: Column(
        children: [
          _AdminSwitchTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Business Pro premium',
            subtitle: premiumEnabled
                ? 'Premium is active for this business.'
                : 'Turn this on to give this business premium access.',
            value: premiumEnabled,
            activeColor: AdminBusinessProfilesPage._goldColor,
            onChanged: (value) => _togglePremium(context, value),
          ),
          const Divider(
            color: AdminBusinessProfilesPage._borderColor,
            height: 1,
          ),
          _PremiumDateSummaryTile(
            title: 'Pro dates and admin notes',
            subtitle: _expirySubtitle(),
            startedAt: _formatDate(profile.premiumStartedAt?.toDate()),
            expiresAt: _formatDate(profile.premiumExpiresAt?.toDate()),
            notes: profile.premiumAdminNotes,
            onTap: () => _openPremiumEditor(context),
          ),
          const Divider(
            color: AdminBusinessProfilesPage._borderColor,
            height: 1,
          ),
          _AdminSwitchTile(
            icon: Icons.star_border_rounded,
            title: 'Featured shop on map',
            subtitle: premiumEnabled
                ? 'Show this business as a featured shop if it has a linked shop.'
                : 'Requires Business Pro premium first.',
            value: premiumEnabled && profile.featuredShopEnabled,
            activeColor: AdminBusinessProfilesPage._goldColor,
            onChanged: premiumEnabled
                ? (value) => _toggleFeaturedShop(context, value)
                : null,
          ),
          const Divider(
            color: AdminBusinessProfilesPage._borderColor,
            height: 1,
          ),
          _AdminSwitchTile(
            icon: Icons.campaign_outlined,
            title: 'Automatically feature posts',
            subtitle: premiumEnabled
                ? 'Business community posts can be automatically featured.'
                : 'Requires Business Pro premium first.',
            value: premiumEnabled && profile.autoFeaturePosts,
            activeColor: AdminBusinessProfilesPage._goldColor,
            onChanged: premiumEnabled
                ? (value) => _toggleAutoFeaturePosts(context, value)
                : null,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not set';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }

  String _expirySubtitle() {
    if (!profile.premiumActive) return 'Business Pro is currently off.';
    if (profile.premiumExpiresAt == null) return 'No expiry date set.';
    if (profile.premiumIsExpired) {
      return 'Expired on ${_formatDate(profile.premiumExpiresAt?.toDate())}.';
    }
    if (profile.premiumExpiresSoon) {
      return 'Expires soon: ${_formatDate(profile.premiumExpiresAt?.toDate())}.';
    }
    return 'Expires: ${_formatDate(profile.premiumExpiresAt?.toDate())}.';
  }

  Future<void> _openPremiumEditor(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final notesController =
        TextEditingController(text: profile.premiumAdminNotes);

    var premiumActive = profile.premiumActive;
    var approved = profile.status == 'approved';
    var verified = profile.verified;
    var featuredShopEnabled = profile.featuredShopEnabled;
    var autoFeaturePosts = profile.autoFeaturePosts;
    var startedAt = profile.premiumStartedAt?.toDate();
    var expiresAt = profile.premiumExpiresAt?.toDate();

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          return StatefulBuilder(
            builder: (context, setState) {
              Future<void> pickStartDate() async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: startedAt ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );

                if (picked == null || !context.mounted) return;
                setState(() => startedAt = picked);
              }

              Future<void> pickExpiryDate() async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );

                if (picked == null || !context.mounted) return;
                setState(() => expiresAt = picked);
              }

              Future<void> save() async {
                try {
                  await BusinessProfileService().adminUpdateBusinessPremium(
                    businessProfileId: profile.id,
                    approved: approved,
                    verified: verified,
                    premiumActive: premiumActive,
                    featuredShopEnabled:
                        premiumActive ? featuredShopEnabled : false,
                    autoFeaturePosts:
                        premiumActive ? autoFeaturePosts : false,
                    premiumStartedAt: startedAt == null
                        ? null
                        : Timestamp.fromDate(startedAt!),
                    premiumExpiresAt: expiresAt == null
                        ? null
                        : Timestamp.fromDate(expiresAt!),
                    premiumAdminNotes: notesController.text.trim(),
                  );

                  if (!context.mounted) return;
                  Navigator.of(context).pop(true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not save Pro settings: $error'),
                    ),
                  );
                }
              }

              return Scaffold(
                backgroundColor: AdminBusinessProfilesPage._backgroundColor,
                appBar: AppBar(
                  title: const Text('Manage Business Pro'),
                  backgroundColor: AdminBusinessProfilesPage._backgroundColor,
                  foregroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                ),
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AdminBusinessProfilesPage._cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AdminBusinessProfilesPage._borderColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.businessName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Set Pro status, expiry dates, featured access and internal admin notes.',
                              style: TextStyle(
                                color: AdminBusinessProfilesPage._softTextColor,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor:
                                  AdminBusinessProfilesPage._goldColor,
                              title: const Text(
                                'Business Pro active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: const Text(
                                'When off, Pro placements and Pro tools are disabled.',
                                style: TextStyle(
                                  color: AdminBusinessProfilesPage._softTextColor,
                                ),
                              ),
                              value: premiumActive,
                              onChanged: (value) {
                                setState(() {
                                  premiumActive = value;
                                  if (value && startedAt == null) {
                                    startedAt = DateTime.now();
                                  }
                                  if (!value) {
                                    featuredShopEnabled = false;
                                    autoFeaturePosts = false;
                                  }
                                });
                              },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor:
                                  AdminBusinessProfilesPage._goldColor,
                              title: const Text(
                                'Approved',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              value: approved,
                              onChanged: (value) {
                                setState(() => approved = value);
                              },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor:
                                  AdminBusinessProfilesPage._goldColor,
                              title: const Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              value: verified,
                              onChanged: (value) {
                                setState(() => verified = value);
                              },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor:
                                  AdminBusinessProfilesPage._goldColor,
                              title: const Text(
                                'Featured map shop',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              value: premiumActive && featuredShopEnabled,
                              onChanged: premiumActive
                                  ? (value) {
                                      setState(
                                        () => featuredShopEnabled = value,
                                      );
                                    }
                                  : null,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor:
                                  AdminBusinessProfilesPage._goldColor,
                              title: const Text(
                                'Auto-feature community posts',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              value: premiumActive && autoFeaturePosts,
                              onChanged: premiumActive
                                  ? (value) {
                                      setState(
                                        () => autoFeaturePosts = value,
                                      );
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _PremiumDateButton(
                              label: 'Start date',
                              value: startedAt == null
                                  ? 'Not set'
                                  : _formatDate(startedAt),
                              icon: Icons.play_circle_outline,
                              onPressed: pickStartDate,
                              onClear: startedAt == null
                                  ? null
                                  : () => setState(() => startedAt = null),
                            ),
                            const SizedBox(height: 10),
                            _PremiumDateButton(
                              label: 'Expiry date',
                              value: expiresAt == null
                                  ? 'No expiry date'
                                  : _formatDate(expiresAt),
                              icon: Icons.event_busy_outlined,
                              onPressed: pickExpiryDate,
                              onClear: expiresAt == null
                                  ? null
                                  : () => setState(() => expiresAt = null),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: notesController,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: 500,
                              style: const TextStyle(color: Colors.white),
                              cursorColor: AdminBusinessProfilesPage._goldColor,
                              decoration: InputDecoration(
                                labelText: 'Admin notes',
                                hintText:
                                    'Payment notes, renewal details, invoice, etc.',
                                labelStyle: const TextStyle(
                                  color:
                                      AdminBusinessProfilesPage._softTextColor,
                                ),
                                hintStyle: const TextStyle(
                                  color: Color(0xFFAFC0E6),
                                ),
                                filled: true,
                                fillColor: AdminBusinessProfilesPage._fieldColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color:
                                        AdminBusinessProfilesPage._borderColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color:
                                        AdminBusinessProfilesPage._borderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: AdminBusinessProfilesPage._goldColor,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      AdminBusinessProfilesPage._goldColor,
                                  foregroundColor:
                                      AdminBusinessProfilesPage._backgroundColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.save_outlined),
                                label: const Text(
                                  'Save Pro settings',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                onPressed: save,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    notesController.dispose();

    if (saved == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Business Pro settings saved.')),
      );
    }
  }

  Future<void> _togglePremium(BuildContext context, bool value) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await BusinessProfileService().adminUpdateBusinessPremium(
        businessProfileId: profile.id,
        approved: profile.status == 'approved',
        verified: profile.verified,
        premiumActive: value,
        featuredShopEnabled: value ? profile.featuredShopEnabled : false,
        autoFeaturePosts: value ? profile.autoFeaturePosts : false,
        premiumStartedAt: value
            ? (profile.premiumStartedAt ?? Timestamp.now())
            : profile.premiumStartedAt,
        premiumExpiresAt: profile.premiumExpiresAt,
        premiumAdminNotes: profile.premiumAdminNotes,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Business Pro premium turned on.'
                : 'Business Pro premium turned off.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update premium: $error')),
      );
    }
  }

  Future<void> _toggleFeaturedShop(BuildContext context, bool value) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!profile.premiumActive) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Turn on Business Pro premium first.'),
        ),
      );
      return;
    }

    if (value && profile.linkedShopId.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Link this business to a TCG shop before featuring it on the map.'),
        ),
      );
      return;
    }

    try {
      await BusinessProfileService().adminUpdateBusinessPremium(
        businessProfileId: profile.id,
        approved: profile.status == 'approved',
        verified: profile.verified,
        premiumActive: profile.premiumActive,
        featuredShopEnabled: value,
        autoFeaturePosts: profile.autoFeaturePosts,
        premiumStartedAt: profile.premiumStartedAt,
        premiumExpiresAt: profile.premiumExpiresAt,
        premiumAdminNotes: profile.premiumAdminNotes,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Featured shop turned on.'
                : 'Featured shop turned off.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update featured shop: $error')),
      );
    }
  }

  Future<void> _toggleAutoFeaturePosts(BuildContext context, bool value) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!profile.premiumActive) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Turn on Business Pro premium first.'),
        ),
      );
      return;
    }

    try {
      await BusinessProfileService().adminUpdateBusinessPremium(
        businessProfileId: profile.id,
        approved: profile.status == 'approved',
        verified: profile.verified,
        premiumActive: profile.premiumActive,
        featuredShopEnabled: profile.featuredShopEnabled,
        autoFeaturePosts: value,
        premiumStartedAt: profile.premiumStartedAt,
        premiumExpiresAt: profile.premiumExpiresAt,
        premiumAdminNotes: profile.premiumAdminNotes,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Automatic featured posts turned on.'
                : 'Automatic featured posts turned off.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update featured posts: $error')),
      );
    }
  }
}


class _PremiumDateSummaryTile extends StatelessWidget {
  const _PremiumDateSummaryTile({
    required this.title,
    required this.subtitle,
    required this.startedAt,
    required this.expiresAt,
    required this.notes,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String startedAt;
  final String expiresAt;
  final String notes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasNotes = notes.trim().isNotEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.event_note_outlined,
        color: AdminBusinessProfilesPage._goldColor,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '$subtitle\nStarted: $startedAt\nExpires: $expiresAt${hasNotes ? '\nNotes: ${notes.trim()}' : ''}',
          style: const TextStyle(
            color: AdminBusinessProfilesPage._softTextColor,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AdminBusinessProfilesPage._goldColor,
      ),
      onTap: onTap,
    );
  }
}

class _PremiumDateButton extends StatelessWidget {
  const _PremiumDateButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
    required this.onClear,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminBusinessProfilesPage._fieldColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdminBusinessProfilesPage._borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: AdminBusinessProfilesPage._goldColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AdminBusinessProfilesPage._softTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear',
                  color: AdminBusinessProfilesPage._softTextColor,
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              else
                const Icon(
                  Icons.edit_calendar_outlined,
                  color: AdminBusinessProfilesPage._goldColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSwitchTile extends StatelessWidget {
  const _AdminSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeColor,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        icon,
        color: enabled
            ? activeColor
            : AdminBusinessProfilesPage._softTextColor.withValues(alpha: 0.60),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.65),
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled
              ? AdminBusinessProfilesPage._softTextColor
              : AdminBusinessProfilesPage._softTextColor.withValues(alpha: 0.55),
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AdminBusinessProfilesPage._goldColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AdminBusinessProfilesPage._softTextColor,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NoAccessState extends StatelessWidget {
  const _NoAccessState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              color: AdminBusinessProfilesPage._goldColor,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'Admin access only',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Only admins and moderators can manage all business profiles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AdminBusinessProfilesPage._softTextColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _NoSearchResultsState extends StatelessWidget {
  const _NoSearchResultsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminBusinessProfilesPage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminBusinessProfilesPage._borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_outlined,
            color: AdminBusinessProfilesPage._goldColor,
            size: 40,
          ),
          SizedBox(height: 10),
          Text(
            'No businesses match your search.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try searching by business name, linked shop, town, county, or owner UID.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AdminBusinessProfilesPage._softTextColor,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No business profiles yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AdminBusinessProfilesPage._softTextColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load business profiles: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AdminBusinessProfilesPage._softTextColor,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
