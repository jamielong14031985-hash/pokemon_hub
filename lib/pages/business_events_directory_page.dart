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
      ].join(' ').toLowerCase();

      final matchesSearch = query.isEmpty || searchText.contains(query);

      return matchesType && matchesSearch;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
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

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: events.length + 3,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _EventsHeroCard(totalCount: allEvents.length);
              }

              if (index == 1) {
                return _buildSearchAndFilters();
              }

              if (index == 2) {
                if (allEvents.isEmpty) {
                  return const _EmptyEventsDirectoryCard();
                }

                if (events.isEmpty) {
                  return _NoResultsCard(query: query);
                }

                return _EventsCountCard(
                  filteredCount: events.length,
                  query: query,
                  selectedTypeLabel: _eventTypeLabels[_selectedEventType] ?? 'All',
                );
              }

              final event = events[index - 3];
              return _DirectoryEventCard(
                event: event,
                formatDateTime: _formatDateTime,
              );
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
        border: Border.all(color: _BusinessEventsDirectoryPageState._borderColor),
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

class _DirectoryEventCard extends StatelessWidget {
  const _DirectoryEventCard({
    required this.event,
    required this.formatDateTime,
  });

  final BusinessEvent event;
  final String Function(DateTime? value) formatDateTime;

  Future<void> _openBooking(BuildContext context) async {
    final cleanUrl = event.bookingUrl.trim();
    if (cleanUrl.isEmpty) return;

    final url = cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')
        ? cleanUrl
        : 'https://$cleanUrl';

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this booking link.')),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this booking link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName = event.businessName.trim().isEmpty
        ? 'Business Pro shop'
        : event.businessName.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BusinessEventsDirectoryPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessEventsDirectoryPageState._borderColor),
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
              const _DirectoryEventBadge(
                icon: Icons.workspace_premium,
                label: 'Business Pro',
                highlighted: true,
              ),
              _DirectoryEventBadge(
                icon: Icons.event_outlined,
                label: event.eventTypeLabel,
                highlighted: false,
              ),
              if (event.onlineEvent)
                const _DirectoryEventBadge(
                  icon: Icons.language,
                  label: 'Online',
                  highlighted: false,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
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
                color: _BusinessEventsDirectoryPageState._goldColor,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BusinessEventsDirectoryPageState._softTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (event.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              event.description.trim(),
              style: const TextStyle(
                color: _BusinessEventsDirectoryPageState._softTextColor,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _DirectoryEventInfoRow(
            icon: Icons.schedule_outlined,
            text: formatDateTime(event.startDate),
          ),
          if (event.endDate != null)
            _DirectoryEventInfoRow(
              icon: Icons.timelapse_outlined,
              text: 'Ends ${formatDateTime(event.endDate)}',
            ),
          if (event.location.trim().isNotEmpty)
            _DirectoryEventInfoRow(
              icon: event.onlineEvent ? Icons.language : Icons.place_outlined,
              text: event.location.trim(),
            ),
          if (event.entryFee.trim().isNotEmpty)
            _DirectoryEventInfoRow(
              icon: Icons.payments_outlined,
              text: event.entryFee.trim(),
            ),
          if (event.bookingUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _BusinessEventsDirectoryPageState._goldColor,
                  foregroundColor:
                      _BusinessEventsDirectoryPageState._backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text(
                  'Booking / more info',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                onPressed: () => _openBooking(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DirectoryEventInfoRow extends StatelessWidget {
  const _DirectoryEventInfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: _BusinessEventsDirectoryPageState._goldColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _BusinessEventsDirectoryPageState._softTextColor,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryEventBadge extends StatelessWidget {
  const _DirectoryEventBadge({
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
            ? _BusinessEventsDirectoryPageState._goldColor
            : _BusinessEventsDirectoryPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? _BusinessEventsDirectoryPageState._goldColor
              : _BusinessEventsDirectoryPageState._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted
                ? _BusinessEventsDirectoryPageState._backgroundColor
                : _BusinessEventsDirectoryPageState._goldColor,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: highlighted
                  ? _BusinessEventsDirectoryPageState._backgroundColor
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

class _EmptyEventsDirectoryCard extends StatelessWidget {
  const _EmptyEventsDirectoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: _BusinessEventsDirectoryPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessEventsDirectoryPageState._borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            color: _BusinessEventsDirectoryPageState._goldColor,
            size: 46,
          ),
          SizedBox(height: 12),
          Text(
            'No upcoming events yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When Business Pro shops add active events, they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _BusinessEventsDirectoryPageState._softTextColor,
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
        color: _BusinessEventsDirectoryPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessEventsDirectoryPageState._borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_outlined,
            color: _BusinessEventsDirectoryPageState._goldColor,
            size: 44,
          ),
          const SizedBox(height: 12),
          const Text(
            'No events found',
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
                : 'No upcoming events matched "$query".',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _BusinessEventsDirectoryPageState._softTextColor,
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
          'Could not load events: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _BusinessEventsDirectoryPageState._softTextColor,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
