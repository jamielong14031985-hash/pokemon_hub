class TcgSet {
  TcgSet({
    required this.id,
    required this.name,
    required this.series,
    required this.total,
    required this.releaseDate,
    this.logoUrl,
    this.symbolUrl,
  });

  final String id;
  final String name;
  final String series;
  final int total;
  final String releaseDate;
  final String? logoUrl;
  final String? symbolUrl;

  factory TcgSet.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>? ?? {};
    return TcgSet(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      series: (json['series'] ?? 'Unknown').toString(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      releaseDate: (json['releaseDate'] ?? 'Unknown').toString(),
      logoUrl: images['logo']?.toString(),
      symbolUrl: images['symbol']?.toString(),
    );
  }
}
