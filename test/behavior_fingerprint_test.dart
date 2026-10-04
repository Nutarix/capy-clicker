import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/fingerprint.dart';

/// Behavior fingerprint (spec 002, Т12): a scripted session over the whole
/// public controller API on a fixed seed and a still clock. Timers (berry,
/// wallow, merge flash, save) run on the fake time of [testWidgets].
///
/// The balance sims fingerprint themselves (progression / showable / player).
void main() {
  const key = 'capy_clicker_game_state_v1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Map<String, Object?>> prefsBlobs() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'main': prefs.getString(key),
      'prev': prefs.getString('${key}_prev'),
      'broken': prefs.getString('${key}_broken'),
    };
  }

  testWidgets('scripted session', (tester) async {
    final fp = Fingerprint('session');
    // UTC: the golden was taken at 09:00 UTC+3; same instant on any machine.
    var clock = DateTime.utc(2026, 9, 22, 6, 0, 0);
    DateTime now() => clock;
    final persistence = GamePersistence();

    var c = GameController(
      persistence: persistence,
      random: Random(2026),
      now: now,
      autoTick: false,
    );
    await c.init();
    fp.mark('init', c);

    /// Game clock in 0.25 s steps (the sims' step).
    void adv(double seconds) {
      var left = seconds;
      while (left > 1e-9) {
        final dt = left < 0.25 ? left : 0.25;
        clock = clock.add(Duration(microseconds: (dt * 1e6).round()));
        c.debugAdvance(dt);
        left -= dt;
      }
    }

    void tapUntilGrass(int grass) {
      for (var i = 0; i < 2000 && c.state.grass < grass; i++) {
        c.onFlowerTap();
        adv(0.5);
      }
    }

    /// Lowest-level same-level pair, in herd order.
    (String, String)? lowestPair() {
      final byLevel = <int, List<Capybara>>{};
      for (final cap in c.state.herd) {
        byLevel.putIfAbsent(cap.level, () => []).add(cap);
      }
      final levels = byLevel.keys.toList()..sort();
      for (final lv in levels) {
        final list = byLevel[lv]!;
        if (list.length >= 2) return (list[0].id, list[1].id);
      }
      return null;
    }

    bool mergeLowest() {
      final pair = lowestPair();
      if (pair == null) return false;
      return c.tryMerge(pair.$1, pair.$2);
    }

    /// Spawn while there is room, merge the lowest pair when full.
    void grow(bool Function() done, {int rounds = 600}) {
      for (var i = 0; i < rounds && !done(); i++) {
        if (c.state.herdCount < c.effectiveMaxHerdSize) {
          c.addProgress(1.0, fromTap: false);
        } else {
          mergeLowest();
        }
        adv(0.5);
      }
    }

    // --- Ticks and taps ---
    adv(5);
    fp.mark('5 s of ticks', c);
    for (var i = 0; i < 6; i++) {
      c.onFlowerTap();
      adv(1);
    }
    fp.mark('flower taps', c);

    // Berry through its own timer.
    await tester.pump(BalanceV0.berryFirstSpawnMax + const Duration(seconds: 1));
    fp.mark('berry timer', c);
    fp.mark('berry tap', c, extra: {'gain': c.onBerryTap()});
    fp.mark('berry tap again', c, extra: {'gain': c.onBerryTap()});

    // --- Mud ---
    for (var i = 0; i < 200 && !c.mudVisible; i++) {
      adv(0.25);
    }
    fp.mark('puddle up', c);
    c.acknowledgePuddleToast();
    final wallowId = c.state.herd.first.id;
    fp.mark('wallow', c, extra: {'ok': c.tryMudWallow(wallowId)});
    await tester.pump(
      BalanceV0.mudWallowAnimDuration + const Duration(milliseconds: 50),
    );
    fp.mark('wallow over', c);
    adv(14);
    fp.mark('mud boost spent', c);
    c.debugPlaceMud(const Offset(0.30, 0.70), seconds: 2);
    fp.mark('mud placed', c);
    adv(3);
    fp.mark('mud gone', c);

    // --- Grass spend ---
    tapUntilGrass(BalanceV0.callCapyGrassCost);
    fp.mark('call capy', c, extra: {'ok': c.spendCallCapy()});
    tapUntilGrass(BalanceV0.grassBoostCost);
    fp.mark('grass boost', c, extra: {'ok': c.spendGrassBoost()});
    adv(3);
    fp.mark('grass boost mid', c);
    adv(4);
    fp.mark('grass boost over', c);

    // --- Merges, twins ---
    grow(() => c.state.herdCount >= 5);
    fp.mark('herd 5', c);
    fp.mark('merge', c, extra: {'ok': mergeLowest()});
    await tester.pump(
      BalanceV0.mergeFlashDuration + const Duration(milliseconds: 20),
    );
    fp.mark('merge flash over', c);
    fp.mark('merge mismatch', c, extra: {
      'ok': c.tryMerge(c.state.herd.first.id, c.state.herd.last.id),
    });
    final pair = lowestPair();
    if (pair != null) {
      c.debugMarkTwins(pair.$1, pair.$2);
      fp.mark('twins marked', c);
      fp.mark('twin merge', c, extra: {'ok': c.tryMerge(pair.$1, pair.$2)});
    }
    adv(40);
    fp.mark('twin reroll', c);

    // --- Food ---
    for (final food in FamilyFood.values) {
      tapUntilGrass(30);
      fp.mark('buy ${food.name}', c, extra: {'ok': c.buyFood(food)});
    }
    c.selectFood(FamilyFood.yagody);
    fp.mark('feed yagody', c, extra: {'ok': c.feedFamily()});
    fp.mark('feed oreshki', c, extra: {'ok': c.feedFamily(FamilyFood.oreshki)});
    fp.mark('feed oreshki empty', c, extra: {
      'ok': c.feedFamily(FamilyFood.oreshki),
    });
    adv(6);
    fp.mark('food mid', c);
    fp.mark('feed travka', c, extra: {'ok': c.feedFamily(FamilyFood.travka)});
    adv(13);
    fp.mark('food over', c);

    // --- Cozy places ---
    final standId = c.state.herd.last.id;
    fp.mark('pen with capy', c, extra: {
      'ok': c.tryActivatePlace(
        CozyPlaceKind.pen,
        capyId: standId,
        standAt: const Offset(0.25, 0.66),
      ),
    });
    fp.mark('pen again', c, extra: {
      'ok': c.tryActivatePlace(CozyPlaceKind.pen),
    });
    fp.mark('tent locked', c, extra: {
      'ok': c.tryActivatePlace(CozyPlaceKind.tent),
    });
    adv(9);
    fp.mark('warm stone', c, extra: {
      'ok': c.tryActivatePlace(CozyPlaceKind.warmStone),
    });
    adv(30);
    fp.mark('places over', c);

    // --- Roles ---
    final herd = c.state.herd;
    fp.mark('role nanya', c, extra: {
      'ok': c.assignRole(herd[0].id, CapyRole.nanya),
    });
    fp.mark('role over slots', c, extra: {
      'ok': c.assignRole(herd[1].id, CapyRole.sobiratel),
    });
    fp.mark('role swap', c, extra: {
      'ok': c.assignRole(herd[0].id, CapyRole.storozh),
    });
    fp.mark('role free', c, extra: {
      'ok': c.assignRoleToFreeCapy(CapyRole.storozh),
    });
    fp.mark('role clear', c, extra: {'ok': c.clearRole(CapyRole.storozh)});
    fp.mark('role clear none', c, extra: {'ok': c.clearRole(CapyRole.nanya)});
    fp.mark('role free nanya', c, extra: {
      'ok': c.assignRoleToFreeCapy(CapyRole.nanya),
    });
    fp.mark('role unassign', c, extra: {
      'ok': c.assignRole(c.state.herd.first.id, null),
    });

    // --- First glade ---
    grow(() => c.state.sunnyGladeAnnounced >= 1);
    fp.mark('berry glade', c);
    c.acknowledgeGladeUnlock();
    c.acknowledgeGoalComplete();
    fp.mark('toasts acknowledged', c);

    // --- Decor ---
    tapUntilGrass(40);
    fp.mark('buy fonarik', c, extra: {'ok': c.buyDecor(HomeDecor.fonarik)});
    fp.mark('buy fonarik twice', c, extra: {
      'ok': c.buyDecor(HomeDecor.fonarik),
    });
    fp.mark('unplace fonarik', c, extra: {
      'ok': c.togglePlaceDecor(HomeDecor.fonarik),
    });
    fp.mark('place fonarik', c, extra: {
      'ok': c.togglePlaceDecor(HomeDecor.fonarik),
    });
    for (final decor in HomeDecor.values) {
      tapUntilGrass(decor.grassCost);
      fp.mark('buy ${decor.name}', c, extra: {'ok': c.buyDecor(decor)});
    }

    // --- Research ---
    for (final id in ['more_flowers', 'longer_mud', 'unlock_tent']) {
      final node = UyutResearch.byId(id)!;
      tapUntilGrass(node.grassCost);
      fp.mark('research $id', c, extra: {'ok': c.unlockResearch(id)});
    }
    fp.mark('research unknown', c, extra: {'ok': c.unlockResearch('nope')});
    adv(45);
    fp.mark('tent', c, extra: {
      'ok': c.tryActivatePlace(CozyPlaceKind.tent),
    });
    for (var i = 0; i < 200 && !c.mudVisible; i++) {
      adv(0.25);
    }
    fp.mark('longer mud', c, extra: {
      'ok': c.tryMudWallow(c.state.herd.first.id),
    });
    await tester.pump(
      BalanceV0.mudWallowAnimDuration + const Duration(milliseconds: 50),
    );

    // --- Forest map ---
    fp.mark('switch berry glade', c, extra: {
      'ok': c.switchToMeadow('berry_glade'),
    });
    adv(5);
    fp.mark('berry glade ticks', c);
    fp.mark('switch locked', c, extra: {
      'ok': c.switchToMeadow(WorldZones.mistEdgeMeadowId),
    });
    fp.mark('switch same', c, extra: {'ok': c.switchToMeadow('berry_glade')});
    fp.mark('switch home', c, extra: {
      'ok': c.switchToMeadow(WorldZones.starterMeadowId),
    });

    // --- More glades, mist ---
    grow(() => c.state.sunnyGladeAnnounced >= 2);
    fp.mark('sunny glade', c);
    grow(() => c.state.sunnyGladeAnnounced >= 3);
    fp.mark('great glade', c);
    grow(() => c.state.mistyBiomeUnlocked, rounds: 1200);
    fp.mark('mist unlocked', c);
    c.acknowledgeGladeUnlock();
    c.acknowledgeGoalComplete();
    fp.mark('switch mist', c, extra: {
      'ok': c.switchToMeadow(WorldZones.mistEdgeMeadowId),
    });
    adv(10);
    fp.mark('mist ticks', c);

    // --- Rocket and lands ---
    fp.mark('launch', c, extra: {'ok': c.launchToNewLand()});
    adv(10);
    fp.mark('new land ticks', c);
    fp.mark('visit land 0', c, extra: {'ok': c.visitLand(0)});
    adv(5);
    fp.mark('old land ticks', c);
    fp.mark('visit land 1', c, extra: {'ok': c.visitLand(1)});
    fp.mark('visit missing', c, extra: {'ok': c.visitLand(7)});
    grow(() => c.state.sunnyGladeAnnounced >= 1);
    fp.mark('new land glade', c);

    // --- Daily ---
    fp.mark('daily claim', c, extra: {'ok': c.claimDailyBonus()});
    fp.mark('daily twice', c, extra: {'ok': c.claimDailyBonus()});
    clock = clock.add(const Duration(days: 1));
    fp.mark('next day', c);

    // --- Save on a timer ---
    c.addProgress(0.01, fromTap: false);
    await tester.pump(
      const Duration(milliseconds: BalanceV0.persistIntervalMs + 100),
    );
    fp.note('timer save', await prefsBlobs());

    // --- Save → load ---
    await c.flushSave();
    fp.note('flush', await prefsBlobs());
    c.dispose();
    c = GameController(
      persistence: persistence,
      random: Random(77),
      now: now,
      autoTick: false,
    );
    await c.init();
    fp.mark('reload', c);
    adv(3);
    fp.mark('reload ticks', c);

    // --- Offline (cold start) ---
    await c.flushSave();
    c.dispose();
    clock = clock.add(const Duration(seconds: 100));
    c = GameController(
      persistence: persistence,
      random: Random(78),
      now: now,
      autoTick: false,
    );
    await c.init();
    fp.mark('offline cold', c);
    c.acknowledgeOfflineWelcome();
    fp.mark('offline acknowledged', c);

    // --- Background ---
    await c.suspend();
    fp.mark('suspended', c);
    clock = clock.add(const Duration(minutes: 10));
    c.resumeFromBackground();
    fp.mark('resumed long', c);
    c.acknowledgeOfflineWelcome();
    await c.suspend();
    clock = clock.add(const Duration(seconds: 5));
    c.resumeFromBackground();
    fp.mark('resumed short', c);
    adv(2);
    fp.mark('resumed ticks', c);
    fp.note('background save', await prefsBlobs());

    c.dispose();
    await tester.pump();
    fp.note('end', await prefsBlobs());
    fp.verify();
  });

  testWidgets('save store: legacy, broken, copy', (tester) async {
    final fp = Fingerprint('save_store');
    // UTC: the golden was taken at 08:00 UTC+3; same instant on any machine.
    var clock = DateTime.utc(2026, 9, 23, 5, 0, 0);
    DateTime now() => clock;
    SharedPreferences.setMockInitialValues({
      key:
          '{"herdProgress":0.4,"nextId":6,"grass":9,"sunnyGladeAnnounced":1,'
          '"savedAtMs":${clock.millisecondsSinceEpoch},'
          '"herd":[{"id":"c1","level":2,"x":0.4,"y":0.7},'
          '{"id":"c2","level":2,"x":0.5,"y":0.72},'
          '{"id":"c5","level":1,"x":0.6,"y":0.7}]}',
    });
    var persistence = GamePersistence();
    var c = GameController(
      persistence: persistence,
      random: Random(5),
      now: now,
      autoTick: false,
    );
    await c.init();
    fp.mark('legacy load', c);
    clock = clock.add(const Duration(seconds: 1));
    await c.flushSave();
    fp.note('first save', await prefsBlobs());
    await c.flushSave();
    fp.note('same save', await prefsBlobs());
    c.addProgress(0.05, fromTap: false);
    clock = clock.add(const Duration(seconds: 1));
    await c.flushSave();
    fp.note('second save', await prefsBlobs());
    c.dispose();
    await tester.pump();

    // Main blob damaged: the copy is raised, the damage is set aside.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, '{"herd": [oops');
    persistence = GamePersistence();
    c = GameController(
      persistence: persistence,
      random: Random(6),
      now: now,
      autoTick: false,
    );
    await c.init();
    fp.mark('broken main', c);
    fp.note('after broken load', await prefsBlobs());
    clock = clock.add(const Duration(seconds: 1));
    await c.flushSave();
    fp.note('save after broken', await prefsBlobs());
    c.dispose();
    await tester.pump();
    fp.note('end', await prefsBlobs());
    fp.verify();
  });

  testWidgets('live tick on fake time', (tester) async {
    final fp = Fingerprint('live_tick');
    final start = tester.binding.clock.now();
    // UTC: the golden was taken at 12:00 UTC+3; same instant on any machine.
    final base = DateTime.utc(2026, 9, 22, 9);
    DateTime now() => base.add(tester.binding.clock.now().difference(start));
    final c = GameController(
      persistence: GamePersistence(),
      random: Random(31),
      now: now,
    );
    await c.init();
    fp.mark('init', c);
    for (var s = 1; s <= 30; s++) {
      for (var f = 0; f < 20; f++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      if (s % 5 == 0) fp.mark('t=$s', c);
      if (s == 12) c.onFlowerTap();
    }
    c.dispose();
    await tester.pump();
    fp.note('end', await prefsBlobs());
    fp.verify();
  });
}
