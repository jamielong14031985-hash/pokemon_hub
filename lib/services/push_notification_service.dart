import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static const String _channelId = 'pocketchase_notifications';
  static const String _channelName = 'PocketChase Notifications';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;
  static String _registeredUserId = '';

  static Future<void> initialise() async {
    await initialiseForCurrentUser();
  }

  static Future<void> initialiseForCurrentUser() async {
    if (!_initialised) {
      _initialised = true;

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

        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        await _initialiseForegroundNotifications();

        _messaging.onTokenRefresh.listen((token) async {
          final user = _auth.currentUser;
          if (user == null) return;
          await _saveToken(user.uid, token);
          _registeredUserId = user.uid;
        });

        FirebaseMessaging.onMessage.listen(
          _showForegroundNotification,
        );

        _auth.authStateChanges().listen((user) async {
          await _syncTokenForUser(user);
        });
      } catch (_) {
        // Push notifications should never stop PocketChase from opening.
      }
    }

    await _syncTokenForUser(_auth.currentUser);
  }

  static Future<void> refreshForCurrentUser() async {
    await initialiseForCurrentUser();
    await _syncTokenForUser(_auth.currentUser);
  }

  static Future<void> _initialiseForegroundNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Messages, community updates and admin alerts.',
        importance: Importance.max,
        playSound: true,
      ),
    );
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: message.messageId?.hashCode ??
          DateTime.now().microsecondsSinceEpoch.remainder(2147483647),
      title: notification.title ?? 'PocketChase',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Messages, community updates and admin alerts.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> _syncTokenForUser(User? user) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) return;

      final nextUserId = user?.uid.trim() ?? '';
      final previousUserId = _registeredUserId.trim();

      if (previousUserId.isNotEmpty && previousUserId != nextUserId) {
        await _deleteToken(previousUserId, token);
      }

      if (nextUserId.isEmpty) {
        _registeredUserId = '';
        return;
      }

      await _saveToken(nextUserId, token);
      _registeredUserId = nextUserId;
    } catch (_) {
      // Token refresh is non-critical and can retry at the next app opening.
    }
  }

  static Future<void> _deleteToken(String uid, String token) async {
    final cleanUid = uid.trim();
    final cleanToken = token.trim();
    if (cleanUid.isEmpty || cleanToken.isEmpty) return;

    final tokenId = base64Url.encode(utf8.encode(cleanToken));
    await _firestore
        .collection('users')
        .doc(cleanUid)
        .collection('fcmTokens')
        .doc(tokenId)
        .delete();
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
