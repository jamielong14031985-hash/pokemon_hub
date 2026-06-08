import 'money_value.dart';

double? _asPrice(dynamic value) {
  if (value is num) return value.toDouble();

  if (value is String) {
    final cleaned = value
        .trim()
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;
    return double.tryParse(cleaned);
  }

  return null;
}

Map<String, dynamic> _asStringDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map<String, dynamic>(
      (dynamic key, dynamic mapValue) => MapEntry<String, dynamic>(
        key.toString(),
        mapValue,
      ),
    );
  }
  return <String, dynamic>{};
}

const List<String> _tcgPlayerRawPriceGroupPriority = <String>[
  'normal',
  'holofoil',
  'reverseHolofoil',
  '1stEditionNormal',
  '1stEditionHolofoil',
  'unlimitedNormal',
  'unlimitedHolofoil',
  'unlimitedReverseHolofoil',
  'unlimited',
];

const List<String> _tcgPlayerPriceFieldPriority = <String>[
  'market',
  'mid',
  'directLow',
  'low',
  'high',
];

const List<String> _cardmarketPriceFieldPriority = <String>[
  'averageSellPrice',
  'trendPrice',
  'avg7',
  'avg30',
  'avg1',
  'lowPrice',
  'lowPriceExPlus',
  'reverseHoloSell',
  'reverseHoloTrend',
  'reverseHoloLow',
];

double? _pickFirstAvailablePrice(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = _asPrice(source[key]);
    if (value != null && value > 0) {
      return value;
    }
  }
  return null;
}

bool _isRawTcgPlayerPriceGroup(String key) {
  final value = key.toLowerCase();
  if (value.contains('psa')) return false;
  if (value.contains('bgs')) return false;
  if (value.contains('cgc')) return false;
  if (value.contains('sgc')) return false;
  if (value.contains('ace')) return false;
  if (value.contains('graded')) return false;
  if (value.contains('grade')) return false;
  if (value.contains('gem')) return false;
  return true;
}

Iterable<String> _tcgPlayerRawPriceGroupKeys(Map<String, dynamic> tcgPrices) sync* {
  final seen = <String>{};

  for (final key in _tcgPlayerRawPriceGroupPriority) {
    if (tcgPrices.containsKey(key) && seen.add(key)) {
      yield key;
    }
  }

  for (final key in tcgPrices.keys) {
    if (_isRawTcgPlayerPriceGroup(key) && seen.add(key)) {
      yield key;
    }
  }
}

MoneyValue? _extractRawCardMoney(Map<String, dynamic> json) {
  final tcgplayer = _asStringDynamicMap(json['tcgplayer']);
  final tcgPrices = _asStringDynamicMap(tcgplayer['prices']);
  final cardmarket = _asStringDynamicMap(json['cardmarket']);
  final cardmarketPrices = _asStringDynamicMap(cardmarket['prices']);

  for (final key in _tcgPlayerRawPriceGroupKeys(tcgPrices)) {
    final priceMap = _asStringDynamicMap(tcgPrices[key]);
    final price = _pickFirstAvailablePrice(priceMap, _tcgPlayerPriceFieldPriority);
    if (price != null) {
      return MoneyValue(amount: price, currencyCode: 'USD');
    }
  }

  final cardmarketPrice = _pickFirstAvailablePrice(
    cardmarketPrices,
    _cardmarketPriceFieldPriority,
  );
  if (cardmarketPrice != null) {
    return MoneyValue(amount: cardmarketPrice, currencyCode: 'EUR');
  }

  return null;
}

String _prettyPriceGroupLabel(String key) {
  const labels = <String, String>{
    'normal': 'Normal',
    'holofoil': 'Holofoil',
    'reverseHolofoil': 'Reverse Holo',
    '1stEditionNormal': '1st Ed Normal',
    '1stEditionHolofoil': '1st Ed Holo',
    'unlimitedNormal': 'Unlimited Normal',
    'unlimitedHolofoil': 'Unlimited Holo',
    'unlimitedReverseHolofoil': 'Unlimited Reverse Holo',
    'unlimited': 'Unlimited',
  };
  return labels[key] ?? _titleCasePriceLabel(key);
}

String _prettyPriceFieldLabel(String key) {
  const labels = <String, String>{
    'market': 'Market',
    'mid': 'Mid',
    'directLow': 'Direct Low',
    'low': 'Low',
    'high': 'High',
    'averageSellPrice': 'Avg Sell',
    'trendPrice': 'Trend',
    'avg1': 'Avg 1 Day',
    'avg7': 'Avg 7 Days',
    'avg30': 'Avg 30 Days',
    'lowPrice': 'Low',
    'lowPriceExPlus': 'Low EX+',
    'reverseHoloSell': 'Reverse Holo Sell',
    'reverseHoloTrend': 'Reverse Holo Trend',
    'reverseHoloLow': 'Reverse Holo Low',
  };
  return labels[key] ?? _titleCasePriceLabel(key);
}

String _titleCasePriceLabel(String value) {
  final spaced = value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .trim();
  if (spaced.isEmpty) return value;

  return spaced
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        if (word.length == 1) return word.toUpperCase();
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}

Map<String, double> _extractRawPriceBreakdown(Map<String, dynamic> json) {
  final tcgplayer = _asStringDynamicMap(json['tcgplayer']);
  final tcgPrices = _asStringDynamicMap(tcgplayer['prices']);
  final cardmarket = _asStringDynamicMap(json['cardmarket']);
  final cardmarketPrices = _asStringDynamicMap(cardmarket['prices']);

  final result = <String, double>{};

  void addIf(String label, double? value) {
    if (value != null && value > 0) result[label] = value;
  }

  void addTcgPlayerPriceMap(String groupKey, Map<String, dynamic> priceMap) {
    final usedFields = <String>{};
    for (final fieldKey in _tcgPlayerPriceFieldPriority) {
      usedFields.add(fieldKey);
      addIf(
        '${_prettyPriceGroupLabel(groupKey)} ${_prettyPriceFieldLabel(fieldKey)}',
        _asPrice(priceMap[fieldKey]),
      );
    }

    for (final entry in priceMap.entries) {
      if (usedFields.contains(entry.key)) continue;
      addIf(
        '${_prettyPriceGroupLabel(groupKey)} ${_prettyPriceFieldLabel(entry.key)}',
        _asPrice(entry.value),
      );
    }
  }

  for (final key in _tcgPlayerRawPriceGroupKeys(tcgPrices)) {
    addTcgPlayerPriceMap(key, _asStringDynamicMap(tcgPrices[key]));
  }

  final usedCardmarketFields = <String>{};
  for (final fieldKey in _cardmarketPriceFieldPriority) {
    usedCardmarketFields.add(fieldKey);
    addIf(
      'Cardmarket ${_prettyPriceFieldLabel(fieldKey)}',
      _asPrice(cardmarketPrices[fieldKey]),
    );
  }

  for (final entry in cardmarketPrices.entries) {
    if (usedCardmarketFields.contains(entry.key)) continue;
    addIf(
      'Cardmarket ${_prettyPriceFieldLabel(entry.key)}',
      _asPrice(entry.value),
    );
  }

  return result;
}

Map<String, double> _extractGradedPrices(Map<String, dynamic> json) {
  final tcgplayer = _asStringDynamicMap(json['tcgplayer']);
  final tcgPrices = _asStringDynamicMap(tcgplayer['prices']);

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
      final priceMap = _asStringDynamicMap(tcgPrices[key]);
      final price = _pickFirstAvailablePrice(priceMap, _tcgPlayerPriceFieldPriority);
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
    this.rawPriceSource = 'Pokémon TCG API',
    this.externalRawPrice,
    this.externalRawPriceCurrency = 'USD',
    this.externalRawPriceSource = '',
    this.externalRawPriceUpdatedAtMs,
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
  final String rawPriceSource;
  final double? externalRawPrice;
  final String externalRawPriceCurrency;
  final String externalRawPriceSource;
  final int? externalRawPriceUpdatedAtMs;
  final Map<String, double> rawPriceBreakdown;
  final Map<String, double> gradedPrices;

  double? get marketPrice => (rawPrice ?? 0) > 0 ? rawPrice : externalRawPrice;

  String get marketPriceCurrency => (rawPrice ?? 0) > 0 ? rawPriceCurrency : externalRawPriceCurrency;

  String get marketPriceSource {
    if ((rawPrice ?? 0) > 0) return rawPriceSource;
    final source = externalRawPriceSource.trim();
    return source.isEmpty ? 'External pricing' : source;
  }

  bool get hasLiveMarketPrice => (marketPrice ?? 0) > 0;

  bool get hasExternalRawPrice => (externalRawPrice ?? 0) > 0;

  TcgCard copyWith({
    String? id,
    String? name,
    String? setId,
    String? setName,
    String? number,
    List<String>? types,
    String? rarity,
    String? hp,
    String? artist,
    String? flavorText,
    String? imageUrl,
    String? largeImageUrl,
    String? setLogoUrl,
    double? rawPrice,
    String? rawPriceCurrency,
    String? rawPriceSource,
    double? externalRawPrice,
    String? externalRawPriceCurrency,
    String? externalRawPriceSource,
    int? externalRawPriceUpdatedAtMs,
    Map<String, double>? rawPriceBreakdown,
    Map<String, double>? gradedPrices,
  }) {
    return TcgCard(
      id: id ?? this.id,
      name: name ?? this.name,
      setId: setId ?? this.setId,
      setName: setName ?? this.setName,
      number: number ?? this.number,
      types: types ?? this.types,
      rarity: rarity ?? this.rarity,
      hp: hp ?? this.hp,
      artist: artist ?? this.artist,
      flavorText: flavorText ?? this.flavorText,
      imageUrl: imageUrl ?? this.imageUrl,
      largeImageUrl: largeImageUrl ?? this.largeImageUrl,
      setLogoUrl: setLogoUrl ?? this.setLogoUrl,
      rawPrice: rawPrice ?? this.rawPrice,
      rawPriceCurrency: rawPriceCurrency ?? this.rawPriceCurrency,
      rawPriceSource: rawPriceSource ?? this.rawPriceSource,
      externalRawPrice: externalRawPrice ?? this.externalRawPrice,
      externalRawPriceCurrency: externalRawPriceCurrency ?? this.externalRawPriceCurrency,
      externalRawPriceSource: externalRawPriceSource ?? this.externalRawPriceSource,
      externalRawPriceUpdatedAtMs: externalRawPriceUpdatedAtMs ?? this.externalRawPriceUpdatedAtMs,
      rawPriceBreakdown: rawPriceBreakdown ?? this.rawPriceBreakdown,
      gradedPrices: gradedPrices ?? this.gradedPrices,
    );
  }

  String? get effectiveImageUrl {
    final candidates = imageUrlCandidates;
    return candidates.isEmpty ? null : candidates.first;
  }

  String? get effectiveLargeImageUrl {
    final candidates = largeImageUrlCandidates;
    return candidates.isEmpty ? effectiveImageUrl : candidates.first;
  }

  List<String> get imageUrlCandidates {
    return _uniqueUrls(<String?>[
      imageUrl,
      ..._fallbackImageUrls(large: false),
      largeImageUrl,
      ..._fallbackImageUrls(large: true),
    ]);
  }

  List<String> get largeImageUrlCandidates {
    return _uniqueUrls(<String?>[
      largeImageUrl,
      ..._fallbackImageUrls(large: true),
      imageUrl,
      ..._fallbackImageUrls(large: false),
    ]);
  }

  bool get _isMcdonaldsCard {
    final haystack = '$id $setId $setName'.toLowerCase();
    return haystack.contains('mcd') ||
        haystack.contains('mcdonald') ||
        haystack.contains('mcdonald') ||
        haystack.contains('mc donald');
  }

  List<String> _fallbackImageUrls({required bool large}) {
    final numberCandidates = _imageNumberCandidates();
    if (numberCandidates.isEmpty) {
      return const <String>[];
    }

    final candidates = <String>[];

    // For older McDonald's cards, Pokellector has reliable direct card scans.
    // Examples found online:
    // 2014 Weedle: den-cards.pokellector.com/158/Weedle.MCD4.1.png
    // 2015 Treecko: den-cards.pokellector.com/182/Treecko.MCD5.1.png
    for (final pokellectorUrl in _pokellectorMcdonaldsImageUrls()) {
      candidates.add(pokellectorUrl);
    }

    // For McDonald's sets, try PokemonCard.io direct card images first.
    // These older McDonald's cards are not always served correctly by the
    // Pokémon TCG image CDN used for normal sets.
    for (final pokemonCardImageSetId in _pokemonCardImageSetIdCandidates()) {
      for (final pokemonCardImageCardId in _pokemonCardImageCardIdCandidates()) {
        final encodedSetId = Uri.encodeComponent(pokemonCardImageSetId);
        final encodedCardId = Uri.encodeComponent(pokemonCardImageCardId);

        if (large) {
          candidates.add('https://images.pokemoncard.io/images/$encodedSetId/${encodedCardId}_hiresopt.jpg');
          candidates.add('https://images.pokemoncard.io/images/$encodedSetId/$encodedCardId.png');
          candidates.add('https://images.pokemoncard.io/images/$encodedSetId/$encodedCardId.jpg');
        } else {
          candidates.add('https://images.pokemoncard.io/images/$encodedSetId/$encodedCardId.png');
          candidates.add('https://images.pokemoncard.io/images/$encodedSetId/$encodedCardId.jpg');
          candidates.add('https://images.pokemoncard.io/images/$encodedSetId/${encodedCardId}_hiresopt.jpg');
        }
      }
    }

    for (final tcgdexSetId in _tcgDexSetIdCandidates()) {
      for (final candidateNumber in numberCandidates) {
        final encodedSetId = Uri.encodeComponent(tcgdexSetId);
        final encodedNumber = Uri.encodeComponent(candidateNumber);

        for (final language in <String>['en']) {
          for (final group in <String>['sm', 'xy', 'swsh', 'sv', 'mc']) {
            if (large) {
              candidates.add('https://assets.tcgdex.net/$language/$group/$encodedSetId/$encodedNumber/high.png');
              candidates.add('https://assets.tcgdex.net/$language/$group/$encodedSetId/$encodedNumber/low.png');
            } else {
              candidates.add('https://assets.tcgdex.net/$language/$group/$encodedSetId/$encodedNumber/low.png');
              candidates.add('https://assets.tcgdex.net/$language/$group/$encodedSetId/$encodedNumber/high.png');
            }
          }
        }
      }
    }

    for (final candidateSetId in _setIdCandidates()) {
      for (final candidateNumber in numberCandidates) {
        final encodedSetId = Uri.encodeComponent(candidateSetId);
        final encodedNumber = Uri.encodeComponent(candidateNumber);

        if (large) {
          candidates.add('https://images.pokemontcg.io/$encodedSetId/${encodedNumber}_hires.png');
          candidates.add('https://images.pokemontcg.io/$encodedSetId/${encodedNumber}_hires.jpg');
          candidates.add('https://images.pokemontcg.io/$encodedSetId/$encodedNumber.png');
          candidates.add('https://images.pokemontcg.io/$encodedSetId/$encodedNumber.jpg');
        } else {
          candidates.add('https://images.pokemontcg.io/$encodedSetId/$encodedNumber.png');
          candidates.add('https://images.pokemontcg.io/$encodedSetId/$encodedNumber.jpg');
        }
      }
    }

    return _uniqueUrls(candidates);
  }

  List<String> _setIdCandidates() {
    final rawSetId = setId.trim().toLowerCase();
    final candidates = <String>[
      rawSetId,
      ..._mcdonaldsSetAliases(),
    ];

    return _uniqueUrls(candidates);
  }

  String? _exactPokellectorMcdonaldsImageUrl() {
    if (!_isMcdonaldsCard) return null;

    final year = _mcdonaldsYear();
    final number = int.tryParse(_primaryImageNumber());
    if (year == null || number == null) return null;

    const exactUrls = <String, Map<int, String>>{
      '2017': <int, String>{
        1: 'https://den-cards.pokellector.com/230/Rowlet.MCD7.1.18575.png',
        2: 'https://den-cards.pokellector.com/230/Grubbin.MCD7.2.18569.png',
        3: 'https://den-cards.pokellector.com/230/Litten.MCD7.3.18570.png',
        4: 'https://den-cards.pokellector.com/230/Popplio.MCD7.4.18573.png',
        5: 'https://den-cards.pokellector.com/230/Pikachu.MCD7.5.18568.png',
        6: 'https://den-cards.pokellector.com/230/Cosmog.MCD7.6.18567.png',
        7: 'https://den-cards.pokellector.com/230/Crabrawler.MCD7.7.18571.png',
        8: 'https://den-cards.pokellector.com/230/Alolan-Meowth.MCD7.8.18578.png',
        9: 'https://den-cards.pokellector.com/230/Alolan-Diglett.MCD7.9.18566.png',
        10: 'https://den-cards.pokellector.com/230/Cutiefly.MCD7.10.18572.png',
        11: 'https://den-cards.pokellector.com/230/Pikipek.MCD7.11.18574.png',
        12: 'https://den-cards.pokellector.com/230/Yungoose.MCD7.12.18565.png',
      },
      '2018': <int, String>{
        1: 'https://den-cards.pokellector.com/265/Growlithe.MCD8.1.24571.png',
        2: 'https://den-cards.pokellector.com/265/Psyduck.MCD8.2.24575.png',
        3: 'https://den-cards.pokellector.com/265/Horsea.MCD8.3.24572.png',
        4: 'https://den-cards.pokellector.com/265/Pikachu.MCD8.4.24573.png',
        5: 'https://den-cards.pokellector.com/265/Slowpoke.MCD8.5.24576.png',
        6: 'https://den-cards.pokellector.com/265/Machop.MCD8.6.24577.png',
        7: 'https://den-cards.pokellector.com/265/Cubone.MCD8.7.24578.png',
        8: 'https://den-cards.pokellector.com/265/Magnemite.MCD8.8.24579.png',
        9: 'https://den-cards.pokellector.com/265/Dratini.MCD8.9.24574.png',
        10: 'https://den-cards.pokellector.com/265/Chansey.MCD8.10.24580.png',
        11: 'https://den-cards.pokellector.com/265/Eevee.MCD8.11.24581.png',
        12: 'https://den-cards.pokellector.com/265/Porygon.MCD8.12.24582.png',
      },
    };

    return exactUrls[year]?[number];
  }

  String? _mcdonaldsYear() {
    if (!_isMcdonaldsCard) return null;

    final text = '$id $setId $setName'.toLowerCase();
    final yearMatch = RegExp(r'(20\d{2})').firstMatch(text);
    if (yearMatch != null) return yearMatch.group(1);

    final shortYearMatch = RegExp(r'mcd(?:onalds?)?[_\-\s]*(\d{1,2})').firstMatch(text);
    final shortYear = int.tryParse(shortYearMatch?.group(1) ?? '');
    if (shortYear == null) return null;

    return '20${shortYear.toString().padLeft(2, '0')}';
  }

  List<String> _pokellectorMcdonaldsImageUrls() {
    if (!_isMcdonaldsCard) return const <String>[];

    final imageNumber = _primaryImageNumber();
    final cleanName = _pokellectorCardName();
    if (imageNumber.isEmpty || cleanName.isEmpty) {
      return const <String>[];
    }

    final candidates = <String>[];

    final exactUrl = _exactPokellectorMcdonaldsImageUrl();
    if (exactUrl != null) {
      candidates.add(exactUrl);
    }

    void addYearSet({
      required String year,
      required String folder,
      required String code,
      List<String> suffixes = const <String>[''],
    }) {
      if (!_mcdonaldsTextContainsYear(year)) return;

      for (final suffix in suffixes) {
        candidates.add(
          'https://den-cards.pokellector.com/$folder/$cleanName.$code.$imageNumber$suffix.png',
        );
      }
    }

    addYearSet(year: '2014', folder: '158', code: 'MCD4');
    addYearSet(year: '2015', folder: '182', code: 'MCD5');
    addYearSet(year: '2017', folder: '230', code: 'MCD7');

    // 2018 Pokellector image URLs include per-card suffixes on some scans.
    // The unsuffixed URL is still harmless to try first if it exists.
    addYearSet(
      year: '2018',
      folder: '265',
      code: 'MCD8',
      suffixes: const <String>['', '.24571'],
    );

    return _uniqueUrls(candidates);
  }

  bool _mcdonaldsTextContainsYear(String year) {
    final text = '$id $setId $setName'.toLowerCase();
    final shortYear = year.substring(2);
    return text.contains(year) ||
        text.contains('mcd$shortYear') ||
        text.contains('mcd${int.tryParse(shortYear) ?? shortYear}') ||
        text.contains('mc$shortYear');
  }

  String _pokellectorCardName() {
    final cleanWords = name
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
      if (word.length == 1) return word.toUpperCase();
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).toList();

    return cleanWords.join('-');
  }

  String _primaryImageNumber() {
    final numberCandidates = _imageNumberCandidates();
    for (final candidate in numberCandidates) {
      final numericOnly = candidate.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(numericOnly);
      if (parsed != null) return parsed.toString();
    }

    return '';
  }

  List<String> _pokemonCardImageSetIdCandidates() {
    if (!_isMcdonaldsCard) return const <String>[];

    final candidates = <String>[
      setId.trim().toLowerCase(),
      ..._mcdonaldsSetAliases(),
    ];

    return _uniqueUrls(candidates);
  }

  List<String> _pokemonCardImageCardIdCandidates() {
    if (!_isMcdonaldsCard) return const <String>[];

    final setCandidates = _pokemonCardImageSetIdCandidates();
    final numberCandidates = _imageNumberCandidates();
    final candidates = <String>[
      id.trim().toLowerCase(),
    ];

    for (final setCandidate in setCandidates) {
      for (final numberCandidate in numberCandidates) {
        candidates.add('$setCandidate-$numberCandidate');
      }
    }

    return _uniqueUrls(candidates);
  }

  List<String> _mcdonaldsSetAliases() {
    if (!_isMcdonaldsCard) return const <String>[];

    final text = '$id $setId $setName'.toLowerCase();
    final aliases = <String>[];

    void addYear(int year) {
      final shortYear = (year % 100).toString().padLeft(2, '0');
      aliases.add('mcd$shortYear');
      aliases.add('mcd${int.parse(shortYear)}');
      aliases.add('mcd$year');
      aliases.add('mc$shortYear');
      aliases.add('mc${int.parse(shortYear)}');
    }

    final yearMatches = RegExp(r'(20\d{2})').allMatches(text);
    for (final match in yearMatches) {
      final year = int.tryParse(match.group(1) ?? '');
      if (year != null && year >= 2011 && year <= 2030) {
        addYear(year);
      }
    }

    final compactMatch = RegExp(r'mcd(?:onalds?)?[_\-\s]*(\d{2})').firstMatch(text);
    if (compactMatch != null) {
      final shortYear = int.tryParse(compactMatch.group(1) ?? '');
      if (shortYear != null) {
        addYear(2000 + shortYear);
      }
    }

    return _uniqueUrls(aliases);
  }

  List<String> _tcgDexSetIdCandidates() {
    if (!_isMcdonaldsCard) return const <String>[];

    final text = '$id $setId $setName'.toLowerCase();
    final candidates = <String>[];

    final knownMappings = <String, String>{
      '2014': '2014xy',
      '2015': '2015xy',
      '2016': '2016xy',
      '2017': '2017sm',
      '2018': '2018sm',
      '2019': '2019sm',
      '2021': '2021swsh',
      '2022': '2022swsh',
      '2023': '2023sv',
      '2024': '2024sv',
    };

    for (final entry in knownMappings.entries) {
      if (text.contains(entry.key) || text.contains('mcd${entry.key.substring(2)}')) {
        candidates.add(entry.value);
      }
    }

    return _uniqueUrls(candidates);
  }

  List<String> _imageNumberCandidates() {
    final raw = number
        .trim()
        .split('/')
        .first
        .trim()
        .replaceAll('#', '')
        .replaceAll(RegExp(r'\s+'), '');

    final idNumber = id.trim().split('-').last.trim();

    final candidates = <String>[
      raw,
      idNumber,
    ];

    void addNumericCandidates(String value) {
      final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
      final numeric = int.tryParse(clean);
      if (numeric == null) return;

      candidates.add(numeric.toString());
      candidates.add(numeric.toString().padLeft(2, '0'));
      candidates.add(numeric.toString().padLeft(3, '0'));
    }

    addNumericCandidates(raw);
    addNumericCandidates(idNumber);

    if (raw.isNotEmpty) {
      final withoutExtraZeroes = raw.replaceFirstMapped(
        RegExp(r'^([A-Za-z]+)0+(\d+)$'),
        (match) => '${match.group(1)}${int.tryParse(match.group(2) ?? '') ?? match.group(2)}',
      );
      candidates.add(withoutExtraZeroes);
    }

    return _uniqueUrls(candidates);
  }

  static String? _cleanUrl(String? value) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty || clean.toLowerCase() == 'null') return null;
    return clean;
  }

  static List<String> _uniqueUrls(Iterable<String?> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in values) {
      final clean = _cleanUrl(value);
      if (clean == null) continue;

      if (seen.add(clean)) {
        result.add(clean);
      }
    }

    return result;
  }

  factory TcgCard.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as Map<String, dynamic>? ?? {});
    final set = (json['set'] as Map<String, dynamic>? ?? {});
    final rawPriceMoney = _extractRawCardMoney(json);

    final baseCard = TcgCard(
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
      rawPriceSource: rawPriceMoney == null ? '' : 'Pokémon TCG API',
      rawPriceBreakdown: _extractRawPriceBreakdown(json),
      gradedPrices: _extractGradedPrices(json),
      types: (json['types'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );

    if (!baseCard._isMcdonaldsCard) {
      return baseCard;
    }

    final mcdSmallCandidates = baseCard._fallbackImageUrls(large: false);
    final mcdLargeCandidates = baseCard._fallbackImageUrls(large: true);

    return TcgCard(
      id: baseCard.id,
      name: baseCard.name,
      setId: baseCard.setId,
      setName: baseCard.setName,
      number: baseCard.number,
      rarity: baseCard.rarity,
      hp: baseCard.hp,
      artist: baseCard.artist,
      flavorText: baseCard.flavorText,
      imageUrl: mcdSmallCandidates.isNotEmpty ? mcdSmallCandidates.first : baseCard.imageUrl,
      largeImageUrl: mcdLargeCandidates.isNotEmpty ? mcdLargeCandidates.first : baseCard.largeImageUrl,
      setLogoUrl: baseCard.setLogoUrl,
      rawPrice: baseCard.rawPrice,
      rawPriceCurrency: baseCard.rawPriceCurrency,
      rawPriceSource: baseCard.rawPriceSource,
      externalRawPrice: baseCard.externalRawPrice,
      externalRawPriceCurrency: baseCard.externalRawPriceCurrency,
      externalRawPriceSource: baseCard.externalRawPriceSource,
      externalRawPriceUpdatedAtMs: baseCard.externalRawPriceUpdatedAtMs,
      rawPriceBreakdown: baseCard.rawPriceBreakdown,
      gradedPrices: baseCard.gradedPrices,
      types: baseCard.types,
    );
  }
}
