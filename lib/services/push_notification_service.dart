import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static bool _initialised = false;

  static Future<void> initialise() async {
    await initialiseForCurrentUser();
  }

  static Future<void> initialiseForCurrentUser() async {
    if (_initialised) return;
    _initialised = true;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      await _saveCurrentToken(user.uid);

      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _saveToken(user.uid, token);
      });
    } catch (_) {
      // Push notifications should never stop the app from opening.
    }
  }

  static Future<void> refreshForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _saveCurrentToken(user.uid);
    } catch (_) {
      // Non-critical.
    }
  }

  static Future<void> _saveCurrentToken(String uid) async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;

    await _saveToken(uid, token);
  }

  static Future<void> _saveToken(String uid, String token) async {
    final cleanUid = uid.trim();
    final cleanToken = token.trim();

    if (cleanUid.isEmpty || cleanToken.isEmpty) return;

    final tokenId = base64Url.encode(utf8.encode(cleanToken));
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };

    await _firestore
        .collection('users')
        .doc(cleanUid)
        .collection('fcmTokens')
        .doc(tokenId)
        .set(
      <String, Object?>{
        'token': cleanToken,
        'platform': platform,
        'app': 'PocketChase',
        'userId': cleanUid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
