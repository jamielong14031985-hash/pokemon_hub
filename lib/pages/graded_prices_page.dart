import 'package:flutter/material.dart';

import '../models/tcg_card.dart';
import '../utils/ebay_sold_search.dart';
import '../widgets/fast_network_image.dart';
import '../widgets/graded_prices_card.dart';
import '../widgets/set_logo_widgets.dart';

class GradedPricesPage extends StatelessWidget {
  const GradedPricesPage({
    super.key,
    required this.card,
  });

  final TcgCard card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Graded Prices'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SetLogoTile(setId: card.setId, setName: card.setName, logoUrl: card.setLogoUrl),
            Card(
              color: const Color(0xFF102754),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (card.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FastNetworkImage(
                          imageUrl: card.imageUrl!,
                          fit: BoxFit.cover,
                          width: 72,
                          height: 100,
                          cacheWidth: 180,
                          cacheHeight: 252,
                        ),
                      )
                    else
                      Container(
                        width: 72,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E2A5E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.white70,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card.setName,
                            style: const TextStyle(
                              color: Color(0xFFC8D4F0),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (card.number.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '#${card.number}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GradedPricesCard(
              card: card,
              gradedPrices: card.gradedPrices,
              onOpenSoldSearch: (gradeLabel) => openEbaySoldSearch(
                context: context,
                card: card,
                gradeLabel: gradeLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
