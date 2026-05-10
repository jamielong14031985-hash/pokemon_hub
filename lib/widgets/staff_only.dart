import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Shows [child] only when the signed-in user has one of the allowed roles.
///
/// Default allowed roles:
/// - admin
/// - moderator
///
/// This is for hiding admin/moderator UI such as buttons, drawer items,
/// settings tiles, and admin feature pages.
///
/// Important:
/// This only hides UI. You must also protect the Firestore rules so normal
/// users cannot write to admin/moderator-only documents.
class StaffOnly extends StatelessWidget {
  const StaffOnly({
    super.key,
    required this.child,
    this.allowedRoles = const {'admin', 'moderator'},
    this.loading,
    this.fallback,
  });

  final Widget child;
  final Set<String> allowedRoles;
  final Widget? loading;
  final Widget? fallback;

  Future<bool> _canAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final roleSnapshot = await FirebaseFirestore.instance
        .collection('app_roles')
        .doc(user.uid)
        .get();

    final role = roleSnapshot.data()?['role'];

    if (role is! String) return false;

    return allowedRoles.contains(role.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ?? const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return fallback ?? const SizedBox.shrink();
        }

        final canAccess = snapshot.data == true;

        if (!canAccess) {
          return fallback ?? const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}

/// Protects a whole page so only admins/moderators can view it.
///
/// Use this when navigating to staff-only pages, for example:
///
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => const StaffGuardPage(
///       child: UserFeaturesPage(),
///     ),
///   ),
/// );
class StaffGuardPage extends StatelessWidget {
  const StaffGuardPage({
    super.key,
    required this.child,
    this.title = 'Access denied',
    this.message = 'Only admins and moderators can access this page.',
    this.allowedRoles = const {'admin', 'moderator'},
  });

  final Widget child;
  final String title;
  final String message;
  final Set<String> allowedRoles;

  Future<bool> _canAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final roleSnapshot = await FirebaseFirestore.instance
        .collection('app_roles')
        .doc(user.uid)
        .get();

    final role = roleSnapshot.data()?['role'];

    if (role is! String) return false;

    return allowedRoles.contains(role.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access error'),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not check your account role. Please try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final canAccess = snapshot.data == true;

        if (!canAccess) {
          return Scaffold(
            appBar: AppBar(
              title: Text(title),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
