import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProStatusService {
  ProStatusService._();

  static const String _proActivePrefsKey = 'pocketchase_pro_active';

  static final ValueNotifier<bool> isProNotifier = ValueNotifier<bool>(false);

  static bool get isProActive => isProNotifier.value;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isProNotifier.value = prefs.getBool(_proActivePrefsKey) ?? false;
    } catch (_) {
      isProNotifier.value = false;
    }
  }

  static Future<void> setProActiveFromVerifiedPurchase(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proActivePrefsKey, active);
    isProNotifier.value = active;
  }

  static Future<void> clearLocalProStatusForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_proActivePrefsKey);
    isProNotifier.value = false;
  }
}
