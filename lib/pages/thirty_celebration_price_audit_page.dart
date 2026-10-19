import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tcg_card.dart';
import '../services/local_card_price_store.dart';
import '../services/pokemon_tcg_service.dart';
import '../utils/card_number_sorter.dart';

/// Reviews the *whole* combined 30th Celebration catalogue without changing
/// ownership, binders, collection totals, or the deployed pricing function.
/// API lookups only happen after the collector explicitly starts the audit.
class ThirtyCelebrationPriceAuditPage extends StatefulWidget {
  const ThirtyCelebrationPriceAuditPage({super.key});

  @override
  State<ThirtyCelebrationPriceAuditPage> createState() =>
      _ThirtyCelebrationPriceAuditPageState();
}

class _AuditMiss {
  const _AuditMiss({required this.reason, required this.checkedAtMs});

  final String reason;
  final int checkedAtMs;

  bool get isRecent =>
      DateTime.now().millisecondsSinceEpoch - checkedAtMs <
      const Duration(hours: 24).inMilliseconds;

  Map<String, Object> toJson() => <String, Object>{
        'reason': reason,
        'checkedAtMs': checkedAtMs,
      };

  static _AuditMiss? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final checkedAt = raw['checkedAtMs'];
    final timestamp = checkedAt is num ? checkedAt.toInt() : null;
    if (timestamp == null) return null;
    return _AuditMiss(
      reason: (raw['reason'] ?? 'No exact matching price').toString(),
      checkedAtMs: timestamp,
    );
  }
}

class _ThirtyCelebrationPriceAuditPageState
    extends State<ThirtyCelebrationPriceAuditPage> {
  static const _auditStorageKey = 'thirty_celebration_price_audit_v1';
  static const _navy = Color(0xFF041B4A);
  static const _gold = Color(0xFFF7DE77);

  // Free tier: <=10 provider calls/min, 20 cards/provider page. Keep a
  // conservative interval even when Firebase handles one provider call/page.
  static const _providerPageSpacing = Duration(seconds: 7);
  static const _maxProviderPagesPerRun = 24;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west2');
  List<TcgCard> _cards = <TcgCard>[];
  Map<String, CachedCardPrice> _prices = <String, CachedCardPrice>{};
  Map<String, _AuditMiss> _misses = <String, _AuditMiss>{};
  bool _loading = true;
  bool _checking = false;
  bool _stopRequested = false;
  int _processed = 0;
  int _planned = 0;
  String _currentCard = '';
  String? _notice;
  String _filter = 'all';
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _loadAudit();
  }

  Future<void> _loadAudit() async {
    try {
      final cards = await PokemonTcgService.fetchCardsBySet('30th');
      final prices = await LocalCardPriceStore.loadAll();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_auditStorageKey);
      final misses = <String, _AuditMiss>{};
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final parsed = _AuditMiss.fromJson(entry.value);
              if (parsed != null) misses[entry.key.toString()] = parsed;
            }
          }
        } catch (_) {
          // Invalid old audit metadata must not affect card prices.
        }
      }
      cards.sort((a, b) => compareCardNumbers(a.number, b.number));
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _prices = prices;
        _misses = misses;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingError = 'Could not load the 30th Celebration checklist: $error';
      });
    }
  }

  Future<void> _saveMisses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _auditStorageKey,
      jsonEncode(<String, Object>{
        for (final entry in _misses.entries) entry.key: entry.value.toJson(),
      }),
    );
  }

  String _group(TcgCard card) {
    final number = card.number.trim().toUpperCase();
    final id = card.id.trim().toLowerCase();
    if (number.startsWith('CC') || id.startsWith('me55c-')) {
      return 'Classic Collection';
    }
    if (<String>{'R/RGB', 'G/RGB', 'B/RGB', 'R', 'G', 'B'}.contains(number) ||
        id.contains('mew-rgb')) {
      return 'RGB Mew';
    }
    if (number.startsWith('MEE')) return 'Special Energy';
    if (number.startsWith('MEP') || id.startsWith('30th-mep-')) {
      return 'Promos';
    }
    return 'Main set';
  }

  bool _hasPrice(TcgCard card) =>
      _prices[card.id]?.isValid == true;

  // Include earlier unmatched cards in the next *whole-set* pass: one
  // cached provider page can be compared against many card identities.
  List<TcgCard> get _eligibleCards =>
      _cards.where((card) => !_hasPrice(card)).toList();

  bool _isRateLimit(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'resource-exhausted' ||
          (error.message ?? '').toLowerCase().contains('rate limit') ||
          (error.message ?? '').contains('429');
    }
    return error.toString().toLowerCase().contains('rate limit');
  }

  Future<void> _saveBatchPrice(TcgCard card, Map<String, dynamic> data) async {
    final raw = data['amount'];
    final amount = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (amount == null || amount <= 0 || !amount.isFinite) return;
    final currency = (data['currencyCode'] ?? 'USD').toString();
    final source = (data['source'] ?? 'JustTCG reference').toString();
    final updated = (data['lastUpdatedMs'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final sold = (data['soldCount'] as num?)?.toInt() ?? 0;
    final confidence = (data['confidence'] ?? 'reference').toString();
    final method = (data['pricingMethod'] ?? 'provider_reference').toString();
    // The existing local price store is the same one used by individual cards.
    await LocalCardPriceStore.save(
      cardId: card.id, amount: amount, currencyCode: currency,
      source: source, updatedAtMs: updated, soldCount: sold,
      confidence: confidence, pricingMethod: method,
    );
    _prices[card.id] = CachedCardPrice(
      amount: amount, currencyCode: currency, source: source,
      updatedAtMs: updated, soldCount: sold, confidence: confidence,
      pricingMethod: method,
    );
    _misses.remove(card.id);
  }

  String _wholeSetMissReason(List<int> evidence) {
    final set = evidence[0], name = evidence[1], number = evidence[2];
    final exactNoPrice = evidence[3];
    if (exactNoPrice > 0) return 'Correct card found but no usable NM price';
    if (set == 0) return 'No cards found in the recognised provider set';
    if (name == 0) return 'Card name / variant mismatch';
    if (number == 0) return 'Collector-number mismatch';
    return 'No exact name, number and variant combination';
  }

  Future<void> _startAudit() async {
    if (_checking) return;
    final pending = _eligibleCards;
    if (pending.isEmpty) {
      setState(() => _notice = 'Every card already has a cached price.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audit the full 30th Celebration catalogue?'),
        content: Text(
          'Check ${pending.length} unpriced cards using set pages of up to '
          '20 provider cards at a time (Free plan). Previously saved prices '
          'will not be replaced. The audit may make up to '
          '$_maxProviderPagesPerRun uncached JustTCG page requests, plus '
          'set discovery requests, and will stop on provider rate limits. '
          'Each page can check many PocketChase cards. The Free plan has '
          '100 requests/day and 1,000/month for all app activity; this audit '
          'does not know your remaining provider allowance.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start set-page audit')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _checking = true;
      _stopRequested = false;
      _processed = 0;
      _planned = pending.length;
      _notice = 'Loading JustTCG set pages; existing prices are safe.';
    });

    final callable = _functions.httpsCallable('lookupExternalPokemonCardPrice');
    var pricedThisRun = 0;
    var missingThisRun = 0;
    var uncachedPages = 0;
    var allPages = 0;
    var failedGroups = 0;
    String? errorNotice;
    const groups = <String>['main', 'classic', 'rgb', 'energy', 'promo'];
    for (final group in groups) {
      if (!mounted || _stopRequested) break;
      final groupCards = pending.where((c) {
        final category = _group(c);
        if (group == 'main') return category == 'Main set';
        if (group == 'classic') return category == 'Classic Collection';
        if (group == 'rgb') return category == 'RGB Mew';
        if (group == 'energy') return category == 'Special Energy';
        return category == 'Promos';
      }).toList();
      if (groupCards.isEmpty) continue;
      final unresolved = <String, TcgCard>{for (final c in groupCards) c.id: c};
      final evidence = <String, List<int>>{
        for (final c in groupCards) c.id: [0, 0, 0, 0],
      };
      var offset = 0;
      var completedGroup = false;
      for (var pageIndex = 0; pageIndex < 16; pageIndex++) {
        if (!mounted || _stopRequested) break;
        setState(() {
          _currentCard = '${_group(groupCards.first)} • page ${pageIndex + 1}';
        });
        try {
          final response = await callable.call<Map<String, dynamic>>({
            'mode': 'thirty_audit_page_v1',
            'group': group,
            'offset': offset,
            'cards': <Map<String, String>>[
              for (final c in unresolved.values)
                {
                  'cardId': c.id, 'name': c.name, 'number': c.number,
                  'setId': c.setId, 'setName': c.setName,
                },
            ],
          }).timeout(const Duration(seconds: 35));
          final result = response.data;
          if (result['status'] == 'set_not_resolved') {
            // Do not mark a missing provider catalogue as a card mismatch.
            failedGroups++;
            errorNotice = '${_group(groupCards.first)} set could not be resolved; '
                'those cards remain due for a later check.';
            break;
          }
          if (result['status'] != 'ok') throw StateError('Unknown audit response');
          final matches = result['matches'];
          if (matches is List) {
            for (final item in matches) {
              if (item is! Map) continue;
              final id = (item['cardId'] ?? '').toString();
              final card = unresolved[id];
              final price = item['price'];
              if (card == null || price is! Map) continue;
              await _saveBatchPrice(card, Map<String, dynamic>.from(price));
              if (_hasPrice(card)) {
                unresolved.remove(id);
                pricedThisRun++;
              }
            }
          }
          final counts = result['counts'];
          if (counts is List) {
            for (final item in counts) {
              if (item is! Map) continue;
              final id = (item['cardId'] ?? '').toString();
              final sums = evidence[id];
              if (sums == null) continue;
              sums[0] += (item['sets'] as num?)?.toInt() ?? 0;
              sums[1] += (item['names'] as num?)?.toInt() ?? 0;
              sums[2] += (item['numbers'] as num?)?.toInt() ?? 0;
              if (item['exactWithoutPrice'] == true) sums[3]++;
            }
          }
          allPages++;
          final cached = result['cachedProviderPage'] == true;
          if (!cached) uncachedPages++;
          if (!mounted) break;
          setState(() => _notice = 'Scanned $allPages provider pages, '
              '$pricedThisRun newly priced • $uncachedPages new API page requests.');
          if (result['hasMore'] != true || unresolved.isEmpty) {
            completedGroup = true;
            break;
          }
          offset = (result['nextOffset'] as num?)?.toInt() ?? (offset + 20);
          if (!cached) await Future<void>.delayed(_providerPageSpacing);
          if (uncachedPages >= _maxProviderPagesPerRun) {
            errorNotice = 'Free-plan safety limit reached for this audit run. '
                'You can resume later; previous progress is saved.';
            break;
          }
        } catch (error) {
          if (_isRateLimit(error)) {
            errorNotice = 'JustTCG Free-plan allowance or audit safety '
                'budget reached. Pause until the allowance resets.';
          } else if (error is TimeoutException) {
            errorNotice = 'A set page timed out; audit paused safely.';
          } else if (error is FirebaseFunctionsException) {
            errorNotice = 'Pricing service error (${error.code}). Audit paused.';
          } else {
            errorNotice = 'Set-page audit failed; pricing was left unchanged.';
          }
          break;
        }
      }
      if (completedGroup) {
        for (final entry in unresolved.entries) {
          _misses[entry.key] = _AuditMiss(
            reason: _wholeSetMissReason(evidence[entry.key] ?? [0, 0, 0, 0]),
            checkedAtMs: DateTime.now().millisecondsSinceEpoch,
          );
          missingThisRun++;
        }
        await _saveMisses();
        if (mounted) setState(() => _processed += groupCards.length);
      }
      if (errorNotice != null && errorNotice.startsWith('Free-plan safety')) break;
      if (errorNotice != null && !errorNotice.contains('set could not be resolved')) break;
      // A missing energy/promo provider set must not block other categories.
      if (errorNotice != null && errorNotice.contains('set could not be resolved')) {
        errorNotice = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _currentCard = '';
      _notice = '${errorNotice ?? (_stopRequested ? 'Paused.' : 'Audit finished.')} '
          '$pricedThisRun new prices, $missingThisRun checked without an '
          'exact priced match. $allPages pages scanned; $uncachedPages '
          'new provider page calls. $failedGroups catalogue groups unavailable.';
    });
  }

  String _status(TcgCard card) {
    final price = _prices[card.id];
    if (price != null && price.isValid) {
      final salesSupported = price.pricingMethod.toLowerCase() == 'sold_median' &&
          price.soldCount >= 3 &&
          <String>{'medium', 'high'}.contains(price.confidence.toLowerCase());
      return '${price.currencyCode.toUpperCase()} '
          '${price.amount.toStringAsFixed(2)} · '
          '${salesSupported ? 'Sales-supported' : 'Reference'}';
    }
    final miss = _misses[card.id];
    if (miss != null && miss.isRecent) return miss.reason;
    return 'Not checked / due for recheck';
  }

  Future<void> _copyMissingReport() async {
    final missing = _cards.where((card) => !_hasPrice(card)).toList();
    final report = <String>[
      'PocketChase — 30th Celebration missing-price audit',
      'Checked on device: ${DateTime.now().toIso8601String()}',
      'Checklist: ${_cards.length} cards • ${_cards.length - missing.length} cached prices • ${missing.length} unpriced',
      'Unpriced cards:',
      for (final card in missing)
        '${_group(card)} | ${card.name} | ${card.number} | ${card.id} | ${_status(card)}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Missing-price report copied. You can paste it into ChatGPT.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priced = _cards.where(_hasPrice).length;
    final recentMiss = _cards.where((card) =>
        !_hasPrice(card) && (_misses[card.id]?.isRecent ?? false)).length;
    final unchecked = _cards.length - priced - recentMiss;
    final shown = _cards.where((card) {
      if (_filter == 'priced') return _hasPrice(card);
      if (_filter == 'unpriced') return !_hasPrice(card);
      if (_filter == 'unchecked') {
        return !_hasPrice(card) && !(_misses[card.id]?.isRecent ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('30th Price Audit'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading || _loadingError != null ? null : _copyMissingReport,
            tooltip: 'Copy missing-price report',
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadingError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_loadingError!,
                        style: const TextStyle(color: Colors.white)),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${_cards.length} cards in current checklist',
                            style: const TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$priced with a cached price • $recentMiss checked '
                            'but unpriced • $unchecked unchecked / due',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Reference prices are not verified sales. '
                            'This audits the full catalogue, not only cards you own. '
                            'Missing prices are not estimated.',
                            style: TextStyle(color: Color(0xFFD2DCEE), fontSize: 12),
                          ),
                          if (_checking) ...<Widget>[
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: _planned == 0 ? 0 : _processed / _planned,
                              color: _gold,
                            ),
                            const SizedBox(height: 4),
                            Text('Checked $_processed / $_planned • $_currentCard',
                                style: const TextStyle(color: Colors.white)),
                          ],
                          if (_notice != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(_notice!,
                                style: const TextStyle(color: _gold)),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _gold,
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: _checking || _eligibleCards.isEmpty
                                      ? null
                                      : _startAudit,
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: Text(_eligibleCards.isEmpty
                                      ? 'All priced'
                                      : 'Audit all unpriced (${_eligibleCards.length})'),
                                ),
                              ),
                              if (_checking) ...<Widget>[
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => setState(() => _stopRequested = true),
                                  child: const Text('Pause'),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: <Widget>[
                                for (final option in const <(String, String)>[
                                  ('all', 'All'),
                                  ('priced', 'Priced'),
                                  ('unpriced', 'Unpriced'),
                                  ('unchecked', 'Due'),
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(option.$2),
                                      selected: _filter == option.$1,
                                      onSelected: (_) => setState(() => _filter = option.$1),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, index) {
                          final card = shown[index];
                          final hasPrice = _hasPrice(card);
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              hasPrice ? Icons.check_circle_outline : Icons.info_outline,
                              color: hasPrice ? _gold : Colors.white70,
                            ),
                            title: Text('${card.name}  •  ${card.number}',
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text('${_group(card)} · ${_status(card)}',
                                style: const TextStyle(color: Color(0xFFD2DCEE))),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

