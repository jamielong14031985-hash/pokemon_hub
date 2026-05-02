import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProStatusService {
  ProStatusService._();

  static const String proProductId = 'pocketchase_pro';
  static const String _proPurchasedPrefsKey = 'pocketchase_pro_purchased';

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final ValueNotifier<bool> isProNotifier = ValueNotifier<bool>(false);

  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _flagSub;

  static bool _purchasedPro = false;
  static bool _adminGrantedPro = false;

  static bool get isProActive => isProNotifier.value;
  static bool get purchasedProActive => _purchasedPro;
  static bool get adminGrantedProActive => _adminGrantedPro;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _purchasedPro = prefs.getBool(_proPurchasedPrefsKey) ?? false;
    } catch (_) {
      _purchasedPro = false;
    }

    _publish();

    await _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) {
      _listenToAdminGrantedPro(user?.uid);
    });

    _listenToAdminGrantedPro(_auth.currentUser?.uid);
  }

  static Future<void> dispose() async {
    await _authSub?.cancel();
    await _flagSub?.cancel();
    _authSub = null;
    _flagSub = null;
  }

  static Future<void> setProActiveFromVerifiedPurchase(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proPurchasedPrefsKey, active);
    _purchasedPro = active;
    _publish();
  }

  static Future<void> clearLocalProStatusForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_proPurchasedPrefsKey);
    _purchasedPro = false;
    _publish();
  }

  static void _listenToAdminGrantedPro(String? uid) {
    _flagSub?.cancel();
    _flagSub = null;
    _adminGrantedPro = false;
    _publish();

    final trimmedUid = uid?.trim() ?? '';
    if (trimmedUid.isEmpty) return;

    _flagSub = _firestore
        .collection('user_feature_flags')
        .doc(trimmedUid)
        .snapshots()
        .listen(
      (doc) {
        _adminGrantedPro = doc.data()?['proEnabled'] == true;
        _publish();
      },
      onError: (_) {
        _adminGrantedPro = false;
        _publish();
      },
    );
  }

  static void _publish() {
    isProNotifier.value = _purchasedPro || _adminGrantedPro;
  }
}
