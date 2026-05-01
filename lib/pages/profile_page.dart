import 'dart:io';

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
import '../services/user_feature_flags_service.dart';
import '../services/user_profile_service.dart';
import '../services/wishlist_service.dart';
import '../utils/auth_input_decoration.dart';
import '../utils/profile_stats_helpers.dart';
import '../widgets/achievement_badges.dart';
import '../widgets/profile_collection_widgets.dart';
import '../widgets/profile_stat_card.dart';
import 'admin_tracked_restock_products_page.dart';
import 'admin_user_feature_flags_page.dart';
import 'card_details_page.dart';
import 'friend_requests_page.dart';
import 'friends_page.dart';
import 'restock_alerts_page.dart';
import 'wishlist_page.dart';
import 'wishlist_trade_match_centre_page.dart';

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
  bool _deletingAccount = false;
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
    _nameController.text = widget.profile.displayName;
    final imagePath = await LocalProfileImageStore.loadForUser(widget.profile.uid);

    if (mounted) {
      setState(() {
        _profileImagePath = imagePath;
        _selectedCurrencyCode = CurrencySettings.selectedCode;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _saveName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a trainer name')),
      );
      return;
    }

    setState(() {
      _savingName = true;
    });

    try {
      await UserProfileService.upsertProfile(user: user, username: newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update your name')),
        );
      }
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

  Future<void> _updateCurrency(String? value) async {
    if (value == null || value == _selectedCurrencyCode) return;

    setState(() {
      _savingCurrency = true;
    });

    try {
      await CurrencySettings.setSelectedCode(value);
      if (!mounted) return;

      setState(() {
        _selectedCurrencyCode = CurrencySettings.selectedCode;
        _statsFuture = _loadStats();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Currency changed to ${CurrencySettings.selectedCurrency.code}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your currency right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingCurrency = false;
        });
      }
    }
  }

  Future<ProfileStats> _loadStats() async {
    return loadProfileStatsForOwner(
      widget.profile.uid,
      preferCurrentUserLocalCache: true,
    );
  }

  Future<void> _refreshStats() async {
    setState(() {
      _statsFuture = _loadStats();
    });
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

  Future<void> _openRestockAlerts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RestockAlertsPage(),
      ),
    );
  }

  Future<void> _openUserFeatures() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminUserFeatureFlagsPage(),
      ),
    );
  }

  Future<void> _openTrackedRestockProducts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminTrackedRestockProductsPage(),
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

    setState(() {
      _deletingAccount = true;
    });

    try {
      await AccountDeletionService.deleteCurrentAccount(password: password);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Password was incorrect. Account not deleted.',
        'requires-recent-login' => 'Please sign out, sign back in, then try deleting your account again.',
        _ => e.message ?? 'Could not delete your account.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingAccount = false;
        });
      }
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
    final existingImageFile = imageFile != null && imageFile.existsSync() ? imageFile : null;
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

  @override
  void dispose() {
    collectionRefreshNotifier.removeListener(_handleCollectionRefresh);
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildProfileSettingsCard(ImageProvider? profileImageProvider) {
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
                onTap: _pickImage,
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
                          border: Border.all(color: const Color(0xFF041B4A), width: 2),
                        ),
                        child: const Icon(Icons.edit, color: Colors.black, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This picture will show beside your community posts and comments.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Trainer Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF0E2A5E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                readOnly: true,
                style: const TextStyle(color: Colors.white70),
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: widget.profile.email,
                  hintStyle: const TextStyle(color: Colors.white70),
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF0E2A5E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCurrencyCode,
                dropdownColor: const Color(0xFF102754),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Display Currency',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF0E2A5E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                onChanged: _savingCurrency ? null : _updateCurrency,
              ),
              const SizedBox(height: 8),
              const Text(
                'Card prices update across the app when you change this setting.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_savingCurrency) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose Picture'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _savingName ? null : _saveName,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_savingName ? 'Saving...' : 'Save Name'),
                    ),
                  ),
                ],
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

  Widget _buildFeatureAccessSection() {
    return StreamBuilder<bool>(
      stream: UserFeatureFlagsService.watchCurrentUserRestockAlertsEnabled(),
      builder: (context, restockSnapshot) {
        final restockAlertsEnabled = restockSnapshot.data == true;

        return StreamBuilder<bool>(
          stream: UserFeatureFlagsService.watchCurrentUserCanManageFeatureFlags(),
          builder: (context, managerSnapshot) {
            final canManageFeatures = managerSnapshot.data == true;

            if (!restockAlertsEnabled && !canManageFeatures) {
              return const SizedBox(height: 16);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                RepaintBoundary(
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
                            'Features',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Manage extra PocketChase tools and account features.',
                            style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
                          ),
                          if (restockAlertsEnabled)
                            _buildFeatureTile(
                              icon: Icons.notifications_active_outlined,
                              iconColor: const Color(0xFFF7DE77),
                              title: 'Restock Alerts',
                              subtitle: 'Choose shops and Pokémon products to watch',
                              onTap: _openRestockAlerts,
                            ),
                          if (canManageFeatures)
                            _buildFeatureTile(
                              icon: Icons.manage_search_outlined,
                              iconColor: const Color(0xFFF7DE77),
                              title: 'Tracked Products',
                              subtitle: 'Add shop pages for automatic checking',
                              onTap: _openTrackedRestockProducts,
                            ),
                          if (canManageFeatures)
                            _buildFeatureTile(
                              icon: Icons.admin_panel_settings_outlined,
                              iconColor: const Color(0xFF54D39A),
                              title: 'User Features',
                              subtitle: 'Turn Restock Alerts on or off for users',
                              onTap: _openUserFeatures,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: const Color(0xFF0E2A5E),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
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
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
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

        final stats = snapshot.data ?? const ProfileStats(
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
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
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
                          const SizedBox(height: 16),
                          _buildFriendsCard(),
                          const SizedBox(height: 16),
                          _buildWishlistCard(),
                          _buildFeatureAccessSection(),
                          _buildAccountSecurityCard(),
                          const SizedBox(height: 16),
                          _buildStatsSection(profileImageProvider),
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
