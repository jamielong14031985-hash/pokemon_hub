import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';

import '../models/business_analytics.dart';
import '../models/business_enquiry.dart';
import '../models/business_event.dart';
import '../models/business_offer.dart';
import '../models/business_product.dart';
import '../models/business_profile.dart';
import '../models/business_review.dart';
import 'user_profile_service.dart';

class BusinessProfileService {
  BusinessProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  static const int maxFeaturedBannerImageBytes = 5 * 1024 * 1024;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _businessProfiles =>
      _firestore.collection('business_profiles');

  Stream<bool> watchCurrentUserIsAdminOrModerator() {
    final user = _auth.currentUser;
    if (user == null) return Stream<bool>.value(false);

    return _firestore.collection('app_roles').doc(user.uid).snapshots().map(
      (snapshot) {
        final role =
            (snapshot.data()?['role'] ?? '').toString().trim().toLowerCase();
        return role == 'admin' || role == 'moderator';
      },
    );
  }

  Future<bool> currentUserIsAdminOrModeratorOnce() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _firestore.collection('app_roles').doc(user.uid).get();
    final role =
        (snapshot.data()?['role'] ?? '').toString().trim().toLowerCase();
    return role == 'admin' || role == 'moderator';
  }

  Stream<BusinessProfile?> watchMyBusinessProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream<BusinessProfile?>.value(null);

    return _businessProfiles
        .where('ownerUid', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return BusinessProfile.fromDoc(snapshot.docs.first);
    });
  }


  Stream<BusinessProfile?> watchCurrentBusinessSetupProfile() {
    return watchMyBusinessProfile();
  }

  Future<BusinessProfile?> getMyBusinessProfileOnce() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _businessProfiles
        .where('ownerUid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return BusinessProfile.fromDoc(snapshot.docs.first);
  }

  Stream<List<BusinessProfile>> watchAllBusinessProfiles() {
    return _businessProfiles.snapshots().map((snapshot) {
      final profiles = snapshot.docs.map(BusinessProfile.fromDoc).toList();

      profiles.sort((a, b) {
        final aPending = a.status == 'pending';
        final bPending = b.status == 'pending';

        if (aPending != bPending) return aPending ? -1 : 1;

        final aTime = a.updatedAt?.millisecondsSinceEpoch ??
            a.createdAt?.millisecondsSinceEpoch ??
            0;
        final bTime = b.updatedAt?.millisecondsSinceEpoch ??
            b.createdAt?.millisecondsSinceEpoch ??
            0;

        if (aTime != bTime) return bTime.compareTo(aTime);

        return a.businessName
            .toLowerCase()
            .compareTo(b.businessName.toLowerCase());
      });

      return profiles;
    });
  }

  Stream<List<BusinessProfile>> watchFeaturedBusinessProfiles() {
    return _businessProfiles
        .where('status', isEqualTo: 'approved')
        .where('premiumActive', isEqualTo: true)
        .where('featuredShopEnabled', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final profiles = snapshot.docs
          .map(BusinessProfile.fromDoc)
          .where((profile) => profile.canFeatureShop)
          .toList();

      profiles.sort((a, b) {
        final aName = a.businessName.toLowerCase();
        final bName = b.businessName.toLowerCase();
        return aName.compareTo(bName);
      });

      return profiles;
    });
  }



  Stream<List<BusinessProfile>> watchMapPremiumBusinessProfiles() {
    return _businessProfiles
        .where('status', isEqualTo: 'approved')
        .where('premiumActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final profiles = snapshot.docs
          .map(BusinessProfile.fromDoc)
          .where((profile) => profile.premiumIsActive)
          .where((profile) {
            final isFeaturedPhysicalShop =
                profile.hasPhysicalShop && profile.canFeatureShop;
            final isFeaturedOnlineShop = !profile.hasPhysicalShop;

            return isFeaturedPhysicalShop || isFeaturedOnlineShop;
          })
          .toList();

      profiles.sort((a, b) {
        final aOnline = !a.hasPhysicalShop;
        final bOnline = !b.hasPhysicalShop;

        if (aOnline != bOnline) {
          return aOnline ? 1 : -1;
        }

        return a.businessName.toLowerCase().compareTo(
              b.businessName.toLowerCase(),
            );
      });

      return profiles;
    });
  }

  Stream<List<BusinessProfile>> watchFeaturedOnlineBusinessProfiles() {
    return _businessProfiles
        .where('status', isEqualTo: 'approved')
        .where('premiumActive', isEqualTo: true)
        .where('hasPhysicalShop', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final profiles = snapshot.docs
          .map(BusinessProfile.fromDoc)
          .where((profile) => profile.premiumIsActive)
          .where((profile) => !profile.hasPhysicalShop)
          .toList();

      profiles.sort((a, b) {
        final aName = a.businessName.toLowerCase();
        final bName = b.businessName.toLowerCase();
        return aName.compareTo(bName);
      });

      return profiles;
    });
  }


  Stream<List<BusinessProfile>> watchOnlineBusinessProfiles() {
    return _businessProfiles
        .where('status', isEqualTo: 'approved')
        .where('hasPhysicalShop', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final profiles = snapshot.docs
          .map(BusinessProfile.fromDoc)
          .where((profile) => !profile.hasPhysicalShop)
          .toList();

      profiles.sort((a, b) {
        final aPremium = a.premiumIsActive;
        final bPremium = b.premiumIsActive;

        if (aPremium != bPremium) {
          return aPremium ? -1 : 1;
        }

        return a.businessName.toLowerCase().compareTo(
              b.businessName.toLowerCase(),
            );
      });

      return profiles;
    });
  }




  DocumentReference<Map<String, dynamic>> _businessAnalyticsSummary(
    String businessId,
  ) {
    return _businessProfiles
        .doc(businessId)
        .collection('analytics')
        .doc('summary');
  }

  Stream<BusinessAnalytics> watchBusinessAnalytics(String businessId) {
    final cleanBusinessId = businessId.trim();

    if (cleanBusinessId.isEmpty) {
      return Stream<BusinessAnalytics>.value(
        BusinessAnalytics.empty(cleanBusinessId),
      );
    }

    return _businessAnalyticsSummary(cleanBusinessId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) {
          return BusinessAnalytics.empty(cleanBusinessId);
        }

        return BusinessAnalytics.fromDoc(snapshot, cleanBusinessId);
      },
    );
  }

  Future<void> incrementBusinessAnalyticsMetric({
    required String businessId,
    required String metric,
  }) async {
    final cleanBusinessId = businessId.trim();
    final cleanMetric = metric.trim();

    if (cleanBusinessId.isEmpty) return;

    const allowedMetrics = <String>{
      'profileViews',
      'websiteClicks',
      'phoneClicks',
      'mapViews',
      'offerViews',
      'eventViews',
      'productViews',
    };

    if (!allowedMetrics.contains(cleanMetric)) return;

    try {
      await _businessAnalyticsSummary(cleanBusinessId).set(
        <String, Object?>{
          cleanMetric: FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Analytics should never block the main user action.
    }
  }

  CollectionReference<Map<String, dynamic>> _businessEvents(
    String businessId,
  ) {
    return _businessProfiles.doc(businessId).collection('events');
  }

  Stream<List<BusinessEvent>> watchBusinessEvents(
    String businessId, {
    bool visibleOnly = false,
  }) {
    final cleanBusinessId = businessId.trim();
    if (cleanBusinessId.isEmpty) {
      return Stream<List<BusinessEvent>>.value(const <BusinessEvent>[]);
    }

    return _businessEvents(cleanBusinessId).snapshots().map((snapshot) {
      final events = snapshot.docs.map(BusinessEvent.fromDoc).where((event) {
        return !visibleOnly || event.isCurrentlyVisible;
      }).toList();

      events.sort((a, b) {
        final aStart = a.startsAt?.millisecondsSinceEpoch ?? 0;
        final bStart = b.startsAt?.millisecondsSinceEpoch ?? 0;

        if (a.isCurrentlyVisible != b.isCurrentlyVisible) {
          return a.isCurrentlyVisible ? -1 : 1;
        }

        return aStart.compareTo(bStart);
      });

      return events;
    });
  }

  Stream<List<BusinessEvent>> watchAllVisibleBusinessEvents() {
    return _firestore.collectionGroup('events').snapshots().map((snapshot) {
      final events = snapshot.docs
          .map(BusinessEvent.fromDoc)
          .where((event) => event.isCurrentlyVisible)
          .toList();

      events.sort((a, b) {
        final aStart = a.startsAt?.millisecondsSinceEpoch ?? 0;
        final bStart = b.startsAt?.millisecondsSinceEpoch ?? 0;

        if (aStart != bStart) return aStart.compareTo(bStart);

        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      return events;
    });
  }

  Future<void> saveBusinessEvent({
    required BusinessProfile profile,
    String? eventId,
    required String title,
    required String description,
    required String eventType,
    required String location,
    required bool onlineEvent,
    required String entryFee,
    required String bookingUrl,
    required DateTime startsAt,
    DateTime? endsAt,
    required bool active,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to save a business event.');
    }

    final cleanBusinessId = profile.id.trim();
    final cleanEventId = eventId?.trim() ?? '';
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanEventType = eventType.trim();
    final cleanLocation = location.trim();
    final cleanEntryFee = entryFee.trim();
    final cleanBookingUrl = bookingUrl.trim();

    if (cleanBusinessId.isEmpty) {
      throw ArgumentError('Missing business profile id.');
    }

    if (cleanTitle.isEmpty) {
      throw ArgumentError('Event title is required.');
    }

    if (cleanDescription.isEmpty) {
      throw ArgumentError('Event description is required.');
    }

    if (!onlineEvent && cleanLocation.isEmpty) {
      throw ArgumentError('Event location is required.');
    }

    if (![
      'trade_night',
      'tournament',
      'pre_release',
      'release_day',
      'giveaway',
      'meetup',
      'other',
    ].contains(cleanEventType)) {
      throw ArgumentError('Choose a valid event type.');
    }

    if (cleanTitle.length > 90) {
      throw ArgumentError('Event title must be 90 characters or fewer.');
    }

    if (cleanDescription.length > 700) {
      throw ArgumentError('Event description must be 700 characters or fewer.');
    }

    if (cleanLocation.length > 180) {
      throw ArgumentError('Event location must be 180 characters or fewer.');
    }

    if (cleanEntryFee.length > 80) {
      throw ArgumentError('Entry fee must be 80 characters or fewer.');
    }

    if (cleanBookingUrl.length > 300) {
      throw ArgumentError('Booking link must be 300 characters or fewer.');
    }

    if (endsAt != null && endsAt.isBefore(startsAt)) {
      throw ArgumentError('End time must be after start time.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canEditAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canEditAsAdmin) {
      throw StateError('Only the business owner or an admin can edit events.');
    }

    final premiumActive = profileData['premiumActive'] == true;
    if (!premiumActive && !canEditAsAdmin) {
      throw StateError('Business Pro must be active before adding events.');
    }

    final eventRef = cleanEventId.isEmpty
        ? _businessEvents(cleanBusinessId).doc()
        : _businessEvents(cleanBusinessId).doc(cleanEventId);

    final existingEvent = await eventRef.get();

    await eventRef.set({
      'businessId': cleanBusinessId,
      'businessName': (profileData['businessName'] ?? profile.businessName)
          .toString()
          .trim(),
      'ownerUid': ownerUid,
      'title': cleanTitle,
      'description': cleanDescription,
      'eventType': cleanEventType,
      'location': cleanLocation,
      'onlineEvent': onlineEvent,
      'entryFee': cleanEntryFee,
      'bookingUrl': cleanBookingUrl,
      'active': active,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': endsAt == null ? null : Timestamp.fromDate(endsAt),
      'createdAt': existingEvent.exists
          ? (existingEvent.data()?['createdAt'] ?? FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBusinessEvent({
    required String businessId,
    required String eventId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete a business event.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanEventId = eventId.trim();

    if (cleanBusinessId.isEmpty || cleanEventId.isEmpty) {
      throw ArgumentError('Missing event id.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canDeleteAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canDeleteAsAdmin) {
      throw StateError('Only the business owner or an admin can delete events.');
    }

    await _businessEvents(cleanBusinessId).doc(cleanEventId).delete();
  }



  CollectionReference<Map<String, dynamic>> _businessEnquiries(
    String businessId,
  ) {
    return _businessProfiles.doc(businessId).collection('enquiries');
  }

  Stream<List<BusinessEnquiry>> watchBusinessEnquiries(String businessId) {
    final cleanBusinessId = businessId.trim();
    if (cleanBusinessId.isEmpty) {
      return Stream<List<BusinessEnquiry>>.value(const <BusinessEnquiry>[]);
    }

    return _businessEnquiries(cleanBusinessId).snapshots().map((snapshot) {
      final enquiries = snapshot.docs.map(BusinessEnquiry.fromDoc).toList();

      enquiries.sort((a, b) {
        final aOpen = a.status == 'open';
        final bOpen = b.status == 'open';

        if (aOpen != bOpen) return aOpen ? -1 : 1;

        final aTime = a.updatedAt?.millisecondsSinceEpoch ??
            a.createdAt?.millisecondsSinceEpoch ??
            0;
        final bTime = b.updatedAt?.millisecondsSinceEpoch ??
            b.createdAt?.millisecondsSinceEpoch ??
            0;

        return bTime.compareTo(aTime);
      });

      return enquiries;
    });
  }

  Future<void> submitBusinessEnquiry({
    required BusinessProfile profile,
    required String enquiryType,
    required String subject,
    required String message,
    required String contactEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to send an enquiry.');
    }

    final cleanBusinessId = profile.id.trim();
    final cleanEnquiryType = enquiryType.trim();
    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    final cleanContactEmail = contactEmail.trim();

    if (cleanBusinessId.isEmpty) {
      throw ArgumentError('Missing business profile id.');
    }

    if (profile.ownerUid == user.uid) {
      throw StateError('You cannot send an enquiry to your own business.');
    }

    if (!['stock', 'event', 'product', 'trade', 'general']
        .contains(cleanEnquiryType)) {
      throw ArgumentError('Choose a valid enquiry type.');
    }

    if (cleanSubject.isEmpty) {
      throw ArgumentError('Subject is required.');
    }

    if (cleanMessage.isEmpty) {
      throw ArgumentError('Message is required.');
    }

    if (cleanSubject.length > 120) {
      throw ArgumentError('Subject must be 120 characters or fewer.');
    }

    if (cleanMessage.length > 1000) {
      throw ArgumentError('Message must be 1000 characters or fewer.');
    }

    if (cleanContactEmail.length > 200) {
      throw ArgumentError('Contact email must be 200 characters or fewer.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final businessOwnerUid = (profileData['ownerUid'] ?? profile.ownerUid)
        .toString()
        .trim();

    if (businessOwnerUid == user.uid) {
      throw StateError('You cannot send an enquiry to your own business.');
    }

    final senderName = await _reviewerDisplayName(user);
    final fallbackEmail = user.email?.trim() ?? '';

    await _businessEnquiries(cleanBusinessId).doc().set({
      'businessId': cleanBusinessId,
      'businessName': (profileData['businessName'] ?? profile.businessName)
          .toString()
          .trim(),
      'businessOwnerUid': businessOwnerUid,
      'senderUid': user.uid,
      'senderName': senderName,
      'senderEmail': cleanContactEmail.isEmpty ? fallbackEmail : cleanContactEmail,
      'enquiryType': cleanEnquiryType,
      'subject': cleanSubject,
      'message': cleanMessage,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt': null,
    });
  }

  Future<void> updateBusinessEnquiryStatus({
    required String businessId,
    required String enquiryId,
    required String status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to update an enquiry.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanEnquiryId = enquiryId.trim();
    final cleanStatus = status.trim();

    if (cleanBusinessId.isEmpty || cleanEnquiryId.isEmpty) {
      throw ArgumentError('Missing enquiry id.');
    }

    if (!['open', 'replied', 'closed'].contains(cleanStatus)) {
      throw ArgumentError('Choose a valid enquiry status.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canUpdateAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canUpdateAsAdmin) {
      throw StateError('Only the business owner or an admin can update enquiries.');
    }

    await _businessEnquiries(cleanBusinessId).doc(cleanEnquiryId).update({
      'status': cleanStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt':
          cleanStatus == 'closed' ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<void> deleteBusinessEnquiry({
    required String businessId,
    required String enquiryId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete an enquiry.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanEnquiryId = enquiryId.trim();

    if (cleanBusinessId.isEmpty || cleanEnquiryId.isEmpty) {
      throw ArgumentError('Missing enquiry id.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canDeleteAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canDeleteAsAdmin) {
      throw StateError('Only the business owner or an admin can delete enquiries.');
    }

    await _businessEnquiries(cleanBusinessId).doc(cleanEnquiryId).delete();
  }

  CollectionReference<Map<String, dynamic>> _businessProducts(
    String businessId,
  ) {
    return _businessProfiles.doc(businessId).collection('products');
  }

  Stream<List<BusinessProduct>> watchBusinessProducts(
    String businessId, {
    bool visibleOnly = false,
  }) {
    final cleanBusinessId = businessId.trim();
    if (cleanBusinessId.isEmpty) {
      return Stream<List<BusinessProduct>>.value(const <BusinessProduct>[]);
    }

    return _businessProducts(cleanBusinessId).snapshots().map((snapshot) {
      final products =
          snapshot.docs.map(BusinessProduct.fromDoc).where((product) {
        return !visibleOnly || product.isVisible;
      }).toList();

      products.sort((a, b) {
        if (a.isVisible != b.isVisible) return a.isVisible ? -1 : 1;
        if (a.featured != b.featured) return a.featured ? -1 : 1;

        final aTime = a.updatedAt?.millisecondsSinceEpoch ??
            a.createdAt?.millisecondsSinceEpoch ??
            0;
        final bTime = b.updatedAt?.millisecondsSinceEpoch ??
            b.createdAt?.millisecondsSinceEpoch ??
            0;

        return bTime.compareTo(aTime);
      });

      return products;
    });
  }

  Future<void> saveBusinessProduct({
    required BusinessProfile profile,
    String? productId,
    required String name,
    required String description,
    required String category,
    required String price,
    required String imageUrl,
    required String buyUrl,
    required bool active,
    required bool featured,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to save a business product.');
    }

    final cleanBusinessId = profile.id.trim();
    final cleanProductId = productId?.trim() ?? '';
    final cleanName = name.trim();
    final cleanDescription = description.trim();
    final cleanCategory = category.trim();
    final cleanPrice = price.trim();
    final cleanImageUrl = imageUrl.trim();
    final cleanBuyUrl = buyUrl.trim();

    if (cleanBusinessId.isEmpty) {
      throw ArgumentError('Missing business profile id.');
    }

    if (cleanName.isEmpty) {
      throw ArgumentError('Product name is required.');
    }

    if (cleanDescription.isEmpty) {
      throw ArgumentError('Product description is required.');
    }

    if (![
      'sealed',
      'singles',
      'accessories',
      'pre_order',
      'new_arrival',
      'deal',
      'other',
    ].contains(cleanCategory)) {
      throw ArgumentError('Choose a valid product category.');
    }

    if (cleanName.length > 120) {
      throw ArgumentError('Product name must be 120 characters or fewer.');
    }

    if (cleanDescription.length > 700) {
      throw ArgumentError('Product description must be 700 characters or fewer.');
    }

    if (cleanPrice.length > 40) {
      throw ArgumentError('Price must be 40 characters or fewer.');
    }

    if (cleanImageUrl.length > 500) {
      throw ArgumentError('Product image URL must be 500 characters or fewer.');
    }

    if (cleanBuyUrl.length > 500) {
      throw ArgumentError('Buy link must be 500 characters or fewer.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canEditAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canEditAsAdmin) {
      throw StateError('Only the business owner or an admin can edit products.');
    }

    final premiumActive = profileData['premiumActive'] == true;
    if (!premiumActive && !canEditAsAdmin) {
      throw StateError('Business Pro must be active before adding products.');
    }

    final productRef = cleanProductId.isEmpty
        ? _businessProducts(cleanBusinessId).doc()
        : _businessProducts(cleanBusinessId).doc(cleanProductId);

    final existingProduct = await productRef.get();
    final existingProductData = existingProduct.data() ?? <String, dynamic>{};

    await productRef.set({
      'businessId': cleanBusinessId,
      'businessName': (profileData['businessName'] ?? profile.businessName)
          .toString()
          .trim(),
      'ownerUid': ownerUid,
      'name': cleanName,
      'description': cleanDescription,
      'category': cleanCategory,
      'price': cleanPrice,
      'imageUrl': cleanImageUrl,
      'buyUrl': cleanBuyUrl,
      'active': active,
      'featured': featured,
      'createdAt': existingProduct.exists
          ? (existingProductData['createdAt'] ?? FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBusinessProduct({
    required String businessId,
    required String productId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete a business product.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanProductId = productId.trim();

    if (cleanBusinessId.isEmpty || cleanProductId.isEmpty) {
      throw ArgumentError('Missing product id.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canDeleteAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canDeleteAsAdmin) {
      throw StateError('Only the business owner or an admin can delete products.');
    }

    await _businessProducts(cleanBusinessId).doc(cleanProductId).delete();
  }

  CollectionReference<Map<String, dynamic>> _businessOffers(
    String businessId,
  ) {
    return _businessProfiles.doc(businessId).collection('offers');
  }

  Stream<List<BusinessOffer>> watchBusinessOffers(
    String businessId, {
    bool visibleOnly = false,
  }) {
    final cleanBusinessId = businessId.trim();
    if (cleanBusinessId.isEmpty) {
      return Stream<List<BusinessOffer>>.value(const <BusinessOffer>[]);
    }

    return _businessOffers(cleanBusinessId).snapshots().map((snapshot) {
      final offers = snapshot.docs.map(BusinessOffer.fromDoc).where((offer) {
        return !visibleOnly || offer.isCurrentlyVisible;
      }).toList();

      offers.sort((a, b) {
        if (a.isCurrentlyVisible != b.isCurrentlyVisible) {
          return a.isCurrentlyVisible ? -1 : 1;
        }

        final aTime = a.updatedAt?.millisecondsSinceEpoch ??
            a.createdAt?.millisecondsSinceEpoch ??
            0;
        final bTime = b.updatedAt?.millisecondsSinceEpoch ??
            b.createdAt?.millisecondsSinceEpoch ??
            0;
        return bTime.compareTo(aTime);
      });

      return offers;
    });
  }


  Stream<List<BusinessOffer>> watchAllVisibleBusinessOffers() {
    return _firestore.collectionGroup('offers').snapshots().map((snapshot) {
      final offers = snapshot.docs
          .map(BusinessOffer.fromDoc)
          .where((offer) => offer.isCurrentlyVisible)
          .toList();

      offers.sort((a, b) {
        final aTime = a.updatedAt?.millisecondsSinceEpoch ??
            a.createdAt?.millisecondsSinceEpoch ??
            0;
        final bTime = b.updatedAt?.millisecondsSinceEpoch ??
            b.createdAt?.millisecondsSinceEpoch ??
            0;

        if (aTime != bTime) return bTime.compareTo(aTime);

        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      return offers;
    });
  }

  Future<void> saveBusinessOffer({
    required BusinessProfile profile,
    String? offerId,
    required String title,
    required String description,
    required String category,
    required String code,
    required String websiteUrl,
    required bool active,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to save a business offer.');
    }

    final cleanBusinessId = profile.id.trim();
    final cleanOfferId = offerId?.trim() ?? '';
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanCategory = category.trim();
    final cleanCode = code.trim();
    final cleanWebsiteUrl = websiteUrl.trim();

    if (cleanBusinessId.isEmpty) {
      throw ArgumentError('Missing business profile id.');
    }

    if (cleanTitle.isEmpty) {
      throw ArgumentError('Offer title is required.');
    }

    if (cleanDescription.isEmpty) {
      throw ArgumentError('Offer description is required.');
    }

    if (!['discount', 'new_stock', 'event', 'announcement']
        .contains(cleanCategory)) {
      throw ArgumentError('Choose a valid offer type.');
    }

    if (cleanTitle.length > 90) {
      throw ArgumentError('Offer title must be 90 characters or fewer.');
    }

    if (cleanDescription.length > 500) {
      throw ArgumentError('Offer description must be 500 characters or fewer.');
    }

    if (cleanCode.length > 40) {
      throw ArgumentError('Offer code must be 40 characters or fewer.');
    }

    if (cleanWebsiteUrl.length > 300) {
      throw ArgumentError('Offer website link must be 300 characters or fewer.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canEditAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canEditAsAdmin) {
      throw StateError('Only the business owner or an admin can edit offers.');
    }

    final premiumActive = profileData['premiumActive'] == true;
    if (!premiumActive && !canEditAsAdmin) {
      throw StateError('Business Pro must be active before adding offers.');
    }

    final offerRef = cleanOfferId.isEmpty
        ? _businessOffers(cleanBusinessId).doc()
        : _businessOffers(cleanBusinessId).doc(cleanOfferId);

    final existingOffer = await offerRef.get();

    await offerRef.set({
      'businessId': cleanBusinessId,
      'businessName': (profileData['businessName'] ?? profile.businessName)
          .toString()
          .trim(),
      'ownerUid': ownerUid,
      'title': cleanTitle,
      'description': cleanDescription,
      'category': cleanCategory,
      'code': cleanCode,
      'websiteUrl': cleanWebsiteUrl,
      'active': active,
      'startsAt': null,
      'endsAt': null,
      'createdAt': existingOffer.exists
          ? (existingOffer.data()?['createdAt'] ?? FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBusinessOffer({
    required String businessId,
    required String offerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete a business offer.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanOfferId = offerId.trim();

    if (cleanBusinessId.isEmpty || cleanOfferId.isEmpty) {
      throw ArgumentError('Missing offer id.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canDeleteAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canDeleteAsAdmin) {
      throw StateError('Only the business owner or an admin can delete offers.');
    }

    await _businessOffers(cleanBusinessId).doc(cleanOfferId).delete();
  }

  CollectionReference<Map<String, dynamic>> _businessReviews(
    String businessId,
  ) {
    return _businessProfiles.doc(businessId).collection('reviews');
  }

  Stream<List<BusinessReview>> watchBusinessReviews(String businessId) {
    final cleanBusinessId = businessId.trim();
    if (cleanBusinessId.isEmpty) {
      return Stream<List<BusinessReview>>.value(const <BusinessReview>[]);
    }

    return _businessReviews(cleanBusinessId).snapshots().map((snapshot) {
      final reviews = snapshot.docs.map(BusinessReview.fromDoc).toList();

      reviews.sort((a, b) {
        final aTime = a.updatedAt?.millisecondsSinceEpoch ??
            a.createdAt?.millisecondsSinceEpoch ??
            0;
        final bTime = b.updatedAt?.millisecondsSinceEpoch ??
            b.createdAt?.millisecondsSinceEpoch ??
            0;
        return bTime.compareTo(aTime);
      });

      return reviews;
    });
  }

  Stream<BusinessReview?> watchMyBusinessReview(String businessId) {
    final user = _auth.currentUser;
    final cleanBusinessId = businessId.trim();

    if (user == null || cleanBusinessId.isEmpty) {
      return Stream<BusinessReview?>.value(null);
    }

    return _businessReviews(cleanBusinessId)
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return BusinessReview.fromDoc(snapshot);
    });
  }

  Future<void> saveBusinessReview({
    required String businessId,
    required String businessName,
    required String ownerUid,
    required int stars,
    required String comment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to review a business.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanComment = comment.trim();

    if (cleanBusinessId.isEmpty) {
      throw ArgumentError('Missing business id.');
    }

    if (ownerUid.trim() == user.uid) {
      throw StateError('You cannot review your own business.');
    }

    if (stars < 1 || stars > 5) {
      throw ArgumentError('Choose a rating between 1 and 5 stars.');
    }

    if (cleanComment.isEmpty) {
      throw ArgumentError('Review comment is required.');
    }

    if (cleanComment.length > 500) {
      throw ArgumentError('Review comment must be 500 characters or fewer.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final savedOwnerUid = (profileData['ownerUid'] ?? '').toString();
    if (savedOwnerUid == user.uid) {
      throw StateError('You cannot review your own business.');
    }

    final reviewerName = await _reviewerDisplayName(user);
    final reviewRef = _businessReviews(cleanBusinessId).doc(user.uid);
    final existingReview = await reviewRef.get();
    final existingReviewData = existingReview.data() ?? <String, dynamic>{};

    await reviewRef.set({
      'businessId': cleanBusinessId,
      'businessName': businessName.trim().isEmpty
          ? (profileData['businessName'] ?? '').toString().trim()
          : businessName.trim(),
      'reviewerUid': user.uid,
      'reviewerName': reviewerName,
      'stars': stars,
      'comment': cleanComment,
      'businessReply': existingReview.exists
          ? (existingReviewData['businessReply'] ?? '')
          : '',
      'businessReplyByUid': existingReview.exists
          ? (existingReviewData['businessReplyByUid'] ?? '')
          : '',
      'businessReplyCreatedAt': existingReview.exists
          ? existingReviewData['businessReplyCreatedAt']
          : null,
      'businessReplyUpdatedAt': existingReview.exists
          ? existingReviewData['businessReplyUpdatedAt']
          : null,
      'createdAt': existingReview.exists
          ? (existingReviewData['createdAt'] ?? FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  Future<void> saveBusinessReviewReply({
    required String businessId,
    required String reviewId,
    required String reply,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to reply to a review.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanReviewId = reviewId.trim();
    final cleanReply = reply.trim();

    if (cleanBusinessId.isEmpty || cleanReviewId.isEmpty) {
      throw ArgumentError('Missing review id.');
    }

    if (cleanReply.isEmpty) {
      throw ArgumentError('Reply is required.');
    }

    if (cleanReply.length > 500) {
      throw ArgumentError('Reply must be 500 characters or fewer.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canReplyAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canReplyAsAdmin) {
      throw StateError('Only the business owner or an admin can reply.');
    }

    final reviewRef = _businessReviews(cleanBusinessId).doc(cleanReviewId);
    final reviewSnapshot = await reviewRef.get();

    if (!reviewSnapshot.exists) {
      throw StateError('This review no longer exists.');
    }

    final data = reviewSnapshot.data() ?? <String, dynamic>{};
    final existingCreatedAt = data['businessReplyCreatedAt'];

    await reviewRef.update({
      'businessReply': cleanReply,
      'businessReplyByUid': user.uid,
      'businessReplyCreatedAt': existingCreatedAt is Timestamp
          ? existingCreatedAt
          : FieldValue.serverTimestamp(),
      'businessReplyUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBusinessReviewReply({
    required String businessId,
    required String reviewId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete a review reply.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanReviewId = reviewId.trim();

    if (cleanBusinessId.isEmpty || cleanReviewId.isEmpty) {
      throw ArgumentError('Missing review id.');
    }

    final profileSnapshot = await _businessProfiles.doc(cleanBusinessId).get();
    if (!profileSnapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final profileData = profileSnapshot.data() ?? <String, dynamic>{};
    final ownerUid = (profileData['ownerUid'] ?? '').toString();
    final canDeleteAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canDeleteAsAdmin) {
      throw StateError('Only the business owner or an admin can delete replies.');
    }

    await _businessReviews(cleanBusinessId).doc(cleanReviewId).update({
      'businessReply': '',
      'businessReplyByUid': '',
      'businessReplyCreatedAt': null,
      'businessReplyUpdatedAt': null,
    });
  }

  Future<void> deleteBusinessReview({
    required String businessId,
    required String reviewId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete a review.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanReviewId = reviewId.trim();

    if (cleanBusinessId.isEmpty || cleanReviewId.isEmpty) {
      throw ArgumentError('Missing review id.');
    }

    await _businessReviews(cleanBusinessId).doc(cleanReviewId).delete();
  }

  Future<String> _reviewerDisplayName(User user) async {
    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final username = (data['username'] ?? '').toString().trim();
      if (username.isNotEmpty) return username;
    } catch (_) {
      // Fall back to email/displayName below.
    }

    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;

    final email = user.email?.trim() ?? '';
    if (email.contains('@')) return email.split('@').first;

    return 'PocketChase user';
  }

  Future<void> saveMyBusinessProfile({
    String? businessProfileId,
    required String businessName,
    required String description,
    required String linkedShopId,
    required String linkedShopName,
    required bool hasPhysicalShop,
    required String website,
    required String phone,
    required String town,
    required String county,
    Uint8List? featuredImageBytes,
    String featuredImageFileName = 'featured_banner.jpg',
    bool removeFeaturedImage = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to create a business profile.');
    }

    final cleanBusinessName = businessName.trim();
    final cleanBusinessProfileId = businessProfileId?.trim() ?? '';

    if (cleanBusinessName.isEmpty) {
      throw ArgumentError('Business name is required.');
    }

    if (description.trim().isEmpty) {
      throw ArgumentError('Business description is required.');
    }

    if (website.trim().isEmpty) {
      throw ArgumentError('Business website is required.');
    }

    if (phone.trim().isEmpty) {
      throw ArgumentError('Business phone number is required.');
    }

    if (town.trim().isEmpty) {
      throw ArgumentError('Business town is required.');
    }

    if (county.trim().isEmpty) {
      throw ArgumentError('Business county is required.');
    }

    if (featuredImageBytes != null &&
        featuredImageBytes.lengthInBytes > maxFeaturedBannerImageBytes) {
      throw ArgumentError('The featured banner image must be 5MB or smaller.');
    }

    final cleanLinkedShopId = linkedShopId.trim();
    final cleanLinkedShopName = linkedShopName.trim();

    if (hasPhysicalShop && cleanLinkedShopId.isEmpty) {
      throw ArgumentError(
        'If your business has a physical shop, you must link it to a TCG Shop Map listing first.',
      );
    }

    final existingProfile = cleanBusinessProfileId.isEmpty
        ? await getMyBusinessProfileOnce()
        : null;

    final profileRef = cleanBusinessProfileId.isNotEmpty
        ? _businessProfiles.doc(cleanBusinessProfileId)
        : existingProfile == null
            ? _businessProfiles.doc()
            : _businessProfiles.doc(existingProfile.id);

    final snapshot = await profileRef.get();

    if (snapshot.exists) {
      final data = snapshot.data() ?? <String, dynamic>{};
      final ownerUid = (data['ownerUid'] ?? '').toString();
      final canEditAsAdmin = await currentUserIsAdminOrModeratorOnce();

      if (ownerUid != user.uid && !canEditAsAdmin) {
        throw StateError('You can only edit your own business profile.');
      }

      final updateData = <String, Object?>{
        'businessName': cleanBusinessName,
        'businessNameLower': cleanBusinessName.toLowerCase(),
        'description': description.trim(),
        'linkedShopId': cleanLinkedShopId,
        'linkedShopName': cleanLinkedShopName,
        'hasPhysicalShop': hasPhysicalShop,
        'website': website.trim(),
        'phone': phone.trim(),
        'town': town.trim(),
        'townLower': town.trim().toLowerCase(),
        'county': county.trim(),
        'countyLower': county.trim().toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (removeFeaturedImage) {
        updateData['bannerUrl'] = '';
      } else if (featuredImageBytes != null && featuredImageBytes.isNotEmpty) {
        updateData['bannerUrl'] = await _uploadFeaturedBannerImage(
          userId: ownerUid.isEmpty ? user.uid : ownerUid,
          businessProfileId: profileRef.id,
          bytes: featuredImageBytes,
          fileName: featuredImageFileName,
        );
      }

      await profileRef.update(updateData);

      await UserProfileService.markBusinessProfileCreated(
        uid: user.uid,
        created: true,
      );

      return;
    }

    String bannerUrl = '';

    if (!removeFeaturedImage &&
        featuredImageBytes != null &&
        featuredImageBytes.isNotEmpty) {
      bannerUrl = await _uploadFeaturedBannerImage(
        userId: user.uid,
        businessProfileId: profileRef.id,
        bytes: featuredImageBytes,
        fileName: featuredImageFileName,
      );
    }

    await profileRef.set({
      'ownerUid': user.uid,
      'ownerEmail': user.email ?? '',
      'businessName': cleanBusinessName,
      'businessNameLower': cleanBusinessName.toLowerCase(),
      'description': description.trim(),
      'linkedShopId': cleanLinkedShopId,
      'linkedShopName': cleanLinkedShopName,
      'hasPhysicalShop': hasPhysicalShop,
      'website': website.trim(),
      'phone': phone.trim(),
      'town': town.trim(),
      'townLower': town.trim().toLowerCase(),
      'county': county.trim(),
      'countyLower': county.trim().toLowerCase(),
      'logoUrl': '',
      'bannerUrl': bannerUrl,
      'status': 'approved',
      'verified': false,
      'premiumActive': false,
      'premiumExpiresAt': null,
      'premiumSource': '',
      'featuredShopEnabled': false,
      'autoFeaturePosts': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await UserProfileService.markBusinessProfileCreated(
      uid: user.uid,
      created: true,
    );
  }

  Future<void> deleteBusinessProfile(String businessProfileId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete a business profile.');
    }

    final cleanBusinessProfileId = businessProfileId.trim();
    if (cleanBusinessProfileId.isEmpty) {
      throw ArgumentError('Missing business profile id.');
    }

    final profileRef = _businessProfiles.doc(cleanBusinessProfileId);
    final snapshot = await profileRef.get();

    if (!snapshot.exists) {
      throw StateError('This business profile no longer exists.');
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final ownerUid = (data['ownerUid'] ?? '').toString();
    final canDeleteAsAdmin = await currentUserIsAdminOrModeratorOnce();

    if (ownerUid != user.uid && !canDeleteAsAdmin) {
      throw StateError('Only the owner or an admin can delete this profile.');
    }

    await profileRef.delete();
  }

  Future<Map<String, Object?>> buildPremiumPostFieldsForCurrentUser() async {
    final profile = await getMyBusinessProfileOnce();

    if (profile == null || !profile.canAutoFeaturePosts) {
      return const <String, Object?>{
        'isBusinessPost': false,
        'businessProfileId': '',
        'businessName': '',
        'businessPremiumFeatured': false,
      };
    }

    return <String, Object?>{
      'isBusinessPost': true,
      'businessProfileId': profile.id,
      'businessName': profile.businessName,
      'businessPremiumFeatured': true,
      'featuredByBusinessPremium': true,
      'featuredUntil': profile.premiumExpiresAt,
    };
  }

  Future<void> adminUpdateBusinessPremium({
    required String businessProfileId,
    required bool approved,
    required bool verified,
    required bool premiumActive,
    required bool featuredShopEnabled,
    required bool autoFeaturePosts,
    Timestamp? premiumExpiresAt,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in.');
    }

    final isAdminOrModerator = await currentUserIsAdminOrModeratorOnce();
    if (!isAdminOrModerator) {
      throw StateError('Only admins and moderators can change premium flags.');
    }

    await _businessProfiles.doc(businessProfileId.trim()).update({
      'status': approved ? 'approved' : 'pending',
      'verified': verified,
      'premiumActive': premiumActive,
      'premiumExpiresAt': premiumExpiresAt,
      'premiumSource': premiumActive ? 'manual_admin_stage_1' : '',
      'featuredShopEnabled': featuredShopEnabled,
      'autoFeaturePosts': autoFeaturePosts,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }
  Future<String> _uploadFeaturedBannerImage({
    required String userId,
    required String businessProfileId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final contentType =
        lookupMimeType(fileName, headerBytes: bytes) ?? 'image/jpeg';
    final extension = _extensionForContentType(contentType);
    final storagePath =
        'business_profiles/$userId/$businessProfileId/featured_banner.$extension';

    final ref = _storage.ref(storagePath);
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{
          'userId': userId,
          'businessProfileId': businessProfileId,
          'feature': 'business_featured_banner',
        },
      ),
    );

    return uploadTask.ref.getDownloadURL();
  }

  String _extensionForContentType(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/heic':
      case 'image/heif':
        return 'heic';
      case 'image/jpeg':
      case 'image/jpg':
      default:
        return 'jpg';
    }
  }

}
