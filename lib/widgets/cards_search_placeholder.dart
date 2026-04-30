import 'package:flutter/material.dart';

import 'custom_app_logo.dart';

class CardsSearchPlaceholder extends StatelessWidget {
  const CardsSearchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF173A78),
            Color(0xFF102754),
            Color(0xFF071B43),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SearchHeroLogo(),
          const SizedBox(height: 22),
          const Text(
            'Search cards or sets',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose Cards or Sets above, then type a Pokémon name, card name, collector number, or set name to start.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFC8D4F0),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SearchHintChip(
                icon: Icons.catching_pokemon,
                label: 'Pikachu',
              ),
              _SearchHintChip(
                icon: Icons.numbers_rounded,
                label: '4/102',
              ),
              _SearchHintChip(
                icon: Icons.collections_bookmark_outlined,
                label: 'Base Set',
              ),
              _SearchHintChip(
                icon: Icons.auto_awesome_outlined,
                label: 'Charizard ex',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: Color(0xFFF7DE77),
                  size: 21,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: shorter searches are usually faster. Try the card name first, then add more words if needed.',
                    style: TextStyle(
                      color: Color(0xFFE4ECFF),
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHeroLogo extends StatelessWidget {
  const _SearchHeroLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 214,
      height: 214,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFF7DE77).withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 178,
            height: 178,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.18),
                width: 10,
              ),
            ),
          ),
          Container(
            width: 158,
            height: 158,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.62),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.26),
                  blurRadius: 28,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                kCustomAppLogoAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) {
                  return const Center(
                    child: Icon(
                      Icons.style,
                      color: Color(0xFFF7DE77),
                      size: 82,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            right: 26,
            bottom: 32,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF7DE77),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF102754), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Color(0xFF071B43),
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHintChip extends StatelessWidget {
  const _SearchHintChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7DE77).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFF7DE77).withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFF7DE77), size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFF2B3),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
