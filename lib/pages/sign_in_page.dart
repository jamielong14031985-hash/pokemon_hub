import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/date_helpers.dart';
import '../widgets/auth_mode_chip.dart';
import '../widgets/custom_app_logo.dart';

const int _kCommunityMinimumAge = 18;

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  static const String _termsVersion = '2025-04-17';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _submitting = false;
  bool _sendingPasswordReset = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  DateTime? _selectedDateOfBirth;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = _selectedDateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(now.year - 120, 1, 1),
      lastDate: now,
      helpText: 'Select your date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3A82)),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateOfBirth = dateOnly(picked);
    });
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password');
      return;
    }

    if (_isSignUp && password != confirmPassword) {
      _showMessage('Passwords do not match');
      return;
    }

    if (_isSignUp && _selectedDateOfBirth == null) {
      _showMessage('Please select your date of birth');
      return;
    }

    if (_isSignUp && !_acceptedTerms) {
      _showMessage('Please read and accept the Terms & Conditions to continue');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      if (_isSignUp) {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email ?? email,
            'username': '',
            'createdAtMs': now,
            'updatedAtMs': now,
            'acceptedTermsVersion': _termsVersion,
            'acceptedTermsAtMs': now,
            'dateOfBirthMs': _selectedDateOfBirth!.millisecondsSinceEpoch,
            'emailVerified': user.emailVerified,
          }, SetOptions(merge: true));
          try {
            await user.sendEmailVerification();
          } catch (_) {}
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Authentication failed');
    } catch (_) {
      _showMessage('Authentication failed');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter your email address first');
      return;
    }

    setState(() {
      _sendingPasswordReset = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Password reset email sent. Check your inbox and spam folder.');
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Could not send password reset email.');
    } catch (_) {
      _showMessage('Could not send password reset email.');
    } finally {
      if (mounted) {
        setState(() {
          _sendingPasswordReset = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openTermsAndConditions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please read and accept these before creating an account.',
                  style: TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16366E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF3F5C96)),
                      ),
                      child: const SelectableText(
                        _kPokemonHubTermsAndConditions,
                        style: TextStyle(
                          color: Color(0xFFE4ECFF),
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
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
              constraints: const BoxConstraints(maxWidth: 420),
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
                      const SizedBox(height: 14),
                      Text(
                        _isSignUp ? 'Create your account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSignUp
                            ? 'Sign up to unlock community sale and swap posts.'
                            : 'Sign in to view your profile and post in the community.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: AuthModeChip(
                              label: 'Sign In',
                              selected: !_isSignUp,
                              onTap: () => setState(() => _isSignUp = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AuthModeChip(
                              label: 'Sign Up',
                              selected: _isSignUp,
                              onTap: () => setState(() => _isSignUp = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: _authInputDecoration('Email address'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _authInputDecoration('Password').copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      if (_isSignUp) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: _authInputDecoration('Confirm password').copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickDateOfBirth,
                          borderRadius: BorderRadius.circular(18),
                          child: InputDecorator(
                            decoration: _authInputDecoration('Date of birth'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedDateOfBirth == null
                                        ? 'Select your date of birth'
                                        : formatDateOfBirth(_selectedDateOfBirth!),
                                    style: TextStyle(
                                      color: _selectedDateOfBirth == null
                                          ? Colors.white54
                                          : Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 20),
                              ],
                            ),
                          ),
                        ),
                        if (_selectedDateOfBirth != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            calculateAgeYears(_selectedDateOfBirth!) >= _kCommunityMinimumAge
                                ? 'You can access the Community page once your profile is complete.'
                                : 'Users under $_kCommunityMinimumAge cannot access the Community page.',
                            style: TextStyle(
                              color: calculateAgeYears(_selectedDateOfBirth!) >= _kCommunityMinimumAge
                                  ? const Color(0xFFC8D4F0)
                                  : const Color(0xFFF7DE77),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16366E),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF3F5C96)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _acceptedTerms,
                                    activeColor: const Color(0xFFF7DE77),
                                    checkColor: Colors.black,
                                    onChanged: (value) {
                                      setState(() {
                                        _acceptedTerms = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: RichText(
                                        text: const TextSpan(
                                          style: TextStyle(
                                            color: Color(0xFFE4ECFF),
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                          children: [
                                            TextSpan(text: 'I have read and agree to the '),
                                            TextSpan(
                                              text: 'Terms & Conditions',
                                              style: TextStyle(
                                                color: Color(0xFFF7DE77),
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            TextSpan(text: ' for PocketChase.'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _openTermsAndConditions,
                                  icon: const Icon(Icons.description_outlined),
                                  label: const Text('Read Terms & Conditions'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isSignUp ? 'Create account' : 'Sign in'),
                      ),
                      if (!_isSignUp) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: (_submitting || _sendingPasswordReset) ? null : _sendPasswordReset,
                          icon: _sendingPasswordReset
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_reset_outlined),
                          label: Text(_sendingPasswordReset ? 'Sending reset email...' : 'Forgot password?'),
                        ),
                      ],
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

const String _kPokemonHubTermsAndConditions = '''PocketChase Terms & Conditions

Effective date: 17 April 2025

1. Acceptance of these terms
By creating an account or using PocketChase, you agree to these Terms & Conditions. If you do not agree, do not create an account or use the app.

2. Community use
PocketChase is intended for collectors to track cards, share wishlists, discuss the hobby, and connect with other users. You agree to use the app respectfully and lawfully.

3. Buying, selling, swapping, and arranging meetups
Any sale, swap, trade, payment, postage, meetup, or other arrangement made through the community area is strictly between the users involved. PocketChase does not verify users, inspect items, guarantee payment, guarantee delivery, or guarantee the condition, authenticity, legality, or value of any card or product. Use your own judgment and take appropriate safety precautions.

4. Acceptable behaviour
You must not post or send content that is abusive, threatening, discriminatory, sexually explicit, fraudulent, misleading, or unlawful. You must not harass other users, impersonate anyone, spam the community, or attempt to scam, phish, or manipulate others.

5. Images and content you upload
You are responsible for the text, images, and other content you upload or send through PocketChase. By posting content, you confirm that you have the right to share it and that it does not infringe another person's rights.

6. Account responsibility
You are responsible for keeping your login details secure and for activity that happens through your account. Tell the app owner promptly if you believe your account has been used without permission.

7. Data and visibility
Some information you add, such as your community posts, friend-visible wishlist, and friend-visible Pokédex data, may be shown to other users based on the app's social features. Do not upload anything you do not want shared within those features.

8. Availability and changes
PocketChase may be updated, changed, suspended, or removed at any time. Features may be added, changed, or discontinued without notice.

9. Termination
Accounts or content may be removed, limited, or suspended if a user breaks these terms or misuses the app or community features.

10. Liability
PocketChase is provided on an "as is" basis. To the fullest extent allowed by law, the app owner is not responsible for losses, damage, disputes, failed trades, payment problems, shipping issues, counterfeit items, meetups, or other issues arising from user activity or third-party services.

11. Children and safety
If a user is under the age required by local law to manage an online account, a parent or guardian should review and approve use of the app. Never share sensitive personal information publicly, and use extra caution when arranging in-person meetups.

12. Changes to these terms
These terms may be updated from time to time. Continued use of PocketChase after changes take effect means you accept the updated terms.

13. Contact
If you have questions, concerns, or need to report misuse, use the contact method provided by the app owner.

These terms are a practical in-app starter set and may need review to match your local laws, privacy wording, and how you run the app.''';


InputDecoration _authInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: const Color(0xFF16366E),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: Color(0xFF3F5C96)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: Color(0xFF3F5C96)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
    ),
  );
}
