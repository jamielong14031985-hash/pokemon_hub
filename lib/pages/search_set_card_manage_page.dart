import 'package:flutter/material.dart';

import '../models/card_ownership.dart';
import '../models/tcg_card.dart';
import '../utils/ebay_sold_search.dart';
import '../widgets/graded_prices_button.dart';
import '../widgets/price_lookup_card.dart';
import '../widgets/set_logo_widgets.dart';
import 'graded_prices_page.dart';

class SearchSetCardManagePage extends StatefulWidget {
  const SearchSetCardManagePage({
    super.key,
    required this.card,
    required this.setName,
    required this.ownership,
  });

  final TcgCard card;
  final String setName;
  final CardOwnership ownership;

  @override
  State<SearchSetCardManagePage> createState() => _SearchSetCardManagePageState();
}

class _SearchSetCardManagePageState extends State<SearchSetCardManagePage> {
  late int _copies;

  @override
  void initState() {
    super.initState();
    _copies = widget.ownership.effectiveCopies;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(card.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SetLogoTile(setId: card.setId, setName: widget.setName, logoUrl: card.setLogoUrl),
                  if (card.largeImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(card.largeImageUrl!, height: 320),
                    ),
                  const SizedBox(height: 16),
                  PriceLookupCard(
                    card: card,
                    onOpenRawSold: () => openEbaySoldSearch(context: context, card: card),
                  ),
                  GradedPricesButton(
                    card: card,
                    onOpenGradedPrices: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GradedPricesPage(card: card),
                        ),
                      );
                    },
                  ),
                  Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Copies in Set Pokédex',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _copies > 0
                                      ? () {
                                          setState(() {
                                            _copies--;
                                          });
                                        }
                                      : null,
                                  child: const Text('- Remove'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 72,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '$_copies',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _copies++;
                                    });
                                  },
                                  child: const Text('+ Add'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'If a card has more than 1 copy, it will get a shiny border in the set Pokédex.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      widget.ownership.copyWith(copies: _copies),
                    );
                  },
                  child: const Text('Save Card Count'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

