import 'package:flutter/material.dart';

import 'custom_app_logo.dart';

class CardsSearchPlaceholder extends StatelessWidget {
  const CardsSearchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.03),
                  Colors.transparent,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 164,
              height: 164,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.55),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.28),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.10),
                    blurRadius: 12,
                    spreadRadius: 1,
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
                        size: 84,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Search cards or sets',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose Cards or Sets above, then type a Pokémon name, card name, or set name to start.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
