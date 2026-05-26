import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_offer.dart';
import '../services/business_profile_service.dart';

class BusinessDealsPage extends StatefulWidget {
  const BusinessDealsPage({super.key});

  @override
  State<BusinessDealsPage> createState() => _BusinessDealsPageState();
}

class _BusinessDealsPageState extends State<BusinessDealsPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  final BusinessProfileService _service = BusinessProfileService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'all';

  static const Map<String, String> _categoryLabels = <String, String>{
    'all': 'All',
    'discount': 'Discount codes',
    'new_stock': 'New stock',
    'event': 'Events',
    'announcement': 'Announcements',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BusinessOffer> _filterOffers(List<BusinessOffer> offers) {
    final query = _searchController.text.trim().toLowerCase();

    return offers.where((offer) {
      final matchesCategory =
          _selectedCategory == 'all' || offer.category == _selectedCategory;

      final searchText = [
        offer.businessName,
        offer.title,
        offer.description,
        offer.categoryLabel,
        offer.code,
        offer.websiteUrl,
      ].join(' ').toLowerCase();

      final matchesSearch = query.isEmpty || searchText.contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      labelText: 'Search deals',
      hintText: 'Search by shop, offer, code or update',
      labelStyle: const TextStyle(color: _softTextColor),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _goldColor,
        fontWeight: FontWeight.w900,
      ),
      prefixIcon: const Icon(Icons.search, color: _softTextColor),
      suffixIcon: _searchController.text.trim().isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.clear, color: _softTextColor),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            ),
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _goldColor, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Deals & Offers'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BusinessOffer>>(
        stream: _service.watchAllVisibleBusinessOffers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _goldColor),
            );
          }

          final allOffers = snapshot.data ?? const <BusinessOffer>[];
          final offers = _filterOffers(allOffers);
          final query = _searchController.text.trim();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: offers.length + 3,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _DealsHeroCard(totalCount: allOffers.length);
              }

              if (index == 1) {
                return _buildSearchAndFilters();
              }

              if (index == 2) {
                if (allOffers.isEmpty) {
                  return const _EmptyDealsCard();
                }

                if (offers.isEmpty) {
                  return _NoResultsCard(query: query);
                }

                return _DealsCountCard(
                  totalCount: allOffers.length,
                  filteredCount: offers.length,
                  query: query,
                  selectedCategoryLabel:
                      _categoryLabels[_selectedCategory] ?? 'All',
                );
              }

              final offer = offers[index - 3];
              return _DealCard(offer: offer);
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            cursorColor: _goldColor,
            decoration: _searchDecoration(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryLabels.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = _categoryLabels.entries.elementAt(index);
                final selected = entry.key == _selectedCategory;

                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  backgroundColor: _fieldColor,
                  selectedColor: _goldColor,
                  side: BorderSide(
                    color: selected ? _goldColor : _borderColor,
                  ),
                  labelStyle: TextStyle(
                    color: selected ? _backgroundColor : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedCategory = entry.key);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DealsHeroCard extends StatelessWidget {
  const _DealsHeroCard({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BusinessDealsPageState._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _BusinessDealsPageState._goldColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _BusinessDealsPageState._fieldColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _BusinessDealsPageState._borderColor),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              color: _BusinessDealsPageState._goldColor,
              size: 31,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest TCG deals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  totalCount == 0
                      ? 'Business Pro offers will appear here.'
                      : '$totalCount live offer${totalCount == 1 ? '' : 's'} from Business Pro shops.',
                  style: const TextStyle(
                    color: _BusinessDealsPageState._softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
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

class _DealsCountCard extends StatelessWidget {
  const _DealsCountCard({
    required this.totalCount,
    required this.filteredCount,
    required this.query,
    required this.selectedCategoryLabel,
  });

  final int totalCount;
  final int filteredCount;
  final String query;
  final String selectedCategoryLabel;

  @override
  Widget build(BuildContext context) {
    final text = query.isEmpty
        ? '$filteredCount ${selectedCategoryLabel.toLowerCase()} deal${filteredCount == 1 ? '' : 's'} available.'
        : '$filteredCount result${filteredCount == 1 ? '' : 's'} for "$query".';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _BusinessDealsPageState._cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _BusinessDealsPageState._borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sell_outlined,
            color: _BusinessDealsPageState._goldColor,
            size: 22,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                height: 1.35,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.offer});

  final BusinessOffer offer;

  Future<void> _openWebsite(BuildContext context) async {
    final cleanWebsite = offer.websiteUrl.trim();
    if (cleanWebsite.isEmpty) return;

    final url = cleanWebsite.startsWith('http://') ||
            cleanWebsite.startsWith('https://')
        ? cleanWebsite
        : 'https://$cleanWebsite';

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this offer link.')),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this offer link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName = offer.businessName.trim().isEmpty
        ? 'Business Pro shop'
        : offer.businessName.trim();
    final description = offer.description.trim();
    final code = offer.code.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BusinessDealsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessDealsPageState._borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DealBadge(
                icon: Icons.workspace_premium,
                label: 'Business Pro',
                highlighted: true,
              ),
              _DealBadge(
                icon: Icons.sell_outlined,
                label: offer.categoryLabel,
                highlighted: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: _BusinessDealsPageState._goldColor,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BusinessDealsPageState._softTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: _BusinessDealsPageState._softTextColor,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (code.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _BusinessDealsPageState._fieldColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _BusinessDealsPageState._borderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    color: _BusinessDealsPageState._goldColor,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'Code: ',
                    style: TextStyle(
                      color: _BusinessDealsPageState._softTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (offer.websiteUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _BusinessDealsPageState._goldColor,
                  foregroundColor: _BusinessDealsPageState._backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text(
                  'Open offer',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                onPressed: () => _openWebsite(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DealBadge extends StatelessWidget {
  const _DealBadge({
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
        color: highlighted
            ? _BusinessDealsPageState._goldColor
            : _BusinessDealsPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? _BusinessDealsPageState._goldColor
              : _BusinessDealsPageState._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted
                ? _BusinessDealsPageState._backgroundColor
                : _BusinessDealsPageState._goldColor,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: highlighted
                  ? _BusinessDealsPageState._backgroundColor
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

class _EmptyDealsCard extends StatelessWidget {
  const _EmptyDealsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: _BusinessDealsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessDealsPageState._borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.local_offer_outlined,
            color: _BusinessDealsPageState._goldColor,
            size: 46,
          ),
          SizedBox(height: 12),
          Text(
            'No live deals yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When Business Pro shops add active offers, they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _BusinessDealsPageState._softTextColor,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResultsCard extends StatelessWidget {
  const _NoResultsCard({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: _BusinessDealsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessDealsPageState._borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_outlined,
            color: _BusinessDealsPageState._goldColor,
            size: 44,
          ),
          const SizedBox(height: 12),
          const Text(
            'No deals found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            query.isEmpty
                ? 'Try another filter.'
                : 'No live deals matched "$query".',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _BusinessDealsPageState._softTextColor,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
          'Could not load deals: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _BusinessDealsPageState._softTextColor,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
