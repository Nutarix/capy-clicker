import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
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
}
