import 'package:cloud_firestore/cloud_firestore.dart';

class TcgShop {
  const TcgShop({
    required this.id,
    required this.name,
    required this.address,
    required this.town,
    required this.county,
    required this.country,
    required this.postcode,
    required this.lat,
    required this.lng,
    required this.games,
    required this.services,
    required this.status,
    this.website = '',
    this.phone = '',
    this.imageUrl = '',
    this.imagePath = '',
    this.submittedBy = '',
    this.approvedBy = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final String town;
  final String county;
  final String country;
  final String postcode;
  final double lat;
  final double lng;
  final List<String> games;
  final List<String> services;
  final String status;
  final String website;
  final String phone;
  final String imageUrl;
  final String imagePath;
  final String submittedBy;
  final String approvedBy;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  static String cleanString(dynamic value) => (value ?? '').toString().trim();

  static double cleanDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(cleanString(value)) ?? 0;
  }

  static List<String> cleanStringList(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) => cleanString(item).toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  factory TcgShop.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final location = data['location'];

    final locationLat = location is GeoPoint ? location.latitude : null;
    final locationLng = location is GeoPoint ? location.longitude : null;

    return TcgShop(
      id: doc.id,
      name: cleanString(data['name']),
      address: cleanString(data['address']),
      town: cleanString(data['town']),
      county: cleanString(data['county']),
      country: cleanString(data['country']).isEmpty
          ? 'United Kingdom'
          : cleanString(data['country']),
      postcode: cleanString(data['postcode']),
      lat: locationLat ?? cleanDouble(data['lat']),
      lng: locationLng ?? cleanDouble(data['lng']),
      games: cleanStringList(data['games']),
      services: cleanStringList(data['services']),
      status: cleanString(data['status']).isEmpty
          ? 'pending'
          : cleanString(data['status']).toLowerCase(),
      website: cleanString(data['website']),
      phone: cleanString(data['phone']),
      imageUrl: cleanString(data['imageUrl']),
      imagePath: cleanString(data['imagePath']),
      submittedBy: cleanString(data['submittedBy']),
      approvedBy: cleanString(data['approvedBy']),
      createdAt: cleanTimestamp(data['createdAt']),
      updatedAt: cleanTimestamp(data['updatedAt']),
    );
  }

  bool get hasValidLocation {
    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0 && lng == 0);
  }

  bool get hasImage => imageUrl.trim().isNotEmpty;

  String get singleLineAddress {
    return [address, town, county, postcode, country]
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }

  String get searchText {
    return [name, address, town, county, postcode, country]
        .join(' ')
        .toLowerCase();
  }
}
