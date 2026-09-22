import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
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
    expect(c.state.herdProgress, closeTo(BalanceV0.autoProgressPerSecond * 2, 0.001));
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
    // Phase 2: clearer visual ladder (scalePerLevel 0.34)
    expect(
      BalanceV0.capySizeForLevel(6) / BalanceV0.capySizeForLevel(1),
      greaterThan(2.5),
    );
    c.dispose();
  });

  test('herd soft-cap is 12', () async {
    expect(BalanceV0.maxHerdSize, 12);
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

  test('zoom widens with Sunny Glade circles', () {
    expect(BalanceV0.zoomForHerdCount(1), BalanceV0.zoomClose);
    expect(BalanceV0.zoomForHerdCount(4), BalanceV0.zoomMid);
    expect(BalanceV0.zoomForHerdCount(7), BalanceV0.zoomFar);
    expect(BalanceV0.zoomForHerdCount(10), BalanceV0.zoomWidest);
    expect(BalanceV0.zoomForHerdCount(12), BalanceV0.zoomWidest);
  });

  test('glade unlock toast fires once when Berry Glade opens', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.currentGlade.id, 'warm_edge');
    expect(c.gladeUnlockToast, isNull);

    // Grow to 3 → Ягодная поляна.
    c.addProgress(1.0, fromTap: true);
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, 3);
    expect(c.currentGlade.id, 'berry_glade');
    expect(c.gladeUnlockToast, 'Открылась Ягодная поляна');
    expect(c.state.sunnyGladeAnnounced, 1);

    c.acknowledgeGladeUnlock();
    expect(c.gladeUnlockToast, isNull);

    // Further growth within same glade — no re-toast.
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, 4);
    expect(c.gladeUnlockToast, isNull);
    c.dispose();
  });

  test('offline progress grants capped auto fill and sets welcome', () async {
    final now = DateTime(2026, 9, 21, 22, 0, 0);
    final savedAt = now.subtract(const Duration(minutes: 10));
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1':
          '{"herdProgress":0.1,"nextId":2,"savedAtMs":${savedAt.millisecondsSinceEpoch},'
          '"herd":[{"id":"c1","level":1,"x":0.5,"y":0.5}]}',
    });

    var clock = now;
    final c = GameController(
      persistence: GamePersistence(),
      now: () => clock,
    );
    await c.init();

    // Cap = 180s * autoProgressPerSecond → progress 0.1 + grant
    expect(c.offlineSecondsApplied, BalanceV0.offlineCapSeconds);
    expect(c.hasOfflineWelcome, isTrue);
    final grant = BalanceV0.autoProgressPerSecond * BalanceV0.offlineCapSeconds;
    final total = 0.1 + grant;
    final spawns = total.floor();
    final rem = total - spawns;
    expect(c.state.herdCount, 1 + spawns);
    expect(c.state.herdProgress, closeTo(rem, 0.01));

    c.acknowledgeOfflineWelcome();
    expect(c.hasOfflineWelcome, isFalse);
    c.dispose();
  });

  test('short offline gaps are ignored', () async {
    final now = DateTime(2026, 9, 21, 22, 0, 0);
    final savedAt = now.subtract(const Duration(seconds: 3));
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1':
          '{"herdProgress":0.2,"nextId":2,"savedAtMs":${savedAt.millisecondsSinceEpoch},'
          '"herd":[{"id":"c1","level":1,"x":0.5,"y":0.5}]}',
    });

    final c = GameController(
      persistence: GamePersistence(),
      now: () => now,
    );
    await c.init();
    expect(c.hasOfflineWelcome, isFalse);
    expect(c.state.herdProgress, closeTo(0.2, 0.001));
    expect(c.state.herdCount, 1);
    c.dispose();
  });

  test('GameState round-trips savedAtMs', () {
    final s = GameState(
      herdProgress: 0.4,
      herd: const [],
      nextId: 3,
      savedAtMs: 1234567890,
    );
    final back = GameState.fromJson(s.toJson());
    expect(back.savedAtMs, 1234567890);
    expect(back.herdProgress, 0.4);
  });

  test('decor milestones are ordered', () {
    expect(BalanceV0.decorBush1At, lessThan(BalanceV0.decorRockAt));
    expect(BalanceV0.decorRockAt, lessThan(BalanceV0.decorBush2At));
    expect(BalanceV0.decorBush2At, lessThanOrEqualTo(BalanceV0.maxHerdSize));
  });

  test('daily bonus available once per local calendar day', () async {
    final day = DateTime(2026, 9, 21, 10, 0, 0);
    var clock = day;
    final c = GameController(
      persistence: GamePersistence(),
      now: () => clock,
    );
    await c.init();
    expect(c.isDailyBonusAvailable, isTrue);
    final before = c.state.herdProgress;
    expect(c.claimDailyBonus(), isTrue);
    expect(c.isDailyBonusAvailable, isFalse);
    expect(
      c.state.herdProgress,
      closeTo(before + BalanceV0.dailyBonusProgress, 0.001),
    );
    expect(c.state.lastDailyClaimYmd, '2026-09-21');

    // Same day: no re-claim.
    expect(c.claimDailyBonus(), isFalse);

    // Next calendar day unlocks again.
    clock = DateTime(2026, 9, 22, 8, 0, 0);
    expect(c.isDailyBonusAvailable, isTrue);
    expect(c.claimDailyBonus(), isTrue);
    expect(c.state.lastDailyClaimYmd, '2026-09-22');
    c.dispose();
  });

  test('daily claim date round-trips through GameState JSON', () {
    final s = GameState(
      herdProgress: 0.1,
      herd: const [],
      nextId: 1,
      lastDailyClaimYmd: '2026-09-21',
    );
    final back = GameState.fromJson(s.toJson());
    expect(back.lastDailyClaimYmd, '2026-09-21');
  });

  test('calendarDayKey pads month and day', () {
    expect(
      GameController.calendarDayKey(DateTime(2026, 9, 21)),
      '2026-09-21',
    );
    expect(
      GameController.calendarDayKey(DateTime(2026, 1, 5)),
      '2026-01-05',
    );
  });


  test('spawn and drag-end clamp into active Sunny Glade', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    for (final capy in c.state.herd) {
      expect(
        WorldZones.isInMeadow(capy.position, herdCount: c.state.herdCount),
        isTrue,
      );
    }
    // Fill herd — every spawn must land on the active glade.
    for (var i = 0; i < 11; i++) {
      c.addProgress(1.0, fromTap: true);
    }
    expect(c.state.herdCount, BalanceV0.maxHerdSize);
    expect(c.currentGlade.id, 'great_meadow');
    for (final capy in c.state.herd) {
      expect(
        WorldZones.isInMeadow(capy.position, herdCount: c.state.herdCount),
        isTrue,
        reason: 'spawn ${capy.id} at ${capy.position}',
      );
    }

    final id = c.state.herd.first.id;
    final glade = WorldZones.gladeForHerd(c.state.herdCount);
    // Drag onto tree canopy / edge — must snap into Большой луг.
    c.updatePosition(id, const Offset(0.01, 0.10));
    final moved = c.state.herd.firstWhere((e) => e.id == id);
    expect(moved.position.dx, glade.left);
    expect(moved.position.dy, glade.top);
    expect(
      WorldZones.isInMeadow(moved.position, herdCount: c.state.herdCount),
      isTrue,
    );
    c.dispose();
  });

  test('loaded out-of-zone positions are reclamped on init', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1':
          '{"herdProgress":0.0,"nextId":2,'
          '"herd":[{"id":"c1","level":1,"x":0.02,"y":0.10}]}',
    });
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.state.herd.single.position.dx, WorldZones.meadowLeft);
    expect(c.state.herd.single.position.dy, WorldZones.meadowTop);
    c.dispose();
  });

  test('cameraZoom respects glade baseline and fit', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.cameraZoom, BalanceV0.zoomClose);
    for (var i = 0; i < 11; i++) {
      c.addProgress(1.0, fromTap: true);
    }
    expect(c.state.herdCount, 12);
    expect(c.cameraZoom, lessThanOrEqualTo(BalanceV0.zoomWidest + 0.001));
    expect(c.cameraZoom, greaterThanOrEqualTo(BalanceV0.zoomWidest));
    c.dispose();
  });

  test('unlocked glade stays open after merge shrinks herd', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    // Grow to 3 → Berry Glade unlocks.
    c.addProgress(1.0, fromTap: true);
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, 3);
    expect(c.currentGlade.id, 'berry_glade');
    expect(c.state.sunnyGladeAnnounced, 1);

    // Merge 3 → 2: herd shrinks but Berry Glade stays (no Warm Edge regression).
    final a = c.state.herd[0].id;
    final b = c.state.herd[1].id;
    expect(c.tryMerge(a, b), isTrue);
    expect(c.state.herdCount, 2);
    expect(c.currentGlade.id, 'berry_glade');
    expect(c.currentGlade.nameRu, 'Ягодная поляна');
    c.dispose();
  });


  test('flower tap grants grass and spendCallCapy spawns under cap', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.state.grass, 0);
    c.onFlowerTap();
    expect(c.state.grass, greaterThanOrEqualTo(BalanceV0.flowerTapGrassMin));
    expect(c.lastTapGrass, greaterThanOrEqualTo(BalanceV0.flowerTapGrassMin));

    // Force enough grass to call a capy.
    while (c.state.grass < BalanceV0.callCapyGrassCost) {
      c.onFlowerTap();
    }
    final before = c.state.herdCount;
    expect(c.canCallCapy, isTrue);
    expect(c.spendCallCapy(), isTrue);
    expect(c.state.herdCount, before + 1);
    expect(c.state.grass, lessThan(BalanceV0.callCapyGrassCost + BalanceV0.flowerTapGrassMax));
    c.dispose();
  });

  test('spendGrassBoost refuses without grass then activates', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.spendGrassBoost(), isFalse);
    expect(c.isGrassBoostActive, isFalse);
    while (c.state.grass < BalanceV0.grassBoostCost) {
      c.onFlowerTap();
    }
    expect(c.spendGrassBoost(), isTrue);
    expect(c.isGrassBoostActive, isTrue);
    expect(c.canGrassBoost, c.state.grass >= BalanceV0.grassBoostCost);
    c.dispose();
  });

  test('session goal advances on Berry Glade unlock', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.currentSessionGoal?.id, 'berry_glade');
    expect(c.sessionGoalProgress, lessThan(1.0));

    // Grow to 3 → Berry Glade + goal complete.
    c.addProgress(1.0, fromTap: true);
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, 3);
    expect(c.state.sunnyGladeAnnounced, 1);
    expect(c.goalCompleteToast, isNotNull);
    expect(c.state.sessionGoalIndex, greaterThanOrEqualTo(1));
    expect(c.currentSessionGoal?.id, 'sunny_clearing');
    c.acknowledgeGoalComplete();
    expect(c.goalCompleteToast, isNull);
    c.dispose();
  });

  test('twin merge grants bonus grass', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, 2);
    final a = c.state.herd[0].id;
    final b = c.state.herd[1].id;
    c.debugMarkTwins(a, b);
    expect(c.state.isTwinMarked(a), isTrue);
    final grassBefore = c.state.grass;
    expect(c.tryMerge(a, b), isTrue);
    expect(
      c.state.grass,
      greaterThanOrEqualTo(grassBefore + BalanceV0.twinMergeBonusGrass),
    );
    expect(c.state.twinIdA, isNull);
    c.dispose();
  });

  test('grass and goals round-trip through GameState JSON', () {
    final s = GameState(
      herdProgress: 0.2,
      herd: const [],
      nextId: 2,
      grass: 17,
      sessionGoalIndex: 2,
      twinIdA: 'c1',
      twinIdB: 'c2',
    );
    final back = GameState.fromJson(s.toJson());
    expect(back.grass, 17);
    expect(back.sessionGoalIndex, 2);
    expect(back.twinIdA, 'c1');
    expect(back.twinIdB, 'c2');
  });

}
