import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import '../widgets/business_rating_summary.dart';
import 'business_reviews_page.dart';
import 'public_business_profile_page.dart';

const Color _onlineBackgroundColor = Color(0xFF041B4A);
const Color _onlineCardColor = Color(0xFF102754);
const Color _onlineFieldColor = Color(0xFF16366E);
const Color _onlineBorderColor = Color(0xFF3F5C96);
const Color _onlineGoldColor = Color(0xFFF7DE77);
const Color _onlineSoftTextColor = Color(0xFFC8D4F0);
const Color _onlineSuccessColor = Color(0xFF4ADE80);

class OnlineShopsPage extends StatefulWidget {
  const OnlineShopsPage({super.key});

  @override
  State<OnlineShopsPage> createState() => _OnlineShopsPageState();
}

class _OnlineShopsPageState extends State<OnlineShopsPage> {
  final BusinessProfileService _businessProfileService =
      BusinessProfileService();
  final TextEditingController _searchController = TextEditingController();

  String _searchTextForProfile(BusinessProfile profile) {
    return [
      profile.businessName,
      profile.description,
      profile.website,
      profile.phone,
      profile.town,
      profile.county,
      profile.status,
    ].join(' ').toLowerCase();
  }

  List<BusinessProfile> _filterProfiles(List<BusinessProfile> profiles) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return profiles;

    return profiles.where((profile) {
      return _searchTextForProfile(profile).contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      labelText: 'Search online shops',
      hintText: 'Search by shop name, website, town or county',
      labelStyle: const TextStyle(color: _onlineSoftTextColor),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _onlineGoldColor,
        fontWeight: FontWeight.w900,
      ),
      prefixIcon: const Icon(Icons.search, color: _onlineSoftTextColor),
      suffixIcon: _searchController.text.trim().isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.clear, color: _onlineSoftTextColor),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            ),
      filled: true,
      fillColor: _onlineFieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _onlineBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _onlineBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _onlineGoldColor, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _onlineBackgroundColor,
      appBar: AppBar(
        title: const Text('Online Shops'),
        backgroundColor: _onlineBackgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BusinessProfile>>(
        stream: _businessProfileService.watchOnlineBusinessProfiles(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _onlineGoldColor),
            );
          }

          final allProfiles = snapshot.data ?? const <BusinessProfile>[];
          final profiles = _filterProfiles(allProfiles);
          final query = _searchController.text.trim();

          if (allProfiles.isEmpty) {
            return const _EmptyState();
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _buildSearchBox(),
                      _buildIntroCard(
                        totalCount: allProfiles.length,
                        filteredCount: profiles.length,
                        query: query,
                      ),
                      if (profiles.isEmpty) const _NoSearchResultsState(),
                    ],
                  ),
                ),
              ),
              if (profiles.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == profiles.length - 1 ? 0 : 14,
                        ),
                        child: _OnlineShopCard(
                          profile: profiles[index],
                        ),
                      ),
                      childCount: profiles.length,
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: _onlineGoldColor,
        decoration: _searchDecoration(),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildIntroCard({
    required int totalCount,
    required int filteredCount,
    required String query,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _onlineCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _onlineBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.language, color: _onlineGoldColor, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              query.isEmpty
                  ? '$totalCount online shop${totalCount == 1 ? '' : 's'} available.'
                  : '$filteredCount result${filteredCount == 1 ? '' : 's'} for "$query".',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineShopCard extends StatelessWidget {
  const _OnlineShopCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final website = profile.website.trim();
    final location = profile.displayLocation;
    final title = profile.businessName.trim().isEmpty
        ? 'Online TCG Shop'
        : profile.businessName.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openPublicProfile(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _onlineCardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: profile.premiumIsActive
                  ? _onlineGoldColor
                  : _onlineBorderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SizedBox(
            height: 154,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 104,
                  height: 154,
                  child: _OnlineShopBanner(profile: profile),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (profile.premiumIsActive)
                          const _SmallBadge(
                            icon: Icons.workspace_premium,
                            label: 'Pro',
                            highlighted: true,
                          ),
                        if (profile.hasAnyOpeningHours)
                          _OnlineOpenStatusBadge(profile: profile),
                      ],
                    ),
                    const SizedBox(height: 7),
                    BusinessRatingSummary(
                      businessId: profile.id,
                      starColor: _onlineGoldColor,
                      textColor: Colors.white,
                      mutedTextColor: _onlineSoftTextColor,
                      onTap: () => _openReviews(context),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            color: _onlineGoldColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _onlineSoftTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _onlineGoldColor,
                                foregroundColor: _onlineBackgroundColor,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _openPublicProfile(context),
                              child: const Text(
                                'Profile',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (website.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _onlineGoldColor,
                                  side: const BorderSide(color: _onlineGoldColor),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _openWebsite(context, website),
                                child: const Text(
                                  'Website',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPublicProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicBusinessProfilePage(profile: profile),
      ),
    );
  }

  void _openReviews(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessReviewsPage(profile: profile),
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context, String website) async {
    final cleanWebsite = website.trim();
    if (cleanWebsite.isEmpty) return;

    final url =
        cleanWebsite.startsWith('http://') || cleanWebsite.startsWith('https://')
            ? cleanWebsite
            : 'https://$cleanWebsite';

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this website.')),
      );
      return;
    }

    await BusinessProfileService().incrementBusinessAnalyticsMetric(
      businessId: profile.id,
      metric: 'websiteClicks',
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this website.')),
      );
    }
  }
}

class _OnlineShopBanner extends StatelessWidget {
  const _OnlineShopBanner({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = profile.bannerUrl.trim();
    final logoUrl = profile.logoUrl.trim();
    final imageUrl = bannerUrl.isNotEmpty ? bannerUrl : logoUrl;

    if (imageUrl.isEmpty) {
      return _BannerFallback(profile: profile);
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _BannerFallback(profile: profile);
      },
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _onlineFieldColor,
      alignment: Alignment.center,
      child: Icon(
        profile.premiumIsActive ? Icons.workspace_premium : Icons.language,
        color: _onlineGoldColor,
        size: 36,
      ),
    );
  }
}

class _OnlineOpenStatusBadge extends StatelessWidget {
  const _OnlineOpenStatusBadge({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    if (!profile.hasAnyOpeningHours) {
      return const SizedBox.shrink();
    }

    final openNow = profile.isOpenNow;
    final color = openNow == true
        ? _onlineSuccessColor
        : openNow == false
            ? Colors.redAccent
            : _onlineGoldColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            openNow == true
                ? Icons.check_circle_outline
                : openNow == false
                    ? Icons.cancel_outlined
                    : Icons.schedule_outlined,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            profile.openStatusLabel,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? _onlineGoldColor : _onlineFieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? _onlineGoldColor : _onlineBorderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted ? _onlineBackgroundColor : _onlineGoldColor,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlighted ? _onlineBackgroundColor : Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResultsState extends StatelessWidget {
  const _NoSearchResultsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _onlineCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _onlineBorderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_outlined,
            color: _onlineGoldColor,
            size: 42,
          ),
          SizedBox(height: 10),
          Text(
            'No online shops found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try searching by shop name, website, town or county.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _onlineSoftTextColor,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language,
              color: _onlineGoldColor,
              size: 46,
            ),
            SizedBox(height: 12),
            Text(
              'No online shops yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Online-only business profiles will appear here after they are created.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _onlineSoftTextColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load online shops: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _onlineSoftTextColor,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
