import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessAnalytics {
  const BusinessAnalytics({
    required this.businessId,
    required this.profileViews,
    required this.websiteClicks,
    required this.phoneClicks,
    required this.mapViews,
    required this.offerViews,
    required this.eventViews,
    this.updatedAt,
  });

  final String businessId;
  final int profileViews;
  final int websiteClicks;
  final int phoneClicks;
  final int mapViews;
  final int offerViews;
  final int eventViews;
  final Timestamp? updatedAt;

  static int cleanInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  factory BusinessAnalytics.empty(String businessId) {
    return BusinessAnalytics(
      businessId: businessId,
      profileViews: 0,
      websiteClicks: 0,
      phoneClicks: 0,
      mapViews: 0,
      offerViews: 0,
      eventViews: 0,
    );
  }

  factory BusinessAnalytics.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String businessId,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return BusinessAnalytics(
      businessId: businessId,
      profileViews: cleanInt(data['profileViews']),
      websiteClicks: cleanInt(data['websiteClicks']),
      phoneClicks: cleanInt(data['phoneClicks']),
      mapViews: cleanInt(data['mapViews']),
      offerViews: cleanInt(data['offerViews']),
      eventViews: cleanInt(data['eventViews']),
      updatedAt: cleanTimestamp(data['updatedAt']),
    );
  }

  int get totalEngagement {
    return profileViews +
        websiteClicks +
        phoneClicks +
        mapViews +
        offerViews +
        eventViews;
  }
}
