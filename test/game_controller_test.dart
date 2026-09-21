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

  test('merge same level yields level+1', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    c.addProgress(1.0, fromTap: true); // now 2 capys Lv.1
    expect(c.state.herdCount, 2);
    final a = c.state.herd[0].id;
    final b = c.state.herd[1].id;
    expect(c.tryMerge(a, b), isTrue);
    expect(c.state.herdCount, 1);
    expect(c.state.herd.single.level, 2);
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
}
