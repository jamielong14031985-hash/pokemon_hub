import 'package:flutter/material.dart';

import '../models/profile_stats.dart';
import '../models/tcg_card.dart';
import '../models/wishlist_entry.dart';
import '../services/currency_settings.dart';
import '../utils/price_format_helpers.dart';
import '../utils/profile_stats_helpers.dart';
import 'profile_showcase_mini_stat.dart';
import 'rarity_dashboard_mini_stat.dart';
import 'rarity_value_bar.dart';

class CollectionOverviewDashboard extends StatelessWidget {
  const CollectionOverviewDashboard({
    super.key,
    required this.stats,
    required this.wishlist,
    required this.onOpenScanner,
    required this.onOpenSets,
    required this.onOpenWishlist,
  });

  final ProfileStats stats;
  final List<WishlistEntry> wishlist;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenSets;
  final VoidCallback onOpenWishlist;

  double get _wishlistValue => wishlist.fold<double>(0, (total, entry) {
        final converted = CurrencySettings.convertAmountSync(
          entry.rawPrice,
          fromCurrency: entry.rawPriceCurrency,
        );
        return total + (converted ?? 0);
      });

  int get _wishlistSetCount => wishlist
      .map((entry) => entry.setId.trim().isEmpty ? entry.setName.trim() : entry.setId.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .length;

  @override
  Widget build(BuildContext context) {
    final pricingMessage = stats.highValueUnverifiedCards > 0
        ? '${stats.highValueUnverifiedCards} high-value guides need review'
        : stats.unpricedUniqueCards > 0
        ? '${stats.unpricedUniqueCards} cards still need a price'
        : stats.lowConfidencePricedCards > 0
            ? '${stats.lowConfidencePricedCards} prices need stronger sales data'
            : 'All available prices are up to date';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard_rounded, color: Color(0xFFF7DE77)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Collection overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 2.05,
            children: [
              _OverviewStat(label: 'Total cards', value: '${stats.totalCards}', icon: Icons.style_rounded),
              _OverviewStat(label: 'Unique cards', value: '${stats.uniqueCards}', icon: Icons.filter_none_rounded),
              _OverviewStat(label: 'Duplicates', value: '${stats.duplicateCards}', icon: Icons.content_copy_rounded),
              _OverviewStat(label: 'Sets collected', value: '${stats.setsCollected}', icon: Icons.collections_bookmark_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OverviewSummary(
                  icon: Icons.favorite_rounded,
                  title: '${wishlist.length} wishlist cards',
                  subtitle: '$_wishlistSetCount sets • ${CurrencySettings.formatSelectedAmount(_wishlistValue)} est.',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _OverviewSummary(
                  icon: Icons.verified_outlined,
                  title: '${stats.pricedUniqueCards}/${stats.uniqueCards} priced',
                  subtitle: pricingMessage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _DashboardAction(icon: Icons.document_scanner_outlined, label: 'Scan', onTap: onOpenScanner)),
              const SizedBox(width: 8),
              Expanded(child: _DashboardAction(icon: Icons.collections_bookmark_outlined, label: 'Sets', onTap: onOpenSets)),
              const SizedBox(width: 8),
              Expanded(child: _DashboardAction(icon: Icons.favorite_border_rounded, label: 'Wishlist', onTap: onOpenWishlist)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFF7DE77), size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _OverviewSummary extends StatelessWidget {
  const _OverviewSummary({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF173872),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFF7DE77), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 9.5, height: 1.2)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF7DE77),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: const Color(0xFF071A3E)),
                const SizedBox(width: 5),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF071A3E), fontSize: 11, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
        ),
      );
}

class RarityValueDashboard extends StatelessWidget {
  const RarityValueDashboard({
    super.key,
    required this.stats,
    this.onOpenCard,
    this.onRefreshPrices,
    this.refreshingPrices = false,
  });

  final ProfileStats stats;
  final ValueChanged<TcgCard>? onOpenCard;
  final VoidCallback? onRefreshPrices;
  final bool refreshingPrices;

  @override
  Widget build(BuildContext context) {
    final rarityValueEntries = stats.rarityValues.entries.toList()
      ..sort((a, b) {
        final valueCompare = b.value.compareTo(a.value);
        if (valueCompare != 0) return valueCompare;
        final rankCompare = profileRarityRank(b.key).compareTo(profileRarityRank(a.key));
        if (rankCompare != 0) return rankCompare;
        return a.key.compareTo(b.key);
      });

    final rarityCopyEntries = stats.rarityCopies.entries.toList()
      ..sort((a, b) {
        final rankCompare = profileRarityRank(b.key).compareTo(profileRarityRank(a.key));
        if (rankCompare != 0) return rankCompare;
        return b.value.compareTo(a.value);
      });

    final pricedRarityValueEntries = rarityValueEntries
        .where((entry) => entry.value > 0)
        .toList();
    final highestRarity = rarityCopyEntries.isEmpty ? 'Not yet' : rarityCopyEntries.first.key;
    final bestValueRarity = pricedRarityValueEntries.isEmpty ? 'Not yet' : pricedRarityValueEntries.first.key;
    final averageValue = stats.totalCards <= 0 ? 0.0 : stats.totalEstimatedPrice / stats.totalCards;
    final visibleValueEntries = pricedRarityValueEntries.take(6).toList();

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF143066),
              Color(0xFF102754),
              Color(0xFF071F4D),
            ],
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.28)),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFF7DE77),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rarity & Value Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Indicative estimates, sales evidence and price sources.',
                          style: TextStyle(
                            color: Color(0xFFC8D4F0),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (stats.totalCards > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.055),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${stats.pricedUniqueCards} of ${stats.uniqueCards} cards priced',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            stats.pricedUniqueCards >= stats.uniqueCards
                                ? 'Complete'
                                : 'Partial estimate',
                            style: const TextStyle(
                              color: Color(0xFFF7DE77),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      LinearProgressIndicator(
                        value: stats.uniqueCards <= 0
                            ? 0
                            : stats.pricedUniqueCards / stats.uniqueCards,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: Colors.white12,
                        color: const Color(0xFFF7DE77),
                      ),
                      if (stats.pricedUniqueCards < stats.uniqueCards &&
                          onRefreshPrices != null) ...[
                        const SizedBox(height: 11),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: refreshingPrices ? null : onRefreshPrices,
                            icon: refreshingPrices
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded),
                            label: Text(
                              refreshingPrices
                                  ? 'Checking up to 20 cards...'
                                  : 'Refresh 20 missing prices',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (stats.totalCards <= 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: const Text(
                    'Save cards to your Set Pokédex and this dashboard will show your rarity spread, value split, and highest-value cards.',
                    style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: RarityDashboardMiniStat(
                        label: 'Indicative value',
                        value: CurrencySettings.formatSelectedAmount(stats.totalEstimatedPrice),
                        icon: Icons.payment_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RarityDashboardMiniStat(
                        label: 'Avg / card',
                        value: CurrencySettings.formatSelectedAmount(averageValue),
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RarityDashboardMiniStat(
                        label: 'Sales-supported*',
                        value: stats.salesSupportedValue > 0
                            ? CurrencySettings.formatSelectedAmount(stats.salesSupportedValue)
                            : 'None yet',
                        icon: Icons.verified_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RarityDashboardMiniStat(
                        label: 'Other guides',
                        value: stats.guideOnlyValue > 0
                            ? CurrencySettings.formatSelectedAmount(stats.guideOnlyValue)
                            : 'None',
                        icon: Icons.info_outline_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  '*Partial subtotal: provider-reported median from 3+ matched sales, with medium/high confidence. Not independently audited. Indicative value also includes unverified price guides.',
                  style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.35),
                ),
                if (stats.highValueUnverifiedCards > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${stats.highValueUnverifiedCards} high-value card price guides need independent confirmation.',
                    style: const TextStyle(color: Color(0xFFFFB36B), fontSize: 10.5, height: 1.3),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RarityDashboardMiniStat(
                        label: 'Highest rarity',
                        value: highestRarity,
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RarityDashboardMiniStat(
                        label: 'Best value rarity',
                        value: bestValueRarity,
                        icon: Icons.show_chart,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Indicative value by rarity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (visibleValueEntries.isEmpty)
                  const Text(
                    'No priced cards found yet.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  ...visibleValueEntries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RarityValueBar(
                        rarity: entry.key,
                        copies: stats.rarityCopies[entry.key] ?? 0,
                        value: entry.value,
                        totalValue: stats.totalEstimatedPrice,
                      ),
                    ),
                  ),
                if (stats.topValueCards.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Top value cards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...stats.topValueCards.take(3).map(
                    (card) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TopValueCardTile(
                        card: card,
                        onOpenCard: onOpenCard,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TopValueCardTile extends StatelessWidget {
  const TopValueCardTile({
    super.key,
    required this.card,
    this.onOpenCard,
  });

  final TcgCard card;
  final ValueChanged<TcgCard>? onOpenCard;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpenCard == null ? null : () => onOpenCard!(card),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 42,
                height: 58,
                child: card.imageUrl == null
                    ? const ColoredBox(
                        color: Color(0xFF0E2A5E),
                        child: Icon(Icons.image_not_supported, color: Colors.white, size: 18),
                      )
                    : Image.network(card.imageUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${profileRarityLabel(card)} • ${card.setName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC8D4F0),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCardPrice(card.marketPrice, fromCurrency: card.marketPriceCurrency),
                    style: const TextStyle(
                      color: Color(0xFFF7DE77),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class ProfileShowcaseCard extends StatelessWidget {
  const ProfileShowcaseCard({
    super.key,
    required this.profileName,
    required this.stats,
    this.imageProvider,
    this.onOpenCard,
  });

  final String profileName;
  final ProfileStats stats;
  final ImageProvider? imageProvider;
  final ValueChanged<TcgCard>? onOpenCard;

  @override
  Widget build(BuildContext context) {
    final topCard = stats.mostExpensiveCard;
    final favouriteSet = stats.favouriteSetName?.trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF183A78),
            Color(0xFF102754),
            Color(0xFF0B214F),
          ],
        ),
        border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white12,
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(Icons.person, color: Colors.white, size: 28)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$profileName's showcase",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your collector highlights in one place.',
                        style: TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF7DE77)),
              ],
            ),
            const SizedBox(height: 16),
            if (topCard == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: const Text(
                  'Start saving cards to build your showcase.',
                  style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
                ),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onOpenCard == null ? null : () => onOpenCard!(topCard),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 70,
                          height: 98,
                          child: topCard.imageUrl == null
                              ? const ColoredBox(
                                  color: Color(0xFF0E2A5E),
                                  child: Icon(Icons.image_not_supported, color: Colors.white),
                                )
                              : Image.network(topCard.imageUrl!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Showcase card',
                              style: TextStyle(
                                color: Color(0xFFF7DE77),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              topCard.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topCard.setName,
                              style: const TextStyle(color: Color(0xFFC8D4F0), fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatCardPrice(topCard.marketPrice, fromCurrency: topCard.marketPriceCurrency),
                              style: const TextStyle(
                                color: Color(0xFFF7DE77),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ProfileShowcaseMiniStat(
                    label: 'Unique cards',
                    value: '${stats.uniqueCards}',
                    icon: Icons.style_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ProfileShowcaseMiniStat(
                    label: 'Favourite set',
                    value: favouriteSet == null || favouriteSet.isEmpty
                        ? 'Not yet'
                        : favouriteSet,
                    icon: Icons.collections_bookmark_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MostExpensiveCardWidget extends StatelessWidget {
  const MostExpensiveCardWidget({
    super.key,
    required this.card,
    required this.copies,
    this.onOpenCard,
  });

  final TcgCard? card;
  final int copies;
  final ValueChanged<TcgCard>? onOpenCard;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: card == null
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Most Expensive Card',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No saved cards yet.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : InkWell(
              onTap: onOpenCard == null ? null : () => onOpenCard!(card!),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 86,
                        height: 120,
                        child: card!.imageUrl == null
                            ? Container(
                                color: const Color(0xFF0E2A5E),
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                ),
                              )
                            : Image.network(card!.imageUrl!, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Most Expensive Card',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            card!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card!.setName,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Est. price: ${formatCardPrice(card!.marketPrice, fromCurrency: card!.rawPriceCurrency)}',
                            style: const TextStyle(
                              color: Color(0xFFF7DE77),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Copies saved: $copies',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap to open card details, prices, and eBay sold checks',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
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
