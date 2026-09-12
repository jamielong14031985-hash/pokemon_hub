import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<int> currencyRefreshNotifier = ValueNotifier<int>(0);

class SupportedCurrency {
  const SupportedCurrency({
    required this.code,
    required this.label,
    required this.symbol,
    required this.defaultMarketplaceCode,
  });

  final String code;
  final String label;
  final String symbol;
  final String defaultMarketplaceCode;
}

class SupportedMarketplace {
  const SupportedMarketplace({
    required this.code,
    required this.label,
    required this.ebayHost,
    required this.currencyCode,
  });

  final String code;
  final String label;
  final String ebayHost;
  final String currencyCode;
}

class CurrencySettings {
  static const String _prefsKey = 'selected_currency_code';
  static const String _marketplacePrefsKey = 'selected_marketplace_code';

  static const Map<String, SupportedCurrency> supportedCurrencies =
      <String, SupportedCurrency>{
    'GBP': SupportedCurrency(
      code: 'GBP',
      label: 'British Pound',
      symbol: '£',
      defaultMarketplaceCode: 'UK',
    ),
    'USD': SupportedCurrency(
      code: 'USD',
      label: 'US Dollar',
      symbol: r'$',
      defaultMarketplaceCode: 'US',
    ),
    'EUR': SupportedCurrency(
      code: 'EUR',
      label: 'Euro',
      symbol: '€',
      defaultMarketplaceCode: 'IE',
    ),
    'CAD': SupportedCurrency(
      code: 'CAD',
      label: 'Canadian Dollar',
      symbol: r'C$',
      defaultMarketplaceCode: 'CA',
    ),
    'AUD': SupportedCurrency(
      code: 'AUD',
      label: 'Australian Dollar',
      symbol: r'A$',
      defaultMarketplaceCode: 'AU',
    ),
  };

  static const Map<String, SupportedMarketplace> supportedMarketplaces =
      <String, SupportedMarketplace>{
    'UK': SupportedMarketplace(
      code: 'UK',
      label: 'eBay UK',
      ebayHost: 'www.ebay.co.uk',
      currencyCode: 'GBP',
    ),
    'US': SupportedMarketplace(
      code: 'US',
      label: 'eBay US',
      ebayHost: 'www.ebay.com',
      currencyCode: 'USD',
    ),
    'IE': SupportedMarketplace(
      code: 'IE',
      label: 'eBay Ireland / Europe',
      ebayHost: 'www.ebay.ie',
      currencyCode: 'EUR',
    ),
    'CA': SupportedMarketplace(
      code: 'CA',
      label: 'eBay Canada',
      ebayHost: 'www.ebay.ca',
      currencyCode: 'CAD',
    ),
    'AU': SupportedMarketplace(
      code: 'AU',
      label: 'eBay Australia',
      ebayHost: 'www.ebay.com.au',
      currencyCode: 'AUD',
    ),
  };

  static final Map<String, Map<String, double>> _ratesByBase =
      <String, Map<String, double>>{
    'USD': <String, double>{
      'USD': 1,
      'GBP': 0.79,
      'EUR': 0.92,
      'CAD': 1.37,
      'AUD': 1.52,
    },
    'EUR': <String, double>{
      'EUR': 1,
      'GBP': 0.86,
      'USD': 1.09,
      'CAD': 1.49,
      'AUD': 1.65,
    },
    'GBP': <String, double>{
      'GBP': 1,
      'USD': 1.26,
      'EUR': 1.16,
      'CAD': 1.73,
      'AUD': 1.92,
    },
    'CAD': <String, double>{
      'CAD': 1,
      'USD': 0.73,
      'GBP': 0.58,
      'EUR': 0.67,
      'AUD': 1.11,
    },
    'AUD': <String, double>{
      'AUD': 1,
      'USD': 0.66,
      'GBP': 0.52,
      'EUR': 0.61,
      'CAD': 0.90,
    },
  };

  static String _selectedCode = 'GBP';
  static String _selectedMarketplaceCode = 'UK';

  static String get selectedCode => _selectedCode;

  static String get selectedMarketplaceCode => _selectedMarketplaceCode;

  static SupportedCurrency get selectedCurrency =>
      supportedCurrencies[_selectedCode] ?? supportedCurrencies['GBP']!;

  static SupportedMarketplace get selectedMarketplace =>
      supportedMarketplaces[_selectedMarketplaceCode] ??
      supportedMarketplaces[selectedCurrency.defaultMarketplaceCode] ??
      supportedMarketplaces['UK']!;

  static String normalizeCurrencyCode(String? code) {
    final normalized = (code ?? '').trim().toUpperCase();
    if (supportedCurrencies.containsKey(normalized)) return normalized;
    return 'GBP';
  }

  static String marketplaceCodeForCurrency(String? currencyCode) {
    final normalizedCurrency = normalizeCurrencyCode(currencyCode);
    return supportedCurrencies[normalizedCurrency]?.defaultMarketplaceCode ?? 'UK';
  }

  static String normalizeMarketplaceCode(
    String? code, {
    String? currencyCode,
  }) {
    final normalized = (code ?? '').trim().toUpperCase();
    if (supportedMarketplaces.containsKey(normalized)) return normalized;
    return marketplaceCodeForCurrency(currencyCode);
  }

  static Map<String, Object?> preferenceDataForCurrency(
    String? currencyCode, {
    String? marketplaceCode,
  }) {
    final cleanCurrencyCode = normalizeCurrencyCode(currencyCode);
    final cleanMarketplaceCode = normalizeMarketplaceCode(
      marketplaceCode,
      currencyCode: cleanCurrencyCode,
    );

    return <String, Object?>{
      'preferredCurrencyCode': cleanCurrencyCode,
      'preferredMarketplaceCode': cleanMarketplaceCode,
    };
  }

  static Map<String, Object?> get selectedPreferenceData {
    return <String, Object?>{
      'preferredCurrencyCode': selectedCode,
      'preferredMarketplaceCode': selectedMarketplaceCode,
    };
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefsKey);
    final savedMarketplaceCode = prefs.getString(_marketplacePrefsKey);

    _selectedCode = normalizeCurrencyCode(savedCode);
    _selectedMarketplaceCode = normalizeMarketplaceCode(
      savedMarketplaceCode,
      currencyCode: _selectedCode,
    );

    await _ensureAllRates();
  }

  static Future<void> setSelectedCode(String code) async {
    await setPreferredCurrencyAndMarketplace(currencyCode: code);
  }

  static Future<void> setPreferredCurrencyAndMarketplace({
    required String currencyCode,
    String? marketplaceCode,
  }) async {
    final normalizedCurrencyCode = normalizeCurrencyCode(currencyCode);
    final normalizedMarketplaceCode = normalizeMarketplaceCode(
      marketplaceCode,
      currencyCode: normalizedCurrencyCode,
    );

    await _ensureAllRates();

    _selectedCode = normalizedCurrencyCode;
    _selectedMarketplaceCode = normalizedMarketplaceCode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalizedCurrencyCode);
    await prefs.setString(_marketplacePrefsKey, normalizedMarketplaceCode);
    currencyRefreshNotifier.value++;
  }

  static Future<void> applyStoredPreferenceData(Map<String, dynamic>? data) async {
    if (data == null) return;

    final rawCurrencyCode = data['preferredCurrencyCode'] ??
        data['displayCurrencyCode'] ??
        data['currencyCode'];
    final rawMarketplaceCode = data['preferredMarketplaceCode'] ??
        data['marketplaceCode'] ??
        data['ebayMarketplaceCode'];

    await setPreferredCurrencyAndMarketplace(
      currencyCode: rawCurrencyCode?.toString() ?? selectedCode,
      marketplaceCode: rawMarketplaceCode?.toString(),
    );
  }

  static Future<void> _ensureAllRates() async {
    await Future.wait<void>(
      supportedCurrencies.keys.map(_ensureRatesForBase),
    );
  }

  static Future<void> _ensureRatesForBase(String base) async {
    final normalizedBase = normalizeCurrencyCode(base);
    final quotes = supportedCurrencies.keys
        .where((item) => item != normalizedBase)
        .join(',');
    final uri = Uri.parse(
      'https://api.frankfurter.dev/v1/latest?base=$normalizedBase&symbols=$quotes',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawRates =
          (json['rates'] as Map<String, dynamic>? ?? const <String, dynamic>{});
      final parsed = <String, double>{normalizedBase: 1};

      for (final entry in rawRates.entries) {
        final value = (entry.value as num?)?.toDouble();
        if (value != null && value > 0) {
          parsed[entry.key.toUpperCase()] = value;
        }
      }

      for (final currency in supportedCurrencies.keys) {
        parsed.putIfAbsent(
          currency,
          () => _ratesByBase[normalizedBase]?[currency] ??
              (currency == normalizedBase ? 1 : 0),
        );
      }

      _ratesByBase[normalizedBase] = parsed;
    } catch (_) {}
  }

  static double? convertAmountSync(
    double? amount, {
    required String fromCurrency,
  }) {
    if (amount == null || !amount.isFinite) return null;

    final normalizedFrom = normalizeCurrencyCode(fromCurrency);
    if (amount <= 0) return amount;
    if (normalizedFrom == _selectedCode) return amount;

    final directRate = _ratesByBase[normalizedFrom]?[_selectedCode];
    if (directRate != null && directRate > 0) {
      return amount * directRate;
    }

    if (normalizedFrom != 'USD') {
      final toUsd = _ratesByBase[normalizedFrom]?['USD'];
      final fromUsd = _ratesByBase['USD']?[_selectedCode];
      if (toUsd != null && toUsd > 0 && fromUsd != null && fromUsd > 0) {
        return amount * toUsd * fromUsd;
      }
    }

    return amount;
  }

  static String formatAmount(
    double? amount, {
    String fromCurrency = 'USD',
  }) {
    final converted = convertAmountSync(amount, fromCurrency: fromCurrency);
    if (converted == null || converted <= 0) return 'Unavailable';
    return '${selectedCurrency.symbol}${converted.toStringAsFixed(2)}';
  }

  static String formatSelectedAmount(double? amount) {
    if (amount == null || !amount.isFinite || amount <= 0) {
      return 'Unavailable';
    }
    return '${selectedCurrency.symbol}${amount.toStringAsFixed(2)}';
  }

  static Uri buildEbaySearchUri(
    String searchText, {
    String? marketplaceCode,
  }) {
    final marketplace = supportedMarketplaces[
            normalizeMarketplaceCode(marketplaceCode, currencyCode: selectedCode)] ??
        selectedMarketplace;
    final cleanSearchText = searchText.trim();

    return Uri.https(
      marketplace.ebayHost,
      '/sch/i.html',
      <String, String>{
        '_nkw': cleanSearchText.isEmpty ? 'pokemon card graded' : cleanSearchText,
        '_sacat': '0',
      },
    );
  }

  static Uri buildGradedCardEbaySearchUri({
    required String cardName,
    String setName = '',
    String number = '',
    String grader = '',
    String? marketplaceCode,
  }) {
    final parts = <String>[
      cardName,
      if (setName.trim().isNotEmpty) setName,
      if (number.trim().isNotEmpty) number,
      if (grader.trim().isNotEmpty) grader,
      'graded pokemon card',
    ];

    return buildEbaySearchUri(
      parts.where((part) => part.trim().isNotEmpty).join(' '),
      marketplaceCode: marketplaceCode,
    );
  }
}
