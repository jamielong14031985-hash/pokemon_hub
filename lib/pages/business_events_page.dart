// ignore_for_file: unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_event.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import 'business_events_directory_page.dart';

class BusinessEventsPage extends StatefulWidget {
  const BusinessEventsPage({
    super.key,
    this.profile,
    this.businessProfile,
    this.businessId,
    this.businessName,
    this.readOnly = false,
    this.publicView = false,
  });

  final BusinessProfile? profile;
  final BusinessProfile? businessProfile;
  final String? businessId;
  final String? businessName;
  final bool readOnly;
  final bool publicView;

  @override
  State<BusinessEventsPage> createState() => _BusinessEventsPageState();
}

class _BusinessEventsPageState extends State<BusinessEventsPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  final BusinessProfileService _service = BusinessProfileService();

  BusinessProfile? get _profile => widget.profile ?? widget.businessProfile;

  String get _businessId {
    final directId = widget.businessId?.trim() ?? '';
    if (directId.isNotEmpty) return directId;

    final profileId = _profile?.id.trim() ?? '';
    return profileId;
  }

  String get _businessName {
    final directName = widget.businessName?.trim() ?? '';
    if (directName.isNotEmpty) return directName;

    final profileName = _profile?.businessName.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;

    return 'Business events';
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

  List<BusinessEvent> _filterEventsForBusiness(List<BusinessEvent> events) {
    final businessId = _businessId.toLowerCase();
    final businessName = _businessName.toLowerCase();

    return events.where((event) {
      final eventBusinessId = event.businessId.trim().toLowerCase();
      final eventBusinessName = event.businessName.trim().toLowerCase();

      if (businessId.isNotEmpty && eventBusinessId == businessId) {
        return true;
      }

      if (businessName.isNotEmpty && eventBusinessName == businessName) {
        return true;
      }

      return false;
    }).toList();
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

  int _gridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 900) return 3;
    if (width >= 340) return 2;

    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final businessName = _businessName;
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
            return _StateCard(
              icon: Icons.error_outline,
              title: 'Could not load events',
              message: snapshot.error.toString(),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _goldColor),
            );
          }

          final events = _filterEventsForBusiness(
            snapshot.data ?? const <BusinessEvent>[],
          );

          if (events.isEmpty) {
            return _StateCard(
              icon: Icons.event_busy_outlined,
              title: 'No events yet',
              message: '$businessName has not added any visible events yet.',
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _HeaderCard(
                    businessName: businessName,
                    eventCount: events.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverGrid.builder(
                  itemCount: events.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 295,
                  ),
                  itemBuilder: (context, index) {
                    final event = events[index];

                    return _BusinessEventTile(
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
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.businessName,
    required this.eventCount,
  });

  final String businessName;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _BusinessEventsPageState._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _BusinessEventsPageState._goldColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_outlined,
            color: _BusinessEventsPageState._goldColor,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$eventCount event${eventCount == 1 ? '' : 's'} from $businessName',
              style: const TextStyle(
                color: Colors.white,
                height: 1.25,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessEventTile extends StatelessWidget {
  const _BusinessEventTile({
    required this.event,
    required this.formatDateTime,
    required this.onTap,
  });

  final BusinessEvent event;
  final String Function(DateTime? value) formatDateTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isEmpty ? 'Shop event' : event.title.trim();
    final description = event.description.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _BusinessEventsPageState._cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _BusinessEventsPageState._borderColor),
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
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _BusinessEventsPageState._softTextColor,
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
                    event.bookingUrl.trim().isEmpty
                        ? 'Tap for details'
                        : 'Link available',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _BusinessEventsPageState._goldColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: _BusinessEventsPageState._goldColor,
                ),
              ],
            ),
          ],
        ),
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
        Icon(icon, color: _BusinessEventsPageState._goldColor, size: 15),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _BusinessEventsPageState._softTextColor,
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
        ? _BusinessEventsPageState._goldColor
        : _BusinessEventsPageState._softTextColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? _BusinessEventsPageState._goldColor.withValues(alpha: 0.16)
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

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _BusinessEventsPageState._cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _BusinessEventsPageState._borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _BusinessEventsPageState._goldColor, size: 36),
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
                  color: _BusinessEventsPageState._softTextColor,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
