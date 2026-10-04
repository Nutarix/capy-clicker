import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/multipliers/capy_role.dart';
import 'package:capy_clicker/features/game/models/session_goals.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/test_game.dart';

/// Spec 006, Т3, Т4, Т10: growth in a pile, the name at level two, growth
/// while away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<GameController> load(
    List<Capybara> herd, {
    Map<String, Object?> extra = const {},
    DateTime? savedAt,
    DateTime Function()? now,
  }) async {
    SharedPreferences.setMockInitialValues(
      herdSave(herd, extra: extra, savedAt: savedAt),
    );
    final c = testController(now: now);
    await c.init();
    return c;
  }

  Capybara get(GameController c, String id) =>
      c.state.herd.firstWhere((e) => e.id == id);

  /// Game clock in quarter seconds, as the sims.
  void run(GameController c, double seconds) {
    for (var t = 0.0; t < seconds; t += 0.25) {
      c.debugAdvance(0.25);
    }
  }

  test('С2. Nursery: babies grow one level at a time up to the eldest',
      () async {
    final c = await load([
      testCapy('e', 3, pile: 'p'),
      testCapy('b1', 1, pile: 'p'),
      testCapy('b2', 1, pile: 'p'),
    ]);
    final step1 = BalanceV0.pileCatchUpSeconds(1);
    final step2 = BalanceV0.pileCatchUpSeconds(2);
    run(c, step1 * 0.9);
    expect(get(c, 'b1').level, 1);
    run(c, step1 * 0.2);
    expect(get(c, 'b1').level, 2);
    expect(get(c, 'b2').level, 2);
    expect(get(c, 'b1').growth, lessThan(0.1), reason: 'no carry, one step');
    run(c, step2 * 1.1);
    expect(get(c, 'b1').level, 3);
    expect(get(c, 'b2').level, 3);
    // Two peers and the eldest: three at level 3 → they grow on together.
    expect(get(c, 'e').level, 3);
    run(c, step2 * 3);
    expect(get(c, 'e').level, 3, reason: 'peer steps take longer');
    c.dispose();
  });

  test('С3. Three peers grow up together; the Lv goal completes', () async {
    final c = await load(
      [
        for (final id in ['a', 'b', 'c'])
          testCapy(id, BalanceV0.goalCapyLevel - 1, pile: 'p'),
      ],
      extra: {'sunnyGladeAnnounced': 3, 'sessionGoalIndex': 3},
    );
    expect(c.currentSessionGoal?.kind, SessionGoalKind.maxLevel);
    run(c, BalanceV0.pilePeerSeconds(BalanceV0.goalCapyLevel - 1) + 1);
    for (final id in ['a', 'b', 'c']) {
      expect(get(c, id).level, BalanceV0.goalCapyLevel);
    }
    expect(c.state.sessionGoalIndex, greaterThan(3));
    expect(c.state.mistyBiomeUnlocked, isTrue);
    c.dispose();
  });

  test('С3. A pair of peers never grows above the eldest', () async {
    final c = await load([
      testCapy('a', 2, pile: 'p'),
      testCapy('b', 2, pile: 'p'),
    ]);
    run(c, BalanceV0.pilePeerSeconds(2) * 3);
    expect(get(c, 'a').level, 2);
    expect(get(c, 'b').level, 2);
    expect(get(c, 'a').growth, 0);
    c.dispose();
  });

  test('Nobody grows on their own', () async {
    final c = await load([testCapy('a', 1, growth: 0.5), testCapy('b', 1)]);
    run(c, 600);
    expect(get(c, 'a').level, 1);
    expect(get(c, 'a').growth, 0.5);
    c.dispose();
  });

  test('A nanny in the pile makes it grow faster', () async {
    Future<double> timeToLevel(CapyRole? role) async {
      final c = await load([
        testCapy('e', 2, pile: 'p', role: role),
        testCapy('b', 1, pile: 'p'),
      ]);
      var t = 0.0;
      while (get(c, 'b').level < 2 && t < 10000) {
        c.debugAdvance(0.25);
        t += 0.25;
      }
      c.dispose();
      return t;
    }

    final plain = await timeToLevel(null);
    final nanny = await timeToLevel(CapyRole.nanya);
    expect(plain, closeTo(BalanceV0.pileCatchUpSeconds(1), 0.5));
    expect(
      nanny,
      closeTo(plain / (1 + BalanceV0.pileNanyaGrowBonus), 0.5),
    );
  });

  test('Т4. Level two in a pile brings a name and «Малыш подрос»', () async {
    final c = await load([
      testCapy('e', 2, pile: 'p'),
      testCapy('b', 1, pile: 'p'),
    ]);
    final events = <GameEvent>[];
    final sub = c.events.listen(events.add);
    final rngBefore = Random(1).nextDouble();
    run(c, BalanceV0.pileCatchUpSeconds(1) + 1);
    final b = get(c, 'b');
    expect(b.level, 2);
    expect(b.isNamed, isTrue);
    expect(b.trait, isNotNull);
    final named = events.whereType<CapyNamed>().single;
    expect(named.text, 'Малыш подрос — теперь это ${b.displayNameRu}');
    expect(named.capyId, 'b');
    final grew = events.whereType<CapyGrew>().single;
    expect(grew.capyId, 'b');
    expect(grew.level, 2);
    expect(c.pileFlashId, 'b');
    // The eldest already had level two: unnamed in the save, named on load.
    expect(get(c, 'e').isNamed, isTrue);
    expect(rngBefore, Random(1).nextDouble());
    await sub.cancel();
    c.dispose();
  });

  test('Growth alone does not notify the screen', () async {
    final c = await load([
      testCapy('e', 3, pile: 'p'),
      testCapy('b', 1, pile: 'p'),
    ]);
    // Settle the puddle and pair clocks off the counted window.
    var notices = 0;
    c.addListener(() => notices++);
    final before = get(c, 'b').growth;
    c.debugAdvance(0.05);
    expect(get(c, 'b').growth, greaterThan(before));
    // The bar moves too (one notice); growth adds none of its own.
    expect(notices, lessThanOrEqualTo(1));
    c.dispose();
  });

  group('С9. Away from the game', () {
    test('cold start: growth for the capped offline seconds', () async {
      final away = testNow.add(const Duration(hours: 2));
      final c = await load(
        [
          testCapy('e', 3, pile: 'p'),
          testCapy('b', 1, pile: 'p'),
        ],
        now: () => away,
      );
      // Capped like the auto bar: 180 s of a 120 s step → exactly one level,
      // and the rest of the cap toward the next.
      expect(c.offlineSecondsApplied, BalanceV0.offlineCapSeconds);
      final b = get(c, 'b');
      final step1 = BalanceV0.pileCatchUpSeconds(1);
      final left = BalanceV0.offlineCapSeconds - step1.ceil();
      expect(b.level, 2);
      expect(
        b.growth,
        closeTo(left / BalanceV0.pileCatchUpSeconds(2), 0.01),
      );
      c.dispose();
    });

    test('back from background: same rules', () async {
      var clock = testNow;
      final persistence = GamePersistence();
      SharedPreferences.setMockInitialValues(
        herdSave([
          testCapy('e', 3, pile: 'p'),
          testCapy('b', 1, pile: 'p'),
        ]),
      );
      final c = testController(persistence: persistence, now: () => clock);
      await c.init();
      await c.suspend();
      clock = clock.add(const Duration(seconds: 60));
      c.resumeFromBackground();
      expect(
        get(c, 'b').growth,
        closeTo(60 / BalanceV0.pileCatchUpSeconds(1), 1e-6),
      );
      await c.suspend();
      clock = clock.add(const Duration(seconds: 5));
      c.resumeFromBackground();
      expect(
        get(c, 'b').growth,
        closeTo(60 / BalanceV0.pileCatchUpSeconds(1), 1e-6),
        reason: 'under the 8 s floor nothing is granted',
      );
      c.dispose();
    });
  });
}
