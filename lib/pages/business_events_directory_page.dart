// ignore_for_file: unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_event.dart';
import '../services/business_profile_service.dart';

class BusinessEventsDirectoryPage extends StatefulWidget {
  const BusinessEventsDirectoryPage({super.key});

  @override
  State<BusinessEventsDirectoryPage> createState() =>
      _BusinessEventsDirectoryPageState();
}

class _BusinessEventsDirectoryPageState
    extends State<BusinessEventsDirectoryPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);

  final BusinessProfileService _service = BusinessProfileService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedEventType = 'all';

  static const Map<String, String> _eventTypeLabels = <String, String>{
    'all': 'All',
    'trade_night': 'Trade nights',
    'tournament': 'Tournaments',
    'pre_release': 'Pre-release',
    'release_day': 'Release day',
    'giveaway': 'Giveaways',
    'meetup': 'Meetups',
    'other': 'Other',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Date TBC';

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

  Future<void> _openBookingLink(BuildContext context, BusinessEvent event) async {
    final url = _normaliseUrl(event.bookingUrl);
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this booking link.')),
      );
      return;
    }

    await _service.incrementBusinessAnalyticsMetric(
      businessId: event.businessId,
      metric: 'eventViews',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this booking link.')),
      );
    }
  }

  List<BusinessEvent> _filterEvents(List<BusinessEvent> events) {
    final query = _searchController.text.trim().toLowerCase();

    return events.where((event) {
      final matchesType =
          _selectedEventType == 'all' || event.eventType == _selectedEventType;

      final searchText = [
        event.businessName,
        event.title,
        event.description,
        event.eventTypeLabel,
        event.location,
        event.entryFee,
        event.bookingUrl,
      ].join(' ').toLowerCase();

      final matchesSearch = query.isEmpty || searchText.contains(query);

      return matchesType && matchesSearch;
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
      labelText: 'Search events',
      hintText: 'Search by shop, event, location or type',
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

  void _openEventDetails(BusinessEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessEventDetailsPage(
          event: event,
          formatDateTime: _formatDateTime,
          onOpenBookingLink: (context) => _openBookingLink(context, event),
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
        title: const Text('Shop Events'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BusinessEvent>>(
        stream: _service.watchAllVisibleBusinessEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _goldColor),
            );
          }

          final allEvents = snapshot.data ?? const <BusinessEvent>[];
          final events = _filterEvents(allEvents);
          final query = _searchController.text.trim();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList.list(
                  children: [
                    _EventsHeroCard(totalCount: allEvents.length),
                    _buildSearchAndFilters(),
                    if (allEvents.isEmpty)
                      const _EmptyEventsDirectoryCard()
                    else if (events.isEmpty)
                      _NoResultsCard(query: query)
                    else
                      _EventsCountCard(
                        filteredCount: events.length,
                        query: query,
                        selectedTypeLabel:
                            _eventTypeLabels[_selectedEventType] ?? 'All',
                      ),
                  ],
                ),
              ),
              if (events.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid.builder(
                    itemCount: events.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 310,
                    ),
                    itemBuilder: (context, index) {
                      final event = events[index];

                      return _DirectoryEventTile(
                        event: event,
                        formatDateTime: _formatDateTime,
                        onTap: () => _openEventDetails(event),
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
              itemCount: _eventTypeLabels.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = _eventTypeLabels.entries.elementAt(index);
                final selected = entry.key == _selectedEventType;

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
                    setState(() => _selectedEventType = entry.key);
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

class BusinessEventDetailsPage extends StatelessWidget {
  const BusinessEventDetailsPage({
    super.key,
    required this.event,
    required this.formatDateTime,
    required this.onOpenBookingLink,
  });

  final BusinessEvent event;
  final String Function(DateTime? value) formatDateTime;
  final Future<void> Function(BuildContext context) onOpenBookingLink;

  static const Color _backgroundColor =
      _BusinessEventsDirectoryPageState._backgroundColor;
  static const Color _cardColor = _BusinessEventsDirectoryPageState._cardColor;
  static const Color _fieldColor = _BusinessEventsDirectoryPageState._fieldColor;
  static const Color _borderColor =
      _BusinessEventsDirectoryPageState._borderColor;
  static const Color _goldColor = _BusinessEventsDirectoryPageState._goldColor;
  static const Color _softTextColor =
      _BusinessEventsDirectoryPageState._softTextColor;

  String get _bookingUrl {
    final cleanUrl = event.bookingUrl.trim();
    if (cleanUrl.isEmpty) return '';

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return cleanUrl;
    }

    return 'https://$cleanUrl';
  }

  @override
  Widget build(BuildContext context) {
    final businessName = event.businessName.trim().isEmpty
        ? 'Business Pro shop'
        : event.businessName.trim();
    final title = event.title.trim().isEmpty ? 'Shop event' : event.title.trim();
    final description = event.description.trim();
    final location = event.onlineEvent
        ? 'Online'
        : event.location.trim().isEmpty
            ? 'Location TBC'
            : event.location.trim();
    final hasBookingUrl = _bookingUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Event details'),
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
                      icon: Icons.event_outlined,
                      label: event.eventTypeLabel,
                      highlighted: true,
                    ),
                    if (event.onlineEvent)
                      const _TinyPill(
                        icon: Icons.language,
                        label: 'Online',
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
            title: 'Event information',
            children: [
              _DetailRow(
                icon: Icons.schedule_outlined,
                label: 'Starts',
                value: formatDateTime(event.startDate),
              ),
              if (event.endDate != null)
                _DetailRow(
                  icon: Icons.schedule_send_outlined,
                  label: 'Ends',
                  value: formatDateTime(event.endDate),
                ),
              _DetailRow(
                icon: event.onlineEvent
                    ? Icons.language
                    : Icons.location_on_outlined,
                label: event.onlineEvent ? 'Where' : 'Location',
                value: location,
              ),
              _DetailRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Entry fee',
                value: event.entryFee.trim().isEmpty
                    ? 'Not listed'
                    : event.entryFee.trim(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailSection(
            title: 'About this event',
            children: [
              SelectableText(
                description.isEmpty ? 'No extra details added.' : description,
                style: const TextStyle(
                  color: _softTextColor,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailSection(
            title: 'Booking / more info',
            children: [
              if (hasBookingUrl) ...[
                SelectableText(
                  _bookingUrl,
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
                    onPressed: () => onOpenBookingLink(context),
                  ),
                ),
              ] else
                const Text(
                  'No booking link has been provided yet.',
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

class _DirectoryEventTile extends StatelessWidget {
  const _DirectoryEventTile({
    required this.event,
    required this.formatDateTime,
    required this.onTap,
  });

  final BusinessEvent event;
  final String Function(DateTime? value) formatDateTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final businessName = event.businessName.trim().isEmpty
        ? 'Business Pro shop'
        : event.businessName.trim();
    final title = event.title.trim().isEmpty ? 'Shop event' : event.title.trim();
    final description = event.description.trim();
    final hasBooking = event.hasBookingUrl;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _BusinessEventsDirectoryPageState._cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _BusinessEventsDirectoryPageState._borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _TinyPill(
                  icon: Icons.event_outlined,
                  label: event.eventTypeLabel,
                  highlighted: true,
                ),
                if (event.onlineEvent)
                  const _TinyPill(
                    icon: Icons.language,
                    label: 'Online',
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
                color: _BusinessEventsDirectoryPageState._softTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _MiniLine(
              icon: Icons.schedule_outlined,
              text: formatDateTime(event.startDate),
            ),
            const SizedBox(height: 5),
            _MiniLine(
              icon: event.onlineEvent ? Icons.language : Icons.location_on_outlined,
              text: event.onlineEvent
                  ? 'Online'
                  : event.location.trim().isEmpty
                      ? 'Location TBC'
                      : event.location.trim(),
            ),
            if (event.hasEntryFee) ...[
              const SizedBox(height: 5),
              _MiniLine(
                icon: Icons.confirmation_number_outlined,
                text: event.entryFee.trim(),
              ),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _BusinessEventsDirectoryPageState._softTextColor,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasBooking ? 'Link available' : 'Tap for details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _BusinessEventsDirectoryPageState._goldColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: _BusinessEventsDirectoryPageState._goldColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsHeroCard extends StatelessWidget {
  const _EventsHeroCard({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BusinessEventsDirectoryPageState._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _BusinessEventsDirectoryPageState._goldColor),
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
              color: _BusinessEventsDirectoryPageState._fieldColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _BusinessEventsDirectoryPageState._borderColor,
              ),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: _BusinessEventsDirectoryPageState._goldColor,
              size: 31,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upcoming shop events',
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
                      ? 'Business Pro events will appear here.'
                      : '$totalCount upcoming event${totalCount == 1 ? '' : 's'} from Business Pro shops.',
                  style: const TextStyle(
                    color: _BusinessEventsDirectoryPageState._softTextColor,
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

class _EventsCountCard extends StatelessWidget {
  const _EventsCountCard({
    required this.filteredCount,
    required this.query,
    required this.selectedTypeLabel,
  });

  final int filteredCount;
  final String query;
  final String selectedTypeLabel;

  @override
  Widget build(BuildContext context) {
    final text = query.isEmpty
        ? '$filteredCount ${selectedTypeLabel.toLowerCase()} event${filteredCount == 1 ? '' : 's'} available.'
        : '$filteredCount result${filteredCount == 1 ? '' : 's'} for "$query".';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _BusinessEventsDirectoryPageState._cardColor,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: _BusinessEventsDirectoryPageState._borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_outlined,
            color: _BusinessEventsDirectoryPageState._goldColor,
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
        color: _BusinessEventsDirectoryPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessEventsDirectoryPageState._borderColor),
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
          Icon(
            icon,
            color: _BusinessEventsDirectoryPageState._goldColor,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _BusinessEventsDirectoryPageState._softTextColor,
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

class _MiniLine extends StatelessWidget {
  const _MiniLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: _BusinessEventsDirectoryPageState._goldColor,
          size: 15,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _BusinessEventsDirectoryPageState._softTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
        ? _BusinessEventsDirectoryPageState._goldColor
        : _BusinessEventsDirectoryPageState._softTextColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? _BusinessEventsDirectoryPageState._goldColor
                .withValues(alpha: 0.16)
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

class _EmptyEventsDirectoryCard extends StatelessWidget {
  const _EmptyEventsDirectoryCard();

  @override
  Widget build(BuildContext context) {
    return const _SimpleStateCard(
      icon: Icons.event_busy_outlined,
      title: 'No events yet',
      message: 'Business Pro shop events will appear here when shops post them.',
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
      title: 'No matching events',
      message: query.isEmpty
          ? 'Try choosing a different event type.'
          : 'No events matched "$query".',
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
      title: 'Could not load events',
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
        color: _BusinessEventsDirectoryPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessEventsDirectoryPageState._borderColor),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: _BusinessEventsDirectoryPageState._goldColor,
            size: 36,
          ),
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
              color: _BusinessEventsDirectoryPageState._softTextColor,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
