import 'money_value.dart';


double? _asPrice(dynamic value) {
  if (value is num) return value.toDouble();
  return null;
}

double? _pickFirstAvailablePrice(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = _asPrice(source[key]);
    if (value != null && value > 0) {
      return value;
    }
  }
  return null;
}

MoneyValue? _extractRawCardMoney(Map<String, dynamic> json) {
  final tcgplayer = (json['tcgplayer'] as Map<String, dynamic>? ?? {});
  final tcgPrices = (tcgplayer['prices'] as Map<String, dynamic>? ?? {});
  final cardmarket = (json['cardmarket'] as Map<String, dynamic>? ?? {});
  final cardmarketPrices = (cardmarket['prices'] as Map<String, dynamic>? ?? {});

  for (final key in [
    'normal',
    'holofoil',
    'reverseHolofoil',
    '1stEditionNormal',
    '1stEditionHolofoil',
    'unlimitedHolofoil',
  ]) {
    final priceMap = (tcgPrices[key] as Map<String, dynamic>? ?? {});
    final price = _pickFirstAvailablePrice(priceMap, ['market', 'mid', 'low']);
    if (price != null) {
      return MoneyValue(amount: price, currencyCode: 'USD');
    }
  }

  final cardmarketPrice = _pickFirstAvailablePrice(
    cardmarketPrices,
    ['averageSellPrice', 'trendPrice', 'avg30', 'lowPrice'],
  );
  if (cardmarketPrice != null) {
    return MoneyValue(amount: cardmarketPrice, currencyCode: 'EUR');
  }

  return null;
}

Map<String, double> _extractRawPriceBreakdown(Map<String, dynamic> json) {
  final tcgplayer = (json['tcgplayer'] as Map<String, dynamic>? ?? {});
  final tcgPrices = (tcgplayer['prices'] as Map<String, dynamic>? ?? {});
  final cardmarket = (json['cardmarket'] as Map<String, dynamic>? ?? {});
  final cardmarketPrices = (cardmarket['prices'] as Map<String, dynamic>? ?? {});

  final result = <String, double>{};

  void addIf(String label, double? value) {
    if (value != null && value > 0) result[label] = value;
  }

  for (final entry in <String, String>{
    'Normal Market': 'normal',
    'Holofoil Market': 'holofoil',
    'Reverse Holo Market': 'reverseHolofoil',
    '1st Ed Normal Market': '1stEditionNormal',
    '1st Ed Holo Market': '1stEditionHolofoil',
    'Unlimited Holo Market': 'unlimitedHolofoil',
  }.entries) {
    final priceMap = (tcgPrices[entry.value] as Map<String, dynamic>? ?? {});
    addIf(entry.key, _pickFirstAvailablePrice(priceMap, ['market', 'mid', 'low']));
  }

  addIf('Cardmarket Avg Sell', _asPrice(cardmarketPrices['averageSellPrice']));
  addIf('Cardmarket Trend', _asPrice(cardmarketPrices['trendPrice']));
  addIf('Cardmarket Avg30', _asPrice(cardmarketPrices['avg30']));
  addIf('Cardmarket Low', _asPrice(cardmarketPrices['lowPrice']));

  return result;
}

Map<String, double> _extractGradedPrices(Map<String, dynamic> json) {
  final tcgplayer = (json['tcgplayer'] as Map<String, dynamic>? ?? {});
  final tcgPrices = (tcgplayer['prices'] as Map<String, dynamic>? ?? {});

  final gradedMappings = <String, List<String>>{
    'PSA 10': ['psa10'],
    'BGS 10': ['bgs10'],
    'CGC 10': ['cgc10'],
    'SGC 10': ['sgc10'],
    'ACE 10': ['ace10'],
    'GEM 10': ['gemMint10', 'grade10', 'graded10'],
  };

  final result = <String, double>{};

  for (final entry in gradedMappings.entries) {
    for (final key in entry.value) {
      final priceMap = (tcgPrices[key] as Map<String, dynamic>? ?? {});
      final price = _pickFirstAvailablePrice(priceMap, ['market', 'mid', 'low']);
      if (price != null) {
        result[entry.key] = price;
        break;
      }
    }
  }

  return result;
}
class TcgCard {
  TcgCard({
    required this.id,
    required this.name,
    required this.setId,
    required this.setName,
    required this.number,
    required this.types,
    this.rarity,
    this.hp,
    this.artist,
    this.flavorText,
    this.imageUrl,
    this.largeImageUrl,
    this.setLogoUrl,
    this.rawPrice,
    this.rawPriceCurrency = 'USD',
    this.rawPriceBreakdown = const {},
    this.gradedPrices = const {},
  });

  final String id;
  final String name;
  final String setId;
  final String setName;
  final String number;
  final List<String> types;
  final String? rarity;
  final String? hp;
  final String? artist;
  final String? flavorText;
  final String? imageUrl;
  final String? largeImageUrl;
  final String? setLogoUrl;
  final double? rawPrice;
  final String rawPriceCurrency;
  final Map<String, double> rawPriceBreakdown;
  final Map<String, double> gradedPrices;

  double? get marketPrice => rawPrice;

  factory TcgCard.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as Map<String, dynamic>? ?? {});
    final set = (json['set'] as Map<String, dynamic>? ?? {});
    final rawPriceMoney = _extractRawCardMoney(json);
    return TcgCard(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      setId: (set['id'] ?? '').toString(),
      setName: (set['name'] ?? 'Unknown').toString(),
      number: (json['number'] ?? 'Unknown').toString(),
      rarity: json['rarity']?.toString(),
      hp: json['hp']?.toString(),
      artist: json['artist']?.toString(),
      flavorText: json['flavorText']?.toString(),
      imageUrl: images['small']?.toString(),
      largeImageUrl: images['large']?.toString(),
      setLogoUrl: (set['images'] as Map<String, dynamic>? ?? {})['logo']?.toString(),
      rawPrice: rawPriceMoney?.amount,
      rawPriceCurrency: rawPriceMoney?.currencyCode ?? 'USD',
      rawPriceBreakdown: _extractRawPriceBreakdown(json),
      gradedPrices: _extractGradedPrices(json),
      types: (json['types'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
