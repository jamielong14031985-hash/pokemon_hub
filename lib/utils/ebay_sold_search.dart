import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tcg_card.dart';

Uri buildEbaySoldSearchUri({
  required TcgCard card,
  String? gradeLabel,
}) {
  final parts = <String>[
    card.name,
    card.setName,
    card.number,
    if (gradeLabel != null && gradeLabel.isNotEmpty) gradeLabel,
    'pokemon card',
  ];
  final query = parts.where((e) => e.trim().isNotEmpty).join(' ');
  return Uri.https('www.ebay.co.uk', '/sch/i.html', {
    '_nkw': query,
    'LH_Sold': '1',
    'LH_Complete': '1',
  });
}

Future<void> openEbaySoldSearch({
  required BuildContext context,
  required TcgCard card,
  String? gradeLabel,
}) async {
  final uri = buildEbaySoldSearchUri(card: card, gradeLabel: gradeLabel);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open eBay sold search.')),
    );
  }
}
