import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/custom_app_logo.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, required this.user});

  final User user;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _sending = false;
  bool _checking = false;
  bool _signingOut = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _emailText {
    final liveEmail = _currentUser?.email?.trim();
    if (liveEmail != null && liveEmail.isNotEmpty) return liveEmail;

    final initialEmail = widget.user.email?.trim();
    if (initialEmail != null && initialEmail.isNotEmpty) return initialEmail;

    return 'your email address';
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'user-token-expired':
      case 'requires-recent-login':
        return 'Please sign in again and try once more.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_sending || _checking || _signingOut) return;

    final user = _currentUser;
    if (user == null) {
      _showMessage('Please sign in again to verify your email.');
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await user.sendEmailVerification();
      _showMessage('Verification email sent. Check your inbox and spam folder.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyAuthError(error));
    } catch (_) {
      _showMessage('Could not send verification email.');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _refreshVerificationStatus() async {
    if (_checking || _sending || _signingOut) return;

    final user = _currentUser;
    if (user == null) {
      _showMessage('Please sign in again to verify your email.');
      return;
    }

    setState(() {
      _checking = true;
    });

    try {
      await user.reload();

      final refreshedUser = _currentUser;
      if (refreshedUser == null) {
        _showMessage('Please sign in again to verify your email.');
        return;
      }

      if (!refreshedUser.emailVerified) {
        _showMessage(
          'Email is not verified yet. Open the email link, then tap refresh again.',
        );
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await FirebaseFirestore.instance.collection('users').doc(refreshedUser.uid).set(
        {
          'emailVerified': true,
          'emailVerifiedAtMs': now,
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );

      _showMessage('Email verified. Welcome to PocketChase.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyAuthError(error));
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not save verification status.');
    } catch (_) {
      _showMessage('Could not check verification status.');
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (_signingOut || _sending || _checking) return;

    setState(() {
      _signingOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      _showMessage('Could not sign out right now.');
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _checking || _signingOut;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CustomAppLogo(
                        height: 64,
                        fallbackIcon: Icons.catching_pokemon,
                        fallbackColor: Color(0xFFF7DE77),
                      ),
                      const SizedBox(height: 16),
                      const Icon(
                        Icons.mark_email_unread_outlined,
                        color: Color(0xFFF7DE77),
                        size: 46,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Verify your email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a verification link to $_emailText. Verify your email before continuing.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16366E),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF3F5C96)),
                        ),
                        child: const Text(
                          'After tapping the link in your email, come back here and press "I have verified". If you cannot see the email, check your spam folder or send a new one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFE4ECFF),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: busy ? null : _refreshVerificationStatus,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFF7DE77),
                          foregroundColor: Colors.black,
                        ),
                        icon: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(
                          _checking ? 'Checking...' : 'I have verified',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _sendVerificationEmail,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF3F5C96)),
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.outgoing_mail),
                        label: Text(_sending ? 'Sending...' : 'Send email again'),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: busy ? null : _signOut,
                        icon: _signingOut
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.logout),
                        label: Text(_signingOut ? 'Signing out...' : 'Use another account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
