import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';

import '../models/tcg_shop.dart';

class TcgShopService {
  TcgShopService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  static const int maxShopImageBytes = 5 * 1024 * 1024;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('tcg_shops');

  CollectionReference<Map<String, dynamic>> get _submissions =>
      _firestore.collection('tcg_shop_submissions');

  Stream<List<TcgShop>> watchApprovedShops() {
    return _shops.snapshots().map(
      (snapshot) {
        final shops = snapshot.docs
            .where((doc) {
              final status = (doc.data()['status'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              return status == 'approved';
            })
            .map(TcgShop.fromDoc)
            .where((shop) => shop.hasValidLocation)
            .toList();

        shops.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

        return shops;
      },
    );
  }

  Stream<List<TcgShop>> watchPendingSubmissions() {
    return _submissions.where('status', isEqualTo: 'pending').snapshots().map(
      (snapshot) {
        final submissions = snapshot.docs.map(TcgShop.fromDoc).toList();
        submissions.sort((a, b) {
          final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });
        return submissions;
      },
    );
  }

  Future<void> submitShop({
    required String name,
    required String address,
    required String town,
    required String county,
    required String country,
    required String postcode,
    required double lat,
    required double lng,
    required List<String> games,
    required List<String> services,
    String website = '',
    String phone = '',
    Uint8List? imageBytes,
    String imageFileName = 'shop_photo.jpg',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to submit a TCG shop.');
    }

    final cleanName = name.trim();
    final cleanTown = town.trim();
    final cleanCounty = county.trim();
    final cleanPostcode = postcode.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Shop name is required.');
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw ArgumentError('Please choose a valid location on the map.');
    }

    if (imageBytes != null && imageBytes.lengthInBytes > maxShopImageBytes) {
      throw ArgumentError('The shop photo must be 5MB or smaller.');
    }

    final submissionRef = _submissions.doc();
    String imageUrl = '';
    String imagePath = '';

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final uploadResult = await _uploadShopImage(
        userId: user.uid,
        submissionId: submissionRef.id,
        bytes: imageBytes,
        fileName: imageFileName,
      );
      imageUrl = uploadResult.downloadUrl;
      imagePath = uploadResult.storagePath;
    }

    await submissionRef.set({
      'name': cleanName,
      'nameLower': cleanName.toLowerCase(),
      'address': address.trim(),
      'town': cleanTown,
      'townLower': cleanTown.toLowerCase(),
      'county': cleanCounty,
      'countyLower': cleanCounty.toLowerCase(),
      'country': country.trim().isEmpty ? 'United Kingdom' : country.trim(),
      'postcode': cleanPostcode,
      'postcodeLower': cleanPostcode.toLowerCase(),
      'lat': lat,
      'lng': lng,
      'location': GeoPoint(lat, lng),
      'games': _cleanList(games),
      'services': _cleanList(services),
      'website': website.trim(),
      'phone': phone.trim(),
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'status': 'pending',
      'submittedBy': user.uid,
      'submittedByEmail': user.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveSubmission(String submissionId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to approve a submission.');
    }

    final submissionRef = _submissions.doc(submissionId);
    final shopRef = _shops.doc(submissionId);

    await _firestore.runTransaction((transaction) async {
      final submission = await transaction.get(submissionRef);
      if (!submission.exists) {
        throw StateError('This submission no longer exists.');
      }

      final data = submission.data() ?? <String, dynamic>{};
      final approvedShop = Map<String, dynamic>.from(data)
        ..['status'] = 'approved'
        ..['approvedBy'] = user.uid
        ..['approvedAt'] = FieldValue.serverTimestamp()
        ..['updatedAt'] = FieldValue.serverTimestamp();

      transaction.set(shopRef, approvedShop);
      transaction.update(submissionRef, {
        'status': 'approved',
        'approvedBy': user.uid,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectSubmission(String submissionId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to reject a submission.');
    }

    await _submissions.doc(submissionId).update({
      'status': 'rejected',
      'rejectedBy': user.uid,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<_ShopImageUploadResult> _uploadShopImage({
    required String userId,
    required String submissionId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final contentType =
        lookupMimeType(fileName, headerBytes: bytes) ?? 'image/jpeg';
    final extension = _extensionForContentType(contentType);
    final storagePath =
        'tcg_shop_submissions/$userId/$submissionId/shop_photo.$extension';

    final ref = _storage.ref(storagePath);
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{
          'userId': userId,
          'submissionId': submissionId,
          'feature': 'tcg_shop_map',
        },
      ),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return _ShopImageUploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
    );
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

  List<String> _cleanList(List<String> values) {
    return values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}

class _ShopImageUploadResult {
  const _ShopImageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}