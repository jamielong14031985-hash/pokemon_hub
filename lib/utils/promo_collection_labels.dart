/// Human-readable collection labels for identifiable promotional printings.
///
/// A promo's canonical set ID remains `mep` for ownership and syncing. The
/// First Partner series is a curated subset of that larger promo set, so its
/// display label must never be used as a replacement database set ID.
class PromoCollectionLabels {
  static const List<String> _firstPartnerNames = <String>[
    'Bulbasaur', 'Charmander', 'Squirtle',
    'Turtwig', 'Chimchar', 'Piplup',
    'Rowlet', 'Litten', 'Popplio',
    'Chikorita', 'Cyndaquil', 'Totodile',
    'Snivy', 'Tepig', 'Oshawott',
    'Grookey', 'Scorbunny', 'Sobble',
    'Treecko', 'Torchic', 'Mudkip',
    'Chespin', 'Fennekin', 'Froakie',
    'Sprigatito', 'Fuecoco', 'Quaxly',
  ];

  static String displaySetName({
    required String cardId,
    required String cardName,
    required String fallbackSetName,
    String setId = '',
    String number = '',
  }) {
    final id = cardId.trim().toLowerCase();
    final parent = setId.trim().toLowerCase();
    final match = RegExp(r'^mep[-_](\d{1,3})(?:[-_](.+))?$').firstMatch(id);
    if (match == null && parent != 'mep') { return fallbackSetName; }

    final code = match == null ? int.tryParse(number.trim()) : int.tryParse(match.group(1)!);
    if (code == null || code < 37 || code > 63) { return fallbackSetName; }
    final expectedName = _firstPartnerNames[code - 37].toLowerCase();
    if (cardName.trim().toLowerCase() != expectedName) { return fallbackSetName; }

    // Do not relabel suspicious legacy IDs such as mep-037-ns-zekrom.
    final suffix = match?.group(2);
    if (suffix != null && suffix.replaceAll('-', '').replaceAll('_', '') != expectedName.replaceAll(' ', '')) {
      return fallbackSetName;
    }

    final series = ((code - 37) ~/ 9) + 1;
    final region = <String>[
      'Kanto', 'Sinnoh', 'Alola', 'Johto', 'Unova', 'Galar',
      'Hoenn', 'Kalos', 'Paldea',
    ][(code - 37) ~/ 3];
    return 'First Partner Series Collection 2026 · Series $series ($region)';
  }
}
