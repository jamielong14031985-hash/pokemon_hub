import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sealed_expansion_matcher.dart';

class SealedCollectionItem {
  const SealedCollectionItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.catalogueImageApproved,
    required this.imageSource,
    required this.productTypeLabel,
    required this.currencyCode,
    required this.quantity,
    required this.purchasePrice,
    required this.marketPrice,
    required this.feePercent,
    required this.postagePerItem,
    required this.condition,
    required this.saleStatus,
    required this.notes,
    required this.updatedAtMs,
    this.expansionName = '',
  });

  final String expansionName;
  final String id;
  final String title;
  final String imageUrl;
  final bool catalogueImageApproved;
  final String imageSource;
  final String productTypeLabel;
  final String currencyCode;
  final int quantity;
  final double purchasePrice;
  final double marketPrice;
  final double feePercent;
  final double postagePerItem;
  final String condition;
  final String saleStatus;
  final String notes;
  final int updatedAtMs;

  double get totalPaid => purchasePrice * quantity;
  double get totalMarketValue => marketPrice * quantity;
  double get estimatedFees => totalMarketValue * (feePercent / 100);
  double get estimatedPostage => postagePerItem * quantity;
  double get expectedPayout =>
      (totalMarketValue - estimatedFees - estimatedPostage)
          .clamp(0, double.infinity)
          .toDouble();
  double get estimatedProfit => expectedPayout - totalPaid;

  SealedCollectionItem copyWith({
    String? imageUrl,
    bool? catalogueImageApproved,
    String? imageSource,
    int? quantity,
    double? purchasePrice,
    double? marketPrice,
    double? feePercent,
    double? postagePerItem,
    String? condition,
    String? saleStatus,
    String? notes,
    String? expansionName,
    int? updatedAtMs,
  }) {
    return SealedCollectionItem(
      id: id,
      expansionName: expansionName ?? this.expansionName,
      title: title,
      imageUrl: imageUrl ?? this.imageUrl,
      catalogueImageApproved:
          catalogueImageApproved ?? this.catalogueImageApproved,
      imageSource: imageSource ?? this.imageSource,
      productTypeLabel: productTypeLabel,
      currencyCode: currencyCode,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      marketPrice: marketPrice ?? this.marketPrice,
      feePercent: feePercent ?? this.feePercent,
      postagePerItem: postagePerItem ?? this.postagePerItem,
      condition: condition ?? this.condition,
      saleStatus: saleStatus ?? this.saleStatus,
      notes: notes ?? this.notes,
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'expansionName': expansionName,
        'title': title,
        'imageUrl': imageUrl,
        'catalogueImageApproved': catalogueImageApproved,
        'imageSource': imageSource,
        'productTypeLabel': productTypeLabel,
        'currencyCode': currencyCode,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'marketPrice': marketPrice,
        'feePercent': feePercent,
        'postagePerItem': postagePerItem,
        'condition': condition,
        'saleStatus': saleStatus,
        'notes': notes,
        'updatedAtMs': updatedAtMs,
      };

  factory SealedCollectionItem.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num?)?.toDouble() ??
        double.tryParse((json[key] ?? '').toString()) ??
        0;
    final imageSource = (json['imageSource'] ?? '').toString();
    final catalogueImageApproved = json['catalogueImageApproved'] == true &&
        imageSource == 'approvedCatalog';
    return SealedCollectionItem(
      id: (json['id'] ?? '').toString(),
      expansionName: (json['expansionName'] ?? '').toString(),
      title: (json['title'] ?? 'Sealed product').toString(),
      // Older builds saved the first marketplace photo without checking it.
      // Hide those legacy photos until a clean product-only image is selected.
      imageUrl: catalogueImageApproved
          ? (json['imageUrl'] ?? '').toString()
          : '',
      catalogueImageApproved: catalogueImageApproved,
      imageSource: imageSource,
      productTypeLabel: (json['productTypeLabel'] ?? 'Sealed product').toString(),
      currencyCode: (json['currencyCode'] ?? 'GBP').toString(),
      quantity: ((json['quantity'] as num?)?.toInt() ?? 1).clamp(1, 9999).toInt(),
      purchasePrice: number('purchasePrice'),
      marketPrice: number('marketPrice'),
      feePercent: number('feePercent'),
      postagePerItem: number('postagePerItem'),
      condition: (json['condition'] ?? 'Sealed').toString(),
      saleStatus: (json['saleStatus'] ?? 'Not for sale').toString(),
      notes: (json['notes'] ?? '').toString(),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  factory SealedCollectionItem.fromAverageProduct({
    required String title,
    required String imageUrl,
    required bool catalogueImageApproved,
    String imageSource = '',
    required String productTypeLabel,
    required String currencyCode,
    required double averageMarketPrice,
    String? productIdentityKey,
    String expansionName = '',
  }) {
    final stableId = '$title|$productTypeLabel'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return SealedCollectionItem(
      id: 'sealed-${(productIdentityKey ?? stableId).replaceAll('|', '-')}',
      expansionName: expansionName,
      title: title,
      imageUrl: imageUrl,
      catalogueImageApproved: catalogueImageApproved,
      imageSource: imageSource,
      productTypeLabel: productTypeLabel,
      currencyCode: currencyCode.isEmpty ? 'GBP' : currencyCode,
      quantity: 1,
      purchasePrice: 0,
      marketPrice: averageMarketPrice,
      feePercent: 0,
      postagePerItem: 0,
      condition: 'Sealed',
      saleStatus: 'Not for sale',
      notes: '',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class SealedCollectionStore {
  SealedCollectionStore._();
  static const String _key = 'sealed_collection_v1';

  static Future<List<SealedCollectionItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <SealedCollectionItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SealedCollectionItem>[];
      final items = decoded
          .whereType<Map>()
          .map((item) => SealedCollectionItem.fromJson(
              Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty)
          .toList();
      // Migrate older entries without changing existing quantities, prices,
      // notes, images, or "recently updated" ordering.
      var migrated = false;
      final populated = <SealedCollectionItem>[];
      for (final item in items) {
        if (item.expansionName.trim().isNotEmpty) {
          populated.add(item);
          continue;
        }
        final guess = SealedExpansionMatcher.fromProductTitle(item.title);
        if (guess == null) {
          populated.add(item);
          continue;
        }
        populated.add(item.copyWith(
          expansionName: guess,
          updatedAtMs: item.updatedAtMs,
        ));
        migrated = true;
      }
      if (migrated) {
        try {
          await saveAll(populated);
        } catch (_) {
          // The existing saved collection still loads if migration cannot
          // be written. A later load can retry the assignment.
        }
      }
      return populated;
    } catch (_) {
      return <SealedCollectionItem>[];
    }
  }

  static Future<void> saveAll(List<SealedCollectionItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((item) => item.toJson()).toList()));
  }

  static Future<void> upsert(SealedCollectionItem item) async {
    final items = await load();
    final index = items.indexWhere((existing) => existing.id == item.id);
    if (index < 0) {
      items.add(item);
    } else {
      items[index] = item;
    }
    await saveAll(items);
  }

  static Future<void> remove(String id) async {
    final items = await load()..removeWhere((item) => item.id == id);
    await saveAll(items);
  }
}
