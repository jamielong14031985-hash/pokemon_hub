import 'package:flutter/material.dart';

import '../models/tcg_set.dart';
import '../pages/search_set_details_page.dart';
import '../services/pokemon_tcg_service.dart';
import 'set_info_chip.dart';
import 'set_logo_widgets.dart';

class SetSearchResultCard extends StatelessWidget {
  const SetSearchResultCard({super.key, required this.set});

  final TcgSet set;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final cardsFuture = PokemonTcgService.fetchCardsBySet(set.id);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SearchSetDetailsPage(
                set: set,
                initialCardsFuture: cardsFuture,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ResolvedSetLogo(
                  setId: set.id,
                  setName: set.name,
                  fallbackLogoUrl: set.logoUrl,
                  height: 72,
                  fit: BoxFit.contain,
                  cacheWidth: 360,
                  cacheHeight: 144,
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SetInfoChip(label: '${set.total} cards'),
                  SetInfoChip(label: set.series),
                  SetInfoChip(label: set.releaseDate),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Tap this set to open it and view all of the cards inside.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
