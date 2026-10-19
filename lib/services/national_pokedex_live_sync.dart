import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collection_refresh_notifier.dart';
import 'national_pokedex_progress_cache.dart';
import 'national_pokedex_service.dart';

/// Keeps the saved National Pokédex in step with owned set and custom binders.
///
/// The binder stores already emit [collectionRefreshNotifier] when ownership
/// changes. The first time National Pokédex is opened, this listener is set up
/// for the rest of the app session, so future collection edits update the
/// saved National Pokédex in the background, including while another tab is
/// open. It does not change ownership or perform any price lookups.
class NationalPokedexLiveSync {
  NationalPokedexLiveSync._();

  /// Pages observe this revision counter; no manual refresh is required.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool _started = false;
  static bool _running = false;
  static bool _again = false;
  static Timer? _debounce;
  static const Duration _pendingRetryDelay = Duration(hours: 12);

  // If the catalogue could not identify a card, retry on a later visit
  // automatically (not on every tab switch, which would flood the provider).
  static Future<bool> _pendingRetryDue() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'device';
      final key = 'pocketchase_national_auto_retry_v8_$uid';
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = prefs.getInt(key);
      if (last != null && now - last < _pendingRetryDelay.inMilliseconds) {
        return false;
      }
      await prefs.setInt(key, now);
      return true;
    } catch (_) {
      return false; // Normal binder edits still trigger fresh reconciliation.
    }
  }

  static void start() {
    if (_started) return;
    _started = true;
    collectionRefreshNotifier.addListener(_onCollectionChanged);
    schedule(); // Catch ownership edits since the previous app session.
  }

  static void _onCollectionChanged() => schedule();

  /// Coalesce bursts of writes, such as an entire set sync, into one pass.
  static void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_reconcile());
    });
  }

  static Future<void> _reconcile() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        try {
          final before = await NationalPokedexService.ownershipSignature();
          final saved = await NationalPokedexProgressCache.load();
          // Returning to Sets is instant if the collection hasn't changed.
          if (saved != null && saved.ownershipSignature == before) {
            if (saved.result.cardsPendingIdentification == 0 ||
                !await _pendingRetryDue()) {
              continue;
            }
          }

          final species = await NationalPokedexService.loadSpecies();
          final result = await NationalPokedexService.scanOwnedSpecies(species);
          final after = await NationalPokedexService.ownershipSignature();
          if (after != before) {
            // Card ownership was edited during the lookup. Don't save stale
            // results; immediately reconcile the latest collection instead.
            _again = true;
            continue;
          }
          await NationalPokedexProgressCache.save(after, result);
          revision.value++;
        } catch (_) {
          // Network failures must never erase previously saved discoveries.
          // The next collection update or Pokédex visit retries automatically.
        }
      } while (_again);
    } finally {
      _running = false;
    }
  }
}
