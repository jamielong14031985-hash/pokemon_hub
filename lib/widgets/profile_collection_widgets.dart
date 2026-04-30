import 'package:flutter/material.dart';

import '../models/profile_stats.dart';
import '../models/tcg_card.dart';
import '../services/currency_settings.dart';
import '../utils/price_format_helpers.dart';
import '../utils/profile_stats_helpers.dart';
import 'profile_showcase_mini_stat.dart';
import 'rarity_dashboard_mini_stat.dart';
import 'rarity_value_bar.dart';

class RarityValueDashboard extends StatelessWidget {
  const RarityValueDashboard({
    super.key,
    required this.stats,
    this.onOpenCard,
  });

  final ProfileStats stats;
  final ValueChanged<TcgCard>? onOpenCard;

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
                          'See where your collection value is coming from.',
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
                        label: 'Collection value',
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
                  'Value by rarity',
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
                    formatCardPrice(card.marketPrice, fromCurrency: card.rawPriceCurrency),
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
                              formatCardPrice(topCard.marketPrice, fromCurrency: topCard.rawPriceCurrency),
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
