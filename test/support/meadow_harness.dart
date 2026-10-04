import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/audio/game_audio.dart';
import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/game_screen.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';
import 'package:capy_clicker/features/game/widgets/meadow_space.dart';

/// Still game clock for meadow tests, in UTC (CI runs in UTC, Nikita not).
final DateTime meadowNow = DateTime.utc(2026, 9, 21, 9);

const saveKey = 'capy_clicker_game_state_v1';

/// One capy in a save: `(id, level, x, y)`.
typedef SavedCapy = (String, int, double, double);

/// Prefs with tips seen and today's gift taken, on [meadowId] with [herd].
Map<String, Object> meadowPrefs({
  String meadowId = 'warm_edge',
  int announced = 0,
  required List<SavedCapy> herd,
  int grass = 0,
  bool dailyTaken = true,
  bool tipsSeen = true,
}) {
  final save = <String, Object?>{
    'nextId': 100,
    'grass': grass,
    'sunnyGladeAnnounced': announced,
    'savedAtMs': meadowNow.millisecondsSinceEpoch,
    if (dailyTaken)
      'lastDailyClaimYmd': GameController.calendarDayKey(meadowNow),
    'activeMeadowId': meadowId,
    'meadows': {
      meadowId: {
        'herdProgress': 0.0,
        'herd': [
          for (final c in herd)
            {'id': c.$1, 'level': c.$2, 'x': c.$3, 'y': c.$4},
        ],
      },
    },
  };
  return {if (tipsSeen) BalanceV0.tipsSeenKey: true, saveKey: jsonEncode(save)};
}

/// A game screen with its own still controller (no live tick), silent sound.
class MeadowHarness {
  MeadowHarness._(this.controller, this.audio);

  final GameController controller;
  final GameAudio audio;

  static Future<MeadowHarness> pump(
    WidgetTester tester,
    Map<String, Object> prefs, {
    Widget Function(Widget screen)? wrap,
  }) async {
    GameAudio.forceSilent = true;
    SharedPreferences.setMockInitialValues(prefs);
    final c = GameController(
      persistence: GamePersistence(),
      random: Random(3),
      now: () => meadowNow,
      autoTick: false,
    );
    final audio = GameAudio(silent: true);
    final screen = GameScreen(controller: c, audio: audio);
    await tester.pumpWidget(
      MaterialApp(home: wrap == null ? screen : wrap(screen)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The camera eases for 450 ms after load.
    await tester.pump(const Duration(milliseconds: 600));
    // The opening «Лужа!» plate would sit over the bottom bar.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .removeCurrentSnackBar();
    await tester.pump();
    return MeadowHarness._(c, audio);
  }

  /// The meadow as the player sees it (scaled by the camera).
  Rect meadowRect(WidgetTester tester) =>
      tester.getRect(find.byType(MeadowSpaceAnchor));

  /// Screen point of a normalized meadow point, from the drawn meadow rect.
  Offset screenAt(WidgetTester tester, Offset normalized) {
    final r = meadowRect(tester);
    return r.topLeft +
        Offset(normalized.dx * r.width, normalized.dy * r.height);
  }

  Finder capy(String id) => find.byKey(ValueKey(id));

  /// Finger down on [from], slide to [to] in small steps, lift.
  Future<void> drag(
    WidgetTester tester,
    Offset from,
    Offset to, {
    Duration holdFirst = Duration.zero,
    int steps = 12,
  }) async {
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 16));
    if (holdFirst > Duration.zero) await tester.pump(holdFirst);
    final step = (to - from) / steps.toDouble();
    for (var i = 0; i < steps; i++) {
      await g.moveBy(step);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    audio.dispose();
    await tester.pump(const Duration(seconds: 1));
    GameAudio.forceSilent = false;
  }
}
