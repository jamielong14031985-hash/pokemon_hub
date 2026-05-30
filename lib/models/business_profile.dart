import 'package:cloud_firestore/cloud_firestore.dart';


class BusinessOpeningHours {
  const BusinessOpeningHours({
    required this.dayKey,
    required this.dayLabel,
    required this.closed,
    required this.open,
    required this.close,
  });

  final String dayKey;
  final String dayLabel;
  final bool closed;
  final String open;
  final String close;

  static const List<String> dayKeys = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const Map<String, String> dayLabels = <String, String>{
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };

  static BusinessOpeningHours defaultForDay(String dayKey) {
    final cleanDayKey = dayKeys.contains(dayKey) ? dayKey : 'monday';

    return BusinessOpeningHours(
      dayKey: cleanDayKey,
      dayLabel: dayLabels[cleanDayKey] ?? cleanDayKey,
      closed: false,
      open: '',
      close: '',
    );
  }

  static BusinessOpeningHours fromData(String dayKey, dynamic value) {
    final fallback = defaultForDay(dayKey);

    if (value is! Map) return fallback;

    final closed = value['closed'] == true;
    final open = (value['open'] ?? '').toString().trim();
    final close = (value['close'] ?? '').toString().trim();

    return BusinessOpeningHours(
      dayKey: fallback.dayKey,
      dayLabel: fallback.dayLabel,
      closed: closed,
      open: closed ? '' : open,
      close: closed ? '' : close,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'closed': closed,
      'open': closed ? '' : open.trim(),
      'close': closed ? '' : close.trim(),
    };
  }

  bool get hasTimes {
    return !closed && open.trim().isNotEmpty && close.trim().isNotEmpty;
  }

  String get displayText {
    if (closed) return 'Closed';
    if (!hasTimes) return 'Hours not set';
    return '${open.trim()} - ${close.trim()}';
  }
}


class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.ownerUid,
    required this.businessName,
    required this.description,
    required this.linkedShopId,
    required this.linkedShopName,
    required this.website,
    required this.phone,
    required this.town,
    required this.county,
    required this.logoUrl,
    required this.bannerUrl,
    required this.status,
    required this.verified,
    required this.premiumActive,
    required this.featuredShopEnabled,
    required this.autoFeaturePosts,
    this.hasPhysicalShop = false,
    this.premiumStartedAt,
    this.premiumExpiresAt,
    this.premiumAdminNotes = '',
    this.openingStatus = 'auto',
    this.openingHours = const <String, BusinessOpeningHours>{},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String businessName;
  final String description;
  final String linkedShopId;
  final String linkedShopName;
  final String website;
  final String phone;
  final String town;
  final String county;
  final String logoUrl;
  final String bannerUrl;
  final String status;
  final bool verified;
  final bool premiumActive;
  final bool featuredShopEnabled;
  final bool autoFeaturePosts;
  final bool hasPhysicalShop;
  final Timestamp? premiumStartedAt;
  final Timestamp? premiumExpiresAt;
  final String premiumAdminNotes;
  final String openingStatus;
  final Map<String, BusinessOpeningHours> openingHours;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  static String cleanString(dynamic value) => (value ?? '').toString().trim();

  static bool cleanBool(dynamic value) => value == true;

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  static String cleanOpeningStatus(dynamic value) {
    final status = cleanString(value).toLowerCase();

    if (status == 'open' || status == 'closed') {
      return status;
    }

    return 'auto';
  }

  static Map<String, BusinessOpeningHours> cleanOpeningHours(dynamic value) {
    final source = value is Map ? value : const <String, dynamic>{};

    return <String, BusinessOpeningHours>{
      for (final dayKey in BusinessOpeningHours.dayKeys)
        dayKey: BusinessOpeningHours.fromData(dayKey, source[dayKey]),
    };
  }

  factory BusinessProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return BusinessProfile(
      id: doc.id,
      ownerUid: cleanString(data['ownerUid']),
      businessName: cleanString(data['businessName']),
      description: cleanString(data['description']),
      linkedShopId: cleanString(data['linkedShopId']),
      linkedShopName: cleanString(data['linkedShopName']),
      website: cleanString(data['website']),
      phone: cleanString(data['phone']),
      town: cleanString(data['town']),
      county: cleanString(data['county']),
      logoUrl: cleanString(data['logoUrl']),
      bannerUrl: cleanString(data['bannerUrl']),
      status: cleanString(data['status']).isEmpty
          ? 'approved'
          : cleanString(data['status']).toLowerCase(),
      verified: cleanBool(data['verified']),
      premiumActive: cleanBool(data['premiumActive']),
      featuredShopEnabled: cleanBool(data['featuredShopEnabled']),
      autoFeaturePosts: cleanBool(data['autoFeaturePosts']),
      hasPhysicalShop: cleanBool(data['hasPhysicalShop']),
      premiumStartedAt: cleanTimestamp(data['premiumStartedAt']),
      premiumExpiresAt: cleanTimestamp(data['premiumExpiresAt']),
      premiumAdminNotes: cleanString(data['premiumAdminNotes']),
      openingStatus: cleanOpeningStatus(data['openingStatus']),
      openingHours: cleanOpeningHours(data['openingHours']),
      createdAt: cleanTimestamp(data['createdAt']),
      updatedAt: cleanTimestamp(data['updatedAt']),
    );
  }

  bool get isApproved => status == 'approved';

  bool get hasLinkedShop => linkedShopId.trim().isNotEmpty;

  bool get hasFeaturedBannerImage => bannerUrl.trim().isNotEmpty;

  String get featuredBannerImageUrl => bannerUrl.trim();

  bool get physicalShopNeedsMapListing => hasPhysicalShop && !hasLinkedShop;


  bool get hasRequiredBusinessDetails {
    return businessName.trim().isNotEmpty &&
        description.trim().isNotEmpty &&
        website.trim().isNotEmpty &&
        phone.trim().isNotEmpty &&
        town.trim().isNotEmpty &&
        county.trim().isNotEmpty;
  }

  bool get setupIsComplete {
    return hasRequiredBusinessDetails && (!hasPhysicalShop || hasLinkedShop);
  }

  bool get setupComplete => setupIsComplete;

  List<String> get setupMissingReasons {
    final missing = <String>[];

    if (businessName.trim().isEmpty) {
      missing.add('Business name');
    }
    if (description.trim().isEmpty) {
      missing.add('Business description');
    }
    if (website.trim().isEmpty) {
      missing.add('Website');
    }
    if (phone.trim().isEmpty) {
      missing.add('Phone number');
    }
    if (town.trim().isEmpty) {
      missing.add('Town');
    }
    if (county.trim().isEmpty) {
      missing.add('County');
    }
    if (hasPhysicalShop && !hasLinkedShop) {
      missing.add('Linked TCG Shop Map listing');
    }

    return missing;
  }

  bool get premiumIsActive {
    if (!premiumActive) return false;

    final expiry = premiumExpiresAt;
    if (expiry == null) return true;

    return expiry.toDate().isAfter(DateTime.now());
  }

  bool get premiumIsExpired {
    if (!premiumActive) return false;

    final expiry = premiumExpiresAt;
    if (expiry == null) return false;

    return !expiry.toDate().isAfter(DateTime.now());
  }

  bool get premiumExpiresSoon {
    if (!premiumIsActive) return false;

    final expiry = premiumExpiresAt;
    if (expiry == null) return false;

    final now = DateTime.now();
    final daysLeft = expiry.toDate().difference(now).inDays;

    return daysLeft >= 0 && daysLeft <= 14;
  }

  int? get premiumDaysRemaining {
    if (!premiumIsActive) return null;

    final expiry = premiumExpiresAt;
    if (expiry == null) return null;

    return expiry.toDate().difference(DateTime.now()).inDays;
  }

  String get premiumStatusLabel {
    if (premiumIsActive) {
      if (premiumExpiresAt == null) return 'Active - no expiry';
      final days = premiumDaysRemaining;
      if (days == null) return 'Active';
      if (days <= 0) return 'Expires today';
      return 'Active - $days day${days == 1 ? '' : 's'} left';
    }

    if (premiumIsExpired) return 'Expired';

    return 'Not active';
  }


  BusinessOpeningHours openingHoursForDay(String dayKey) {
    return openingHours[dayKey] ?? BusinessOpeningHours.defaultForDay(dayKey);
  }

  bool get hasAnyOpeningHours {
    if (openingStatus == 'open' || openingStatus == 'closed') {
      return true;
    }

    return BusinessOpeningHours.dayKeys.any((dayKey) {
      final hours = openingHoursForDay(dayKey);
      return hours.closed || hours.hasTimes;
    });
  }

  bool get hasManualOpeningStatus {
    return openingStatus == 'open' || openingStatus == 'closed';
  }

  String get openingStatusLabel {
    return switch (openingStatus) {
      'open' => 'Open now',
      'closed' => 'Closed now',
      _ => 'Use opening hours',
    };
  }

  BusinessOpeningHours get todayOpeningHours {
    final weekday = DateTime.now().weekday;
    final dayKey = BusinessOpeningHours.dayKeys[weekday - 1];
    return openingHoursForDay(dayKey);
  }

  int? _minutesFromTime(String value) {
    final cleanValue = value.trim();
    final parts = cleanValue.split(':');

    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return (hour * 60) + minute;
  }

  bool? get isOpenNow {
    if (openingStatus == 'open') return true;
    if (openingStatus == 'closed') return false;

    final hours = todayOpeningHours;

    if (hours.closed) return false;
    if (!hours.hasTimes) return null;

    final openMinutes = _minutesFromTime(hours.open);
    final closeMinutes = _minutesFromTime(hours.close);

    if (openMinutes == null || closeMinutes == null) return null;

    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;

    if (openMinutes == closeMinutes) return null;

    if (openMinutes < closeMinutes) {
      return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
    }

    return nowMinutes >= openMinutes || nowMinutes < closeMinutes;
  }

  String get openStatusLabel {
    if (openingStatus == 'open') return 'Open now';
    if (openingStatus == 'closed') return 'Closed now';

    final openNow = isOpenNow;
    final today = todayOpeningHours;

    if (openNow == true) return 'Open now';
    if (openNow == false) return 'Closed now';
    if (today.closed) return 'Closed today';
    if (today.hasTimes) return 'Hours today: ${today.displayText}';

    return 'Opening hours not set';
  }

  bool get canFeatureShop {
    return isApproved &&
        premiumIsActive &&
        featuredShopEnabled &&
        linkedShopId.trim().isNotEmpty;
  }

  bool get canAutoFeaturePosts {
    return isApproved && premiumIsActive && autoFeaturePosts;
  }

  String get displayLocation {
    return [town, county]
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }
}
