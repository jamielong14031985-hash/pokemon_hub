import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_shell.dart';
import 'models/app_user_profile.dart';
import 'pages/welcome_back_page.dart';
import 'pages/welcome_page.dart';
import 'widgets/full_screen_loader.dart';

/// Users created before this date are treated as existing users.
///
/// Existing users see a short animated "Welcome back" screen.
/// New users see the full onboarding welcome screen once.
const int _kWelcomeCutoffCreatedAtMs = 1777762800000; // 03 May 2026 00:00 UK

class WelcomeGate extends StatefulWidget {
  const WelcomeGate({
    super.key,
    required this.profile,
  });

  final AppUserProfile profile;

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  bool _loading = true;
  bool _newUserWelcomeSeen = false;
  bool _existingUserWelcomeSeen = false;

  bool get _isExistingUser {
    final createdAtMs = widget.profile.createdAtMs;
    if (createdAtMs <= 0) return false;
    return createdAtMs < _kWelcomeCutoffCreatedAtMs;
  }

  String get _newUserPrefsKey =>
      'pocketchase_new_user_welcome_seen_${widget.profile.uid}';

  String get _existingUserPrefsKey =>
      'pocketchase_existing_user_simple_welcome_seen_${widget.profile.uid}_v1';

  @override
  void initState() {
    super.initState();
    _loadWelcomeState();
  }

  @override
  void didUpdateWidget(covariant WelcomeGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile.uid != widget.profile.uid) {
      setState(() {
        _loading = true;
        _newUserWelcomeSeen = false;
        _existingUserWelcomeSeen = false;
      });
      _loadWelcomeState();
    }
  }

  Future<void> _loadWelcomeState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newUserSeen = prefs.getBool(_newUserPrefsKey) ?? false;
      final existingUserSeen = prefs.getBool(_existingUserPrefsKey) ?? false;

      if (!mounted) return;
      setState(() {
        _newUserWelcomeSeen = newUserSeen;
        _existingUserWelcomeSeen = existingUserSeen;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _newUserWelcomeSeen = false;
        _existingUserWelcomeSeen = false;
        _loading = false;
      });
    }
  }

  Future<void> _markNewUserWelcomeSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_newUserPrefsKey, true);
    } catch (_) {
      // The user should still be able to continue even if local storage fails.
    }

    if (!mounted) return;
    setState(() {
      _newUserWelcomeSeen = true;
    });
  }

  Future<void> _markExistingUserWelcomeSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_existingUserPrefsKey, true);
    } catch (_) {
      // The user should still be able to continue even if local storage fails.
    }

    if (!mounted) return;
    setState(() {
      _existingUserWelcomeSeen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const FullScreenLoader();
    }

    if (_isExistingUser && !_existingUserWelcomeSeen) {
      return WelcomeBackPage(
        profile: widget.profile,
        onFinished: _markExistingUserWelcomeSeen,
      );
    }

    if (!_isExistingUser && !_newUserWelcomeSeen) {
      return WelcomePage(
        profile: widget.profile,
        onStart: _markNewUserWelcomeSeen,
      );
    }

    return AppShell(profile: widget.profile);
  }
}
