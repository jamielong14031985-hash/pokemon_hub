import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tcg_card.dart';
import '../services/currency_settings.dart';

enum SealedProductType {
  boosterBox,
  eliteTrainerBox,
  boosterBundle,
  ultraPremiumCollection,
}

extension SealedProductTypeDetails on SealedProductType {
  String get label {
    switch (this) {
      case SealedProductType.boosterBox:
        return 'Booster Box';
      case SealedProductType.eliteTrainerBox:
        return 'Elite Trainer Box';
      case SealedProductType.boosterBundle:
        return 'Booster Bundle';
      case SealedProductType.ultraPremiumCollection:
        return 'Ultra-Premium Collection (UPC)';
    }
  }

  String get shortLabel {
    switch (this) {
      case SealedProductType.boosterBox:
        return 'Booster Box';
      case SealedProductType.eliteTrainerBox:
        return 'ETB';
      case SealedProductType.boosterBundle:
        return 'Booster Bundle';
      case SealedProductType.ultraPremiumCollection:
        return 'UPC';
    }
  }

  String get searchPhrase {
    switch (this) {
      case SealedProductType.boosterBox:
        return 'booster box';
      case SealedProductType.eliteTrainerBox:
        return 'elite trainer box';
      case SealedProductType.boosterBundle:
        return 'booster bundle';
      case SealedProductType.ultraPremiumCollection:
        return 'ultra premium collection';
    }
  }
}

Uri _buildRegionalEbaySoldUri({
  required String query,
  String? marketplaceCode,
}) {
  final normalizedMarketplaceCode = CurrencySettings.normalizeMarketplaceCode(
    marketplaceCode,
    currencyCode: CurrencySettings.selectedCode,
  );
  final marketplace =
      CurrencySettings.supportedMarketplaces[normalizedMarketplaceCode] ??
          CurrencySettings.selectedMarketplace;

  return Uri.https(
    marketplace.ebayHost,
    '/sch/i.html',
    <String, String>{
      '_nkw': query.trim().isEmpty ? 'pokemon sealed product' : query.trim(),
      '_sacat': '0',
      'LH_Sold': '1',
      'LH_Complete': '1',
    },
  );
}

Uri buildEbaySoldSearchUri({
  required TcgCard card,
  String? gradeLabel,
  String? marketplaceCode,
}) {
  final parts = <String>[
    card.name,
    card.setName,
    card.number,
    if (gradeLabel != null && gradeLabel.trim().isNotEmpty) gradeLabel.trim(),
    'pokemon card',
  ];

  return _buildRegionalEbaySoldUri(
    query: parts.where((part) => part.trim().isNotEmpty).join(' '),
    marketplaceCode: marketplaceCode,
  );
}

Uri buildEbaySealedSoldSearchUri({
  required String setName,
  required SealedProductType productType,
  String? marketplaceCode,
}) {
  final cleanSetName = setName.trim();
  final parts = <String>[
    'pokemon',
    if (cleanSetName.isNotEmpty) cleanSetName,
    productType.searchPhrase,
    'sealed',
  ];

  return _buildRegionalEbaySoldUri(
    query: parts.join(' '),
    marketplaceCode: marketplaceCode,
  );
}

Future<void> openEbaySoldSearch({
  required BuildContext context,
  required TcgCard card,
  String? gradeLabel,
  String? marketplaceCode,
}) async {
  final uri = buildEbaySoldSearchUri(
    card: card,
    gradeLabel: gradeLabel,
    marketplaceCode: marketplaceCode,
  );
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open ${CurrencySettings.selectedMarketplace.label} sold prices.',
        ),
      ),
    );
  }
}

Future<void> openEbaySealedSoldSearch({
  required BuildContext context,
  required String setName,
  required SealedProductType productType,
  String? marketplaceCode,
}) async {
  final uri = buildEbaySealedSoldSearchUri(
    setName: setName,
    productType: productType,
    marketplaceCode: marketplaceCode,
  );
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open ${CurrencySettings.selectedMarketplace.label} sold prices.',
        ),
      ),
    );
  }
}
