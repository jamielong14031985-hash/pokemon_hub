import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
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
                itemCount: profiles.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildSearchBox();
                  }

                  if (index == 1) {
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

                  final profile = profiles[index - 2];
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
        premiumExpiresAt: profile.premiumExpiresAt,
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
        premiumExpiresAt: profile.premiumExpiresAt,
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
        premiumExpiresAt: profile.premiumExpiresAt,
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
