import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_user_profile.dart';
import 'pages/card_scanner_page.dart';
import 'pages/card_search_page.dart';
import 'pages/community_page.dart';
import 'pages/master_sets_page.dart';
import 'pages/profile_page.dart';
import 'services/currency_settings.dart';
import 'services/custom_binder_sync_service.dart';
import 'services/pokedex_sync_service.dart';
import 'widgets/profile_app_bar_button.dart';

const int _kCommunityMinimumAge = 18;

const String _kCommunityForumDisclaimer = '''Disclaimer: PocketChase and the creators of this app are not responsible for any sales, swaps, trades, payments, deliveries, meetups, item condition, authenticity, losses, disputes, or damages arising from community posts or arrangements made between users. All transactions and interactions are carried out entirely at the users’ own risk.''';


class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _communityDisclaimerAccepted = false;
  bool _loadingCommunityDisclaimer = true;
  final GlobalKey<CardSearchPageState> _cardSearchKey = GlobalKey<CardSearchPageState>();
  final GlobalKey<MasterSetsPageState> _masterSetsKey = GlobalKey<MasterSetsPageState>();

  @override
  void initState() {
    super.initState();
    _loadCommunityDisclaimerAcceptance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PokedexSyncService.ensureCurrentUserPokedexReady();
      CustomBinderSyncService.ensureCurrentUserBindersReady();
    });
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
    final wasOnCards = _currentIndex == 0;

    setState(() {
      _currentIndex = index;
    });

    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cardSearchKey.currentState?.scrollToTop(animated: wasOnCards);
      });
    }

    if (index == 2) {
      _masterSetsKey.currentState?.refreshSets();
    }
  }

  Future<void> _onDestinationSelected(int index) async {
    HapticFeedback.lightImpact();

    if (index == 3) {
      if (!widget.profile.hasDateOfBirth) {
        _showMessage('Please complete your profile with your date of birth first.');
        return;
      }

      if (!widget.profile.isAdult) {
        _showMessage('Community is only available to users aged $_kCommunityMinimumAge or over.');
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
      case 1:
        return 'Scan Card';
      case 2:
        return 'Master Sets';
      case 3:
        return 'Community';
      case 0:
      default:
        return 'PocketChase';
    }
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 1:
        return const CardScannerPage(showAppBar: false);
      case 2:
        return MasterSetsPage(key: _masterSetsKey);
      case 3:
        return CommunityPage(profile: widget.profile);
      case 0:
      default:
        return CardSearchPage(key: _cardSearchKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        actions: [
          ProfileAppBarButton(
            profile: widget.profile,
            onOpenProfile: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProfilePage(profile: widget.profile)),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: currencyRefreshNotifier,
        builder: (context, _, __) => _buildCurrentPage(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
          icon: Icon(Icons.style_outlined),
          selectedIcon: Icon(Icons.style),
          label: 'Cards',
        ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Master Sets',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}
