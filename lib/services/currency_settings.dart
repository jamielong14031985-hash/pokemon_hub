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
  });

  final String code;
  final String label;
  final String symbol;
}

class CurrencySettings {
  static const String _prefsKey = 'selected_currency_code';

  static const Map<String, SupportedCurrency> supportedCurrencies =
      <String, SupportedCurrency>{
    'GBP': SupportedCurrency(
      code: 'GBP',
      label: 'British Pound',
      symbol: '£',
    ),
    'USD': SupportedCurrency(
      code: 'USD',
      label: 'US Dollar',
      symbol: r'$',
    ),
    'EUR': SupportedCurrency(
      code: 'EUR',
      label: 'Euro',
      symbol: '€',
    ),
  };

  static final Map<String, Map<String, double>> _ratesByBase =
      <String, Map<String, double>>{
    'USD': <String, double>{'USD': 1, 'GBP': 0.79, 'EUR': 0.92},
    'EUR': <String, double>{'EUR': 1, 'GBP': 0.86, 'USD': 1.09},
    'GBP': <String, double>{'GBP': 1, 'USD': 1.26, 'EUR': 1.16},
  };

  static String _selectedCode = 'GBP';

  static String get selectedCode => _selectedCode;

  static SupportedCurrency get selectedCurrency =>
      supportedCurrencies[_selectedCode] ?? supportedCurrencies['GBP']!;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefsKey)?.toUpperCase();
    if (savedCode != null && supportedCurrencies.containsKey(savedCode)) {
      _selectedCode = savedCode;
    }

    await Future.wait(<Future<void>>[
      _ensureRatesForBase('USD'),
      _ensureRatesForBase('EUR'),
      _ensureRatesForBase('GBP'),
    ]);
  }

  static Future<void> setSelectedCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!supportedCurrencies.containsKey(normalized)) return;

    await Future.wait(<Future<void>>[
      _ensureRatesForBase('USD'),
      _ensureRatesForBase('EUR'),
      _ensureRatesForBase('GBP'),
    ]);

    _selectedCode = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);
    currencyRefreshNotifier.value++;
  }

  static Future<void> _ensureRatesForBase(String base) async {
    final quotes = supportedCurrencies.keys.where((item) => item != base).join(',');
    final uri = Uri.parse(
      'https://api.frankfurter.dev/v1/latest?base=$base&symbols=$quotes',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawRates = (json['rates'] as Map<String, dynamic>? ?? const <String, dynamic>{});
      final parsed = <String, double>{base: 1};

      for (final entry in rawRates.entries) {
        final value = (entry.value as num?)?.toDouble();
        if (value != null && value > 0) {
          parsed[entry.key.toUpperCase()] = value;
        }
      }

      for (final currency in supportedCurrencies.keys) {
        parsed.putIfAbsent(
          currency,
          () => _ratesByBase[base]?[currency] ?? (currency == base ? 1 : 0),
        );
      }

      _ratesByBase[base] = parsed;
    } catch (_) {}
  }

  static double? convertAmountSync(
    double? amount, {
    required String fromCurrency,
  }) {
    if (amount == null || !amount.isFinite) return null;

    final normalizedFrom = fromCurrency.trim().toUpperCase();
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
}
