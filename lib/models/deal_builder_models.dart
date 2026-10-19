enum DealDirection { buying, selling }
enum DealItemKind { card, sealedProduct }

/// Which collector is offering an item in this trade.
enum DealSide { mine, theirs }

class DealItem {
  const DealItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.quantity,
    required this.unitPrice,
    required this.priceSource,
    this.referenceId = '',
    this.imageUrl = '',
    this.side = DealSide.mine,
  });

  final String id;
  final DealItemKind kind;
  final String title;
  final String subtitle;
  final int quantity;
  // A snapshot expressed in the parent deal's currency. Never mixes currencies.
  final double? unitPrice;
  final String priceSource;
  final String referenceId;
  /// Snapshot of the exact item's approved artwork URL. Blank for legacy/manual items.
  final String imageUrl;
  final DealSide side;

  double get pricedTotal => (unitPrice ?? 0) * quantity;
  bool get hasPrice => unitPrice != null && unitPrice! > 0 && unitPrice!.isFinite;

  DealItem copyWith({int? quantity, double? unitPrice, bool clearPrice = false,
    String? priceSource, String? imageUrl, DealSide? side}) => DealItem(
    id: id, kind: kind, title: title, subtitle: subtitle,
    quantity: quantity ?? this.quantity,
    unitPrice: clearPrice ? null : unitPrice ?? this.unitPrice,
    priceSource: priceSource ?? this.priceSource,
    referenceId: referenceId,
    imageUrl: imageUrl ?? this.imageUrl,
    side: side ?? this.side,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id, 'kind': kind.name, 'title': title, 'subtitle': subtitle,
    'quantity': quantity, 'unitPrice': unitPrice,
    'priceSource': priceSource, 'referenceId': referenceId,
    'imageUrl': imageUrl, 'side': side.name,
  };

  static DealItem fromJson(Map<String, dynamic> json) {
    final rawPrice = json['unitPrice'];
    final parsed = rawPrice is num ? rawPrice.toDouble() : double.tryParse('$rawPrice');
    return DealItem(
      id: (json['id'] ?? '').toString(),
      kind: json['kind'] == DealItemKind.sealedProduct.name ? DealItemKind.sealedProduct : DealItemKind.card,
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      quantity: (json['quantity'] is num ? (json['quantity'] as num).toInt() : 1).clamp(1, 999).toInt(),
      unitPrice: parsed != null && parsed > 0 && parsed.isFinite ? parsed : null,
      priceSource: (json['priceSource'] ?? '').toString(),
      referenceId: (json['referenceId'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      side: json['side'] == DealSide.theirs.name ? DealSide.theirs : DealSide.mine,
    );
  }
}

class CollectorDeal {
  const CollectorDeal({
    required this.id,
    required this.title,
    required this.direction,
    required this.currencyCode,
    required this.percentage,
    this.myPercentage = 100,
    required this.items,
    required this.savedAtMs,
  });

  final String id;
  final String title;
  final DealDirection direction;
  final String currencyCode;
  /// Their offer multiplier, preserved under the legacy JSON key `percentage`.
  final double percentage;
  /// My offer multiplier; defaults to 100% for earlier locally saved trades.
  final double myPercentage;
  final List<DealItem> items;
  final int savedAtMs;

  /// Keep every saved item and its image; group by the collector offering it.
  List<DealItem> get myItems => items.where((e) => e.side == DealSide.mine).toList();
  List<DealItem> get theirItems => items.where((e) => e.side == DealSide.theirs).toList();
  double get myValue => myItems.fold<double>(0, (s, e) => s + (e.hasPrice ? e.pricedTotal : 0));
  double get theirValue => theirItems.fold<double>(0, (s, e) => s + (e.hasPrice ? e.pricedTotal : 0));
  double get adjustedTheirValue => (theirValue * percentage / 100 * 100).round() / 100;
  double get adjustedMyValue => (myValue * myPercentage / 100 * 100).round() / 100;
  /// Positive means you add cash; negative means the other collector adds cash.
  double get cashBalance => ((adjustedTheirValue - adjustedMyValue) * 100).round() / 100;
  int get myUnpriced => myItems.where((e) => !e.hasPrice).length;
  int get theirUnpriced => theirItems.where((e) => !e.hasPrice).length;

  double get pricedMarketTotal => items.fold<double>(0, (s, item) => s + item.pricedTotal);
  double get offerTotal => (pricedMarketTotal * percentage / 100 * 100).round() / 100;
  double get difference => (pricedMarketTotal - offerTotal).abs();
  int get unpricedCount => items.where((item) => !item.hasPrice).length;
  int get itemCount => items.fold<int>(0, (s, item) => s + item.quantity);
  bool get hasItems => items.isNotEmpty;
  bool get hasPricedItems => items.any((item) => item.hasPrice);

  CollectorDeal copyWith({String? title, DealDirection? direction,
    double? percentage, double? myPercentage, List<DealItem>? items, int? savedAtMs}) => CollectorDeal(
      id: id,
      title: title ?? this.title,
      direction: direction ?? this.direction,
      currencyCode: currencyCode,
      percentage: percentage ?? this.percentage,
      myPercentage: myPercentage ?? this.myPercentage,
      items: items ?? this.items,
      savedAtMs: savedAtMs ?? this.savedAtMs,
    );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id, 'title': title, 'direction': direction.name,
    'currencyCode': currencyCode, 'percentage': percentage, 'myPercentage': myPercentage,
    'savedAtMs': savedAtMs, 'items': items.map((e) => e.toJson()).toList(),
  };

  static CollectorDeal fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final legacySide = json['direction'] == DealDirection.selling.name
        ? DealSide.mine : DealSide.theirs;
    final migrated = <DealItem>[];
    if (rawItems is List) {
      for (final entry in rawItems.whereType<Map>()) {
        final obj = Map<String, dynamic>.from(entry);
        final parsed = DealItem.fromJson(obj);
        if (parsed.id.isNotEmpty && parsed.title.isNotEmpty) {
          migrated.add(obj.containsKey('side') ? parsed : parsed.copyWith(side: legacySide));
        }
      }
    }
    final rawPercent = json['percentage'];
    final percent = rawPercent is num ? rawPercent.toDouble() : 100.0;
    final rawMy = json['myPercentage'];
    final mine = rawMy is num ? rawMy.toDouble() : double.tryParse('$rawMy') ?? 100.0;
    return CollectorDeal(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled deal').toString(),
      direction: json['direction'] == DealDirection.selling.name ? DealDirection.selling : DealDirection.buying,
      currencyCode: (json['currencyCode'] ?? 'GBP').toString(),
      percentage: percent.isFinite ? percent.clamp(0.0, 200.0).toDouble() : 100.0,
      myPercentage: mine.isFinite ? mine.clamp(0.0, 200.0).toDouble() : 100.0,
      items: migrated,
      savedAtMs: (json['savedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
