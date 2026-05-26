import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessEvent {
  const BusinessEvent({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerUid,
    required this.title,
    required this.description,
    required this.eventType,
    required this.location,
    required this.onlineEvent,
    required this.entryFee,
    required this.bookingUrl,
    required this.active,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String ownerUid;
  final String title;
  final String description;
  final String eventType;
  final String location;
  final bool onlineEvent;
  final String entryFee;
  final String bookingUrl;
  final bool active;
  final Timestamp? startsAt;
  final Timestamp? endsAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  static String cleanString(dynamic value) => (value ?? '').toString().trim();

  static bool cleanBool(dynamic value) {
    if (value is bool) return value;
    return false;
  }

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  factory BusinessEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return BusinessEvent(
      id: doc.id,
      businessId: cleanString(data['businessId']),
      businessName: cleanString(data['businessName']),
      ownerUid: cleanString(data['ownerUid']),
      title: cleanString(data['title']),
      description: cleanString(data['description']),
      eventType: cleanString(data['eventType']),
      location: cleanString(data['location']),
      onlineEvent: cleanBool(data['onlineEvent']),
      entryFee: cleanString(data['entryFee']),
      bookingUrl: cleanString(data['bookingUrl']),
      active: cleanBool(data['active']),
      startsAt: cleanTimestamp(data['startsAt']),
      endsAt: cleanTimestamp(data['endsAt']),
      createdAt: cleanTimestamp(data['createdAt']),
      updatedAt: cleanTimestamp(data['updatedAt']),
    );
  }

  String get eventTypeLabel {
    return switch (eventType) {
      'trade_night' => 'Trade night',
      'tournament' => 'Tournament',
      'pre_release' => 'Pre-release',
      'release_day' => 'Release day',
      'giveaway' => 'Giveaway',
      'meetup' => 'Meetup',
      _ => 'Shop event',
    };
  }

  DateTime? get startDate => startsAt?.toDate();

  DateTime? get endDate => endsAt?.toDate();

  bool get hasBookingUrl => bookingUrl.trim().isNotEmpty;

  bool get hasEntryFee => entryFee.trim().isNotEmpty;

  bool get isCurrentlyVisible {
    if (!active) return false;

    final now = DateTime.now();
    final start = startDate;
    final end = endDate;

    if (end != null) {
      return end.isAfter(now);
    }

    if (start == null) return true;

    // If no end time is set, keep the event visible until 24 hours after it starts.
    return start.add(const Duration(hours: 24)).isAfter(now);
  }
}
