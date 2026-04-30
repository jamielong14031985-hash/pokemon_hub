import 'package:cloud_firestore/cloud_firestore.dart';

import 'tcg_card.dart';

class WishlistEntry {
  const WishlistEntry({
    required this.cardId,
    required this.name,
    required this.setId,
    required this.setName,
    required this.number,
    required this.createdAtMs,
    this.imageUrl,
    this.largeImageUrl,
    this.setLogoUrl,
    this.rawPrice,
    this.rawPriceCurrency = 'USD',
  });

  final String cardId;
  final String name;
  final String setId;
  final String setName;
  final String number;
  final int createdAtMs;
  final String? imageUrl;
  final String? largeImageUrl;
  final String? setLogoUrl;
  final double? rawPrice;
  final String rawPriceCurrency;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  factory WishlistEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    return WishlistEntry(
      cardId: (json['cardId'] ?? doc.id).toString(),
      name: (json['name'] ?? 'Unknown Card').toString(),
      setId: (json['setId'] ?? '').toString(),
      setName: (json['setName'] ?? 'Unknown Set').toString(),
      number: (json['number'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl']?.toString(),
      largeImageUrl: json['largeImageUrl']?.toString(),
      setLogoUrl: json['setLogoUrl']?.toString(),
      rawPrice: (json['rawPrice'] as num?)?.toDouble(),
      rawPriceCurrency: (json['rawPriceCurrency'] ?? 'USD').toString().toUpperCase(),
    );
  }

  TcgCard toSummaryCard() {
    return TcgCard(
      id: cardId,
      name: name,
      setId: setId,
      setName: setName,
      number: number,
      types: const <String>[],
      imageUrl: imageUrl,
      largeImageUrl: largeImageUrl ?? imageUrl,
      setLogoUrl: setLogoUrl,
      rawPrice: rawPrice,
      rawPriceCurrency: rawPriceCurrency,
    );
  }
}
