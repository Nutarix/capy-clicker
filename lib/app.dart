import 'dart:async';

import 'package:flutter/material.dart';

import 'features/game/audio/game_audio.dart';
import 'features/game/game_screen.dart';
import 'features/game/persistence/game_persistence.dart';
import 'features/menu/main_menu_screen.dart';
import 'theme/cozy_theme.dart';
import 'widgets/portrait_phone_frame.dart';

/// Root widget for Grow! Capy! — menu ↔ game via simple root state.
class CapyClickerApp extends StatefulWidget {
  const CapyClickerApp({super.key, this.now, this.audio});

  /// Game clock (tests pin it; null = wall clock).
  final DateTime Function()? now;

  /// Shared sound (tests pass a silent one; null = app-owned).
  final GameAudio? audio;

  @override
  State<CapyClickerApp> createState() => _CapyClickerAppState();
}

class _CapyClickerAppState extends State<CapyClickerApp> {
  late final GameAudio _audio = widget.audio ?? GameAudio();

  /// Sound is quiet in background on the menu and in the game alike.
  late final AppLifecycleListener _lifecycle;

  /// One save store for menu and game: its writes run in call order.
  final GamePersistence _persistence = GamePersistence();

  /// When false, show [MainMenuScreen]; when true, [GameScreen].
  bool _inGame = false;

  @override
  void initState() {
    super.initState();
    _audio.init();
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(_audio.setInBackground(true)),
      onShow: () => unawaited(_audio.setInBackground(false)),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    if (widget.audio == null) {
      _audio.dispose();
    }
    super.dispose();
  }

  void _enterGame() {
    setState(() => _inGame = true);
  }

  void _backToMenu() {
    setState(() => _inGame = false);
  }

  Future<void> _newGame() async {
    await _persistence.clear();
    if (!mounted) return;
    setState(() => _inGame = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grow! Capy!',
      debugShowCheckedModeBanner: false,
      theme: CozyTheme.build(),
      // Menu: forest full-bleed + 9:16 content column (no phone chrome).
      // Game keeps PortraitPhoneFrame on desktop/web for playtest.
      home: _inGame
          ? PortraitPhoneFrame(
              child: GameScreen(
                audio: _audio,
                persistence: _persistence,
                now: widget.now,
                onBackToMenu: _backToMenu,
              ),
            )
          : MainMenuScreen(
              audio: _audio,
              persistence: _persistence,
              onPlay: _enterGame,
              onContinue: _enterGame,
              onNewGame: _newGame,
            ),
    );
  }
}
