import 'package:flutter/material.dart';

enum _CardsPlaceholderMode {
  cards,
  sets,
}

class CardsSearchPlaceholder extends StatelessWidget {
  const CardsSearchPlaceholder({super.key})
      : _mode = _CardsPlaceholderMode.cards;

  const CardsSearchPlaceholder.sets({super.key})
      : _mode = _CardsPlaceholderMode.sets;

  final _CardsPlaceholderMode _mode;

  bool get _isCards => _mode == _CardsPlaceholderMode.cards;

  @override
  Widget build(BuildContext context) {
    final title = _isCards ? 'Find your next card' : 'Search all sets';
    final message = _isCards
        ? 'Search by Pokémon name, set code or card number.'
        : 'Find English and Japanese Pokémon sets by name.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlossySearchPromptCard(
          title: title,
          message: message,
          badge: _GlossyModeBadge(
            label: _isCards ? 'Cards' : 'Sets',
            assetPath: _isCards
                ? 'assets/images/pc_search_cards.png'
                : 'assets/images/pc_search_sets.png',
            selected: false,
            fallbackIcon: _isCards
                ? Icons.style_rounded
                : Icons.collections_bookmark_rounded,
          ),
        ),
        const SizedBox(height: 18),
        _PageBadgeShowcase(
          assetPath: _isCards
              ? 'assets/images/pc_hero_cards.png'
              : 'assets/images/pc_hero_sets.png',
          fallbackIcon: _isCards
              ? Icons.style_rounded
              : Icons.collections_bookmark_rounded,
        ),
      ],
    );
  }
}

class _GlossySearchPromptCard extends StatelessWidget {
  const _GlossySearchPromptCard({
    required this.title,
    required this.message,
    required this.badge,
  });

  final String title;
  final String message;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E2D63),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.11),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            badge,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFD4E1FA),
                      fontSize: 13.2,
                      height: 1.34,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uses the exact illustration from the approved PocketChase mockup.
/// It already contains its own Poké Ball motif, lighting and artwork.
/// Do not overlay extra circles or redraw the glow in Flutter.
class _PageBadgeShowcase extends StatelessWidget {
  const _PageBadgeShowcase({
    required this.assetPath,
    required this.fallbackIcon,
  });

  final String assetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 280,
        width: double.infinity,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              fallbackIcon,
              size: 106,
              color: const Color(0xFFF7DE77),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlossyModeBadge extends StatelessWidget {
  const _GlossyModeBadge({
    required this.label,
    required this.assetPath,
    required this.selected,
    required this.fallbackIcon,
  });

  final String label;
  final String assetPath;
  final bool selected;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0B224A);

    return Container(
      width: 94,
      height: 94,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? const [
                  Color(0xFFFFF3A0),
                  Color(0xFFFFDE57),
                  Color(0xFFF8C93E),
                ]
              : const [
                  Color(0xFF18518F),
                  Color(0xFF0D3266),
                  Color(0xFF061D49),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? const Color(0xFFFFF2A9)
              : const Color(0xFF468AC4),
          width: selected ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? const Color(0xFFFFDE56).withValues(alpha: 0.30)
                : const Color(0xFF2D8EDF).withValues(alpha: 0.16),
            blurRadius: selected ? 16 : 11,
            spreadRadius: selected ? 0.4 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              top: -16,
              right: -10,
              child: Icon(
                Icons.catching_pokemon,
                size: 50,
                color: selected
                    ? Colors.white.withValues(alpha: 0.14)
                    : const Color(0xFFB3DAFF).withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => Icon(
                          fallbackIcon,
                          size: 34,
                          color: selected ? ink : const Color(0xFFFFDE56),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? ink : Colors.white,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 4,
                    width: selected ? 24 : 18,
                    decoration: BoxDecoration(
                      color: selected ? ink : const Color(0xFFA9D0F5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
