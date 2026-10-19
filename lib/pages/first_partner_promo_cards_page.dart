import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import '../services/pokedex_sync_service.dart';
import 'set_card_details_page.dart';

/// First Partner Illustration Collection 2026 promo checklist.
///
/// These are nine selected MEP Black Star Promo cards per series, NOT
/// independent printed expansion sets. Saved ownership therefore uses their
/// canonical `mep-XXX` IDs and `mep` set ID, so the same card is not counted
/// twice if a collector views it in the wider MEP promo binder.
class FirstPartnerPromoCardsPage extends StatefulWidget {
  const FirstPartnerPromoCardsPage({
    super.key,
    required this.seriesNumber,
  }) : assert(seriesNumber >= 1 && seriesNumber <= 3);

  final int seriesNumber;

  /// The same canonical MEP cards used by the three First Partner checklists.
  /// Reuse these in the Set Pokédex so owned cards do not disappear when the
  /// remote MEP set catalogue temporarily returns an empty card list.
  static List<TcgCard> knownMepPromoCards() => _allPromos.map((promo) {
    final image = _firstPartnerArtwork[promo.number];
    return TcgCard(
      id: promo.cardId,
      name: promo.name,
      setId: 'mep',
      setName: 'MEP Black Star Promos',
      number: promo.number.toString().padLeft(3, '0'),
      types: const <String>[],
      rarity: 'Promo',
      imageUrl: image,
      largeImageUrl: image,
      hasNormalVariant: true,
      hasReverseHoloVariant: false,
      hasHoloVariant: false,
    );
  }).toList(growable: false);

  @override
  State<FirstPartnerPromoCardsPage> createState() =>
      _FirstPartnerPromoCardsPageState();
}

class _FirstPartnerPromo {
  const _FirstPartnerPromo(this.number, this.name, this.region);

  final int number;
  final String name;
  final String region;

  String get cardId => 'mep-${number.toString().padLeft(3, '0')}';
}

const List<_FirstPartnerPromo> _allPromos = <_FirstPartnerPromo>[
  _FirstPartnerPromo(37, 'Bulbasaur', 'Kanto'),
  _FirstPartnerPromo(38, 'Charmander', 'Kanto'),
  _FirstPartnerPromo(39, 'Squirtle', 'Kanto'),
  _FirstPartnerPromo(40, 'Turtwig', 'Sinnoh'),
  _FirstPartnerPromo(41, 'Chimchar', 'Sinnoh'),
  _FirstPartnerPromo(42, 'Piplup', 'Sinnoh'),
  _FirstPartnerPromo(43, 'Rowlet', 'Alola'),
  _FirstPartnerPromo(44, 'Litten', 'Alola'),
  _FirstPartnerPromo(45, 'Popplio', 'Alola'),
  _FirstPartnerPromo(46, 'Chikorita', 'Johto'),
  _FirstPartnerPromo(47, 'Cyndaquil', 'Johto'),
  _FirstPartnerPromo(48, 'Totodile', 'Johto'),
  _FirstPartnerPromo(49, 'Snivy', 'Unova'),
  _FirstPartnerPromo(50, 'Tepig', 'Unova'),
  _FirstPartnerPromo(51, 'Oshawott', 'Unova'),
  _FirstPartnerPromo(52, 'Grookey', 'Galar'),
  _FirstPartnerPromo(53, 'Scorbunny', 'Galar'),
  _FirstPartnerPromo(54, 'Sobble', 'Galar'),
  _FirstPartnerPromo(55, 'Treecko', 'Hoenn'),
  _FirstPartnerPromo(56, 'Torchic', 'Hoenn'),
  _FirstPartnerPromo(57, 'Mudkip', 'Hoenn'),
  _FirstPartnerPromo(58, 'Chespin', 'Kalos'),
  _FirstPartnerPromo(59, 'Fennekin', 'Kalos'),
  _FirstPartnerPromo(60, 'Froakie', 'Kalos'),
  _FirstPartnerPromo(61, 'Sprigatito', 'Paldea'),
  _FirstPartnerPromo(62, 'Fuecoco', 'Paldea'),
  _FirstPartnerPromo(63, 'Quaxly', 'Paldea'),
];

// Verified MEP promo file names from the First Partner Illustration
// Collection archive. TCGdex currently omits an image field on many MEP
// records, so those metadata-only responses cannot supply the card art.
// These card-specific URLs preserve the exact English promo printing.
const Map<int, String> _firstPartnerArtwork = <int, String>{
  37: 'https://archives.bulbagarden.net/media/upload/3/32/BulbasaurMEPPromo37.jpg',
  38: 'https://archives.bulbagarden.net/media/upload/b/b3/CharmanderMEPPromo38.jpg',
  39: 'https://archives.bulbagarden.net/media/upload/e/e9/SquirtleMEPPromo39.jpg',
  40: 'https://archives.bulbagarden.net/media/upload/b/ba/TurtwigMEPPromo40.jpg',
  41: 'https://archives.bulbagarden.net/media/upload/d/de/ChimcharMEPPromo41.jpg',
  42: 'https://archives.bulbagarden.net/media/upload/5/5f/PiplupMEPPromo42.jpg',
  43: 'https://archives.bulbagarden.net/media/upload/5/5b/RowletMEPPromo43.jpg',
  44: 'https://archives.bulbagarden.net/media/upload/9/92/LittenMEPPromo44.jpg',
  45: 'https://archives.bulbagarden.net/media/upload/9/9c/PopplioMEPPromo45.jpg',
  46: 'https://archives.bulbagarden.net/media/upload/4/41/ChikoritaMEPPromo46.jpg',
  47: 'https://archives.bulbagarden.net/media/upload/f/fb/CyndaquilMEPPromo47.jpg',
  48: 'https://archives.bulbagarden.net/media/upload/8/8c/TotodileMEPPromo48.jpg',
  49: 'https://archives.bulbagarden.net/media/upload/2/2f/SnivyMEPPromo49.jpg',
  50: 'https://archives.bulbagarden.net/media/upload/c/c2/TepigMEPPromo50.jpg',
  51: 'https://archives.bulbagarden.net/media/upload/0/02/OshawottMEPPromo51.jpg',
  52: 'https://archives.bulbagarden.net/media/upload/4/48/GrookeyMEPPromo52.jpg',
  53: 'https://archives.bulbagarden.net/media/upload/e/e5/ScorbunnyMEPPromo53.jpg',
  54: 'https://archives.bulbagarden.net/media/upload/3/37/SobbleMEPPromo54.jpg',
  55: 'https://archives.bulbagarden.net/media/upload/3/38/TreeckoMEPPromo55.jpg',
  56: 'https://archives.bulbagarden.net/media/upload/a/a8/TorchicMEPPromo56.jpg',
  57: 'https://archives.bulbagarden.net/media/upload/6/63/MudkipMEPPromo57.jpg',
  58: 'https://archives.bulbagarden.net/media/upload/b/bb/ChespinMEPPromo58.jpg',
  59: 'https://archives.bulbagarden.net/media/upload/5/5b/FennekinMEPPromo59.jpg',
  60: 'https://archives.bulbagarden.net/media/upload/5/50/FroakieMEPPromo60.jpg',
  61: 'https://archives.bulbagarden.net/media/upload/d/d6/SprigatitoMEPPromo61.jpg',
  62: 'https://archives.bulbagarden.net/media/upload/8/81/FuecocoMEPPromo62.jpg',
  63: 'https://archives.bulbagarden.net/media/upload/d/d9/QuaxlyMEPPromo63.jpg',
};

class _FirstPartnerPromoCardsPageState
    extends State<FirstPartnerPromoCardsPage> {
  static const _background = Color(0xFF041B4A);
  static const _panel = Color(0xFF102754);
  static const _gold = Color(0xFFF7DE77);
  static const _muted = Color(0xFFC8D4F0);

  final Map<String, CardOwnership> _ownership = <String, CardOwnership>{};
  final Map<String, TcgCard> _cards = <String, TcgCard>{};
  bool _loadingOwnership = true;
  bool _missingOnly = false;

  late final List<_FirstPartnerPromo> _promos;

  @override
  void initState() {
    super.initState();
    final firstNumber = 37 + (widget.seriesNumber - 1) * 9;
    _promos = _allPromos
        .where((entry) => entry.number >= firstNumber && entry.number < firstNumber + 9)
        .toList(growable: false);
    for (final promo in _promos) {
      _cards[promo.cardId] = _asCard(promo);
    }
    _loadOwnership();
  }

  TcgCard _asCard(_FirstPartnerPromo promo) {
    final image = _firstPartnerArtwork[promo.number];
    return TcgCard(
      id: promo.cardId,
      name: promo.name,
      setId: 'mep',
      setName: 'MEP Black Star Promos',
      number: promo.number.toString().padLeft(3, '0'),
      types: const <String>[],
      rarity: 'Promo',
      imageUrl: image,
      largeImageUrl: image,
      hasNormalVariant: true,
      hasReverseHoloVariant: false,
      hasHoloVariant: false,
    );
  }

  Future<void> _loadOwnership() async {
    try {
      final existing = await PokedexSyncService.loadCurrentUserSetOwnership('mep');
      if (!mounted) return;
      setState(() {
        _ownership
          ..clear()
          ..addAll(existing);
        _loadingOwnership = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOwnership = false);
    }
  }

  CardOwnership _ownershipForPromo(_FirstPartnerPromo promo) {
    final canonical = _ownership[promo.cardId] ?? const CardOwnership();
    // Support earlier provider-style IDs without changing stored data.
    // Only the matching Pokémon's name is a safe alias for this promo.
    final slug = promo.name.trim().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final alias = _ownership['${promo.cardId}-$slug'];
    if (alias != null && alias.collectionCount > canonical.collectionCount) {
      return alias;
    }
    return canonical;
  }

  int _copies(_FirstPartnerPromo promo) =>
      _ownershipForPromo(promo).collectionCount;

  Future<void> _openCard(_FirstPartnerPromo promo) async {
    final cards = _promos.map((e) => _cards[e.cardId]!).toList();
    final index = _promos.indexOf(promo);
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => SetCardDetailsPage(
        card: cards[index],
        ownership: _ownershipForPromo(promo),
        navigationCards: cards,
        navigationIndex: index,
      ),
    ));
    if (mounted) await _loadOwnership();
  }

  String get _seriesRegions => switch (widget.seriesNumber) {
    1 => 'Kanto / Sinnoh / Alola',
    2 => 'Johto / Unova / Galar',
    _ => 'Hoenn / Kalos / Paldea',
  };

  String get _logoPath =>
      'assets/images/first_partner_series_${widget.seriesNumber}.png';

  // Match the layout used by Search > Sets for regular expansions, while
  // keeping ownership and card details linked to the canonical MEP promos.
  Widget _setBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _muted,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _setHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: [
        SizedBox(
          width: double.infinity,
          height: 112,
          child: Center(
            child: Image.asset(
              _logoPath,
              height: 94,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.collections_bookmark_outlined,
                color: _gold,
                size: 48,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // These badges mirror the regular set page's card-count/series row.
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _setBadge('9 cards'),
              const SizedBox(width: 8),
              _setBadge('MEP Black Star Promos'),
              const SizedBox(width: 8),
              _setBadge('Series ${widget.seriesNumber}'),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _seriesRegions,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _cardImage(TcgCard card) {
    final url = (card.imageUrl ?? card.largeImageUrl ?? '').trim();
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFF0E2A5E),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: _gold),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF0E2A5E),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: _gold),
      ),
    );
  }

  Widget _cardTile(_FirstPartnerPromo promo) {
    final copies = _copies(promo);
    final card = _cards[promo.cardId]!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openCard(promo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _cardImage(card),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  '#${card.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (copies > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'x$copies',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owned = _promos.where((p) => _copies(p) > 0).length;
    final visible = _missingOnly
        ? _promos.where((p) => _copies(p) == 0).toList(growable: false)
        : _promos;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: _background,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('First Partner — Series ${widget.seriesNumber}'),
        actions: [
          IconButton(
            tooltip: 'Refresh ownership',
            onPressed: _loadOwnership,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOwnership,
        color: _gold,
        backgroundColor: _panel,
        child: LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 5
              : constraints.maxWidth >= 650
                  ? 4
                  : 3;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  _setHero(),
                  const SizedBox(height: 16),
                  Text(
                    _loadingOwnership
                        ? 'Showing 9 cards from this set\n• Loading your collection...'
                        : 'Showing 9 cards from this set\n• $owned saved to your collection.',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilterChip(
                      label: const Text('Missing only'),
                      selected: _missingOnly,
                      onSelected: (value) => setState(() => _missingOnly = value),
                    ),
                  ),
                  const SizedBox(height: 10),
                ])),
              ),
              if (visible.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        _loadingOwnership
                            ? 'Loading your collection...'
                            : 'All nine cards in this series are owned.',
                        style: const TextStyle(color: _muted, fontSize: 14),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.76,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _cardTile(visible[index]),
                      childCount: visible.length,
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
