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

  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _sending = true;
    });

    try {
      await user.sendEmailVerification();
      _showMessage('Verification email sent. Check your inbox and spam folder.');
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Could not send verification email.');
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _checking = true;
    });

    try {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser != null && refreshedUser.emailVerified) {
        await FirebaseFirestore.instance.collection('users').doc(refreshedUser.uid).set(
          {
            'emailVerified': true,
            'emailVerifiedAtMs': DateTime.now().millisecondsSinceEpoch,
            'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
          },
          SetOptions(merge: true),
        );
        _showMessage('Email verified. Welcome to PocketChase.');
      } else {
        _showMessage('Email is not verified yet. Open the email link, then tap refresh again.');
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Could not check verification status.');
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
    await FirebaseAuth.instance.signOut();
  }
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
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
                        'We sent a verification link to ${widget.user.email ?? 'your email address'}. Verify your email before continuing.',
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
                          'After tapping the link in your email, come back here and press “I have verified”.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFE4ECFF),
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _checking ? null : _refreshVerificationStatus,
                        icon: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(_checking ? 'Checking...' : 'I have verified'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _sending ? null : _sendVerificationEmail,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(_sending ? 'Sending...' : 'Resend verification email'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _signOut,
                        child: const Text('Use a different email'),
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
