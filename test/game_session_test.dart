import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

/// Controller session edges on fake timers and the fake clock.
void main() {
  const key = 'capy_clicker_game_state_v1';

  String family(DateTime savedAt) =>
      '{"herdProgress":0.3,"nextId":4,"grass":12,'
      '"savedAtMs":${savedAt.millisecondsSinceEpoch},'
      '"herd":[{"id":"c1","level":2,"x":0.4,"y":0.7},'
      '{"id":"c2","level":1,"x":0.5,"y":0.7},'
      '{"id":"c3","level":1,"x":0.6,"y":0.7}]}';

  testWidgets('leaving before the save loads keeps the save (С5, Т7)', (
    tester,
  ) async {
    final clock = tester.binding.clock;
    SharedPreferences.setMockInitialValues({key: family(clock.now())});
    final c = GameController(
      persistence: GamePersistence(),
      random: Random(2),
      now: clock.now,
    );

    final loading = c.init(); // «Играть»…
    c.dispose(); // …and straight back to the menu
    await loading;
    await tester.pump(const Duration(seconds: 5));

    final saved = await GamePersistence().load();
    expect(saved, isNotNull);
    expect(saved!.herdCount, 3);
    expect(saved.grass, 12);
    expect(c.isReady, isFalse);
    // No live tick left behind on the closed controller (the binding also
    // fails the test on a pending timer).
  });

  group('background (С2)', () {
    // Fake clock of the test binding; moves with tester.pump.
    late DateTime Function() now;

    Future<GameController> started(WidgetTester tester) async {
      now = tester.binding.clock.now;
      SharedPreferences.setMockInitialValues({key: family(now())});
      final c = GameController(
        persistence: GamePersistence(),
        random: Random(4),
        now: now,
      );
      await c.init();
      await tester.pump(const Duration(seconds: 1));
      return c;
    }

    Future<Map<String, dynamic>> saved() async {
      final prefs = await SharedPreferences.getInstance();
      return jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    }

    testWidgets('hiding writes at once and stops the game clock (Т2)', (
      tester,
    ) async {
      final c = await started(tester);
      await tester.pump(const Duration(milliseconds: 700));

      await c.suspend();

      final json = await saved();
      expect(json['savedAtMs'], now().millisecondsSinceEpoch);
      expect(json['herdProgress'], c.state.herdProgress);
      expect(c.isSuspended, isTrue);
      final before = c.state.toJson();
      await tester.pump(const Duration(seconds: 30));
      expect(c.state.toJson(), before, reason: 'no live ticks in background');
      c.dispose();
    });

    testWidgets('back after 10 min: cold-start offline rules, one welcome '
        '(Т3)', (tester) async {
      final c = await started(tester);
      await c.suspend();
      final hiddenAt = now();
      await tester.pump(const Duration(minutes: 10));

      // What a cold start would grant from the save written on hide.
      final cold = GameController(
        persistence: GamePersistence(),
        random: Random(4),
        now: now,
        autoTick: false,
      );
      await cold.init();

      c.resumeFromBackground();

      expect(c.isSuspended, isFalse);
      expect(c.hasOfflineWelcome, isTrue);
      expect(c.offlineSecondsApplied, BalanceV0.offlineCapSeconds);
      expect(c.offlineSecondsApplied, cold.offlineSecondsApplied);
      expect(
        c.offlineProgressGranted,
        closeTo(cold.offlineProgressGranted, 1e-9),
      );
      expect(c.state.herdCount, cold.state.herdCount);
      expect(c.state.herdProgress, closeTo(cold.state.herdProgress, 1e-9));
      expect(now().difference(hiddenAt), const Duration(minutes: 10));

      c.acknowledgeOfflineWelcome();
      c.resumeFromBackground(); // a stray second «shown» grants nothing
      expect(c.hasOfflineWelcome, isFalse);

      // The live clock runs again.
      final progress = c.state.herdProgress;
      final count = c.state.herdCount;
      await tester.pump(const Duration(seconds: 1));
      expect(
        c.state.herdProgress > progress || c.state.herdCount > count,
        isTrue,
      );
      cold.dispose();
      c.dispose();
    });

    testWidgets('back after 3 s: nothing granted, no jump', (tester) async {
      final c = await started(tester);
      await c.suspend();
      final progress = c.state.herdProgress;
      await tester.pump(const Duration(seconds: 3));

      c.resumeFromBackground();

      expect(c.hasOfflineWelcome, isFalse);
      expect(c.state.herdProgress, progress);
      await tester.pump(const Duration(seconds: 1));
      // One live second, not four.
      expect(
        c.state.herdProgress - progress,
        closeTo(c.autoRatePerSecond, c.autoRatePerSecond * 0.1),
      );
      c.dispose();
    });
  });
}
