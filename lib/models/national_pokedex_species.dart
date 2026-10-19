class NationalPokedexSpecies {
  const NationalPokedexSpecies({required this.number, required this.slug});

  final int number;
  final String slug;

  int get generation {
    if (number <= 151) return 1;
    if (number <= 251) return 2;
    if (number <= 386) return 3;
    if (number <= 493) return 4;
    if (number <= 649) return 5;
    if (number <= 721) return 6;
    if (number <= 809) return 7;
    if (number <= 905) return 8;
    return 9;
  }

  String get displayName {
    const exceptions = <String, String>{
      'nidoran-f': 'Nidoran ♀',
      'nidoran-m': 'Nidoran ♂',
      'mr-mime': 'Mr. Mime',
      'mime-jr': 'Mime Jr.',
      'farfetchd': "Farfetch’d",
      'sirfetchd': "Sirfetch’d",
      'ho-oh': 'Ho-Oh',
      'porygon-z': 'Porygon-Z',
      'type-null': 'Type: Null',
      'flabebe': 'Flabébé',
      'jangmo-o': 'Jangmo-o',
      'hakamo-o': 'Hakamo-o',
      'kommo-o': 'Kommo-o',
      'tapu-koko': 'Tapu Koko',
      'tapu-lele': 'Tapu Lele',
      'tapu-bulu': 'Tapu Bulu',
      'tapu-fini': 'Tapu Fini',
    };
    final special = exceptions[slug];
    if (special != null) return special;
    return slug.split('-').map((part) => part.isEmpty
        ? part
        : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
  }

  String get artworkUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$number.png';

  String get labelNumber => '#${number.toString().padLeft(4, '0')}';
}

class NationalOwnedCard {
  const NationalOwnedCard({
    required this.cardId,
    required this.name,
    required this.setName,
    this.imageUrl,
  });

  final String cardId;
  final String name;
  final String setName;
  final String? imageUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cardId': cardId, 'name': name, 'setName': setName, 'imageUrl': imageUrl,
  };

  factory NationalOwnedCard.fromJson(Map<String, dynamic> json) => NationalOwnedCard(
    cardId: (json['cardId'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    setName: (json['setName'] ?? '').toString(),
    imageUrl: json['imageUrl']?.toString(),
  );
}

class NationalPokedexResult {
  const NationalPokedexResult({
    required this.cardsBySpecies,
    required this.cardsPendingIdentification,
    required this.cardsWithoutSpeciesMatch,
  });

  final Map<int, List<NationalOwnedCard>> cardsBySpecies;
  final int cardsPendingIdentification;
  final int cardsWithoutSpeciesMatch;

  Set<int> get ownedSpeciesNumbers => cardsBySpecies.keys.toSet();
}
