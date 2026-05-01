import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';
import 'pokemon_hub_app.dart';
import 'services/currency_settings.dart';
import 'services/push_notification_service.dart';
import 'services/pro_status_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await CurrencySettings.init();

  await ProStatusService.init();

  await MobileAds.instance.initialize();

  await PushNotificationService.initialise();

  runApp(const PokemonHubApp());
}