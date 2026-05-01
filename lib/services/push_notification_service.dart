import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('Background notification received: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialised = false;
  static String? _latestToken;
  static StreamSubscription<User?>? _authSubscription;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'pocketchase_notifications',
    'PocketChase notifications',
    description:
        'Notifications for PocketChase updates, friends, community posts, restocks, and app activity.',
    importance: Importance.high,
  );

  static Future<void> initialise() async {
    if (_isInitialised) return;
    _isInitialised = true;

    if (kIsWeb) {
      debugPrint('Push notifications are not configured for web yet.');
      return;
    }

    await _initialiseLocalNotifications();
    await _requestPermission();

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    final token = await getToken();
    _latestToken = token;

    debugPrint('FCM token: $token');

    await _saveTokenForCurrentUser(token);

    _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) return;

      final tokenToSave = _latestToken ?? await getToken();
      await _saveTokenForUser(user: user, token: tokenToSave);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _latestToken = newToken;

      debugPrint('FCM token refreshed: $newToken');

      await _saveTokenForCurrentUser(newToken);
    });
  }

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('Could not get FCM token: $error');
      return null;
    }
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
      'Notification permission status: ${settings.authorizationStatus}',
    );
  }

  static Future<void> _initialiseLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;

    final title = notification?.title ??
        message.data['title']?.toString() ??
        'PocketChase';

    final body = notification?.body ?? message.data['body']?.toString() ?? '';

    if (title.trim().isEmpty && body.trim().isEmpty) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  static Future<void> _saveTokenForCurrentUser(String? token) async {
    final user = _auth.currentUser;

    if (user == null) {
      debugPrint('FCM token not saved because no user is signed in yet.');
      return;
    }

    await _saveTokenForUser(user: user, token: token);
  }

  static Future<void> _saveTokenForUser({
    required User user,
    required String? token,
  }) async {
    if (token == null || token.trim().isEmpty) return;

    try {
      final tokenDocId = base64Url.encode(utf8.encode(token));

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(tokenDocId)
          .set(
        {
          'token': token,
          'platform': _platformName,
          'app': 'PocketChase',
          'userId': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint('FCM token saved to Firestore for user: ${user.uid}');
    } catch (error) {
      debugPrint('Could not save FCM token to Firestore: $error');
    }
  }

  static String get _platformName {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    debugPrint('Notification data: ${message.data}');

    // Later we can use message.data to open a specific page.
    // Example restock notification data:
    // type: restock
    // shopName: Pokemon Center
    // productName: 151 Booster Bundle
    // productUrl: https://...
  }
}