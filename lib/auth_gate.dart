import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'models/app_user_profile.dart';
import 'pages/complete_profile_page.dart';
import 'pages/email_verification_page.dart';
import 'pages/sign_in_page.dart';
import 'services/user_profile_service.dart';
import 'widgets/full_screen_loader.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const FullScreenLoader();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const SignInPage();
        }

        if (!user.emailVerified && (user.email ?? '').trim().isNotEmpty) {
          return EmailVerificationPage(user: user);
        }

        return StreamBuilder<AppUserProfile?>(
          stream: UserProfileService.streamProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const FullScreenLoader();
            }

            final profile = profileSnapshot.data;
            if (profile == null ||
                profile.username.trim().isEmpty ||
                !profile.hasDateOfBirth) {
              return CompleteProfilePage(user: user);
            }

            return AppShell(profile: profile);
          },
        );
      },
    );
  }
}
