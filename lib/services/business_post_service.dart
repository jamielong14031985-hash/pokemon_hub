import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../models/business_event.dart';
import '../models/business_offer.dart';
import '../models/business_product.dart';
import '../models/business_profile.dart';

class BusinessPostImageResult {
  const BusinessPostImageResult({
    required this.imageUrl,
    required this.imagePath,
  });

  final String imageUrl;
  final String imagePath;
}

class BusinessPostService {
  BusinessPostService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  static const int maxPostImageBytes = 5 * 1024 * 1024;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _businessProfiles =>
      _firestore.collection('business_profiles');

  CollectionReference<Map<String, dynamic>> _products(String businessId) =>
      _businessProfiles.doc(businessId).collection('products');

  CollectionReference<Map<String, dynamic>> _offers(String businessId) =>
      _businessProfiles.doc(businessId).collection('offers');

  CollectionReference<Map<String, dynamic>> _events(String businessId) =>
      _businessProfiles.doc(businessId).collection('events');

  Stream<List<BusinessProduct>> watchBusinessProducts(
    String businessId, {
    bool visibleOnly = false,
  }) {
    final cleanBusinessId = businessId.trim();
    if (cleanBusinessId.isEmpty) {
      return Stream<List<BusinessProduct>>.value(const <BusinessProduct>[]);
    }

    return _products(cleanBusinessId).snapshots().map((snapshot) {
      final products = snapshot.docs.map(BusinessProduct.fromDoc).where((item) {
        return !visibleOnly || item.isVisible;
      }).toList();

      products.sort((a, b) {
        if (a.featured != b.featured) return a.featured ? -1 : 1;
        final aTime = a.updatedAt?.millisecondsSinceEpoch ??
            a.createdAt?.millisecondsSinceEpoch ??
            0;
        final bTime = b.updatedAt?.millisecondsSinceEpoch ??
            b.createdAt?.millisecondsSinceEpoch ??
            0;
        if (aTime != bTime) return bTime.compareTo(aTime);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return products;
    });
  }

  Stream<List<BusinessOffer>> watchBusinessOffers(
    String businessId, {
    bool visibleOnly = false,
  }) {
    final cleanBusinessId = businessId.trim();
    if (cleanBusinessId.isEmpty) {
      return Stream<List<BusinessOffer>>.value(const <BusinessOffer>[]);
    }

    return _offers(cleanBusinessId).snapshots().map((snapshot) {
      final offers = snapshot.docs.map(BusinessOffer.fromDoc).where((item) {
        return !visibleOnly || item.isCurrentlyVisible;
      }).toList();

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

  Stream<List<BusinessEvent>> watchBusinessEvents(
    String businessId, {
    bool visibleOnly = false,
  }) {
    final cleanBusinessId = businessId.trim();
    if (cleanBusinessId.isEmpty) {
      return Stream<List<BusinessEvent>>.value(const <BusinessEvent>[]);
    }

    return _events(cleanBusinessId).snapshots().map((snapshot) {
      final events = snapshot.docs.map(BusinessEvent.fromDoc).where((item) {
        return !visibleOnly || item.isCurrentlyVisible;
      }).toList();

      events.sort((a, b) {
        final aStart = a.startsAt?.millisecondsSinceEpoch ?? 0;
        final bStart = b.startsAt?.millisecondsSinceEpoch ?? 0;

        if (a.isCurrentlyVisible != b.isCurrentlyVisible) {
          return a.isCurrentlyVisible ? -1 : 1;
        }

        if (aStart != bStart) return aStart.compareTo(bStart);
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      return events;
    });
  }

  Future<void> saveBusinessProduct({
    required BusinessProfile profile,
    String? productId,
    required String name,
    required String description,
    required String category,
    required String price,
    required String buyUrl,
    required bool active,
    required bool featured,
    XFile? pickedImage,
    required String existingImageUrl,
    required String existingImagePath,
    required bool removeImage,
  }) async {
    final user = await _assertCanManageBusiness(profile);
    _assertPremiumActive(profile);

    final cleanBusinessId = profile.id.trim();
    final ownerUid = profile.ownerUid.trim().isEmpty ? user.uid : profile.ownerUid.trim();
    final docRef = productId == null || productId.trim().isEmpty
        ? _products(cleanBusinessId).doc()
        : _products(cleanBusinessId).doc(productId.trim());

    final cleanName = name.trim();
    final cleanDescription = description.trim();
    final cleanCategory = category.trim();
    final cleanPrice = price.trim();
    final cleanBuyUrl = buyUrl.trim();

    if (cleanName.isEmpty) throw ArgumentError('Product name is required.');
    if (cleanDescription.isEmpty) {
      throw ArgumentError('Product description is required.');
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
    if (cleanBuyUrl.length > 500) {
      throw ArgumentError('Product link must be 500 characters or fewer.');
    }
    const allowedCategories = <String>{
      'sealed',
      'singles',
      'accessories',
      'pre_order',
      'new_arrival',
      'deal',
      'other',
    };
    if (!allowedCategories.contains(cleanCategory)) {
      throw ArgumentError('Choose a valid product category.');
    }

    final image = await _resolvePostImage(
      ownerUid: ownerUid,
      businessId: cleanBusinessId,
      collectionName: 'products',
      postId: docRef.id,
      pickedImage: pickedImage,
      existingImageUrl: existingImageUrl,
      existingImagePath: existingImagePath,
      removeImage: removeImage,
    );

    final data = <String, Object?>{
      'businessId': cleanBusinessId,
      'businessName': profile.businessName.trim(),
      'ownerUid': ownerUid,
      'name': cleanName,
      'description': cleanDescription,
      'category': cleanCategory,
      'price': cleanPrice,
      'imageUrl': image.imageUrl,
      'imagePath': image.imagePath,
      'buyUrl': cleanBuyUrl,
      'active': active,
      'featured': featured,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (productId == null || productId.trim().isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
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
    XFile? pickedImage,
    required String existingImageUrl,
    required String existingImagePath,
    required bool removeImage,
  }) async {
    final user = await _assertCanManageBusiness(profile);
    _assertPremiumActive(profile);

    final cleanBusinessId = profile.id.trim();
    final ownerUid = profile.ownerUid.trim().isEmpty ? user.uid : profile.ownerUid.trim();
    final docRef = offerId == null || offerId.trim().isEmpty
        ? _offers(cleanBusinessId).doc()
        : _offers(cleanBusinessId).doc(offerId.trim());

    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanCategory = category.trim();
    final cleanCode = code.trim();
    final cleanWebsiteUrl = websiteUrl.trim();

    if (cleanTitle.isEmpty) throw ArgumentError('Offer title is required.');
    if (cleanDescription.isEmpty) {
      throw ArgumentError('Offer description is required.');
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
      throw ArgumentError('Offer link must be 300 characters or fewer.');
    }
    const allowedCategories = <String>{
      'discount',
      'new_stock',
      'event',
      'announcement',
    };
    if (!allowedCategories.contains(cleanCategory)) {
      throw ArgumentError('Choose a valid offer type.');
    }

    final image = await _resolvePostImage(
      ownerUid: ownerUid,
      businessId: cleanBusinessId,
      collectionName: 'offers',
      postId: docRef.id,
      pickedImage: pickedImage,
      existingImageUrl: existingImageUrl,
      existingImagePath: existingImagePath,
      removeImage: removeImage,
    );

    final data = <String, Object?>{
      'businessId': cleanBusinessId,
      'businessName': profile.businessName.trim(),
      'ownerUid': ownerUid,
      'title': cleanTitle,
      'description': cleanDescription,
      'category': cleanCategory,
      'code': cleanCode,
      'websiteUrl': cleanWebsiteUrl,
      'imageUrl': image.imageUrl,
      'imagePath': image.imagePath,
      'active': active,
      'startsAt': null,
      'endsAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (offerId == null || offerId.trim().isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
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
    XFile? pickedImage,
    required String existingImageUrl,
    required String existingImagePath,
    required bool removeImage,
  }) async {
    final user = await _assertCanManageBusiness(profile);
    _assertPremiumActive(profile);

    final cleanBusinessId = profile.id.trim();
    final ownerUid = profile.ownerUid.trim().isEmpty ? user.uid : profile.ownerUid.trim();
    final docRef = eventId == null || eventId.trim().isEmpty
        ? _events(cleanBusinessId).doc()
        : _events(cleanBusinessId).doc(eventId.trim());

    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanEventType = eventType.trim();
    final cleanLocation = location.trim();
    final cleanEntryFee = entryFee.trim();
    final cleanBookingUrl = bookingUrl.trim();

    if (cleanTitle.isEmpty) throw ArgumentError('Event title is required.');
    if (cleanDescription.isEmpty) {
      throw ArgumentError('Event description is required.');
    }
    if (!onlineEvent && cleanLocation.isEmpty) {
      throw ArgumentError('Event location is required.');
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
    const allowedEventTypes = <String>{
      'trade_night',
      'tournament',
      'pre_release',
      'release_day',
      'giveaway',
      'meetup',
      'other',
    };
    if (!allowedEventTypes.contains(cleanEventType)) {
      throw ArgumentError('Choose a valid event type.');
    }

    final image = await _resolvePostImage(
      ownerUid: ownerUid,
      businessId: cleanBusinessId,
      collectionName: 'events',
      postId: docRef.id,
      pickedImage: pickedImage,
      existingImageUrl: existingImageUrl,
      existingImagePath: existingImagePath,
      removeImage: removeImage,
    );

    final data = <String, Object?>{
      'businessId': cleanBusinessId,
      'businessName': profile.businessName.trim(),
      'ownerUid': ownerUid,
      'title': cleanTitle,
      'description': cleanDescription,
      'eventType': cleanEventType,
      'location': onlineEvent ? '' : cleanLocation,
      'onlineEvent': onlineEvent,
      'entryFee': cleanEntryFee,
      'bookingUrl': cleanBookingUrl,
      'imageUrl': image.imageUrl,
      'imagePath': image.imagePath,
      'active': active,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': endsAt == null ? null : Timestamp.fromDate(endsAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (eventId == null || eventId.trim().isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  Future<void> deleteBusinessProduct(BusinessProduct product) async {
    await _assertCanManageBusinessId(product.businessId);
    await _deleteStoragePath(product.imagePath);
    await _products(product.businessId).doc(product.id).delete();
  }

  Future<void> deleteBusinessOffer(BusinessOffer offer) async {
    await _assertCanManageBusinessId(offer.businessId);
    await _deleteStoragePath(offer.imagePath);
    await _offers(offer.businessId).doc(offer.id).delete();
  }

  Future<void> deleteBusinessEvent(BusinessEvent event) async {
    await _assertCanManageBusinessId(event.businessId);
    await _deleteStoragePath(event.imagePath);
    await _events(event.businessId).doc(event.id).delete();
  }

  Future<User> _assertCanManageBusiness(BusinessProfile profile) async {
    final cleanBusinessId = profile.id.trim();
    if (cleanBusinessId.isEmpty) {
      throw StateError('Missing business profile id.');
    }

    return _assertCanManageBusinessId(cleanBusinessId);
  }

  Future<User> _assertCanManageBusinessId(String businessId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to manage business posts.');
    }

    final snapshot = await _businessProfiles.doc(businessId.trim()).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('This business profile no longer exists.');
    }

    final ownerUid = (data['ownerUid'] ?? '').toString().trim();
    if (ownerUid == user.uid) return user;

    final roleSnapshot = await _firestore.collection('app_roles').doc(user.uid).get();
    final role = (roleSnapshot.data()?['role'] ?? '').toString().toLowerCase();
    if (role == 'admin' || role == 'moderator') return user;

    throw StateError('Only the business owner or an admin can manage this post.');
  }

  void _assertPremiumActive(BusinessProfile profile) {
    if (!profile.premiumIsActive) {
      throw StateError('Business Pro must be active before adding posts.');
    }
  }

  Future<BusinessPostImageResult> _resolvePostImage({
    required String ownerUid,
    required String businessId,
    required String collectionName,
    required String postId,
    required XFile? pickedImage,
    required String existingImageUrl,
    required String existingImagePath,
    required bool removeImage,
  }) async {
    final cleanExistingImageUrl = existingImageUrl.trim();
    final cleanExistingImagePath = existingImagePath.trim();

    if (removeImage && pickedImage == null) {
      await _deleteStoragePath(cleanExistingImagePath);
      return const BusinessPostImageResult(imageUrl: '', imagePath: '');
    }

    if (pickedImage == null) {
      return BusinessPostImageResult(
        imageUrl: cleanExistingImageUrl,
        imagePath: cleanExistingImagePath,
      );
    }

    final bytes = await pickedImage.readAsBytes();
    if (bytes.isEmpty) throw ArgumentError('The selected image is empty.');
    if (bytes.length > maxPostImageBytes) {
      throw ArgumentError('Image must be 5MB or smaller.');
    }

    final mimeType = lookupMimeType(pickedImage.name, headerBytes: bytes) ??
        'image/jpeg';

    if (!mimeType.startsWith('image/')) {
      throw ArgumentError('Please choose an image file.');
    }

    final extension = _extensionForMimeType(mimeType);
    final cleanOwnerUid = ownerUid.trim();
    if (cleanOwnerUid.isEmpty) {
      throw ArgumentError('Missing business owner id.');
    }

    final path =
        'business_post_images/$cleanOwnerUid/$businessId/$collectionName/$postId/post_image.$extension';
    final ref = _storage.ref(path);

    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: mimeType,
        cacheControl: 'public,max-age=3600',
      ),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    if (cleanExistingImagePath.isNotEmpty && cleanExistingImagePath != path) {
      await _deleteStoragePath(cleanExistingImagePath);
    }

    return BusinessPostImageResult(imageUrl: downloadUrl, imagePath: path);
  }

  String _extensionForMimeType(String mimeType) {
    return switch (mimeType.toLowerCase()) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      _ => 'jpg',
    };
  }

  Future<void> _deleteStoragePath(String imagePath) async {
    final cleanPath = imagePath.trim();
    if (cleanPath.isEmpty) return;

    try {
      await _storage.ref(cleanPath).delete();
    } catch (_) {
      // A missing old image should not block deleting or saving the post.
    }
  }
}
