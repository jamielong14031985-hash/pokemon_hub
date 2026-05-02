import 'package:flutter/material.dart';

import '../pages/admin_user_feature_flags_page.dart';
import '../services/user_feature_flags_service.dart';

class ProfileFeatureButtons extends StatelessWidget {
  const ProfileFeatureButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _AdminUserFeaturesProfileButton(),
      ],
    );
  }
}

class _AdminUserFeaturesProfileButton extends StatelessWidget {
  const _AdminUserFeaturesProfileButton();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: UserFeatureFlagsService.watchCurrentUserCanManageFeatureFlags(),
      builder: (context, snapshot) {
        final canManage = snapshot.data == true;

        if (!canManage) return const SizedBox.shrink();

        return ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: const Text('User Features'),
          subtitle: const Text('Turn PocketChase Pro and admin permissions on or off for users'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminUserFeatureFlagsPage(),
              ),
            );
          },
        );
      },
    );
  }
}
