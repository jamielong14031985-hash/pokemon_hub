import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deal_builder_models.dart';

/// Private, local-to-this-device drafts. Sharing is explicit via the UI.
/// In-app negotiation / synchronisation is intentionally not implemented here.
class LocalDealBuilderStore {
  const LocalDealBuilderStore._();

  static String _key() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'signed_out';
    return 'pocketchase_deal_builder_v1_$uid';
  }

  static Future<List<CollectorDeal>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key());
    if (raw == null || raw.isEmpty) return <CollectorDeal>[];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return <CollectorDeal>[];
      return data.whereType<Map>()
          .map((entry) => CollectorDeal.fromJson(Map<String, dynamic>.from(entry)))
          .where((deal) => deal.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <CollectorDeal>[];
    }
  }

  static Future<void> save(CollectorDeal deal) async {
    final deals = await load();
    final index = deals.indexWhere((saved) => saved.id == deal.id);
    if (index < 0) {
      deals.insert(0, deal);
    } else {
      deals[index] = deal;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(), jsonEncode(deals.map((value) => value.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final deals = await load();
    deals.removeWhere((deal) => deal.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(), jsonEncode(deals.map((value) => value.toJson()).toList()));
  }
}
