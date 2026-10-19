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
import '../services/local_pokedex_store.dart';
import '../services/pro_status_service.dart';
import '../services/user_profile_service.dart';
import '../services/wishlist_service.dart';
import '../utils/auth_input_decoration.dart';
import '../utils/profile_stats_helpers.dart';
import '../widgets/achievement_badges.dart';
import '../widgets/profile_collection_widgets.dart';
import 'business_profile_page.dart';
import 'card_details_page.dart';
import 'card_scanner_page.dart';
import 'collection_data_page.dart';
import 'featured_online_shops_page.dart';
import 'friend_requests_page.dart';
import 'friends_page.dart';
import 'master_sets_page.dart';
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
  bool _refreshingCollectionPrices = false;
  final bool _deletingAccount = false;
  String _selectedCurrencyCode = CurrencySettings.selectedCode;
  late Future<ProfileStats> _statsFuture;
  late Future<List<WishlistEntry>> _wishlistFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
    _wishlistFuture = WishlistService.fetchWishlist(widget.profile.uid);
    _loadProfile();
    collectionRefreshNotifier.addListener(_handleCollectionRefresh);
  }

  void _handleCollectionRefresh() {
    if (!mounted) return;
    _refreshStats();
  }

  Future<void> _loadProfile() async {
    _nameController.text = widget.profile.username.trim();

    final preferredCurrencyCode = widget.profile.preferredCurrencyCode.trim();
    if (preferredCurrencyCode.isNotEmpty) {
      await CurrencySettings.setPreferredCurrencyAndMarketplace(
        currencyCode: preferredCurrencyCode,
        marketplaceCode: widget.profile.preferredMarketplaceCode,
      );
    }

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
      final preferenceData = CurrencySettings.preferenceDataForCurrency(value);

      await CurrencySettings.setPreferredCurrencyAndMarketplace(
        currencyCode: value,
        marketplaceCode: preferenceData['preferredMarketplaceCode']?.toString(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'preferredCurrencyCode': preferenceData['preferredCurrencyCode'],
          'preferredMarketplaceCode': preferenceData['preferredMarketplaceCode'],
          'updatedAtMs': now,
        }, SetOptions(merge: true));

        if (widget.profile.isBusinessAccount) {
          final businessSnapshot = await FirebaseFirestore.instance
              .collection('business_profiles')
              .where('ownerUid', isEqualTo: user.uid)
              .limit(1)
              .get();

          if (businessSnapshot.docs.isNotEmpty) {
            await businessSnapshot.docs.first.reference.set({
              'preferredCurrencyCode': preferenceData['preferredCurrencyCode'],
              'preferredMarketplaceCode': preferenceData['preferredMarketplaceCode'],
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }

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
      ).timeout(const Duration(minutes: 3));
    } catch (_) {
      // Price enrichment can take longer for a large collection or when the
      // card API is slow. Never replace a real local collection with zeroes.
      try {
        final localCopies = normalPokedexCardCopiesOnly(
          await LocalPokedexStore.loadAllCardCopies(),
        );
        return basicProfileStatsFromCopies(localCopies);
      } catch (_) {
        return _emptyProfileStats();
      }
    }
  }

  Future<void> _refreshStats() async {
    setState(() {
      _statsFuture = _loadStats();
      _wishlistFuture = WishlistService.fetchWishlist(widget.profile.uid);
    });
  }

  Future<void> _refreshCollectionPrices() async {
    if (_refreshingCollectionPrices) return;
    setState(() {
      _refreshingCollectionPrices = true;
    });

    try {
      final result = await refreshMissingCollectionPrices(limit: 20);
      if (!mounted) return;
      await _refreshStats();
      if (!mounted) return;
      final message = result.attempted == 0
          ? 'No missing card prices to check.'
          : result.priced == 0
              ? 'No new prices were available. Try again later.'
              : 'Added ${result.priced} new price${result.priced == 1 ? '' : 's'}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshingCollectionPrices = false;
        });
      }
    }
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

  Future<void> _openCollectionData() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CollectionDataPage()),
    );
    if (mounted) await _refreshStats();
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
    if (mounted) {
      setState(() {
        _wishlistFuture = WishlistService.fetchWishlist(widget.profile.uid);
      });
    }
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

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CardScannerPage()),
    );
    if (mounted) await _refreshStats();
  }

  Future<void> _openSets() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF041B4A),
          appBar: AppBar(
            title: const Text('Sets'),
            backgroundColor: const Color(0xFF041B4A),
            foregroundColor: Colors.white,
          ),
          body: const SafeArea(
            top: false,
            child: MasterSetsPage(),
          ),
        ),
      ),
    );
    if (mounted) await _refreshStats();
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
                        'Raw card prices update across the app. Graded card searches use the matching eBay region.',
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
        if (snapshot.data != true) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: RepaintBoundary(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: const Color(0xFF102754),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.32),
                ),
              ),
              child: InkWell(
                onTap: _openAdminTools,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Color(0xFFF7DE77),
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin tools',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Reports, users and shop approvals',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFB9CBE9),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 26,
                        color: Color(0xFFF7DE77),
                      ),
                    ],
                  ),
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
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: const Color(0xFF4389C8).withValues(alpha: 0.46),
          ),
        ),
        child: InkWell(
          onTap: _openProfileEditSheet,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFF1B4276),
                      backgroundImage: profileImageProvider,
                      child: profileImageProvider == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Color(0xFFF7DE77),
                              size: 38,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: -1,
                      right: -2,
                      child: Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7DE77),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF102754),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Color(0xFF071E48),
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.profile.isBusinessAccount
                            ? 'Edit business profile'
                            : 'Edit trainer profile',
                        style: const TextStyle(
                          color: Color(0xFFF7DE77),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFADC5E8),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsCard() {
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.people_alt_outlined,
                    color: Color(0xFFF7DE77),
                    size: 21,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Friends & shared Pokédex',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FriendRequestsPage(
                              currentProfile: widget.profile,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      label: const Text('Requests'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE6EEFF),
                        side: const BorderSide(color: Color(0xFF436A9E)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openFriends,
                      icon: const Icon(Icons.people_outline_rounded, size: 18),
                      label: const Text('Friends'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF247858),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _openWishlistMatchCentre,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                  label: const Text('Duplicate & Trade Matches'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF7DE77),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionDataCard() {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: _openCollectionData,
        borderRadius: BorderRadius.circular(24),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0x2EF7DE77),
                child: Icon(Icons.cloud_done_outlined, color: Color(0xFFF7DE77)),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Import, export & backups', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('Protect or move your card collection.', style: TextStyle(color: Color(0xFFB9C9E8))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
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
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        collapsedIconColor: const Color(0xFFACC1E2),
        iconColor: const Color(0xFFF7DE77),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(
          Icons.shield_outlined,
          color: Color(0xFFF7DE77),
        ),
        title: const Text(
          'Account & security',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: const Text(
          'Verification and account controls',
          style: TextStyle(
            color: Color(0xFFACC1E2),
            fontSize: 11.5,
          ),
        ),
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF54D39A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  FirebaseAuth.instance.currentUser?.emailVerified == true
                      ? 'Email verified: ${widget.profile.email}'
                      : 'Email not verified yet: ${widget.profile.email}',
                  style: const TextStyle(
                    color: Color(0xFFD8E3FB),
                    height: 1.35,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Deleting your account permanently removes your synced PocketChase data.',
            style: TextStyle(
              color: Color(0xFFB7C8E5),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
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
              label: Text(
                _deletingAccount ? 'Deleting account...' : 'Delete Account',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Lightweight collector overview. The detailed dashboards remain available
  // below, but are no longer repeated in several large cards on the main view.
  Widget _collectionStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B396B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFFF7DE77)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB7C9E6),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectionShortcut({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF7DE77),
          side: const BorderSide(color: Color(0xFF456799)),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionSnapshot(ProfileStats stats) {
    final featuredCard = stats.mostExpensiveCard;
    final imageUrl = featuredCard?.imageUrl?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF315581)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 22, color: Color(0xFFF7DE77)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Collection at a glance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _collectionStat(
                  icon: Icons.style_rounded,
                  label: 'Total cards',
                  value: '${stats.totalCards}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _collectionStat(
                  icon: Icons.collections_bookmark_outlined,
                  label: 'Unique cards',
                  value: '${stats.uniqueCards}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _collectionStat(
                  icon: Icons.copy_all_rounded,
                  label: 'Duplicates',
                  value: '${stats.duplicateCards}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _collectionStat(
                  icon: Icons.trending_up_rounded,
                  label: 'Indicative value',
                  value: CurrencySettings.formatSelectedAmount(
                    stats.totalEstimatedPrice,
                  ),
                ),
              ),
            ],
          ),
          if (stats.uniqueCards > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${stats.pricedUniqueCards}/${stats.uniqueCards} unique cards priced',
              style: const TextStyle(
                color: Color(0xFFB8CBE7),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
          if (featuredCard != null) ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFF1A3664),
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                onTap: () => _openCardDetails(featuredCard),
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: SizedBox(
                          width: 38,
                          height: 53,
                          child: imageUrl.isEmpty
                              ? const Icon(
                                  Icons.style_rounded,
                                  color: Color(0xFFF7DE77),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.style_rounded,
                                    color: Color(0xFFF7DE77),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Most valuable card',
                              style: TextStyle(
                                color: Color(0xFFF7DE77),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              featuredCard.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              featuredCard.setName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFBCCCE6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFF7DE77),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 11),
          Row(
            children: [
              _collectionShortcut(
                icon: Icons.document_scanner_outlined,
                label: 'Scan',
                onTap: _openScanner,
              ),
              const SizedBox(width: 7),
              _collectionShortcut(
                icon: Icons.collections_bookmark_outlined,
                label: 'Sets',
                onTap: _openSets,
              ),
              const SizedBox(width: 7),
              _collectionShortcut(
                icon: Icons.favorite_border_rounded,
                label: 'Wishlist',
                onTap: _openWishlist,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _collectionDetailsPanel({
    required String keyName,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFF102754),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Use a normal identity key here. PageStorageKey persists a bool
          // (ExpansionTile's expanded state); nested non-scrolling GridViews
          // may attempt to read that stored bool as a double scroll offset.
          // ValueKey keeps each panel's identity without sharing that state.
          key: ValueKey<String>('profile_$keyName'),
          maintainState: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(9, 0, 9, 10),
          iconColor: const Color(0xFFF7DE77),
          collapsedIconColor: const Color(0xFFA8C2E8),
          leading: Icon(icon, size: 23, color: const Color(0xFFF7DE77)),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFB8CBE7),
              fontSize: 11.5,
            ),
          ),
          children: [child],
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
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading your collection...',
                    style: TextStyle(color: Color(0xFFD8E3FB)),
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
            _buildCollectionSnapshot(stats),
            const SizedBox(height: 9),
            _collectionDetailsPanel(
              keyName: 'showcase',
              title: 'Collector showcase',
              subtitle: 'Featured card and favourite set',
              icon: Icons.auto_awesome_outlined,
              child: ProfileShowcaseCard(
                profileName: widget.profile.displayName,
                imageProvider: profileImageProvider,
                stats: stats,
                onOpenCard: _openCardDetails,
              ),
            ),
            const SizedBox(height: 9),
            _collectionDetailsPanel(
              keyName: 'overview',
              title: 'Collection breakdown',
              subtitle: 'Sets, wishlist and pricing coverage',
              icon: Icons.dashboard_outlined,
              // A stable one-time load avoids the single-subscription stream
              // listener error seen when opening and closing this panel.
              // Pull-to-refresh and returning from Wishlist reload the data.
              child: FutureBuilder<List<WishlistEntry>>(
                future: _wishlistFuture,
                builder: (context, wishlistSnapshot) {
                  return CollectionOverviewDashboard(
                    stats: stats,
                    wishlist: wishlistSnapshot.data ?? const <WishlistEntry>[],
                    onOpenScanner: _openScanner,
                    onOpenSets: _openSets,
                    onOpenWishlist: _openWishlist,
                  );
                },
              ),
            ),
            const SizedBox(height: 9),
            _collectionDetailsPanel(
              keyName: 'rarity',
              title: 'Prices & rarity analysis',
              subtitle: 'Rarity values, price sources and top cards',
              icon: Icons.insights_outlined,
              child: RarityValueDashboard(
                stats: stats,
                onOpenCard: _openCardDetails,
                onRefreshPrices: _refreshCollectionPrices,
                refreshingPrices: _refreshingCollectionPrices,
              ),
            ),
            const SizedBox(height: 9),
            _collectionDetailsPanel(
              keyName: 'achievements',
              title: 'Achievement badges',
              subtitle: 'Show, hide or browse your badges',
              icon: Icons.workspace_premium_outlined,
              child: AchievementBadges(stats: stats),
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
        toolbarHeight: 76,
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        title: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.07),
                const Color(0xFF173A78).withValues(alpha: 0.20),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
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
                    padding: EdgeInsets.fromLTRB(12, 10, 12, 20 + bottomSafePadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileSettingsCard(profileImageProvider),
                          _buildAdminToolsCard(),
                          const SizedBox(height: 10),
                          if (widget.profile.isBusinessAccount) ...[
                            _buildBusinessDashboardCard(),
                            const SizedBox(height: 10),
                            _buildBusinessProInfoCard(),
                            const SizedBox(height: 10),
                            _buildAccountSecurityCard(),
                          ] else ...[
                            _buildStatsSection(profileImageProvider),
                            const SizedBox(height: 10),
                            _buildFriendsCard(),
                            const SizedBox(height: 10),
                            _buildCollectionDataCard(),
                            const SizedBox(height: 10),
                            _buildProUpgradeCard(),
                            const SizedBox(height: 10),
                            _buildAccountSecurityCard(),
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
