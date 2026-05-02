import 'package:flutter/material.dart';

import '../widgets/glass_page_header.dart';

import '../services/user_feature_flags_service.dart';

class AdminUserFeatureFlagsPage extends StatefulWidget {
  const AdminUserFeatureFlagsPage({super.key});

  @override
  State<AdminUserFeatureFlagsPage> createState() =>
      _AdminUserFeatureFlagsPageState();
}

class _AdminUserFeatureFlagsPageState extends State<AdminUserFeatureFlagsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<AppUserSummary> _filteredUsers(
    List<AppUserSummary> users,
    String query,
  ) {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return users;

    return users.where((user) {
      return user.username.toLowerCase().contains(cleanQuery) ||
          user.email.toLowerCase().contains(cleanQuery) ||
          user.uid.toLowerCase().contains(cleanQuery);
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.requestFocus();
  }

  Widget _buildSearchField() {
    return TextField(
      key: const ValueKey('admin-user-feature-search-field'),
      controller: _searchController,
      focusNode: _searchFocusNode,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Search users by username, email, or UID',
        hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFFF7DE77),
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, _) {
            final hasSearch = value.text.trim().isNotEmpty;
            if (!hasSearch) return const SizedBox.shrink();

            return IconButton(
              onPressed: _clearSearch,
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
              ),
              tooltip: 'Clear search',
            );
          },
        ),
        filled: true,
        fillColor: const Color(0xFF0E2A5E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFF7DE77),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard(List<AppUserSummary> users) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 10),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                final query = value.text.trim();
                final visibleUsers = _filteredUsers(users, query).length;
                final hasSearch = query.isNotEmpty;

                return Row(
                  children: [
                    Icon(
                      hasSearch
                          ? Icons.filter_alt_rounded
                          : Icons.people_alt_outlined,
                      color: const Color(0xFFF7DE77),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasSearch
                            ? 'Showing $visibleUsers of ${users.length} users'
                            : '${users.length} users available',
                        style: const TextStyle(
                          color: Color(0xFFD8E3FB),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedContent(List<AppUserSummary> users) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final query = value.text.trim();
        final filteredUsers = _filteredUsers(users, query);

        final items = <Widget>[
          const _IntroCard(),
          _buildSearchCard(users),
          if (filteredUsers.isEmpty)
            _NoSearchResultsCard(query: query)
          else
            ...filteredUsers.map((user) => _UserFeatureCard(user: user)),
        ];

        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => items[index],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: const GlassPageAppBar(
        title: 'User Features',
        subtitle: 'Manage app permissions',
        icon: Icons.admin_panel_settings_outlined,
      ),
      body: StreamBuilder<List<AppUserSummary>>(
        stream: UserFeatureFlagsService.watchUsers(),
        builder: (context, usersSnapshot) {
          if (usersSnapshot.hasError) {
            return _ErrorMessage(error: usersSnapshot.error.toString());
          }

          if (usersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = usersSnapshot.data ?? const <AppUserSummary>[];

          if (users.isEmpty) {
            return const Center(
              child: Text(
                'No users found.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return _buildLoadedContent(users);
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Manage feature access for each account. '
          'Restock Alerts controls the restock tools. '
          'PocketChase Pro removes banner ads for that user without needing a purchase.',
          style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
        ),
      ),
    );
  }
}

class _NoSearchResultsCard extends StatelessWidget {
  const _NoSearchResultsCard({
    required this.query,
  });

  final String query;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.person_search_outlined,
              color: Color(0xFFF7DE77),
              size: 34,
            ),
            const SizedBox(height: 10),
            const Text(
              'No users found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              query.trim().isEmpty
                  ? 'No users are available.'
                  : 'No username, email, or UID matched “$query”.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC8D4F0),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserFeatureCard extends StatelessWidget {
  const _UserFeatureCard({
    required this.user,
  });

  final AppUserSummary user;

  Future<void> _setRestockAlerts(
    BuildContext context,
    bool enabled,
  ) async {
    try {
      await UserFeatureFlagsService.setRestockAlertsEnabled(
        userId: user.uid,
        enabled: enabled,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Restock Alerts ${enabled ? 'enabled' : 'disabled'} for ${user.username}.',
            ),
          ),
        );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Could not update Restock Alerts. Make sure your account has admin or moderator permission. $error',
            ),
          ),
        );
    }
  }

  Future<void> _setProAccess(
    BuildContext context,
    bool enabled,
  ) async {
    try {
      await UserFeatureFlagsService.setProEnabled(
        userId: user.uid,
        enabled: enabled,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'PocketChase Pro ${enabled ? 'enabled' : 'disabled'} for ${user.username}.',
            ),
          ),
        );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Could not update PocketChase Pro. Make sure your account has admin or moderator permission. $error',
            ),
          ),
        );
    }
  }


  Future<void> _setAdminAccess(
    BuildContext context,
    bool enabled,
  ) async {
    final confirm = await _confirmAdminChange(
      context: context,
      enabled: enabled,
    );

    if (confirm != true) return;

    try {
      await UserFeatureFlagsService.setAdminEnabled(
        userId: user.uid,
        enabled: enabled,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Admin permission ${enabled ? 'enabled' : 'removed'} for ${user.username}.',
            ),
          ),
        );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Could not update admin permission. Only admin accounts can change this. $error',
            ),
          ),
        );
    }
  }

  Future<bool?> _confirmAdminChange({
    required BuildContext context,
    required bool enabled,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102754),
          title: Text(
            enabled
                ? 'Make ${user.username} an admin?'
                : 'Remove admin permission?',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            enabled
                ? 'This will let ${user.username} manage user features, admin permissions, and moderation tools.'
                : 'This will remove admin permission from ${user.username}.',
            style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: enabled
                    ? const Color(0xFFF7DE77)
                    : const Color(0xFFB13B59),
                foregroundColor: enabled ? Colors.black : Colors.white,
              ),
              child: Text(enabled ? 'Make Admin' : 'Remove Admin'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserFeatureFlags>(
      stream: UserFeatureFlagsService.watchFlagsForUser(user.uid),
      builder: (context, flagsSnapshot) {
        final flags = flagsSnapshot.data ?? UserFeatureFlags.disabled(user.uid);
        final flagsLoading =
            flagsSnapshot.connectionState == ConnectionState.waiting;

        return StreamBuilder<UserAppRole>(
          stream: UserFeatureFlagsService.watchRoleForUser(user.uid),
          builder: (context, roleSnapshot) {
            final role = roleSnapshot.data ?? UserAppRole.none(user.uid);
            final roleLoading =
                roleSnapshot.connectionState == ConnectionState.waiting;
            final isLoading = flagsLoading || roleLoading;

            return Card(
          color: const Color(0xFF102754),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF0E2A5E),
                      child: Text(
                        _initials(user.username),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (role.isAdmin) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7DE77),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'ADMIN',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (user.email.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  color: Color(0xFFD8E3FB),
                                ),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Text(
                              user.uid,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _FeatureToggleRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Restock Alerts',
                  subtitle: flags.restockAlertsEnabled
                      ? 'User can access restock alert features.'
                      : 'Restock alert features are hidden.',
                  value: flags.restockAlertsEnabled,
                  enabled: !isLoading,
                  onChanged: (enabled) => _setRestockAlerts(context, enabled),
                ),
                const SizedBox(height: 10),
                _FeatureToggleRow(
                  icon: Icons.workspace_premium_outlined,
                  title: 'PocketChase Pro',
                  subtitle: flags.proEnabled
                      ? 'Ads are removed for this user by admin permission.'
                      : 'User needs to buy Pro to remove ads.',
                  value: flags.proEnabled,
                  enabled: !isLoading,
                  onChanged: (enabled) => _setProAccess(context, enabled),
                ),
                const SizedBox(height: 10),
                _FeatureToggleRow(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Permission',
                  subtitle: role.isAdmin
                      ? 'User can manage app features and moderation tools.'
                      : 'User has normal account permission.',
                  value: role.isAdmin,
                  enabled: !isLoading,
                  onChanged: (enabled) => _setAdminAccess(context, enabled),
                ),
              ],
            ),
          ),
            );
          },
        );
      },
    );
  }

  static String _initials(String username) {
    final trimmed = username.trim();

    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _FeatureToggleRow extends StatelessWidget {
  const _FeatureToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2A5E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value
              ? const Color(0xFFF7DE77).withValues(alpha: 0.40)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? const Color(0xFFF7DE77) : Colors.white54,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFC8D4F0),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.error,
  });

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: const Color(0xFF102754),
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Could not load users.\n\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
