import 'package:flutter/material.dart';

import 'features/game/game_screen.dart';

/// Root widget for Capy Clicker.
class CapyClickerApp extends StatelessWidget {
  const CapyClickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capy Clicker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B9B4A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
