import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

/// The live tick, on fake timers and the fake clock of [testWidgets].
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('live tick and debugAdvance run the same game clock', (
    tester,
  ) async {
    final clock = tester.binding.clock;
    // Both load the same family (bootstrap would only run for the first).
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1':
          '{"herdProgress":0.2,"nextId":3,'
          '"savedAtMs":${clock.now().millisecondsSinceEpoch},'
          '"herd":[{"id":"c1","level":1,"x":0.5,"y":0.5},'
          '{"id":"c2","level":1,"x":0.6,"y":0.55}]}',
    });
    final live = GameController(
      persistence: GamePersistence(),
      random: Random(3),
      now: clock.now,
    );
    final twin = GameController(
      persistence: GamePersistence(),
      random: Random(3),
      now: clock.now,
      autoTick: false,
    );
    await live.init();
    await twin.init();

    // 40 s of 50 ms ticks: mud comes and goes, twins reroll, grass accrues.
    for (var i = 0; i < 800; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      twin.debugAdvance(0.05);
    }

    expect(live.state.herdProgress, greaterThan(0));
    expect(twin.state.toJson(), live.state.toJson());
    expect(twin.mudCenter, live.mudCenter);
    expect(twin.mudVisible, live.mudVisible);
    expect(twin.puddleToast, live.puddleToast);
    live.dispose();
    twin.dispose();
  });

  testWidgets('live play writes the save at least every 5 s', (tester) async {
    final clock = tester.binding.clock;
    const key = 'capy_clicker_game_state_v1';
    SharedPreferences.setMockInitialValues({
      key:
          '{"herdProgress":0.2,"nextId":3,'
          '"savedAtMs":${clock.now().millisecondsSinceEpoch},'
          '"herd":[{"id":"c1","level":1,"x":0.5,"y":0.5},'
          '{"id":"c2","level":1,"x":0.6,"y":0.55}]}',
    });
    final c = GameController(
      persistence: GamePersistence(),
      random: Random(5),
      now: clock.now,
    );
    await c.init();
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> saved() =>
        jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;

    // Ticks change the state every 50 ms; the write must not wait them out.
    for (var window = 0; window < 4; window++) {
      await tester.pump(const Duration(seconds: 5));
      final savedAt = saved()['savedAtMs'] as int;
      final age = clock.now().millisecondsSinceEpoch - savedAt;
      expect(age, lessThanOrEqualTo(5000), reason: 'window $window');
    }
    final json = saved();
    final herd = json['herd'] as List;
    expect(
      herd.length > 2 || (json['herdProgress'] as num) > 0.2,
      isTrue,
      reason: 'saved state carries the live progress',
    );
    c.dispose();
  });
}
