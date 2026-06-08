import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user_profile.dart';
import '../models/profile_stats.dart';
import '../models/tcg_card.dart';
import '../models/wishlist_entry.dart';
import '../services/account_deletion_service.dart';
import '../services/collection_refresh_notifier.dart';
import '../services/community_image_services.dart';
import '../services/currency_settings.dart';
import '../services/local_image_store.dart';
import '../services/pro_status_service.dart';
import '../services/user_profile_service.dart';
import '../services/wishlist_service.dart';
import '../utils/auth_input_decoration.dart';
import '../utils/profile_stats_helpers.dart';
import '../widgets/achievement_badges.dart';
import '../widgets/profile_collection_widgets.dart';
import '../widgets/profile_stat_card.dart';
import 'business_profile_page.dart';
import 'card_details_page.dart';
import 'featured_online_shops_page.dart';
import 'friend_requests_page.dart';
import 'friends_page.dart';
import 'pro_upgrade_page.dart';
import 'wishlist_page.dart';
import 'wishlist_trade_match_centre_page.dart';
import 'admin_tools_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String? _profileImagePath;
  bool _loadingProfile = true;
  bool _savingName = false;
  bool _savingCurrency = false;
  final bool _deletingAccount = false;
  String _selectedCurrencyCode = CurrencySettings.selectedCode;
  late Future<ProfileStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
    _loadProfile();
    collectionRefreshNotifier.addListener(_handleCollectionRefresh);
  }

  void _handleCollectionRefresh() {
    if (!mounted) return;
    _refreshStats();
  }

  Future<void> _loadProfile() async {
    _nameController.text = widget.profile.username.trim();
    final imagePath = await LocalProfileImageStore.loadForUser(widget.profile.uid);

    if (mounted) {
      setState(() {
        _profileImagePath = imagePath;
        _selectedCurrencyCode = CurrencySettings.selectedCode;
        _loadingProfile = false;
      });
    }
  }

  Future<bool> _saveName({bool showSnackBar = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.profile.isBusinessAccount
                ? 'Enter a business name'
                : 'Enter a trainer name',
          ),
        ),
      );
      return false;
    }

    setState(() {
      _savingName = true;
    });

    try {
      await UserProfileService.upsertProfile(user: user, username: newName);
      if (mounted && showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated')),
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update your name')),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _savingName = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    String? permanentPath;
    try {
      permanentPath = await LocalProfileImageStore.saveForUser(
        uid: widget.profile.uid,
        sourcePath: picked.path,
      );

      final imageRef = await CommunityImageCodec.storeFileForFirestore(
        permanentPath ?? picked.path,
        storageFolder: 'profile_images',
      );
      await UserProfileService.updateProfileImageBase64(
        uid: widget.profile.uid,
        imageBase64: imageRef,
      );

      if (!mounted) return;
      setState(() {
        _profileImagePath = permanentPath;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture saved and shared with community posts')),
      );
    } catch (_) {
      if (!mounted) return;
      if (permanentPath != null) {
        setState(() {
          _profileImagePath = permanentPath;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture saved on this device, but could not be shared online')),
      );
    }
  }

  Future<bool> _updateCurrency(
    String? value, {
    bool showSnackBar = true,
  }) async {
    if (value == null || value == _selectedCurrencyCode) return true;

    setState(() {
      _savingCurrency = true;
    });

    try {
      await CurrencySettings.setSelectedCode(value);
      if (!mounted) return false;

      setState(() {
        _selectedCurrencyCode = CurrencySettings.selectedCode;
        _statsFuture = _loadStats();
      });

      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Currency changed to ${CurrencySettings.selectedCurrency.code}',
            ),
          ),
        );
      }

      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your currency right now')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _savingCurrency = false;
        });
      }
    }
  }

  ProfileStats _emptyProfileStats() {
    return const ProfileStats(
      totalCards: 0,
      uniqueCards: 0,
      totalEstimatedPrice: 0,
      mostExpensiveCard: null,
      mostExpensiveCardCopies: 0,
      favouriteSetName: null,
      favouriteSetCopies: 0,
      rarityCopies: <String, int>{},
      rarityValues: <String, double>{},
      topValueCards: <TcgCard>[],
    );
  }

  Future<ProfileStats> _loadStats() async {
    try {
      return await loadProfileStatsForOwner(
        widget.profile.uid,
        preferCurrentUserLocalCache: true,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      return _emptyProfileStats();
    }
  }

  Future<void> _refreshStats() async {
    setState(() {
      _statsFuture = _loadStats();
    });
  }


  Stream<bool> _watchCurrentUserIsAdminOrModerator() {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();

    if (uid == null || uid.isEmpty) {
      return Stream<bool>.value(false);
    }

    return FirebaseFirestore.instance
        .collection('app_roles')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      final role = (data?['role'] as String? ?? '').trim().toLowerCase();

      return role == 'admin' || role == 'moderator';
    });
  }

  Future<void> _openAdminTools() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminToolsPage(),
      ),
    );
  }

  Future<void> _openFriends() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendsPage(currentProfile: widget.profile),
      ),
    );
  }

  Future<void> _openWishlistMatchCentre() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishlistTradeMatchCentrePage(currentProfile: widget.profile),
      ),
    );
  }

  Future<void> _openWishlist() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishlistPage(
          ownerUid: widget.profile.uid,
          ownerName: widget.profile.displayName,
        ),
      ),
    );
  }

  Future<void> _openProUpgrade() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProUpgradePage(),
      ),
    );
  }

  Future<void> _openBusinessProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BusinessProfilePage(),
      ),
    );
  }

  Future<void> _openFeaturedOnlineShops() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FeaturedOnlineShopsPage(),
      ),
    );
  }

  Future<void> _openCardDetails(TcgCard card) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardDetailsPage(card: card)),
    );
  }

  Future<void> _deleteAccount() async {
    final password = await _showDeleteAccountConfirmationDialog();
    if (password == null) return;
    if (!mounted) return;

    try {
      await AccountDeletionService.deleteCurrentAccount(password: password);

      // Do nothing else after a successful delete.
      // Firebase Auth will sign the user out and the root auth listener should
      // move the app back to the sign-in screen. Calling setState, snackbar, or
      // Navigator here can trigger Flutter inherited-widget assertions.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final message = switch (e.code) {
        'wrong-password' || 'invalid-credential' =>
          'Password was incorrect. Account not deleted.',
        'requires-recent-login' =>
          'Please sign out, sign back in, then try deleting your account again.',
        'too-many-requests' =>
          'Too many attempts. Please wait a while and try again.',
        _ => e.message ?? 'Could not delete your account.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<String?> _showDeleteAccountConfirmationDialog() async {
    final passwordController = TextEditingController();
    var confirmed = false;

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF102754),
              title: const Text(
                'Delete account?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This permanently deletes your account and app data from PocketChase, including your profile, wishlist, synced Pokédex, custom binders, friend records, community posts, replies, ratings, and private message records.',
                      style: TextStyle(color: Color(0xFFC8D4F0), height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: authInputDecoration('Confirm password'),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: confirmed,
                      onChanged: (value) => setDialogState(() {
                        confirmed = value ?? false;
                      }),
                      activeColor: const Color(0xFFF7DE77),
                      checkColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I understand this cannot be undone.',
                        style: TextStyle(color: Color(0xFFE4ECFF), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: confirmed && passwordController.text.trim().isNotEmpty
                      ? () => Navigator.of(dialogContext).pop(passwordController.text.trim())
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB13B59),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete forever'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    return result;
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  ImageProvider? _profileImageProvider() {
    final imageFile = _profileImagePath != null ? File(_profileImagePath!) : null;
    final existingImageFile =
        imageFile != null && imageFile.existsSync() ? imageFile : null;
    final sharedImageRef = widget.profile.profileImageBase64?.trim() ?? '';

    if (existingImageFile != null) {
      return FileImage(existingImageFile);
    }

    if (sharedImageRef.isEmpty) {
      return null;
    }

    if (FirebaseImageStorageService.isRemoteRef(sharedImageRef)) {
      return NetworkImage(sharedImageRef);
    }

    final sharedImageBytes = CommunityImageCodec.decode(sharedImageRef);
    if (sharedImageBytes != null) {
      return MemoryImage(sharedImageBytes);
    }

    return null;
  }

  InputDecoration _profileSheetInputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFFF7DE77),
        fontWeight: FontWeight.w900,
      ),
      filled: true,
      fillColor: const Color(0xFF0E2A5E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3F5C96)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3F5C96)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFF7DE77), width: 1.5),
      ),
    );
  }

  Future<void> _openProfileEditSheet() async {
    var selectedCurrencyCode = _selectedCurrencyCode;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        var saving = false;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final profileImageProvider = _profileImageProvider();

            Future<void> saveChanges() async {
              setSheetState(() {
                saving = true;
              });

              final nameSaved = await _saveName(showSnackBar: false);

              if (!nameSaved) {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    saving = false;
                  });
                }
                return;
              }

              final currencySaved = await _updateCurrency(
                selectedCurrencyCode,
                showSnackBar: false,
              );

              if (!currencySaved) {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    saving = false;
                  });
                }
                return;
              }

              if (!bottomSheetContext.mounted) return;
              Navigator.of(bottomSheetContext).pop();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile details updated')),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 4,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFFF7DE77),
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.profile.isBusinessAccount
                                  ? 'Edit business details'
                                  : 'Edit profile details',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.white12,
                              backgroundImage: profileImageProvider,
                              child: profileImageProvider == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 44,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7DE77),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF041B4A),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.black,
                                  size: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF7DE77),
                          side: const BorderSide(color: Color(0xFFF7DE77)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                await _pickImage();
                                if (sheetContext.mounted) {
                                  setSheetState(() {});
                                }
                              },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text(
                          'Change picture',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        enabled: !saving,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: const Color(0xFFF7DE77),
                        decoration: _profileSheetInputDecoration(
                          widget.profile.isBusinessAccount
                              ? 'Business name'
                              : 'Trainer name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        readOnly: true,
                        style: const TextStyle(color: Colors.white70),
                        decoration: _profileSheetInputDecoration('Email').copyWith(
                          hintText: widget.profile.email,
                          hintStyle: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCurrencyCode,
                        dropdownColor: const Color(0xFF102754),
                        iconEnabledColor: const Color(0xFFC8D4F0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _profileSheetInputDecoration(
                          'Display currency',
                        ),
                        items: CurrencySettings.supportedCurrencies.values
                            .map(
                              (currency) => DropdownMenuItem<String>(
                                value: currency.code,
                                child: Text(
                                  '${currency.code} • ${currency.label}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setSheetState(() {
                                  selectedCurrencyCode = value;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Card prices update across the app when you change this setting.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      if (_savingName || _savingCurrency || saving) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(
                          color: Color(0xFFF7DE77),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF7DE77),
                          foregroundColor: const Color(0xFF041B4A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: saving ? null : saveChanges,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          saving ? 'Saving...' : 'Save changes',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildAdminToolsCard() {
    return StreamBuilder<bool>(
      stream: _watchCurrentUserIsAdminOrModerator(),
      builder: (context, snapshot) {
        final canUseAdminTools = snapshot.data == true;

        if (!canUseAdminTools) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: RepaintBoundary(
            child: Card(
              color: const Color(0xFF102754),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.42),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFF7DE77).withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Color(0xFFF7DE77),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin tools',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Manage reports, Pro users, shop requests and business approvals.',
                                style: TextStyle(
                                  color: Color(0xFFC8D4F0),
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openAdminTools,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF7DE77),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.dashboard_customize_outlined),
                        label: const Text(
                          'Open Admin Tools',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileSettingsCard(ImageProvider? profileImageProvider) {
    final displayName = _nameController.text.trim().isEmpty
        ? widget.profile.displayName
        : _nameController.text.trim();

    return RepaintBoundary(
      child: Card(
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: _openProfileEditSheet,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white12,
                      backgroundImage: profileImageProvider,
                      child: profileImageProvider == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 50,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7DE77),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF041B4A),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.profile.isBusinessAccount
                    ? 'Tap the pencil to edit your business name, email, currency and profile picture.'
                    : 'Tap the pencil to edit your trainer name, email, currency and profile picture.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildFriendsCard() {
    return RepaintBoundary(
      child: Card(
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Friends & shared Pokédex',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open your friends list, review requests, and browse their synced Pokédex collections.',
                style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FriendRequestsPage(currentProfile: widget.profile),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Requests'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openFriends,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2C7A5B),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.collections_bookmark_outlined),
                      label: const Text('Friends'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openWishlistMatchCentre,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF7DE77),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Wishlist Match Centre'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistCard() {
    return RepaintBoundary(
      child: StreamBuilder<List<WishlistEntry>>(
        stream: WishlistService.wishlistStream(widget.profile.uid),
        builder: (context, snapshot) {
          final wishlistCount = (snapshot.data ?? const <WishlistEntry>[]).length;
          return Card(
            color: const Color(0xFF102754),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wishlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wishlistCount == 1
                        ? '1 card saved for later.'
                        : '$wishlistCount cards saved for later.',
                    style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openWishlist,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB13B59),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.favorite_outline_rounded),
                      label: const Text('Open Wishlist'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProUpgradeCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: ProStatusService.isProNotifier,
      builder: (context, isPro, _) {
        return RepaintBoundary(
          child: Card(
            color: const Color(0xFF102754),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isPro
                    ? const Color(0xFFF7DE77).withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: InkWell(
              onTap: _openProUpgrade,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF7DE77).withValues(alpha: 0.30),
                        ),
                      ),
                      child: Icon(
                        isPro
                            ? Icons.verified_rounded
                            : Icons.workspace_premium_outlined,
                        color: const Color(0xFFF7DE77),
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPro ? 'PocketChase Pro active' : 'Remove ads with Pro',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPro
                                ? 'Thanks for supporting PocketChase. Ads are hidden.'
                                : 'Upgrade once to remove banner ads from the app.',
                            style: const TextStyle(
                              color: Color(0xFFC8D4F0),
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBusinessDashboardCard() {
    return RepaintBoundary(
      child: Card(
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: const Color(0xFFF7DE77).withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: Color(0xFFF7DE77),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage your shop or business profile on PocketChase.',
                          style: TextStyle(
                            color: Color(0xFFC8D4F0),
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E2A5E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3F5C96)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFF7DE77),
                      size: 20,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'This is a business account, so personal collection sections such as cards, sets, wishlist, and achievements are hidden.',
                        style: TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openBusinessProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF7DE77),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.business_center_outlined),
                  label: const Text(
                    'Open Business Profile',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openFeaturedOnlineShops,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF7DE77),
                    side: const BorderSide(color: Color(0xFFF7DE77)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.language),
                  label: const Text(
                    'View Featured Online Shops',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessProInfoCard() {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: const Color(0xFFF7DE77).withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFF7DE77),
                  size: 28,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Business Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            const Text(
              'Business Pro features are controlled by admin toggles for now. Later this can connect to Apple and Google in-app purchases.',
              style: TextStyle(
                color: Color(0xFFC8D4F0),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildBusinessFeatureLine(
              icon: Icons.star_border_rounded,
              title: 'Featured shop on map',
            ),
            _buildBusinessFeatureLine(
              icon: Icons.campaign_outlined,
              title: 'Automatically featured business posts',
            ),
            _buildBusinessFeatureLine(
              icon: Icons.verified_outlined,
              title: 'Premium business badge',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessFeatureLine({
    required IconData icon,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFF7DE77),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSecurityCard() {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account & security',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Color(0xFF54D39A), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    FirebaseAuth.instance.currentUser?.emailVerified == true
                        ? 'Email verified: ${widget.profile.email}'
                        : 'Email not verified yet: ${widget.profile.email}',
                    style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Deleting your account removes your synced PocketChase data and cannot be undone.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deletingAccount ? null : _deleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB3C7),
                  side: const BorderSide(color: Color(0xFFB13B59)),
                ),
                icon: _deletingAccount
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(_deletingAccount ? 'Deleting account...' : 'Delete Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(ImageProvider? profileImageProvider) {
    return FutureBuilder<ProfileStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: const Color(0xFF102754),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Loading collection stats...',
                      style: TextStyle(
                        color: Color(0xFFD8E3FB),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: const Color(0xFF102754),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load profile stats: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final stats = snapshot.data ?? _emptyProfileStats();

        return Column(
          children: [
            ProfileShowcaseCard(
              profileName: widget.profile.displayName,
              imageProvider: profileImageProvider,
              stats: stats,
              onOpenCard: _openCardDetails,
            ),
            const SizedBox(height: 12),
            RarityValueDashboard(
              stats: stats,
              onOpenCard: _openCardDetails,
            ),
            const SizedBox(height: 12),
            AchievementBadges(stats: stats),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ProfileStatCard(
                    title: 'Total Cards',
                    value: '${stats.totalCards}',
                    icon: Icons.style_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ProfileStatCard(
                    title: 'Total Value',
                    value: CurrencySettings.formatSelectedAmount(stats.totalEstimatedPrice),
                    icon: Icons.payment_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MostExpensiveCardWidget(
              card: stats.mostExpensiveCard,
              copies: stats.mostExpensiveCardCopies,
              onOpenCard: _openCardDetails,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileImageProvider = _profileImageProvider();
    final bottomSafePadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        toolbarHeight: 68,
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        title: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.26),
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFFF7DE77),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded),
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshStats,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + bottomSafePadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileSettingsCard(profileImageProvider),
                          _buildAdminToolsCard(),
                          const SizedBox(height: 16),
                          if (widget.profile.isBusinessAccount) ...[
                            _buildBusinessDashboardCard(),
                            const SizedBox(height: 16),
                            _buildBusinessProInfoCard(),
                            const SizedBox(height: 16),
                            _buildAccountSecurityCard(),
                          ] else ...[
                            _buildFriendsCard(),
                            const SizedBox(height: 16),
                            _buildWishlistCard(),
                            const SizedBox(height: 16),
                            _buildProUpgradeCard(),
                            _buildAccountSecurityCard(),
                            const SizedBox(height: 16),
                            _buildStatsSection(profileImageProvider),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
