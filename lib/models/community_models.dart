import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/community_image_services.dart';
import '../services/currency_settings.dart';

String _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _normalizeCommunityMarketStatus(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Available';
  switch (trimmed.toLowerCase()) {
    case 'sold':
      return 'Sold';
    case 'reserved':
      return 'Reserved';
    case 'traded':
      return 'Traded';
    case 'found':
      return 'Found';
    case 'closed':
      return 'Closed';
    default:
      return 'Available';
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.postType,
    required this.title,
    required this.description,
    required this.contact,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.marketStatus = 'Available',
    this.askingPrice,
    this.askingCurrency = 'GBP',
    this.cardCondition = '',
    this.deliveryMethod = '',
    this.locationText = '',
    this.wantedTradeFor = '',
    this.lastBumpedAtMs,
    this.imageBase64List = const <String>[],
    this.hiddenReplyIds = const <String>[],
  });

  final String id;
  final String authorId;
  final String authorName;
  final String postType;
  final String title;
  final String description;
  final String contact;
  final int createdAtMs;
  final int updatedAtMs;
  final String marketStatus;
  final double? askingPrice;
  final String askingCurrency;
  final String cardCondition;
  final String deliveryMethod;
  final String locationText;
  final String wantedTradeFor;
  final int? lastBumpedAtMs;
  final List<String> imageBase64List;
  final List<String> hiddenReplyIds;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(
        updatedAtMs > 0 ? updatedAtMs : createdAtMs,
      );
  DateTime? get lastBumpedAt =>
      lastBumpedAtMs == null || lastBumpedAtMs! <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastBumpedAtMs!);
  bool get hasImages => imageBase64List.isNotEmpty;
  int get imageCount => imageBase64List.length;
  String? get primaryImageBase64 => hasImages ? imageBase64List.first : null;
  bool get isDiscussion => postType == 'Thread';
  bool get isMarketplace => !isDiscussion;
  bool get isForSale => postType == 'For Sale';
  bool get isSwap => postType == 'Swap';
  bool get isWanted => postType == 'Wanted';
  String get normalizedMarketStatus =>
      isMarketplace ? _normalizeCommunityMarketStatus(marketStatus) : 'Discussion';
  bool get hasPrice => askingPrice != null && askingPrice!.isFinite && askingPrice! > 0;
  String get askingCurrencyCode {
    final normalized = askingCurrency.trim().toUpperCase();
    if (CurrencySettings.supportedCurrencies.containsKey(normalized)) {
      return normalized;
    }
    return 'GBP';
  }

  String get formattedPrice =>
      hasPrice ? CurrencySettings.formatAmount(askingPrice, fromCurrency: askingCurrencyCode) : 'Price not set';
  int get lastActivityAtMs => math.max(
        math.max(createdAtMs, updatedAtMs),
        lastBumpedAtMs ?? 0,
      );

  String? get compactMarketplaceSummary {
    if (!isMarketplace) return null;
    final parts = <String>[];
    if (isForSale && hasPrice) {
      parts.add(formattedPrice);
    }
    if (isWanted && wantedTradeFor.trim().isNotEmpty) {
      parts.add('Looking for ${wantedTradeFor.trim()}');
    }
    if (cardCondition.trim().isNotEmpty) {
      parts.add(cardCondition.trim());
    }
    if (deliveryMethod.trim().isNotEmpty) {
      parts.add(deliveryMethod.trim());
    }
    if (locationText.trim().isNotEmpty) {
      parts.add(locationText.trim());
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  Map<String, dynamic> toJson() => {
        'authorId': authorId,
        'authorName': authorName,
        'postType': postType,
        'title': title,
        'description': description,
        'contact': contact,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'imageRefs': imageBase64List,
        'imageBase64List': imageBase64List,
        if (isMarketplace) 'marketStatus': normalizedMarketStatus,
        if (isForSale && hasPrice) 'askingPrice': askingPrice,
        if (isMarketplace) 'askingCurrency': askingCurrencyCode,
        if (isMarketplace && cardCondition.trim().isNotEmpty) 'cardCondition': cardCondition.trim(),
        if (isMarketplace && deliveryMethod.trim().isNotEmpty) 'deliveryMethod': deliveryMethod.trim(),
        if (isMarketplace && locationText.trim().isNotEmpty) 'locationText': locationText.trim(),
        if ((isSwap || isWanted) && wantedTradeFor.trim().isNotEmpty) 'wantedTradeFor': wantedTradeFor.trim(),
        if (lastBumpedAtMs != null && lastBumpedAtMs! > 0) 'lastBumpedAtMs': lastBumpedAtMs,
        if (hiddenReplyIds.isNotEmpty) 'hiddenReplyIds': hiddenReplyIds,
      };

  factory CommunityPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    final rawImageList = json['imageRefs'] ?? json['imageUrlList'] ?? json['imageBase64List'];
    final legacyImage = _firstNonEmptyString([
      json['imageRef'],
      json['imageUrl'],
      json['imageBase64'],
    ]);

    final imageBase64List = <String>[];
    if (rawImageList is List) {
      for (final value in rawImageList) {
        final encoded = value.toString().trim();
        if (encoded.isNotEmpty) {
          imageBase64List.add(encoded);
        }
      }
    }
    if (imageBase64List.isEmpty && legacyImage.trim().isNotEmpty) {
      imageBase64List.add(legacyImage.trim());
    }

    final postType = (json['postType'] ?? 'Swap').toString();
    final isMarketplace = postType != 'Thread';
    final rawPrice = (json['askingPrice'] as num?)?.toDouble();

    return CommunityPost(
      id: doc.id,
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (json['authorName'] ?? 'Trainer').toString(),
      postType: postType,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? ((json['createdAtMs'] as num?)?.toInt() ?? 0),
      marketStatus: isMarketplace
          ? _normalizeCommunityMarketStatus((json['marketStatus'] ?? 'Available').toString())
          : 'Discussion',
      askingPrice: rawPrice != null && rawPrice.isFinite && rawPrice > 0 ? rawPrice : null,
      askingCurrency: (json['askingCurrency'] ?? 'GBP').toString().toUpperCase(),
      cardCondition: isMarketplace ? (json['cardCondition'] ?? '').toString() : '',
      deliveryMethod: isMarketplace ? (json['deliveryMethod'] ?? '').toString() : '',
      locationText: isMarketplace ? (json['locationText'] ?? '').toString() : '',
      wantedTradeFor: postType == 'Swap' || postType == 'Wanted'
          ? (json['wantedTradeFor'] ?? '').toString()
          : '',
      lastBumpedAtMs: (json['lastBumpedAtMs'] as num?)?.toInt(),
      imageBase64List: imageBase64List,
      hiddenReplyIds: ((json['hiddenReplyIds'] as List<dynamic>?) ?? const <dynamic>[])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}

class CommunityReply {
  const CommunityReply({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.message,
    required this.createdAtMs,
    this.imageBase64,
    this.authorProfileImageBase64,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String message;
  final int createdAtMs;
  final String? imageBase64;
  final String? authorProfileImageBase64;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  bool get hasImage => imageBase64 != null && imageBase64!.trim().isNotEmpty;
  bool get hasAuthorProfileImage =>
      authorProfileImageBase64 != null && authorProfileImageBase64!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'authorId': authorId,
        'authorName': authorName,
        'message': message,
        'createdAtMs': createdAtMs,
        if (hasImage) 'imageRef': imageBase64!.trim(),
        if (hasImage && FirebaseImageStorageService.isRemoteRef(imageBase64)) 'imageUrl': imageBase64!.trim(),
        if (hasImage && !FirebaseImageStorageService.isRemoteRef(imageBase64)) 'imageBase64': imageBase64!.trim(),
        if (hasAuthorProfileImage) 'authorProfileImageRef': authorProfileImageBase64!.trim(),
        if (hasAuthorProfileImage && FirebaseImageStorageService.isRemoteRef(authorProfileImageBase64))
          'authorProfileImageUrl': authorProfileImageBase64!.trim(),
        if (hasAuthorProfileImage && !FirebaseImageStorageService.isRemoteRef(authorProfileImageBase64))
          'authorProfileImageBase64': authorProfileImageBase64!.trim(),
      };

  factory CommunityReply.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    final rawImage = _firstNonEmptyString([
      json['imageRef'],
      json['imageUrl'],
      json['imageBase64'],
    ]);
    final rawAuthorProfileImage = _firstNonEmptyString([
      json['authorProfileImageRef'],
      json['authorProfileImageUrl'],
      json['authorProfileImageBase64'],
      json['profileImageRef'],
      json['profileImageUrl'],
      json['profileImageBase64'],
    ]);
    return CommunityReply(
      id: doc.id,
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (json['authorName'] ?? 'Trainer').toString(),
      message: (json['message'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      imageBase64: rawImage.isEmpty ? null : rawImage,
      authorProfileImageBase64: rawAuthorProfileImage.isEmpty ? null : rawAuthorProfileImage,
    );
  }
}
