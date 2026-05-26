import 'package:flutter/material.dart';

import '../models/business_offer.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import '../pages/business_offers_page.dart';

class BusinessOffersPreview extends StatelessWidget {
  const BusinessOffersPreview({
    super.key,
    required this.profile,
    this.maxItems = 2,
    this.compact = false,
  });

  final BusinessProfile profile;
  final int maxItems;
  final bool compact;

  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  void _openOffers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessOffersPage(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (profile.id.trim().isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<BusinessOffer>>(
      stream: BusinessProfileService().watchBusinessOffers(
        profile.id,
        visibleOnly: true,
      ),
      builder: (context, snapshot) {
        final offers = snapshot.data ?? const <BusinessOffer>[];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _PreviewShell(
            compact: compact,
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _goldColor,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loading offers...',
                    style: TextStyle(
                      color: _softTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (offers.isEmpty) return const SizedBox.shrink();

        final visibleOffers = offers.take(maxItems).toList();

        return _PreviewShell(
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    color: _goldColor,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      offers.length == 1
                          ? '1 current offer'
                          : '${offers.length} current offers',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: _goldColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openOffers(context),
                    child: const Text(
                      'View all',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...visibleOffers.map(
                (offer) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MiniOfferCard(offer: offer),
                ),
              ),
              if (offers.length > visibleOffers.length)
                Text(
                  '+${offers.length - visibleOffers.length} more offer${offers.length - visibleOffers.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: _softTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewShell extends StatelessWidget {
  const _PreviewShell({
    required this.child,
    required this.compact,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: BusinessOffersPreview._cardColor,
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(color: BusinessOffersPreview._goldColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: compact ? 0.08 : 0.16),
            blurRadius: compact ? 8 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniOfferCard extends StatelessWidget {
  const _MiniOfferCard({required this.offer});

  final BusinessOffer offer;

  @override
  Widget build(BuildContext context) {
    final title = offer.title.trim().isEmpty ? 'Business offer' : offer.title;
    final description = offer.description.trim();
    final code = offer.code.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BusinessOffersPreview._fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BusinessOffersPreview._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _SmallOfferBadge(
                icon: Icons.sell_outlined,
                text: offer.categoryLabel,
                highlighted: true,
              ),
              if (code.isNotEmpty)
                const _SmallOfferBadge(
                  icon: Icons.confirmation_number_outlined,
                  text: 'Code available',
                  highlighted: false,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BusinessOffersPreview._softTextColor,
                height: 1.3,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          if (code.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: BusinessOffersPreview._backgroundColor.withValues(
                  alpha: 0.72,
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: BusinessOffersPreview._goldColor.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    color: BusinessOffersPreview._goldColor,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallOfferBadge extends StatelessWidget {
  const _SmallOfferBadge({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? BusinessOffersPreview._goldColor
            : BusinessOffersPreview._backgroundColor.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? BusinessOffersPreview._goldColor
              : BusinessOffersPreview._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted
                ? BusinessOffersPreview._backgroundColor
                : BusinessOffersPreview._goldColor,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: highlighted
                  ? BusinessOffersPreview._backgroundColor
                  : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
