import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import '../widgets/business_enquiry_button.dart';
import '../widgets/business_offers_preview.dart';
import '../widgets/business_products_preview.dart';
import '../widgets/business_rating_summary.dart';
import 'business_reviews_page.dart';

const Color _onlineBackgroundColor = Color(0xFF041B4A);
const Color _onlineCardColor = Color(0xFF102754);
const Color _onlineFieldColor = Color(0xFF16366E);
const Color _onlineBorderColor = Color(0xFF3F5C96);
const Color _onlineGoldColor = Color(0xFFF7DE77);
const Color _onlineSoftTextColor = Color(0xFFC8D4F0);

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

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: profiles.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildSearchBox();
              }

              if (index == 1) {
                return _buildIntroCard(
                  totalCount: allProfiles.length,
                  filteredCount: profiles.length,
                  query: query,
                );
              }

              if (profiles.isEmpty) {
                return const _NoSearchResultsState();
              }

              final profile = profiles[index - 2];
              return _OnlineShopCard(profile: profile);
            },
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
    final phone = profile.phone.trim();
    final location = profile.displayLocation;
    final title = profile.businessName.trim().isEmpty
        ? 'Online TCG Shop'
        : profile.businessName.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _onlineCardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: profile.premiumIsActive ? _onlineGoldColor : _onlineBorderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.bannerUrl.trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  profile.bannerUrl.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _BannerFallback(profile: profile);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BusinessAvatar(profile: profile),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        const _SmallBadge(
                          icon: Icons.language,
                          label: 'Online shop',
                          highlighted: false,
                        ),
                        if (profile.premiumIsActive)
                          const _SmallBadge(
                            icon: Icons.workspace_premium,
                            label: 'Business Pro',
                            highlighted: true,
                          ),
                        if (profile.autoFeaturePosts)
                          const _SmallBadge(
                            icon: Icons.campaign_outlined,
                            label: 'Featured posts',
                            highlighted: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BusinessRatingSummary(
                      businessId: profile.id,
                      starColor: _onlineGoldColor,
                      textColor: Colors.white,
                      mutedTextColor: _onlineSoftTextColor,
                      onTap: () => _openReviews(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile.description.trim(),
              style: const TextStyle(
                color: _onlineSoftTextColor,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.place_outlined, color: _onlineGoldColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      color: _onlineSoftTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          BusinessOffersPreview(
            profile: profile,
            maxItems: 2,
          ),
          const SizedBox(height: 12),
          BusinessProductsPreview(
            profile: profile,
            maxItems: 3,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _onlineGoldColor,
                side: const BorderSide(color: _onlineGoldColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.star_rate_rounded),
              label: const Text(
                'View reviews',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () => _openReviews(context),
            ),
          ),
          const SizedBox(height: 10),
          BusinessEnquiryButton(profile: profile),
          if (website.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (website.isNotEmpty)
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _onlineGoldColor,
                        foregroundColor: _onlineBackgroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text(
                        'Website',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () => _openWebsite(context, website),
                    ),
                  ),
                if (website.isNotEmpty && phone.isNotEmpty)
                  const SizedBox(width: 10),
                if (phone.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _onlineGoldColor,
                        side: const BorderSide(color: _onlineGoldColor),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text(
                        'Contact',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () => _showContact(context, phone),
                    ),
                  ),
              ],
            ),
          ],
        ],
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

    final url = cleanWebsite.startsWith('http://') ||
            cleanWebsite.startsWith('https://')
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

  void _showContact(BuildContext context, String phone) {
    unawaited(
      BusinessProfileService().incrementBusinessAnalyticsMetric(
        businessId: profile.id,
        metric: 'phoneClicks',
      ),
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _onlineCardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phone_outlined,
                  color: _onlineGoldColor,
                  size: 36,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Contact online shop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _onlineSoftTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _onlineGoldColor,
                      foregroundColor: _onlineBackgroundColor,
                    ),
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BusinessAvatar extends StatelessWidget {
  const _BusinessAvatar({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final logoUrl = profile.logoUrl.trim();

    return CircleAvatar(
      radius: 27,
      backgroundColor: _onlineFieldColor,
      child: logoUrl.isEmpty
          ? const Icon(
              Icons.language,
              color: _onlineGoldColor,
              size: 28,
            )
          : ClipOval(
              child: Image.network(
                logoUrl,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.language,
                    color: _onlineGoldColor,
                    size: 28,
                  );
                },
              ),
            ),
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
      child: Center(
        child: Icon(
          profile.premiumIsActive ? Icons.workspace_premium : Icons.language,
          color: _onlineGoldColor,
          size: 40,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: highlighted ? _onlineBackgroundColor : Colors.white,
              fontSize: 11,
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
