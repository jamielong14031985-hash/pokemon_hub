// ignore_for_file: unused_field, unused_element

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

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not set';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} at $hour:$minute';
  }

  String _normaliseUrl(String rawValue) {
    final cleanUrl = rawValue.trim();
    if (cleanUrl.isEmpty) return '';

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return cleanUrl;
    }

    return 'https://$cleanUrl';
  }

  Future<void> _openOfferLink(BuildContext context, BusinessOffer offer) async {
    final url = _normaliseUrl(offer.websiteUrl);
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this offer link.')),
      );
      return;
    }

    await _service.incrementBusinessAnalyticsMetric(
      businessId: offer.businessId,
      metric: 'offerViews',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this offer link.')),
      );
    }
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

  int _gridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 900) return 3;
    if (width >= 340) return 2;

    return 1;
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

  void _openOfferDetails(BusinessOffer offer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessOfferDetailsPage(
          offer: offer,
          formatDateTime: _formatDateTime,
          onOpenOfferLink: (context) => _openOfferLink(context, offer),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = _gridColumns(context);

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

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList.list(
                  children: [
                    _DealsHeroCard(totalCount: allOffers.length),
                    _buildSearchAndFilters(),
                    if (allOffers.isEmpty)
                      const _EmptyDealsCard()
                    else if (offers.isEmpty)
                      _NoResultsCard(query: query)
                    else
                      _DealsCountCard(
                        totalCount: allOffers.length,
                        filteredCount: offers.length,
                        query: query,
                        selectedCategoryLabel:
                            _categoryLabels[_selectedCategory] ?? 'All',
                      ),
                  ],
                ),
              ),
              if (offers.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid.builder(
                    itemCount: offers.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 295,
                    ),
                    itemBuilder: (context, index) {
                      final offer = offers[index];

                      return _DirectoryOfferTile(
                        offer: offer,
                        onTap: () => _openOfferDetails(offer),
                      );
                    },
                  ),
                ),
            ],
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

class BusinessOfferDetailsPage extends StatelessWidget {
  const BusinessOfferDetailsPage({
    super.key,
    required this.offer,
    required this.formatDateTime,
    required this.onOpenOfferLink,
  });

  final BusinessOffer offer;
  final String Function(DateTime? value) formatDateTime;
  final Future<void> Function(BuildContext context) onOpenOfferLink;

  static const Color _backgroundColor = _BusinessDealsPageState._backgroundColor;
  static const Color _cardColor = _BusinessDealsPageState._cardColor;
  static const Color _fieldColor = _BusinessDealsPageState._fieldColor;
  static const Color _borderColor = _BusinessDealsPageState._borderColor;
  static const Color _goldColor = _BusinessDealsPageState._goldColor;
  static const Color _softTextColor = _BusinessDealsPageState._softTextColor;

  String get _offerUrl {
    final cleanUrl = offer.websiteUrl.trim();
    if (cleanUrl.isEmpty) return '';

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return cleanUrl;
    }

    return 'https://$cleanUrl';
  }

  @override
  Widget build(BuildContext context) {
    final businessName = offer.businessName.trim().isEmpty
        ? 'Business Pro shop'
        : offer.businessName.trim();
    final title = offer.title.trim().isEmpty ? 'Deal / offer' : offer.title.trim();
    final description = offer.description.trim();
    final hasCode = offer.code.trim().isNotEmpty;
    final hasLink = _offerUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Offer details'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _goldColor),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TinyPill(
                      icon: Icons.local_offer_outlined,
                      label: offer.categoryLabel,
                      highlighted: true,
                    ),
                    if (hasCode)
                      const _TinyPill(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Code',
                        highlighted: false,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  businessName,
                  style: const TextStyle(
                    color: _softTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DetailSection(
            title: 'Offer information',
            children: [
              _DetailRow(
                icon: Icons.category_outlined,
                label: 'Type',
                value: offer.categoryLabel,
              ),
              if (offer.startsAt != null)
                _DetailRow(
                  icon: Icons.play_circle_outline,
                  label: 'Starts',
                  value: formatDateTime(offer.startsAt?.toDate()),
                ),
              if (offer.endsAt != null)
                _DetailRow(
                  icon: Icons.stop_circle_outlined,
                  label: 'Ends',
                  value: formatDateTime(offer.endsAt?.toDate()),
                ),
              _DetailRow(
                icon: Icons.visibility_outlined,
                label: 'Status',
                value: offer.isCurrentlyVisible ? 'Live now' : 'Not live',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailSection(
            title: 'Details',
            children: [
              SelectableText(
                description.isEmpty ? 'No extra details added.' : description,
                style: const TextStyle(
                  color: _softTextColor,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hasCode) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _fieldColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _goldColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        color: _goldColor,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Code: ',
                        style: TextStyle(
                          color: _softTextColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          offer.code.trim(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _DetailSection(
            title: 'Link / more info',
            children: [
              if (hasLink) ...[
                SelectableText(
                  _offerUrl,
                  style: const TextStyle(
                    color: _goldColor,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: _goldColor,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _goldColor,
                      foregroundColor: _backgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text(
                      'Open link',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onPressed: () => onOpenOfferLink(context),
                  ),
                ),
              ] else
                const Text(
                  'No link has been provided for this offer.',
                  style: TextStyle(
                    color: _softTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectoryOfferTile extends StatelessWidget {
  const _DirectoryOfferTile({
    required this.offer,
    required this.onTap,
  });

  final BusinessOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final businessName = offer.businessName.trim().isEmpty
        ? 'Business Pro shop'
        : offer.businessName.trim();
    final title = offer.title.trim().isEmpty ? 'Deal / offer' : offer.title.trim();
    final description = offer.description.trim();
    final hasLink = offer.websiteUrl.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _BusinessDealsPageState._cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _BusinessDealsPageState._borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _TinyPill(
                  icon: Icons.local_offer_outlined,
                  label: offer.categoryLabel,
                  highlighted: true,
                ),
                if (offer.hasCode)
                  const _TinyPill(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Code',
                    highlighted: false,
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _BusinessDealsPageState._softTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: offer.hasCode ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _BusinessDealsPageState._softTextColor,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (offer.hasCode) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: _BusinessDealsPageState._fieldColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _BusinessDealsPageState._goldColor
                        .withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  'Code: ${offer.code.trim()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasLink ? 'Link available' : 'Tap for details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _BusinessDealsPageState._goldColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: _BusinessDealsPageState._goldColor,
                ),
              ],
            ),
          ],
        ),
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
                      ? 'Business Pro deals and offers will appear here.'
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
            Icons.local_offer_outlined,
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _BusinessDealsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessDealsPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _BusinessDealsPageState._goldColor, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _BusinessDealsPageState._softTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
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

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? _BusinessDealsPageState._goldColor
        : _BusinessDealsPageState._softTextColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? _BusinessDealsPageState._goldColor.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: highlighted ? color : Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
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

class _EmptyDealsCard extends StatelessWidget {
  const _EmptyDealsCard();

  @override
  Widget build(BuildContext context) {
    return const _SimpleStateCard(
      icon: Icons.local_offer_outlined,
      title: 'No deals yet',
      message:
          'Business Pro deals and offers will appear here when shops post them.',
    );
  }
}

class _NoResultsCard extends StatelessWidget {
  const _NoResultsCard({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return _SimpleStateCard(
      icon: Icons.search_off_outlined,
      title: 'No matching deals',
      message: query.isEmpty
          ? 'Try choosing a different offer type.'
          : 'No deals matched "$query".',
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return _SimpleStateCard(
      icon: Icons.error_outline,
      title: 'Could not load deals',
      message: error,
    );
  }
}

class _SimpleStateCard extends StatelessWidget {
  const _SimpleStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BusinessDealsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessDealsPageState._borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: _BusinessDealsPageState._goldColor, size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _BusinessDealsPageState._softTextColor,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
