import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_event.dart';
import '../models/business_offer.dart';
import '../models/business_product.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import '../widgets/business_enquiry_button.dart';
import '../widgets/business_rating_summary.dart';
import 'business_events_page.dart';
import 'business_offers_page.dart';
import 'business_products_page.dart';
import 'business_reviews_page.dart';

class PublicBusinessProfilePage extends StatelessWidget {
  const PublicBusinessProfilePage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);

  double? _readCoordinate(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse((value ?? '').toString());
  }

  Uri _mapsSearchUri(String query) {
    return Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': query,
      },
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final cleanWebsite = profile.website.trim();
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

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this website.')),
      );
    }
  }

  Future<void> _openMap(BuildContext context) async {
    Uri? mapUri;

    final linkedShopId = profile.linkedShopId.trim();

    if (linkedShopId.isNotEmpty) {
      try {
        final shopSnapshot = await FirebaseFirestore.instance
            .collection('tcg_shops')
            .doc(linkedShopId)
            .get();

        final shopData = shopSnapshot.data();

        if (shopData != null) {
          final location = shopData['location'];
          double? lat = _readCoordinate(shopData['lat']);
          double? lng = _readCoordinate(shopData['lng']);

          if (location is GeoPoint) {
            lat = location.latitude;
            lng = location.longitude;
          }

          if (lat != null && lng != null && (lat != 0 || lng != 0)) {
            mapUri = _mapsSearchUri('$lat,$lng');
          }
        }
      } catch (_) {
        // Fall back to the saved display location below.
      }
    }

    if (mapUri == null) {
      final fallbackLocation = profile.displayLocation.trim();

      if (fallbackLocation.isEmpty) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No map location is available.')),
        );
        return;
      }

      mapUri = _mapsSearchUri(fallbackLocation);
    }

    await BusinessProfileService().incrementBusinessAnalyticsMetric(
      businessId: profile.id,
      metric: 'mapViews',
    );

    final opened = await launchUrl(
      mapUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps.')),
      );
    }
  }

  void _openReviews(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessReviewsPage(profile: profile),
      ),
    );
  }

  void _openOffers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessOffersPage(profile: profile),
      ),
    );
  }

  void _openEvents(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessEventsPage(profile: profile),
      ),
    );
  }

  void _openProducts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessProductsPage(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = profile.businessName.trim().isEmpty
        ? 'Business profile'
        : profile.businessName.trim();
    final location = profile.displayLocation;
    final website = profile.website.trim();
    final phone = profile.phone.trim();
    final isOnlineOnly = !profile.hasPhysicalShop;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Business Profile'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _PublicHeroCard(
            profile: profile,
            title: title,
            onReviews: () => _openReviews(context),
          ),
          const SizedBox(height: 14),
          _QuickActionsCard(
            profile: profile,
            website: website,
            phone: phone,
            onMap: isOnlineOnly ? null : () => _openMap(context),
            onWebsite: website.isEmpty ? null : () => _openWebsite(context),
          ),
          const SizedBox(height: 16),
          _PublicBusinessSummaryButtons(
            profile: profile,
            onOffers: () => _openOffers(context),
            onEvents: () => _openEvents(context),
            onProducts: () => _openProducts(context),
          ),
          const SizedBox(height: 16),
          _OpeningHoursDropdownCard(profile: profile),
          const SizedBox(height: 16),
          const _SectionHeader(
            icon: Icons.contact_support_outlined,
            title: 'Contact details',
          ),
          const SizedBox(height: 10),
          _ContactCard(
            location: location,
            website: website,
            phone: phone,
            isOnlineOnly: isOnlineOnly,
          ),
        ],
      ),
    );
  }
}

class _PublicHeroCard extends StatelessWidget {
  const _PublicHeroCard({
    required this.profile,
    required this.title,
    required this.onReviews,
  });

  final BusinessProfile profile;
  final String title;
  final VoidCallback onReviews;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = profile.bannerUrl.trim();

    return Container(
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: PublicBusinessProfilePage._goldColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: SizedBox(
          height: 265,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bannerUrl.isNotEmpty)
                Image.network(
                  bannerUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) {
                    return const _BannerPlaceholder();
                  },
                )
              else
                const _BannerPlaceholder(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.02),
                      PublicBusinessProfilePage._backgroundColor.withValues(
                        alpha: 0.22,
                      ),
                      PublicBusinessProfilePage._backgroundColor.withValues(
                        alpha: 0.96,
                      ),
                    ],
                    stops: const [0.28, 0.58, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile.verified) ...[
                      const _TinyBadge(
                        icon: Icons.verified_outlined,
                        text: 'Verified',
                        highlighted: true,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 9,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _HeroRatingChip(
                          businessId: profile.id,
                          onTap: onReviews,
                        ),
                        _OpenNowBadge(profile: profile),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroRatingChip extends StatelessWidget {
  const _HeroRatingChip({
    required this.businessId,
    required this.onTap,
  });

  final String businessId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PublicBusinessProfilePage._backgroundColor.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: PublicBusinessProfilePage._goldColor.withValues(
                alpha: 0.55,
              ),
            ),
          ),
          child: BusinessRatingSummary(
            businessId: businessId,
            starColor: PublicBusinessProfilePage._goldColor,
            textColor: Colors.white,
            mutedTextColor: PublicBusinessProfilePage._softTextColor,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}


class _OpenNowBadge extends StatelessWidget {
  const _OpenNowBadge({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final openNow = profile.isOpenNow;
    final color = openNow == true
        ? PublicBusinessProfilePage._successColor
        : openNow == false
            ? Colors.redAccent
            : PublicBusinessProfilePage._goldColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            profile.openStatusLabel,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}


class _PublicBusinessSummaryButtons extends StatelessWidget {
  const _PublicBusinessSummaryButtons({
    required this.profile,
    required this.onOffers,
    required this.onEvents,
    required this.onProducts,
  });

  final BusinessProfile profile;
  final VoidCallback onOffers;
  final VoidCallback onEvents;
  final VoidCallback onProducts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PublicSummaryButton<BusinessOffer>(
          stream: BusinessProfileService().watchBusinessOffers(
            profile.id,
            visibleOnly: true,
          ),
          icon: Icons.local_offer_outlined,
          title: 'Offers & deals',
          emptyText: 'No current offers',
          countText: (itemCount) => itemCount == 1 ? '1 current offer' : '$itemCount current offers',
          buttonText: 'View offers',
          onPressed: onOffers,
        ),
        const SizedBox(height: 10),
        _PublicSummaryButton<BusinessEvent>(
          stream: BusinessProfileService().watchBusinessEvents(
            profile.id,
            visibleOnly: true,
          ),
          icon: Icons.event_outlined,
          title: 'Shop events',
          emptyText: 'No upcoming events',
          countText: (itemCount) => itemCount == 1 ? '1 upcoming event' : '$itemCount upcoming events',
          buttonText: 'View events',
          onPressed: onEvents,
        ),
        const SizedBox(height: 10),
        _PublicSummaryButton<BusinessProduct>(
          stream: BusinessProfileService().watchBusinessProducts(
            profile.id,
            visibleOnly: true,
          ),
          icon: Icons.inventory_2_outlined,
          title: 'Product showcase',
          emptyText: 'No showcased products',
          countText: (itemCount) => itemCount == 1 ? '1 showcased product' : '$itemCount showcased products',
          buttonText: 'View products',
          onPressed: onProducts,
        ),
      ],
    );
  }
}

class _PublicSummaryButton<T> extends StatelessWidget {
  const _PublicSummaryButton({
    required this.stream,
    required this.icon,
    required this.title,
    required this.emptyText,
    required this.countText,
    required this.buttonText,
    required this.onPressed,
  });

  final Stream<List<T>> stream;
  final IconData icon;
  final String title;
  final String emptyText;
  final String Function(int count) countText;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        final itemCount = snapshot.data?.length ?? 0;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        if (!loading && itemCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PublicBusinessProfilePage._cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: PublicBusinessProfilePage._borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PublicBusinessProfilePage._fieldColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: PublicBusinessProfilePage._borderColor,
                  ),
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PublicBusinessProfilePage._goldColor,
                        ),
                      )
                    : Icon(
                        icon,
                        color: PublicBusinessProfilePage._goldColor,
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loading ? 'Checking...' : countText(itemCount),
                      style: const TextStyle(
                        color: PublicBusinessProfilePage._softTextColor,
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PublicBusinessProfilePage._goldColor,
                  foregroundColor: PublicBusinessProfilePage._backgroundColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: loading ? null : onPressed,
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OpeningHoursDropdownCard extends StatefulWidget {
  const _OpeningHoursDropdownCard({required this.profile});

  final BusinessProfile profile;

  @override
  State<_OpeningHoursDropdownCard> createState() =>
      _OpeningHoursDropdownCardState();
}

class _OpeningHoursDropdownCardState extends State<_OpeningHoursDropdownCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final todayHours = profile.todayOpeningHours;
    final todayText = todayHours.hasTimes || todayHours.closed
        ? todayHours.displayText
        : 'Hours not set';

    return Container(
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                setState(() => _expanded = !_expanded);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: PublicBusinessProfilePage._fieldColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: PublicBusinessProfilePage._borderColor,
                        ),
                      ),
                      child: const Icon(
                        Icons.schedule_outlined,
                        color: PublicBusinessProfilePage._goldColor,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Opening hours',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Today: $todayText',
                            style: const TextStyle(
                              color: PublicBusinessProfilePage._softTextColor,
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _OpenNowBadge(profile: profile),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: PublicBusinessProfilePage._goldColor,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: BusinessOpeningHours.dayKeys.map((dayKey) {
                  final hours = profile.openingHoursForDay(dayKey);
                  final isToday = hours.dayKey ==
                      BusinessOpeningHours.dayKeys[DateTime.now().weekday - 1];

                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? PublicBusinessProfilePage._goldColor.withValues(
                              alpha: 0.12,
                            )
                          : PublicBusinessProfilePage._fieldColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isToday
                            ? PublicBusinessProfilePage._goldColor
                            : PublicBusinessProfilePage._borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isToday
                                ? '${hours.dayLabel}  •  Today'
                                : hours.dayLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          hours.displayText,
                          style: TextStyle(
                            color: hours.closed
                                ? PublicBusinessProfilePage._softTextColor
                                : PublicBusinessProfilePage._goldColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.profile,
    required this.website,
    required this.phone,
    required this.onMap,
    required this.onWebsite,
  });

  final BusinessProfile profile;
  final String website;
  final String phone;
  final VoidCallback? onMap;
  final VoidCallback? onWebsite;

  Future<void> _openPhoneDialler(BuildContext context) async {
    final cleanPhone = phone.trim();

    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number is available.')),
      );
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: cleanPhone,
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      BusinessEnquiryButton(
        profile: profile,
        compact: true,
      ),
      if (onMap != null)
        _ActionButton(
          icon: Icons.map_outlined,
          label: 'Map',
          onPressed: onMap,
          filled: false,
        ),
      if (website.isNotEmpty)
        _ActionButton(
          icon: Icons.open_in_new,
          label: 'Website',
          onPressed: onWebsite,
          filled: true,
        ),
      if (phone.isNotEmpty)
        _ActionButton(
          icon: Icons.phone_outlined,
          label: 'Call',
          onPressed: () => _openPhoneDialler(context),
          filled: false,
        ),
    ];

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          final buttonWidth = (constraints.maxWidth - spacing) / 2;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final button in buttons)
                SizedBox(
                  width: buttonWidth,
                  height: 58,
                  child: button,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = filled
        ? PublicBusinessProfilePage._goldColor
        : Colors.transparent;
    final foregroundColor = filled
        ? PublicBusinessProfilePage._backgroundColor
        : PublicBusinessProfilePage._goldColor;
    final borderColor = filled
        ? PublicBusinessProfilePage._goldColor
        : PublicBusinessProfilePage._goldColor;

    return SizedBox.expand(
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: foregroundColor,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.location,
    required this.website,
    required this.phone,
    required this.isOnlineOnly,
  });

  final String location;
  final String website;
  final String phone;
  final bool isOnlineOnly;

  @override
  Widget build(BuildContext context) {
    final hasInfo = location.isNotEmpty || website.isNotEmpty || phone.isNotEmpty;

    if (!hasInfo) {
      return const _EmptyPreviewCard(
        icon: Icons.contact_support_outlined,
        text: 'Use the enquiry button to contact this business.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: Column(
        children: [
          if (location.isNotEmpty)
            _InfoLine(
              icon: isOnlineOnly ? Icons.public_outlined : Icons.place_outlined,
              text: location,
            ),
          if (website.isNotEmpty)
            _InfoLine(
              icon: Icons.language,
              text: website,
            ),
          if (phone.isNotEmpty)
            _InfoLine(
              icon: Icons.phone_outlined,
              text: phone,
            ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: PublicBusinessProfilePage._goldColor, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(
                color: PublicBusinessProfilePage._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PublicBusinessProfilePage._fieldColor,
      child: const Center(
        child: Icon(
          Icons.storefront_outlined,
          color: PublicBusinessProfilePage._goldColor,
          size: 46,
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.icon,
    required this.text,
    required this.highlighted,
  });

  final IconData icon;
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? PublicBusinessProfilePage._goldColor
            : PublicBusinessProfilePage._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? PublicBusinessProfilePage._goldColor
              : PublicBusinessProfilePage._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted
                ? PublicBusinessProfilePage._backgroundColor
                : PublicBusinessProfilePage._goldColor,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: highlighted
                  ? PublicBusinessProfilePage._backgroundColor
                  : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: PublicBusinessProfilePage._goldColor, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPreviewCard extends StatelessWidget {
  const _EmptyPreviewCard({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: PublicBusinessProfilePage._goldColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: PublicBusinessProfilePage._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
