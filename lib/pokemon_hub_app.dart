import 'package:flutter/material.dart';

import 'auth_gate.dart';

class PokemonHubApp extends StatelessWidget {
  const PokemonHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketChase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3A82)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF041B4A),
      ),
      home: const AuthGate(),
    );
  }
}
