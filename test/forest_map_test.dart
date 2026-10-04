import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/models/meadow_snapshot.dart';
import 'package:capy_clicker/features/game/models/multipliers/family_food.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('GameState multi-meadow round-trip preserves herds', () {
    final warm = MeadowSnapshot(
      herdProgress: 0.3,
      herd: [
        Capybara(id: 'c1', level: 2, position: const Offset(0.4, 0.7)),
        Capybara(id: 'c2', level: 1, position: const Offset(0.5, 0.7)),
      ],
    );
    final berry = MeadowSnapshot(
      herd: [Capybara(id: 'c3', level: 1, position: const Offset(0.3, 0.6))],
    );
    final state = GameState(
      herdProgress: warm.herdProgress,
      herd: warm.herd,
      nextId: 10,
      grass: 42,
      sunnyGladeAnnounced: 1,
      activeMeadowId: 'warm_edge',
      meadows: {'warm_edge': warm, 'berry_glade': berry},
    );

    final back = GameState.fromJson(state.toJson());
    expect(back.activeMeadowId, 'warm_edge');
    expect(back.herdCount, 2);
    expect(back.grass, 42);
    expect(back.meadows['berry_glade']!.herdCount, 1);
    expect(back.meadows['warm_edge']!.herd.first.level, 2);
    expect(back.totalHerdAcrossMeadows, 3);
  });

  test('legacy single-herd save migrates into warm_edge', () {
    final legacy = {
      'herdProgress': 0.2,
      'nextId': 6,
      'sunnyGladeAnnounced': 2,
      'grass': 9,
      'herd': [
        {'id': 'c1', 'level': 3, 'x': 0.5, 'y': 0.7},
        {'id': 'c2', 'level': 1, 'x': 0.4, 'y': 0.65},
      ],
    };
    final state = GameState.fromJson(legacy);
    expect(state.activeMeadowId, WorldZones.starterMeadowId);
    expect(state.herdCount, 2);
    expect(state.herd.first.level, 3);
    expect(state.sunnyGladeAnnounced, 2);
    expect(state.meadows.containsKey('berry_glade'), isTrue);
    expect(state.meadows.containsKey('sunny_clearing'), isTrue);
  });

  test('switch meadow restores each herd; grass stays shared', () async {
    final c = testController();
    await c.init();

    // Grow warm family to the Berry power → unlock berry with starter.
    growFamily(c, () => c.state.sunnyGladeAnnounced >= 1);
    final warmCount = c.state.herdCount;
    expect(c.state.sunnyGladeAnnounced, 1);
    while (c.state.grass < 5) {
      c.onFlowerTap();
    }
    final grassBefore = c.state.grass;
    final warmIds = c.state.herd.map((e) => e.id).toSet();

    expect(c.switchToMeadow('berry_glade'), isTrue);
    expect(c.currentGlade.id, 'berry_glade');
    expect(c.state.herdCount, BalanceV0.meadowStarterHerdSize);
    expect(c.state.grass, grassBefore); // shared wallet
    final berryIds = c.state.herd.map((e) => e.id).toSet();
    expect(berryIds.intersection(warmIds), isEmpty);

    // Grow berry a bit, then return — warm herd intact.
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, BalanceV0.meadowStarterHerdSize + 1);

    expect(c.switchToMeadow('warm_edge'), isTrue);
    expect(c.state.herdCount, warmCount);
    expect(c.state.herd.map((e) => e.id).toSet(), warmIds);
    expect(c.state.grass, greaterThanOrEqualTo(grassBefore));
    expect(
      c.herdCountForMeadow('berry_glade'),
      BalanceV0.meadowStarterHerdSize + 1,
    );
    c.dispose();
  });

  test('unlock adds meadow with starter herd', () async {
    final c = testController();
    await c.init();
    expect(c.unlockedMeadowIds, ['warm_edge']);

    growFamily(c, () => c.state.sunnyGladeAnnounced >= 1);
    final warmCount = c.state.herdCount;
    expect(c.unlockedMeadowIds, ['warm_edge', 'berry_glade']);
    expect(
      c.herdCountForMeadow('berry_glade'),
      BalanceV0.meadowStarterHerdSize,
    );
    expect(
      c.state.meadows['berry_glade']!.herd.every((e) => e.level == 1),
      isTrue,
    );
    // Active meadow unchanged.
    expect(c.state.activeMeadowId, 'warm_edge');
    expect(c.state.herdCount, warmCount);
    c.dispose();
  });

  test('persistence save/load keeps multi-meadow herds', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = GamePersistence();
    final c = testController(persistence: persistence);
    await c.init();
    growFamily(c, () => c.state.sunnyGladeAnnounced >= 1);
    final warmCount = c.state.herdCount;
    expect(c.switchToMeadow('berry_glade'), isTrue);
    c.addProgress(1.0, fromTap: true);
    final berryCount = c.state.herdCount;
    final grass = c.state.grass;
    await persistence.save(c.state.withActiveSynced());
    c.dispose();

    final c2 = testController();
    await c2.init();
    expect(c2.state.activeMeadowId, 'berry_glade');
    expect(c2.state.herdCount, berryCount);
    expect(c2.state.grass, grass);
    expect(c2.herdCountForMeadow('warm_edge'), warmCount);
    c2.dispose();
  });

  test('legacy save loads and fills starters for unlocked meadows', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 8,
        'sunnyGladeAnnounced': 1,
        'grass': 4,
        'herd': [
          {'id': 'c1', 'level': 2, 'x': 0.5, 'y': 0.7},
          {'id': 'c2', 'level': 1, 'x': 0.45, 'y': 0.72},
          {'id': 'c3', 'level': 1, 'x': 0.55, 'y': 0.68},
        ],
      }),
    });
    final c = testController();
    await c.init();
    expect(c.state.activeMeadowId, 'warm_edge');
    expect(c.state.herdCount, 3);
    expect(c.state.isMeadowUnlocked('berry_glade'), isTrue);
    expect(
      c.herdCountForMeadow('berry_glade'),
      BalanceV0.meadowStarterHerdSize,
    );
    expect(c.state.grass, 4);
    c.dispose();
  });

  test('grass never goes negative when switching meadows', () async {
    final c = testController();
    await c.init();
    growFamily(c, () => c.state.sunnyGladeAnnounced >= 1);
    expect(c.state.grass, greaterThanOrEqualTo(0));
    c.switchToMeadow('berry_glade');
    expect(c.state.grass, greaterThanOrEqualTo(0));
    while (c.state.grass < BalanceV0.callCapyGrassCost) {
      c.onFlowerTap();
    }
    final g = c.state.grass;
    c.switchToMeadow('warm_edge');
    expect(c.state.grass, g);
    c.dispose();
  });

  test('unlock thresholds by family power (spec 006 numbers)', () async {
    final c = testController();
    await c.init();
    expect(c.state.sunnyGladeAnnounced, 0);
    expect(c.unlockedMeadowIds, ['warm_edge']);

    // Below the Berry power nothing opens; at it, Ягодная does.
    growFamily(c, () {
      final berry = c.state.familyPower >= BalanceV0.gladeBerryPower;
      if (!berry) expect(c.state.sunnyGladeAnnounced, 0);
      return berry;
    });
    expect(c.state.sunnyGladeAnnounced, 1);
    expect(c.state.isMeadowUnlocked('berry_glade'), isTrue);
    expect(c.state.isMeadowUnlocked('sunny_clearing'), isFalse);

    growFamily(c, () => c.state.familyPower >= BalanceV0.gladeSunnyPower);
    expect(c.state.sunnyGladeAnnounced, 2);
    expect(c.state.isMeadowUnlocked('sunny_clearing'), isTrue);
    expect(c.state.isMeadowUnlocked('great_meadow'), isFalse);
    expect(
      c.herdCountForMeadow('sunny_clearing'),
      BalanceV0.meadowStarterHerdSize,
    );
    // Places, not bodies: more capys than places.
    expect(c.placesUsed, lessThanOrEqualTo(c.effectiveMaxHerdSize));

    growFamily(c, () => c.state.familyPower >= BalanceV0.gladeGreatPower);
    expect(c.state.sunnyGladeAnnounced, 3);
    expect(c.state.herdCount, greaterThan(BalanceV0.maxHerdSize));
    c.dispose();
  });

  test('no soft-lock with only warm_edge unlocked', () async {
    final c = testController();
    await c.init();
    expect(c.unlockedMeadowIds, ['warm_edge']);
    expect(c.state.herdCount, greaterThanOrEqualTo(1));

    // Locked meadows refuse switch; starter always works.
    expect(c.switchToMeadow('berry_glade'), isFalse);
    expect(c.switchToMeadow('sunny_clearing'), isFalse);
    expect(c.switchToMeadow('great_meadow'), isFalse);
    expect(c.switchToMeadow('warm_edge'), isTrue);
    expect(c.state.activeMeadowId, 'warm_edge');
    expect(c.state.herdCount, greaterThanOrEqualTo(1));
    expect(c.state.grass, greaterThanOrEqualTo(0));

    // Progress / flower still work — no soft-lock.
    final herdBefore = c.state.herdCount;
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, herdBefore + 1);
    c.onFlowerTap();
    expect(c.state.grass, greaterThanOrEqualTo(0));
    c.dispose();
  });

  test('shared grass spend visible after meadow switch', () async {
    final c = testController();
    await c.init();
    growFamily(c, () => c.state.sunnyGladeAnnounced >= 1);
    while (c.state.grass < BalanceV0.callCapyGrassCost + 5) {
      c.onFlowerTap();
    }
    // The meadow may be full by now (places): spend on food instead.
    final before = c.state.grass;
    expect(c.buyFood(FamilyFood.travka), isTrue);
    expect(c.state.grass, before - BalanceV0.grassToTravkaCost);
    final afterSpend = c.state.grass;

    expect(c.switchToMeadow('berry_glade'), isTrue);
    expect(c.state.grass, afterSpend);
    expect(
      c.spendGrassBoost() || c.state.grass < BalanceV0.grassBoostCost,
      isTrue,
    );
    // Grass never negative after spend/switch.
    expect(c.state.grass, greaterThanOrEqualTo(0));
    c.switchToMeadow('warm_edge');
    expect(c.state.grass, greaterThanOrEqualTo(0));
    c.dispose();
  });

  test('multi-meadow scripted flow: grow / switch / return / unlock chain', () async {
    final c = testController();
    await c.init();

    // Unlock berry on warm.
    growFamily(c, () => c.state.sunnyGladeAnnounced >= 1);
    final warmHerd = c.state.herdCount;
    expect(
      c.state.familyPower,
      greaterThanOrEqualTo(BalanceV0.gladeBerryPower),
    );

    // Visit berry, grow local herd, grass shared wallet grows via flowers.
    expect(c.switchToMeadow('berry_glade'), isTrue);
    expect(c.state.herdCount, BalanceV0.meadowStarterHerdSize);
    c.addProgress(1.0, fromTap: true);
    c.addProgress(1.0, fromTap: true);
    final berryHerd = c.state.herdCount;
    expect(berryHerd, BalanceV0.meadowStarterHerdSize + 2);
    while (c.state.grass < 20) {
      c.onFlowerTap();
    }
    final grassMid = c.state.grass;

    // Return — warm intact; grass unchanged by switch.
    expect(c.switchToMeadow('warm_edge'), isTrue);
    expect(c.state.herdCount, warmHerd);
    expect(c.state.grass, grassMid);
    expect(c.herdCountForMeadow('berry_glade'), berryHerd);

    // Push warm to the Sunny power → unlock sunny_clearing without visiting.
    growFamily(c, () => c.state.sunnyGladeAnnounced >= 2);
    expect(
      c.state.familyPower,
      greaterThanOrEqualTo(BalanceV0.gladeSunnyPower),
    );
    expect(c.state.sunnyGladeAnnounced, 2);
    expect(c.switchToMeadow('sunny_clearing'), isTrue);
    expect(c.state.herdCount, BalanceV0.meadowStarterHerdSize);

    // Back to berry — still its own herd.
    expect(c.switchToMeadow('berry_glade'), isTrue);
    expect(c.state.herdCount, berryHerd);
    expect(c.state.grass, greaterThanOrEqualTo(0));
    c.dispose();
  });
}
