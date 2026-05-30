import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_event.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import '../widgets/business_enquiry_button.dart';
import '../widgets/business_offers_preview.dart';
import '../widgets/business_products_preview.dart';
import '../widgets/business_rating_summary.dart';
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

  void _openReviews(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessReviewsPage(profile: profile),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} $hour:$minute';
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
            isOnlineOnly: isOnlineOnly,
          ),
          const SizedBox(height: 14),
          _QuickActionsCard(
            profile: profile,
            website: website,
            phone: phone,
            onWebsite: website.isEmpty ? null : () => _openWebsite(context),
            onReviews: () => _openReviews(context),
          ),
          if (profile.description.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionHeader(
              icon: Icons.info_outline,
              title: 'About this business',
            ),
            const SizedBox(height: 10),
            _DescriptionCard(text: profile.description.trim()),
          ],
          const SizedBox(height: 16),
          const _SectionHeader(
            icon: Icons.star_rate_rounded,
            title: 'Reviews',
          ),
          const SizedBox(height: 10),
          _ReviewsCard(
            profile: profile,
            onReviews: () => _openReviews(context),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            icon: Icons.local_offer_outlined,
            title: 'Offers & deals',
          ),
          const SizedBox(height: 10),
          BusinessOffersPreview(
            profile: profile,
            maxItems: 3,
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            icon: Icons.event_outlined,
            title: 'Shop events',
          ),
          const SizedBox(height: 10),
          _PublicEventsPreview(
            profile: profile,
            formatDate: _formatDate,
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Product showcase',
          ),
          const SizedBox(height: 10),
          BusinessProductsPreview(
            profile: profile,
            maxItems: 4,
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            icon: Icons.schedule_outlined,
            title: 'Opening hours',
          ),
          const SizedBox(height: 10),
          _OpeningHoursCard(profile: profile),
          const SizedBox(height: 16),
          const _SectionHeader(
            icon: Icons.contact_support_outlined,
            title: 'Contact and enquiries',
          ),
          const SizedBox(height: 10),
          _ContactCard(
            location: location,
            website: website,
            phone: phone,
            isOnlineOnly: isOnlineOnly,
          ),
          const SizedBox(height: 10),
          BusinessEnquiryButton(profile: profile),
        ],
      ),
    );
  }
}

class _PublicHeroCard extends StatelessWidget {
  const _PublicHeroCard({
    required this.profile,
    required this.title,
    required this.isOnlineOnly,
  });

  final BusinessProfile profile;
  final String title;
  final bool isOnlineOnly;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = profile.bannerUrl.trim();

    return Container(
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: profile.premiumIsActive
              ? PublicBusinessProfilePage._goldColor
              : PublicBusinessProfilePage._borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bannerUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const _BannerPlaceholder();
                  },
                ),
              ),
            )
          else
            const _BannerPlaceholder(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BusinessLogo(profile: profile),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _TinyBadge(
                            icon: isOnlineOnly
                                ? Icons.language
                                : Icons.storefront_outlined,
                            text: isOnlineOnly ? 'Online shop' : 'Physical shop',
                            highlighted: false,
                          ),
                          if (profile.premiumIsActive)
                            const _TinyBadge(
                              icon: Icons.workspace_premium,
                              text: 'Business Pro',
                              highlighted: true,
                            ),
                          if (profile.verified)
                            const _TinyBadge(
                              icon: Icons.verified_outlined,
                              text: 'Verified',
                              highlighted: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      BusinessRatingSummary(
                        businessId: profile.id,
                        starColor: PublicBusinessProfilePage._goldColor,
                        textColor: Colors.white,
                        mutedTextColor: PublicBusinessProfilePage._softTextColor,
                      ),
                      const SizedBox(height: 8),
                      _OpenNowBadge(profile: profile),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _OpeningHoursCard extends StatelessWidget {
  const _OpeningHoursCard({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: Column(
        children: BusinessOpeningHours.dayKeys.map((dayKey) {
          final hours = profile.openingHoursForDay(dayKey);
          final isToday = hours.dayKey ==
              BusinessOpeningHours.dayKeys[DateTime.now().weekday - 1];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isToday
                  ? PublicBusinessProfilePage._goldColor.withValues(alpha: 0.12)
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
                    isToday ? '${hours.dayLabel}  •  Today' : hours.dayLabel,
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
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.profile,
    required this.website,
    required this.phone,
    required this.onWebsite,
    required this.onReviews,
  });

  final BusinessProfile profile;
  final String website;
  final String phone;
  final VoidCallback? onWebsite;
  final VoidCallback onReviews;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          _ActionButton(
            icon: Icons.star_rate_rounded,
            label: 'Reviews',
            onPressed: onReviews,
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
              label: 'Contact',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Contact: $phone')),
                );
              },
              filled: false,
            ),
        ],
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
    if (filled) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: PublicBusinessProfilePage._goldColor,
          foregroundColor: PublicBusinessProfilePage._backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        onPressed: onPressed,
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: PublicBusinessProfilePage._goldColor,
        side: const BorderSide(color: PublicBusinessProfilePage._goldColor),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      onPressed: onPressed,
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({
    required this.profile,
    required this.onReviews,
  });

  final BusinessProfile profile;
  final VoidCallback onReviews;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: BusinessRatingSummary(
              businessId: profile.id,
              starColor: PublicBusinessProfilePage._goldColor,
              textColor: Colors.white,
              mutedTextColor: PublicBusinessProfilePage._softTextColor,
              onTap: onReviews,
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: PublicBusinessProfilePage._goldColor,
              side: const BorderSide(color: PublicBusinessProfilePage._goldColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text(
              'View',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: onReviews,
          ),
        ],
      ),
    );
  }
}

class _PublicEventsPreview extends StatelessWidget {
  const _PublicEventsPreview({
    required this.profile,
    required this.formatDate,
  });

  final BusinessProfile profile;
  final String Function(DateTime? value) formatDate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessEvent>>(
      stream: BusinessProfileService().watchBusinessEvents(
        profile.id,
        visibleOnly: true,
      ),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <BusinessEvent>[];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }

        if (events.isEmpty) {
          return const _EmptyPreviewCard(
            icon: Icons.event_outlined,
            text: 'No upcoming public events yet.',
          );
        }

        final visibleEvents = events.take(3).toList();

        return Column(
          children: visibleEvents.map((event) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: PublicBusinessProfilePage._cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: PublicBusinessProfilePage._borderColor,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    color: PublicBusinessProfilePage._goldColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _TinyBadge(
                              icon: Icons.event_outlined,
                              text: event.eventTypeLabel,
                              highlighted: true,
                            ),
                            if (event.onlineEvent)
                              const _TinyBadge(
                                icon: Icons.language,
                                text: 'Online',
                                highlighted: false,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.title.trim().isEmpty
                              ? 'Shop event'
                              : event.title.trim(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (formatDate(event.startDate).isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            formatDate(event.startDate),
                            style: const TextStyle(
                              color: PublicBusinessProfilePage._softTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (event.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            event.description.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PublicBusinessProfilePage._softTextColor,
                              height: 1.35,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
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

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: PublicBusinessProfilePage._softTextColor,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
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

class _BusinessLogo extends StatelessWidget {
  const _BusinessLogo({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final logoUrl = profile.logoUrl.trim();

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._fieldColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: logoUrl.isEmpty
          ? const Icon(
              Icons.storefront_outlined,
              color: PublicBusinessProfilePage._goldColor,
              size: 34,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.storefront_outlined,
                    color: PublicBusinessProfilePage._goldColor,
                    size: 34,
                  );
                },
              ),
            ),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: const BoxDecoration(
        color: PublicBusinessProfilePage._fieldColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PublicBusinessProfilePage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PublicBusinessProfilePage._borderColor),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: PublicBusinessProfilePage._goldColor,
        ),
      ),
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
