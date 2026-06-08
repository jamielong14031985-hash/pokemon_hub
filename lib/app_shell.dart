import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_user_profile.dart';
import 'models/business_profile.dart';
import 'pages/business_profile_editor_page.dart';
import 'pages/business_profile_page.dart';
import 'pages/card_scanner_page.dart';
import 'pages/card_search_page.dart';
import 'pages/community_page.dart';
import 'pages/master_sets_page.dart';
import 'pages/profile_page.dart';
import 'pages/pocketchase_onboarding_page.dart';
import 'pages/send_feedback_page.dart';
import 'pages/tcg_shop_map_page.dart';
import 'services/business_profile_service.dart';
import 'services/community_unread_private_message_service.dart';
import 'services/currency_settings.dart';
import 'services/custom_binder_sync_service.dart';
import 'services/friend_service.dart';
import 'services/pokedex_sync_service.dart';
import 'services/push_notification_service.dart';
import 'widgets/pocketchase_banner_ad.dart';
import 'widgets/profile_app_bar_button.dart';

const int _kCommunityMinimumAge = 18;

const int _kCardsIndex = 0;
const int _kScanIndex = 1;
const int _kMasterSetsIndex = 2;
const int _kMapIndex = 3;
const int _kCommunityIndex = 4;

const String _kCommunityForumDisclaimer =
    '''Disclaimer: PocketChase and the creators of this app are not responsible for any sales, swaps, trades, payments, deliveries, meetups, item condition, authenticity, losses, disputes, or damages arising from community posts or arrangements made between users. All transactions and interactions are carried out entirely at the users’ own risk.''';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = _kCardsIndex;
  bool _communityDisclaimerAccepted = false;
  bool _loadingCommunityDisclaimer = true;
  final GlobalKey<CardSearchPageState> _cardSearchKey =
      GlobalKey<CardSearchPageState>();
  final GlobalKey<MasterSetsPageState> _masterSetsKey =
      GlobalKey<MasterSetsPageState>();
  final BusinessProfileService _businessProfileService =
      BusinessProfileService();

  @override
  void initState() {
    super.initState();
    _loadCommunityDisclaimerAcceptance();
    PushNotificationService.initialiseForCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PokedexSyncService.ensureCurrentUserPokedexReady();
      CustomBinderSyncService.ensureCurrentUserBindersReady();
      _showOnboardingIfNeeded();
    });
  }

  String _onboardingPrefsKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;
    return 'pocketchase_onboarding_seen_$uid';
  }

  Future<void> _showOnboardingIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _onboardingPrefsKey();

    if (prefs.getBool(key) == true || !mounted) return;

    // Give the main shell a moment to finish opening before showing the
    // first-time app guide. The guide is shown once per signed-in account.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const PocketChaseOnboardingPage(),
      ),
    );

    await prefs.setBool(key, true);
  }

  Future<void> _openOnboarding() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const PocketChaseOnboardingPage(),
      ),
    );
  }

  Future<void> _openFeedback(AppUserProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SendFeedbackPage(profile: profile),
      ),
    );
  }

  String _communityDisclaimerPrefsKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;
    return 'community_forum_disclaimer_accepted_$uid';
  }

  Future<void> _loadCommunityDisclaimerAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_communityDisclaimerPrefsKey()) ?? false;
    if (!mounted) return;
    setState(() {
      _communityDisclaimerAccepted = accepted;
      _loadingCommunityDisclaimer = false;
    });
  }

  Future<void> _saveCommunityDisclaimerAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityDisclaimerPrefsKey(), true);
    if (!mounted) return;
    setState(() {
      _communityDisclaimerAccepted = true;
    });
  }

  Future<bool> _ensureCommunityDisclaimerAccepted() async {
    if (_communityDisclaimerAccepted) return true;
    final accepted = await showModalBottomSheet<bool>(
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
                  'Community Disclaimer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16366E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3F5C96)),
                  ),
                  child: const Text(
                    _kCommunityForumDisclaimer,
                    style: TextStyle(
                      color: Color(0xFFE4ECFF),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You must accept this before entering the community page.',
                  style: TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF3F5C96)),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('I Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (accepted == true) {
      await _saveCommunityDisclaimerAcceptance();
      return true;
    }
    return false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _applyDestinationSelected(int index) {
    final wasOnCards = _currentIndex == _kCardsIndex;

    setState(() {
      _currentIndex = index;
    });

    if (index == _kCardsIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cardSearchKey.currentState?.scrollToTop(animated: wasOnCards);
      });
    }

    if (index == _kMasterSetsIndex) {
      _masterSetsKey.currentState?.refreshSets();
    }
  }

  Future<void> _onDestinationSelected(int index) async {
    HapticFeedback.lightImpact();

    if (index == _kCommunityIndex) {
      if (!widget.profile.hasDateOfBirth) {
        _showMessage('Please complete your profile with your date of birth first.');
        return;
      }

      if (!widget.profile.isAdult) {
        _showMessage(
          'Community is only available to users aged $_kCommunityMinimumAge or over.',
        );
        return;
      }

      if (_loadingCommunityDisclaimer) {
        await _loadCommunityDisclaimerAcceptance();
      }
      final accepted = await _ensureCommunityDisclaimerAccepted();
      if (!accepted) return;
    }

    _applyDestinationSelected(index);
  }

  String get _appBarTitle {
    switch (_currentIndex) {
      case _kScanIndex:
        return 'Scan Card';
      case _kMasterSetsIndex:
        return 'Master Sets';
      case _kMapIndex:
        return 'TCG Shop Map';
      case _kCommunityIndex:
        return 'Community';
      case _kCardsIndex:
      default:
        return 'PocketChase';
    }
  }

  String get _appBarSubtitle {
    switch (_currentIndex) {
      case _kScanIndex:
        return 'Scan and identify your cards';
      case _kMasterSetsIndex:
        return 'Track and manage your sets';
      case _kMapIndex:
        return 'Find local TCG shops and submit new ones';
      case _kCommunityIndex:
        return 'Chat, swap, sell and trade safely';
      case _kCardsIndex:
      default:
        return 'Search cards, sets and collection numbers';
    }
  }

  IconData get _appBarIcon {
    switch (_currentIndex) {
      case _kScanIndex:
        return Icons.document_scanner_outlined;
      case _kMasterSetsIndex:
        return Icons.collections_bookmark_outlined;
      case _kMapIndex:
        return Icons.map_outlined;
      case _kCommunityIndex:
        return Icons.forum_outlined;
      case _kCardsIndex:
      default:
        return Icons.style_outlined;
    }
  }

  AppUserProfile _effectiveProfileForBusiness(BusinessProfile? businessProfile) {
    if (!widget.profile.isBusinessAccount || businessProfile == null) {
      return widget.profile;
    }

    final businessName = businessProfile.businessName.trim();
    final businessLogoUrl = businessProfile.logoUrl.trim();

    return AppUserProfile(
      uid: widget.profile.uid,
      email: widget.profile.email,
      username: businessName.isEmpty ? widget.profile.username : businessName,
      createdAtMs: widget.profile.createdAtMs,
      updatedAtMs: widget.profile.updatedAtMs,
      accountType: widget.profile.accountType,
      businessProfileCreated: widget.profile.businessProfileCreated,
      dateOfBirthMs: widget.profile.dateOfBirthMs,
      profileImageBase64: businessLogoUrl.isNotEmpty
          ? businessLogoUrl
          : widget.profile.profileImageBase64,
    );
  }

  Widget _buildCurrentPage({AppUserProfile? effectiveProfile}) {
    switch (_currentIndex) {
      case _kScanIndex:
        return const CardScannerPage(showAppBar: false);
      case _kMasterSetsIndex:
        return MasterSetsPage(key: _masterSetsKey);
      case _kMapIndex:
        return const TcgShopMapPage();
      case _kCommunityIndex:
        return CommunityPage(profile: effectiveProfile ?? widget.profile);
      case _kCardsIndex:
      default:
        return CardSearchPage(key: _cardSearchKey);
    }
  }

  BoxDecoration _glassHeaderDecoration({double goldGlowAlpha = 0.08}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.07),
          const Color(0xFF173A78).withValues(alpha: 0.20),
        ],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.18),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFFF7DE77).withValues(alpha: goldGlowAlpha),
          blurRadius: 24,
          spreadRadius: 1,
        ),
      ],
    );
  }

  Widget _buildGlassAppBarTitle({AppUserProfile? effectiveProfile}) {
    final appBarProfile = effectiveProfile ?? widget.profile;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _glassHeaderDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
              border: Border.all(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              _appBarIcon,
              color: const Color(0xFFF7DE77),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Column(
                key: ValueKey<String>(_appBarTitle),
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _appBarTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _appBarSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC8D4F0),
                      fontSize: 11.5,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Help and feedback',
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white70,
            ),
            color: const Color(0xFF102754),
            onSelected: (value) {
              if (value == 'feedback') {
                _openFeedback(appBarProfile);
              } else if (value == 'guide') {
                _openOnboarding();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'feedback',
                child: Row(
                  children: [
                    Icon(Icons.feedback_outlined, color: Color(0xFFF7DE77)),
                    SizedBox(width: 10),
                    Text(
                      'Report a problem',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'guide',
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: Color(0xFFF7DE77)),
                    SizedBox(width: 10),
                    Text(
                      'App guide',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          ProfileAppBarButton(
            profile: appBarProfile,
            onOpenProfile: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) {
                    if (widget.profile.isBusinessAccount) {
                      return const BusinessProfilePage();
                    }

                    return ProfilePage(profile: appBarProfile);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityNavIcon({
    required bool selected,
    required bool hasUnreadPrivateMessages,
    required bool hasPendingFriendRequests,
  }) {
    final hasCommunityAlert = hasUnreadPrivateMessages || hasPendingFriendRequests;
    final icon = Icon(selected ? Icons.forum : Icons.forum_outlined);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasCommunityAlert
            ? const Color(0xFFF7DE77).withValues(alpha: selected ? 0.24 : 0.16)
            : Colors.transparent,
        boxShadow: hasCommunityAlert
            ? [
                BoxShadow(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.80),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          if (hasCommunityAlert)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7DE77),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF041B4A), width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  NavigationBar _buildNavigationBar({
    required bool hasUnreadPrivateMessages,
    required bool hasPendingFriendRequests,
  }) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onDestinationSelected,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.style_outlined),
          selectedIcon: Icon(Icons.style),
          label: 'Cards',
        ),
        const NavigationDestination(
          icon: Icon(Icons.document_scanner_outlined),
          selectedIcon: Icon(Icons.document_scanner),
          label: 'Scan',
        ),
        const NavigationDestination(
          icon: Icon(Icons.collections_bookmark_outlined),
          selectedIcon: Icon(Icons.collections_bookmark),
          label: 'Master Sets',
        ),
        const NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Map',
        ),
        NavigationDestination(
          icon: _buildCommunityNavIcon(
            selected: false,
            hasUnreadPrivateMessages: hasUnreadPrivateMessages,
            hasPendingFriendRequests: hasPendingFriendRequests,
          ),
          selectedIcon: _buildCommunityNavIcon(
            selected: true,
            hasUnreadPrivateMessages: hasUnreadPrivateMessages,
            hasPendingFriendRequests: hasPendingFriendRequests,
          ),
          label: (hasUnreadPrivateMessages || hasPendingFriendRequests)
              ? 'Community • New'
              : 'Community',
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    final currentUid =
        (FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid).trim();

    return ValueListenableBuilder<int>(
      valueListenable:
          CommunityUnreadPrivateMessageService.privateInboxSeenVersion,
      builder: (context, _, __) {
        if (currentUid.isEmpty) {
          return _buildNavigationBar(
            hasUnreadPrivateMessages: false,
            hasPendingFriendRequests: false,
          );
        }

        return StreamBuilder<bool>(
          stream: CommunityUnreadPrivateMessageService
              .hasUnreadPrivateMessagesStream(currentUid),
          builder: (context, privateSnapshot) {
            return StreamBuilder(
              stream: FriendService.incomingRequestsStream(currentUid),
              builder: (context, friendSnapshot) {
                final incomingRequests = friendSnapshot.data ?? const [];
                return _buildNavigationBar(
                  hasUnreadPrivateMessages: privateSnapshot.data == true,
                  hasPendingFriendRequests: incomingRequests.isNotEmpty,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMainAppShell({BusinessProfile? businessProfile}) {
    final effectiveProfile = _effectiveProfileForBusiness(businessProfile);

    return Scaffold(
      appBar: _currentIndex == _kMapIndex
          ? null
          : AppBar(
              titleSpacing: 12,
              toolbarHeight: 86,
              title: _buildGlassAppBarTitle(effectiveProfile: effectiveProfile),
              backgroundColor: const Color(0xFF041B4A),
              foregroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
      body: ValueListenableBuilder<int>(
        valueListenable: currencyRefreshNotifier,
        builder: (context, _, __) {
          return Column(
            children: [
              Expanded(child: _buildCurrentPage(effectiveProfile: effectiveProfile)),
              if (_currentIndex != _kScanIndex) const PocketChaseBannerAd(),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBusinessSetupGate(BusinessProfile? businessProfile) {
    final missingItems = businessProfile?.setupMissingReasons ??
        const <String>[
          'Business name',
          'Business description',
          'Website',
          'Phone number',
          'Town',
          'County',
          'Shop type',
        ];

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Complete Business Setup'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF102754),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF7DE77)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    color: Color(0xFFF7DE77),
                    size: 42,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Finish your business profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Business accounts must complete all required details before using the rest of PocketChase. Physical shops must be linked to the TCG Shop Map.',
                    style: TextStyle(
                      color: Color(0xFFC8D4F0),
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF102754),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3F5C96)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Still needed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...missingItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radio_button_unchecked,
                            color: Color(0xFFF7DE77),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: Color(0xFFC8D4F0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF7DE77),
                foregroundColor: const Color(0xFF041B4A),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text(
                'Complete business profile',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BusinessProfileEditorPage(
                      profile: businessProfile,
                      forceCompleteSetup: true,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessSetupAwareShell() {
    if (!widget.profile.isBusinessAccount) {
      return _buildMainAppShell();
    }

    return StreamBuilder<BusinessProfile?>(
      stream: _businessProfileService.watchCurrentBusinessSetupProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xFF041B4A),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFF7DE77)),
            ),
          );
        }

        final businessProfile = snapshot.data;

        if (businessProfile == null || !businessProfile.setupIsComplete) {
          return _buildBusinessSetupGate(businessProfile);
        }

        return _buildMainAppShell(businessProfile: businessProfile);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBusinessSetupAwareShell();
  }
}
