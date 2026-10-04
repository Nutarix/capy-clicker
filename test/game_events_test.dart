import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/test_game.dart';

/// One-shot messages arrive as events (spec 002, Т4).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fresh start: daily gift and puddle, in poll order', () async {
    final c = testController();
    final got = <GameEvent>[];
    c.events.listen(got.add);
    await c.init();
    expect(got.map((e) => e.runtimeType), [DailyBonusReady, PuddleAppeared]);
    expect((got.last as PuddleAppeared).text, 'Лужа!');
    c.dispose();
  });

  test('glade opens once, with its grass; goal follows', () async {
    final c = testController();
    final got = <GameEvent>[];
    c.events.listen(got.add);
    await c.init();
    got.clear();
    growFamily(c, () => c.state.sunnyGladeAnnounced >= 1);
    final glades = got.whereType<GladeUnlocked>().toList();
    expect(glades, hasLength(1));
    expect(glades.single.text, c.gladeUnlockToast);
    expect(glades.single.grass, c.lastGladeGrassReward);
    final goals = got.whereType<GoalCompleted>().toList();
    expect(goals, hasLength(1));
    expect(got.indexOf(glades.single), lessThan(got.indexOf(goals.single)));
    // Further changes do not repeat them.
    got.clear();
    c.addProgress(0.01, fromTap: false);
    expect(got.whereType<GladeUnlocked>(), isEmpty);
    c.dispose();
  });

  test('role assigned → event; nobody listening → it waits', () async {
    final c = testController();
    await c.init();
    expect(c.assignRole(c.state.herd.first.id, CapyRole.nanya), isTrue);
    final got = <GameEvent>[];
    c.events.listen(got.add);
    c.addProgress(0.01, fromTap: false);
    expect(got.whereType<RoleAssigned>(), hasLength(1));
    c.dispose();
  });

  test('offline welcome arrives once the game is ready', () async {
    final persistence = GamePersistence();
    var clock = testNow;
    final first = testController(persistence: persistence, now: () => clock);
    await first.init();
    await first.flushSave();
    first.dispose();

    clock = clock.add(const Duration(seconds: 60));
    final c = testController(persistence: persistence, now: () => clock);
    final got = <GameEvent>[];
    c.events.listen(got.add);
    await c.init();
    final welcome = got.whereType<OfflineWelcome>().single;
    expect(welcome.seconds, 60);
    expect(welcome.progress, greaterThan(0));
    expect(got.first, isA<OfflineWelcome>());
    c.dispose();
  });
}
