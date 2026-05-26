import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_event.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';

class BusinessEventsPage extends StatefulWidget {
  const BusinessEventsPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

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

  static const Map<String, String> _eventTypeLabels = <String, String>{
    'trade_night': 'Trade night',
    'tournament': 'Tournament',
    'pre_release': 'Pre-release',
    'release_day': 'Release day',
    'giveaway': 'Giveaway',
    'meetup': 'Meetup',
    'other': 'Other event',
  };

  final BusinessProfileService _service = BusinessProfileService();

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _canManage {
    return _currentUid.isNotEmpty && _currentUid == widget.profile.ownerUid;
  }

  bool get _canCreateEvents {
    return _canManage && widget.profile.premiumIsActive;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not set';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} at $hour:$minute';
  }

  Future<DateTime?> _pickDateTime({
    required BuildContext pickerContext,
    required DateTime initialDateTime,
  }) async {
    final date = await showDatePicker(
      context: pickerContext,
      initialDate: initialDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (date == null || !pickerContext.mounted) return null;

    final time = await showTimePicker(
      context: pickerContext,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );

    if (time == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _openEventSheet({BusinessEvent? existingEvent}) async {
    if (!_canCreateEvents) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business Pro must be active before adding events.'),
        ),
      );
      return;
    }

    final titleController = TextEditingController(
      text: existingEvent?.title ?? '',
    );
    final descriptionController = TextEditingController(
      text: existingEvent?.description ?? '',
    );
    final locationController = TextEditingController(
      text: existingEvent?.location ??
          (widget.profile.hasPhysicalShop
              ? widget.profile.linkedShopName
              : widget.profile.displayLocation),
    );
    final entryFeeController = TextEditingController(
      text: existingEvent?.entryFee ?? '',
    );
    final bookingUrlController = TextEditingController(
      text: existingEvent?.bookingUrl ?? widget.profile.website,
    );

    var selectedEventType = existingEvent?.eventType ?? 'trade_night';
    if (!_eventTypeLabels.containsKey(selectedEventType)) {
      selectedEventType = 'other';
    }

    var onlineEvent = existingEvent?.onlineEvent ?? false;
    var active = existingEvent?.active ?? true;
    var startsAt = existingEvent?.startDate ??
        DateTime.now().add(const Duration(days: 7));
    DateTime? endsAt = existingEvent?.endDate;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        var saving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveEvent() async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event title is required.')),
                );
                return;
              }

              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Event description is required.'),
                  ),
                );
                return;
              }

              if (!onlineEvent && locationController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Event location is required.'),
                  ),
                );
                return;
              }

              if (endsAt != null && endsAt!.isBefore(startsAt)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('End time must be after start time.'),
                  ),
                );
                return;
              }

              setModalState(() => saving = true);

              try {
                await _service.saveBusinessEvent(
                  profile: widget.profile,
                  eventId: existingEvent?.id,
                  title: title,
                  description: description,
                  eventType: selectedEventType,
                  location: locationController.text.trim(),
                  onlineEvent: onlineEvent,
                  entryFee: entryFeeController.text.trim(),
                  bookingUrl: bookingUrlController.text.trim(),
                  startsAt: startsAt,
                  endsAt: endsAt,
                  active: active,
                );

                if (!bottomSheetContext.mounted) return;
                Navigator.of(bottomSheetContext).pop();

                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      existingEvent == null ? 'Event added.' : 'Event saved.',
                    ),
                  ),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not save event: $error')),
                );
              } finally {
                if (context.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existingEvent == null ? 'Add event' : 'Edit event',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create a Business Pro shop event for customers to discover.',
                        style: TextStyle(
                          color: _softTextColor,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedEventType,
                        dropdownColor: _fieldColor,
                        iconEnabledColor: _softTextColor,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration('Event type'),
                        items: _eventTypeLabels.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setModalState(() => selectedEventType = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        enabled: !saving,
                        maxLength: 90,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration('Event title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        enabled: !saving,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 700,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration('Description'),
                      ),
                      const SizedBox(height: 12),
                      _DateTimeButton(
                        label: 'Start time',
                        value: _formatDateTime(startsAt),
                        onPressed: saving
                            ? null
                            : () async {
                                final picked = await _pickDateTime(
                                  pickerContext: context,
                                  initialDateTime: startsAt,
                                );
                                if (picked == null) return;
                                setModalState(() => startsAt = picked);
                              },
                      ),
                      const SizedBox(height: 10),
                      _DateTimeButton(
                        label: 'End time',
                        value: endsAt == null
                            ? 'Optional'
                            : _formatDateTime(endsAt),
                        onPressed: saving
                            ? null
                            : () async {
                                final picked = await _pickDateTime(
                                  pickerContext: context,
                                  initialDateTime: endsAt ??
                                      startsAt.add(const Duration(hours: 2)),
                                );
                                if (picked == null) return;
                                setModalState(() => endsAt = picked);
                              },
                        trailing: endsAt == null
                            ? null
                            : IconButton(
                                tooltip: 'Clear end time',
                                color: _softTextColor,
                                icon: const Icon(Icons.clear),
                                onPressed: saving
                                    ? null
                                    : () => setModalState(() => endsAt = null),
                              ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: _goldColor,
                        activeTrackColor: _goldColor.withValues(alpha: 0.35),
                        title: const Text(
                          'Online event',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: const Text(
                          'Turn this on if the event is online only.',
                          style: TextStyle(color: _softTextColor),
                        ),
                        value: onlineEvent,
                        onChanged: saving
                            ? null
                            : (value) {
                                setModalState(() => onlineEvent = value);
                              },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        enabled: !saving,
                        maxLength: 180,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration(
                          onlineEvent ? 'Online location / platform' : 'Location',
                          hintText: onlineEvent
                              ? 'Discord, website, livestream, etc.'
                              : 'Shop address or venue',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: entryFeeController,
                        enabled: !saving,
                        maxLength: 80,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration(
                          'Entry fee',
                          hintText: 'Optional',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bookingUrlController,
                        enabled: !saving,
                        maxLength: 300,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: _inputDecoration(
                          'Booking / more info link',
                          hintText: 'Optional',
                        ),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: _goldColor,
                        activeTrackColor: _goldColor.withValues(alpha: 0.35),
                        title: const Text(
                          'Show this event',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: const Text(
                          'Turn this off to hide the event without deleting it.',
                          style: TextStyle(color: _softTextColor),
                        ),
                        value: active,
                        onChanged: saving
                            ? null
                            : (value) {
                                setModalState(() => active = value);
                              },
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _goldColor,
                          foregroundColor: _backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _backgroundColor,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          saving ? 'Saving...' : 'Save event',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        onPressed: saving ? null : saveEvent,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    entryFeeController.dispose();
    bookingUrlController.dispose();
  }

  Future<void> _deleteEvent(BusinessEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete event?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will permanently delete "${event.title}".',
            style: const TextStyle(
              color: _softTextColor,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _service.deleteBusinessEvent(
        businessId: widget.profile.id,
        eventId: event.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete event: $error')),
      );
    }
  }

  InputDecoration _inputDecoration(String labelText, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: _softTextColor),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _goldColor,
        fontWeight: FontWeight.w900,
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
    final businessName = widget.profile.businessName.trim().isEmpty
        ? 'Business events'
        : widget.profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Shop Events'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              heroTag: 'add-business-event',
              backgroundColor: _goldColor,
              foregroundColor: _backgroundColor,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add event',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () => _openEventSheet(),
            )
          : null,
      body: StreamBuilder<List<BusinessEvent>>(
        stream: _service.watchBusinessEvents(widget.profile.id),
        builder: (context, snapshot) {
          final events = snapshot.data ?? const <BusinessEvent>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _EventsHeaderCard(
                businessName: businessName,
                eventCount: events.length,
                premiumActive: widget.profile.premiumIsActive,
              ),
              if (_canManage && !widget.profile.premiumIsActive) ...[
                const SizedBox(height: 14),
                const _BusinessProRequiredCard(),
              ],
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _goldColor),
                  ),
                )
              else if (events.isEmpty)
                _EmptyEventsCard(canManage: _canManage)
              else
                ...events.map(
                  (event) => _EventCard(
                    event: event,
                    canManage: _canManage,
                    onEdit: () => _openEventSheet(existingEvent: event),
                    onDelete: () => _deleteEvent(event),
                    formatDateTime: _formatDateTime,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.onPressed,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback? onPressed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _BusinessEventsPageState._fieldColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _BusinessEventsPageState._borderColor),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_outlined,
                color: _BusinessEventsPageState._goldColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: _BusinessEventsPageState._softTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.edit_calendar_outlined,
                    color: _BusinessEventsPageState._goldColor,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsHeaderCard extends StatelessWidget {
  const _EventsHeaderCard({
    required this.businessName,
    required this.eventCount,
    required this.premiumActive,
  });

  final String businessName;
  final int eventCount;
  final bool premiumActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BusinessEventsPageState._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: premiumActive
              ? _BusinessEventsPageState._goldColor
              : _BusinessEventsPageState._borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _BusinessEventsPageState._fieldColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _BusinessEventsPageState._borderColor),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: _BusinessEventsPageState._goldColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  eventCount == 0
                      ? 'Create trade nights, tournaments, release days and meetups.'
                      : '$eventCount event${eventCount == 1 ? '' : 's'} saved.',
                  style: const TextStyle(
                    color: _BusinessEventsPageState._softTextColor,
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

class _BusinessProRequiredCard extends StatelessWidget {
  const _BusinessProRequiredCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.55)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Shop Events are a Business Pro feature. Ask an admin to activate Business Pro for this business.',
              style: TextStyle(
                color: _BusinessEventsPageState._softTextColor,
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

class _EmptyEventsCard extends StatelessWidget {
  const _EmptyEventsCard({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: _BusinessEventsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessEventsPageState._borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            color: _BusinessEventsPageState._goldColor,
            size: 46,
          ),
          const SizedBox(height: 12),
          const Text(
            'No events yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canManage
                ? 'Tap Add event to create your first Business Pro event.'
                : 'This business has not posted any events yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _BusinessEventsPageState._softTextColor,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.formatDateTime,
  });

  final BusinessEvent event;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
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

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this booking link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = event.isCurrentlyVisible;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BusinessEventsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: visible
              ? _BusinessEventsPageState._goldColor
              : _BusinessEventsPageState._borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EventBadge(
                icon: Icons.event_outlined,
                label: event.eventTypeLabel,
                highlighted: true,
              ),
              _EventBadge(
                icon:
                    visible ? Icons.visibility_outlined : Icons.visibility_off,
                label: visible ? 'Visible' : 'Hidden/ended',
                highlighted: false,
              ),
              if (event.onlineEvent)
                const _EventBadge(
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
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (event.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              event.description.trim(),
              style: const TextStyle(
                color: _BusinessEventsPageState._softTextColor,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _EventInfoRow(
            icon: Icons.schedule_outlined,
            text: formatDateTime(event.startDate),
          ),
          if (event.endDate != null)
            _EventInfoRow(
              icon: Icons.timelapse_outlined,
              text: 'Ends ${formatDateTime(event.endDate)}',
            ),
          if (event.location.trim().isNotEmpty)
            _EventInfoRow(
              icon: event.onlineEvent ? Icons.language : Icons.place_outlined,
              text: event.location.trim(),
            ),
          if (event.entryFee.trim().isNotEmpty)
            _EventInfoRow(
              icon: Icons.payments_outlined,
              text: event.entryFee.trim(),
            ),
          if (event.bookingUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _BusinessEventsPageState._goldColor,
                  side: const BorderSide(color: _BusinessEventsPageState._goldColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
          if (canManage) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(
                      color: _BusinessEventsPageState._borderColor,
                    ),
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EventInfoRow extends StatelessWidget {
  const _EventInfoRow({
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
          Icon(icon, color: _BusinessEventsPageState._goldColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _BusinessEventsPageState._softTextColor,
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

class _EventBadge extends StatelessWidget {
  const _EventBadge({
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
            ? _BusinessEventsPageState._goldColor
            : _BusinessEventsPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? _BusinessEventsPageState._goldColor
              : _BusinessEventsPageState._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted
                ? _BusinessEventsPageState._backgroundColor
                : _BusinessEventsPageState._goldColor,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: highlighted
                  ? _BusinessEventsPageState._backgroundColor
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
