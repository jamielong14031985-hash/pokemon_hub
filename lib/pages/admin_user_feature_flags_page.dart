import 'package:flutter/material.dart';

import '../services/user_feature_flags_service.dart';

class AdminUserFeatureFlagsPage extends StatelessWidget {
  const AdminUserFeatureFlagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('User Features'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<bool>(
        stream: UserFeatureFlagsService.watchCurrentUserCanManageFeatureFlags(),
        builder: (context, permissionSnapshot) {
          if (permissionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final canManage = permissionSnapshot.data == true;

          if (!canManage) {
            return const _NoPermissionMessage();
          }

          return StreamBuilder<List<AppUserSummary>>(
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

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const _IntroCard();
                  }

                  final user = users[index - 1];
                  return _UserFeatureCard(user: user);
                },
              );
            },
          );
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Turn Restock Alerts on or off for each account. '
          'When this is off, the user will not see the Restock Alerts feature in their profile.',
          style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserFeatureFlags>(
      stream: UserFeatureFlagsService.watchFlagsForUser(user.uid),
      builder: (context, flagsSnapshot) {
        final flags = flagsSnapshot.data ?? UserFeatureFlags.disabled(user.uid);
        final isLoading = flagsSnapshot.connectionState == ConnectionState.waiting;

        return Card(
          color: const Color(0xFF102754),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
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
                        Text(
                          user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (user.email.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            user.email,
                            style: const TextStyle(color: Color(0xFFD8E3FB)),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          user.uid,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Switch(
                    value: flags.restockAlertsEnabled,
                    onChanged: (enabled) async {
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
                            SnackBar(content: Text(error.toString())),
                          );
                      }
                    },
                  ),
              ],
            ),
          ),
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

class _NoPermissionMessage extends StatelessWidget {
  const _NoPermissionMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        color: Color(0xFF102754),
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'You do not have permission to manage user features.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
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
