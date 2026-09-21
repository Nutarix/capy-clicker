import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('bootstrap spawns starting herd and auto-ticks progress', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.state.herdCount, BalanceV0.startingHerdSize);
    expect(c.state.herdProgress, 0);

    // Simulate ~2 seconds of auto progress without waiting real time.
    c.addProgress(BalanceV0.autoProgressPerSecond * 2, fromTap: false);
    expect(c.state.herdProgress, closeTo(0.03, 0.001));
    c.dispose();
  });

  test('progress at threshold spawns another capybara', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, 2);
    expect(c.state.herdProgress, closeTo(0.0, 0.001));
    c.dispose();
  });

  test('merge same level yields level+1 with flash id', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    c.addProgress(1.0, fromTap: true); // now 2 capys Lv.1
    expect(c.state.herdCount, 2);
    final a = c.state.herd[0].id;
    final b = c.state.herd[1].id;
    expect(c.tryMerge(a, b), isTrue);
    expect(c.state.herdCount, 1);
    expect(c.state.herd.single.level, 2);
    expect(c.mergeFlashId, c.state.herd.single.id);
    c.dispose();
  });

  test('chain merge reaches higher visual levels', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    // Spawn enough Lv.1 to merge up toward Lv.3+
    for (var i = 0; i < 3; i++) {
      c.addProgress(1.0, fromTap: true);
    }
    expect(c.state.herdCount, 4); // 1 start + 3
    // Pairwise merge all Lv.1 → 2 Lv.2
    while (true) {
      final ones = c.state.herd.where((e) => e.level == 1).toList();
      if (ones.length < 2) break;
      expect(c.tryMerge(ones[0].id, ones[1].id), isTrue);
    }
    final twos = c.state.herd.where((e) => e.level == 2).toList();
    expect(twos.length, greaterThanOrEqualTo(2));
    expect(c.tryMerge(twos[0].id, twos[1].id), isTrue);
    expect(c.state.herd.any((e) => e.level == 3), isTrue);
    expect(
      BalanceV0.capySizeForLevel(5),
      greaterThan(BalanceV0.capySizeForLevel(1)),
    );
    expect(
      BalanceV0.capySizeForLevel(6),
      greaterThan(BalanceV0.capySizeForLevel(5)),
    );
    c.dispose();
  });

  test('herd soft-cap is 10', () async {
    expect(BalanceV0.maxHerdSize, 10);
    final c = GameController(persistence: GamePersistence());
    await c.init();
    for (var i = 0; i < 20; i++) {
      c.addProgress(1.0, fromTap: true);
    }
    expect(c.state.herdCount, BalanceV0.maxHerdSize);
    c.dispose();
  });

  test('mud wallow activates boost', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    final id = c.state.herd.single.id;
    expect(c.tryMudWallow(id), isTrue);
    expect(c.isMudBoostActive, isTrue);
    expect(c.wallowingCapyId, id);
    c.dispose();
  });

  test('isOverMud detects puddle zone', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(
      c.isOverMud(const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY)),
      isTrue,
    );
    expect(c.isOverMud(const Offset(0.9, 0.2)), isFalse);
    c.dispose();
  });

  test('zoom widens for large herds', () {
    expect(BalanceV0.zoomForHerdCount(1), BalanceV0.zoomClose);
    expect(BalanceV0.zoomForHerdCount(4), BalanceV0.zoomMid);
    expect(BalanceV0.zoomForHerdCount(7), BalanceV0.zoomFar);
    expect(BalanceV0.zoomForHerdCount(10), BalanceV0.zoomWidest);
  });
}
