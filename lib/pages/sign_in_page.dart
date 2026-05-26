import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/tcg_shop.dart';
import '../services/tcg_shop_service.dart';
import '../utils/date_helpers.dart';
import '../widgets/auth_mode_chip.dart';
import '../widgets/custom_app_logo.dart';

const int _kCommunityMinimumAge = 18;
const String _kPersonalAccountType = 'personal';
const String _kBusinessAccountType = 'business';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  static const String _termsVersion = '2025-04-17';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessDescriptionController =
      TextEditingController();
  final TextEditingController _businessWebsiteController =
      TextEditingController();
  final TextEditingController _businessPhoneController = TextEditingController();
  final TextEditingController _businessTownController = TextEditingController();
  final TextEditingController _businessCountyController = TextEditingController();
  final TcgShopService _shopService = TcgShopService();

  bool? _businessHasPhysicalShop;
  String _businessLinkedShopId = '';
  String _businessLinkedShopName = '';

  bool _isSignUp = false;
  bool _submitting = false;
  bool _sendingPasswordReset = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  String _selectedAccountType = _kPersonalAccountType;
  DateTime? _selectedDateOfBirth;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _businessWebsiteController.dispose();
    _businessPhoneController.dispose();
    _businessTownController.dispose();
    _businessCountyController.dispose();
    super.dispose();
  }

  bool get _isBusinessSignUp {
    return _isSignUp && _selectedAccountType == _kBusinessAccountType;
  }

  Future<void> _pickDateOfBirth() async {
    if (_submitting) return;

    final now = DateTime.now();
    final initialDate =
        _selectedDateOfBirth ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(now.year - 120, 1, 1),
      lastDate: now,
      helpText: 'Select your date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0B3A82),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateOfBirth = dateOnly(picked);
    });
  }

  bool _looksLikeEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'Email sign in is not enabled for this app yet.';
      default:
        return error.message ?? 'Authentication failed';
    }
  }

  Future<void> _saveNewUserProfile({
    required User user,
    required String email,
    required int now,
    required String username,
    required bool businessProfileCreated,
  }) async {
    final dateOfBirth = _selectedDateOfBirth;
    if (dateOfBirth == null) {
      throw StateError('Missing date of birth.');
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? email,
      'username': username.trim(),
      'createdAtMs': now,
      'updatedAtMs': now,
      'acceptedTermsVersion': _termsVersion,
      'acceptedTermsAtMs': now,
      'dateOfBirthMs': dateOfBirth.millisecondsSinceEpoch,
      'emailVerified': user.emailVerified,
      'accountType': _selectedAccountType == _kBusinessAccountType
          ? _kBusinessAccountType
          : _kPersonalAccountType,
      'businessProfileCreated': businessProfileCreated,
    }, SetOptions(merge: true));
  }

  Future<void> _createBusinessProfileForNewUser({
    required User user,
    required String email,
  }) async {
    final businessName = _businessNameController.text.trim();
    final town = _businessTownController.text.trim();
    final county = _businessCountyController.text.trim();

    await FirebaseFirestore.instance
        .collection('business_profiles')
        .doc(user.uid)
        .set({
      'ownerUid': user.uid,
      'ownerEmail': user.email ?? email,
      'businessName': businessName,
      'businessNameLower': businessName.toLowerCase(),
      'description': _businessDescriptionController.text.trim(),
      'linkedShopId': _businessLinkedShopId.trim(),
      'linkedShopName': _businessLinkedShopName.trim(),
      'hasPhysicalShop': _businessHasPhysicalShop == true,
      'website': _businessWebsiteController.text.trim(),
      'phone': _businessPhoneController.text.trim(),
      'town': town,
      'townLower': town.toLowerCase(),
      'county': county,
      'countyLower': county.toLowerCase(),
      'logoUrl': '',
      'bannerUrl': '',
      'status': 'approved',
      'verified': false,
      'premiumActive': false,
      'premiumExpiresAt': null,
      'premiumSource': '',
      'featuredShopEnabled': false,
      'autoFeaturePosts': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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

    if (!_looksLikeEmail(email)) {
      _showMessage('Enter a valid email address');
      return;
    }

    if (_isSignUp && password.length < 6) {
      _showMessage('Password must be at least 6 characters');
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

    if (_isBusinessSignUp) {
      final businessName = _businessNameController.text.trim();
      final businessDescription = _businessDescriptionController.text.trim();
      final businessWebsite = _businessWebsiteController.text.trim();
      final businessPhone = _businessPhoneController.text.trim();
      final businessTown = _businessTownController.text.trim();
      final businessCounty = _businessCountyController.text.trim();

      if (businessName.isEmpty) {
        _showMessage('Enter your business name');
        return;
      }

      if (businessDescription.isEmpty) {
        _showMessage('Enter a short business description');
        return;
      }

      if (businessWebsite.isEmpty) {
        _showMessage('Enter your business website');
        return;
      }

      if (businessPhone.isEmpty) {
        _showMessage('Enter your business phone number');
        return;
      }

      if (businessTown.isEmpty || businessCounty.isEmpty) {
        _showMessage('Enter your business town and county');
        return;
      }

      if (_businessHasPhysicalShop == null) {
        _showMessage('Choose whether you have a physical shop or are online-only');
        return;
      }
    }

    setState(() {
      _submitting = true;
    });

    try {
      if (_isSignUp) {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user == null) {
          throw StateError('Could not create account. Please try again.');
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final isBusinessAccount = _selectedAccountType == _kBusinessAccountType;
        final businessName = _businessNameController.text.trim();

        await _saveNewUserProfile(
          user: user,
          email: email,
          now: now,
          username: isBusinessAccount ? businessName : '',
          businessProfileCreated: isBusinessAccount,
        );

        if (isBusinessAccount) {
          await _createBusinessProfileForNewUser(user: user, email: email);
        }

        try {
          await user.sendEmailVerification();
        } catch (_) {
          // Account creation should still complete if the verification email fails.
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyAuthError(error));
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not save your profile details.');
    } on StateError catch (error) {
      _showMessage(error.message);
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

    if (!_looksLikeEmail(email)) {
      _showMessage('Enter a valid email address');
      return;
    }

    setState(() {
      _sendingPasswordReset = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Password reset email sent. Check your inbox and spam folder.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyAuthError(error));
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

  void _switchAuthMode(bool signUp) {
    if (_submitting || _sendingPasswordReset) return;
    if (_isSignUp == signUp) return;

    setState(() {
      _isSignUp = signUp;
      _confirmPasswordController.clear();
      _obscureConfirmPassword = true;
    });
  }




  Widget _buildBusinessMapLinkDropdown() {
    return StreamBuilder<List<TcgShop>>(
      stream: _shopService.watchApprovedShops(),
      builder: (context, snapshot) {
        final shops = snapshot.data ?? const <TcgShop>[];

        final shopIds = shops.map((shop) => shop.id).toSet();
        final safeSelectedShopId =
            _businessLinkedShopId.isNotEmpty &&
                    shopIds.contains(_businessLinkedShopId)
                ? _businessLinkedShopId
                : '';

        if (_businessLinkedShopId.isNotEmpty && safeSelectedShopId.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _businessLinkedShopId = '';
              _businessLinkedShopName = '';
            });
          });
        }

        return DropdownButtonFormField<String>(
          initialValue: safeSelectedShopId,
          isExpanded: true,
          dropdownColor: const Color(0xFF16366E),
          iconEnabledColor: const Color(0xFFC8D4F0),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          decoration: _authInputDecoration('Link existing map shop'),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('I will add/link my shop after sign-up'),
            ),
            ...shops.map(
              (shop) => DropdownMenuItem<String>(
                value: shop.id,
                child: Text(
                  shop.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: _submitting
              ? null
              : (value) {
                  final selectedShopId = value ?? '';
                  TcgShop? selectedShop;

                  for (final shop in shops) {
                    if (shop.id == selectedShopId) {
                      selectedShop = shop;
                      break;
                    }
                  }

                  setState(() {
                    _businessLinkedShopId = selectedShopId;
                    _businessLinkedShopName = selectedShop?.name ?? '';
                  });
                },
        );
      },
    );
  }

  Widget _buildBusinessDetailsForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16366E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3F5C96)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                color: Color(0xFFF7DE77),
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Business details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'These details create your Business Profile straight away. You must complete business setup before entering the app.',
            style: TextStyle(
              color: Color(0xFFC8D4F0),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _businessNameController,
            enabled: !_submitting,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            decoration: _authInputDecoration('Business name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _businessDescriptionController,
            enabled: !_submitting,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            decoration: _authInputDecoration('Business description'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _businessWebsiteController,
            enabled: !_submitting,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white),
            decoration: _authInputDecoration('Website'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _businessPhoneController,
            enabled: !_submitting,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white),
            decoration: _authInputDecoration('Phone number'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _businessTownController,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: _authInputDecoration('Town'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _businessCountyController,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: _authInputDecoration('County'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Shop type',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AccountTypeCard(
                  title: 'Physical shop',
                  subtitle: 'Link to a shop on the TCG Shop Map.',
                  icon: Icons.store_mall_directory_outlined,
                  selected: _businessHasPhysicalShop == true,
                  onTap: _submitting
                      ? null
                      : () => setState(() {
                            _businessHasPhysicalShop = true;
                          }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AccountTypeCard(
                  title: 'Online-only',
                  subtitle: 'No map link needed.',
                  icon: Icons.language,
                  selected: _businessHasPhysicalShop == false,
                  onTap: _submitting
                      ? null
                      : () => setState(() {
                            _businessHasPhysicalShop = false;
                            _businessLinkedShopId = '';
                            _businessLinkedShopName = '';
                          }),
                ),
              ),
            ],
          ),
          if (_businessHasPhysicalShop == true) ...[
            const SizedBox(height: 10),
            _buildBusinessMapLinkDropdown(),
          ],
          const SizedBox(height: 10),
          const Text(
            'Physical shops must be linked to the TCG Shop Map before the account can continue into the app. If your shop is not listed yet, you can add it straight after sign-up.',
            style: TextStyle(
              color: Color(0xFFF7DE77),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose account type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _AccountTypeCard(
                title: 'Personal',
                subtitle: 'Collect cards, track sets, wishlist and community.',
                icon: Icons.person_outline,
                selected: _selectedAccountType == _kPersonalAccountType,
                onTap: _submitting
                    ? null
                    : () => setState(() {
                          _selectedAccountType = _kPersonalAccountType;
                          _businessHasPhysicalShop = null;
                          _businessLinkedShopId = '';
                          _businessLinkedShopName = '';
                        }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AccountTypeCard(
                title: 'Business',
                subtitle: 'Enter your business details during sign-up.',
                icon: Icons.storefront_outlined,
                selected: _selectedAccountType == _kBusinessAccountType,
                onTap: _submitting
                    ? null
                    : () => setState(() {
                          _selectedAccountType = _kBusinessAccountType;
                        }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _selectedAccountType == _kBusinessAccountType
              ? 'Business accounts create their Business Profile now. You can edit it later from Profile.'
              : 'Personal accounts can use PocketChase as a collector account.',
          style: const TextStyle(
            color: Color(0xFFC8D4F0),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateOfBirth = _selectedDateOfBirth;
    final selectedAge =
        dateOfBirth == null ? null : calculateAgeYears(dateOfBirth);

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
                              onTap: () => _switchAuthMode(false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AuthModeChip(
                              label: 'Sign Up',
                              selected: _isSignUp,
                              onTap: () => _switchAuthMode(true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_isSignUp) ...[
                        _buildAccountTypeSelector(),
                        if (_selectedAccountType == _kBusinessAccountType) ...[
                          const SizedBox(height: 14),
                          _buildBusinessDetailsForm(),
                        ],
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: _emailController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: _authInputDecoration('Email address'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        enabled: !_submitting,
                        obscureText: _obscurePassword,
                        autofillHints: _isSignUp
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        textInputAction:
                            _isSignUp ? TextInputAction.next : TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_isSignUp && !_submitting) {
                            _submit();
                          }
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: _authInputDecoration('Password').copyWith(
                          suffixIcon: IconButton(
                            onPressed: _submitting
                                ? null
                                : () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      if (_isSignUp) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          enabled: !_submitting,
                          obscureText: _obscureConfirmPassword,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_submitting) {
                              _submit();
                            }
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: _authInputDecoration('Confirm password')
                              .copyWith(
                            suffixIcon: IconButton(
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _submitting ? null : _pickDateOfBirth,
                          borderRadius: BorderRadius.circular(18),
                          child: InputDecorator(
                            decoration: _authInputDecoration('Date of birth'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dateOfBirth == null
                                        ? 'Select your date of birth'
                                        : formatDateOfBirth(dateOfBirth),
                                    style: TextStyle(
                                      color: dateOfBirth == null
                                          ? Colors.white54
                                          : Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (dateOfBirth != null && selectedAge != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            selectedAge >= _kCommunityMinimumAge
                                ? 'You can access the Community page once your profile is complete.'
                                : 'Users under $_kCommunityMinimumAge cannot access the Community page.',
                            style: TextStyle(
                              color: selectedAge >= _kCommunityMinimumAge
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
                                    fillColor:
                                        WidgetStateProperty.resolveWith<Color?>(
                                      (states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return const Color(0xFFF7DE77);
                                        }
                                        return null;
                                      },
                                    ),
                                    checkColor: Colors.black,
                                    onChanged: _submitting
                                        ? null
                                        : (value) {
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
                                            TextSpan(
                                              text:
                                                  'I have read and agree to the ',
                                            ),
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
                                  onPressed:
                                      _submitting ? null : _openTermsAndConditions,
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
                          onPressed: (_submitting || _sendingPasswordReset)
                              ? null
                              : _sendPasswordReset,
                          icon: _sendingPasswordReset
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_reset_outlined),
                          label: Text(
                            _sendingPasswordReset
                                ? 'Sending reset email...'
                                : 'Forgot password?',
                          ),
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


class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? const Color(0xFFF7DE77) : const Color(0xFF3F5C96);
    final backgroundColor = selected
        ? const Color(0xFFF7DE77).withValues(alpha: 0.14)
        : const Color(0xFF16366E);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFFF7DE77) : Colors.white70,
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFC8D4F0),
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
