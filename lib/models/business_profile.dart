import 'package:cloud_firestore/cloud_firestore.dart';

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
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  static String cleanString(dynamic value) => (value ?? '').toString().trim();

  static bool cleanBool(dynamic value) => value == true;

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
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
