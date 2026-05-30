import 'package:cloud_firestore/cloud_firestore.dart';

class SavedTcgShop {
  const SavedTcgShop({
    required this.id,
    required this.userId,
    required this.shopId,
    required this.name,
    required this.address,
    required this.town,
    required this.imageUrl,
    required this.website,
    required this.phone,
    required this.lat,
    required this.lng,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String shopId;
  final String name;
  final String address;
  final String town;
  final String imageUrl;
  final String website;
  final String phone;
  final double lat;
  final double lng;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  static String cleanString(dynamic value) => (value ?? '').toString().trim();

  static double cleanDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  factory SavedTcgShop.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return SavedTcgShop(
      id: doc.id,
      userId: cleanString(data['userId']),
      shopId: cleanString(data['shopId']).isEmpty
          ? doc.id
          : cleanString(data['shopId']),
      name: cleanString(data['name']),
      address: cleanString(data['address']),
      town: cleanString(data['town']),
      imageUrl: cleanString(data['imageUrl']),
      website: cleanString(data['website']),
      phone: cleanString(data['phone']),
      lat: cleanDouble(data['lat']),
      lng: cleanDouble(data['lng']),
      createdAt: cleanTimestamp(data['createdAt']),
      updatedAt: cleanTimestamp(data['updatedAt']),
    );
  }

  String get displayName => name.isEmpty ? 'Saved shop' : name;

  String get displayAddress {
    if (address.isNotEmpty) return address;
    if (town.isNotEmpty) return town;
    return 'No address saved';
  }

  bool get hasLocation => lat != 0 || lng != 0;

  bool get hasWebsite => website.trim().isNotEmpty;

  bool get hasPhone => phone.trim().isNotEmpty;
}
