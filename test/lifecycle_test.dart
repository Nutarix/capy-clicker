import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/app.dart';
import 'package:capy_clicker/features/game/audio/game_audio.dart';
import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/game_screen.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

/// App lifecycle → save, game clock, welcome, sound (Т2–Т4).
void main() {
  const key = 'capy_clicker_game_state_v1';
  final base = DateTime(2026, 9, 21, 12);

  setUp(() {
    GameAudio.forceSilent = true;
  });

  tearDown(() {
    GameAudio.forceSilent = false;
  });

  /// Game clock pinned to a midday, moving with the test's fake time.
  DateTime Function() gameClock(WidgetTester tester) {
    final start = tester.binding.clock.now();
    return () => base.add(tester.binding.clock.now().difference(start));
  }

  void seed() {
    SharedPreferences.setMockInitialValues({
      BalanceV0.tipsSeenKey: true,
      key:
          '{"herdProgress":0.3,"nextId":4,"grass":12,'
          '"savedAtMs":${base.millisecondsSinceEpoch},'
          '"lastDailyClaimYmd":"${GameController.calendarDayKey(base)}",'
          '"herd":[{"id":"c1","level":2,"x":0.4,"y":0.7},'
          '{"id":"c2","level":1,"x":0.5,"y":0.7},'
          '{"id":"c3","level":1,"x":0.6,"y":0.7}]}',
    });
  }

  /// Frame by frame, so snackbar animations and their timers run.
  Future<void> pumpFrames(WidgetTester tester, Duration total) async {
    for (
      var t = Duration.zero;
      t < total;
      t += const Duration(milliseconds: 100)
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Up to 20 s of frames until [finder] shows.
  Future<bool> waitShown(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> waitGone(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200 && finder.evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsNothing);
  }

  /// Walk the states one by one, as the engine reports them on device.
  Future<void> setLifecycle(WidgetTester tester, AppLifecycleState to) async {
    const order = [
      AppLifecycleState.resumed,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ];
    final from = tester.binding.lifecycleState ?? AppLifecycleState.resumed;
    var i = order.indexOf(from);
    final target = order.indexOf(to);
    if (tester.binding.lifecycleState == null) {
      tester.binding.handleAppLifecycleStateChanged(from);
    }
    while (i != target) {
      i += target > i ? 1 : -1;
      tester.binding.handleAppLifecycleStateChanged(order[i]);
      await tester.pump();
    }
  }

  testWidgets('hidden: saved and still; shown after 10 min: welcome', (
    tester,
  ) async {
    seed();
    final now = gameClock(tester);
    final c = GameController(
      persistence: GamePersistence(),
      random: Random(1),
      now: now,
    );
    final audio = GameAudio(silent: true);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(controller: c, audio: audio),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await setLifecycle(tester, AppLifecycleState.resumed);
    // Let the opening «Лужа!» snackbar go, so the welcome is not queued.
    await pumpFrames(tester, const Duration(seconds: 4));

    await setLifecycle(tester, AppLifecycleState.paused);
    expect(c.isSuspended, isTrue);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    expect(saved['savedAtMs'], now().millisecondsSinceEpoch);
    final still = c.state.toJson();

    await tester.pump(const Duration(minutes: 10));
    expect(c.state.toJson(), still);

    await setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.isSuspended, isFalse);
    expect(find.textContaining('Пока тебя не было'), findsOneWidget);

    // Second trip to background greets again (other snackbars may queue
    // first: the grant can open a glade).
    await waitGone(tester, find.textContaining('Пока тебя не было'));
    await setLifecycle(tester, AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 5));
    await setLifecycle(tester, AppLifecycleState.resumed);
    expect(
      await waitShown(tester, find.textContaining('Пока тебя не было')),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox());
    c.dispose();
    audio.dispose();
  });

  testWidgets('short trip to background: no welcome', (tester) async {
    seed();
    final c = GameController(
      persistence: GamePersistence(),
      random: Random(1),
      now: gameClock(tester),
    );
    final audio = GameAudio(silent: true);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(controller: c, audio: audio),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await setLifecycle(tester, AppLifecycleState.resumed);

    await setLifecycle(tester, AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    await setLifecycle(tester, AppLifecycleState.resumed);
    expect(c.isSuspended, isFalse);
    expect(
      await waitShown(tester, find.textContaining('Пока тебя не было')),
      isFalse,
    );

    await tester.pumpWidget(const SizedBox());
    c.dispose();
    audio.dispose();
  });

  testWidgets('app sound goes quiet in background, on the menu too', (
    tester,
  ) async {
    seed();
    final audio = GameAudio(silent: true);
    await tester.pumpWidget(
      CapyClickerApp(now: gameClock(tester), audio: audio),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await setLifecycle(tester, AppLifecycleState.resumed);

    await setLifecycle(tester, AppLifecycleState.hidden);
    expect(audio.isInBackground, isTrue);
    await setLifecycle(tester, AppLifecycleState.resumed);
    expect(audio.isInBackground, isFalse);

    await tester.pumpWidget(const SizedBox());
    audio.dispose();
  });
}
