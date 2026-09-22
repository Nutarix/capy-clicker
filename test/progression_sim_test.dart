import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

/// Headless ~10–15 min cozy-session simulation for loop v1.1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cozy session: fresh → berry glade → spend → twin → goals', () async {
    final rng = Random(42);
    var clock = DateTime(2026, 9, 22, 10, 0, 0);
    final c = GameController(
      persistence: GamePersistence(),
      random: rng,
      now: () => clock,
    );
    await c.init();

    var simSeconds = 0.0;
    var flowerCooldown = 0.0;
    var mudCooldown = 0.0;
    var berryCheckIn = 12.0;
    var mergesDone = 0;
    var twinMerges = 0;
    var calls = 0;
    var boosts = 0;
    var spendCooldown = 0.0;
    double? firstGladeAt;
    double? firstSpendAt;
    double? twinBonusAt;
    final twinMarkWindows = <double>[];
    String? lastTwinKey;

    void step(double dt) {
      clock = clock.add(Duration(milliseconds: (dt * 1000).round()));
      simSeconds += dt;
      c.debugAdvance(dt);
      flowerCooldown -= dt;
      mudCooldown -= dt;
      berryCheckIn -= dt;
      spendCooldown -= dt;
    }

    // ~12 min equivalent active cozy play.
    while (simSeconds < 720) {
      step(0.25);

      // Track twin mark windows (start of a new pair).
      final tA = c.state.twinIdA;
      final tB = c.state.twinIdB;
      if (tA != null && tB != null) {
        final key = ([tA, tB]..sort()).join(':');
        if (key != lastTwinKey) {
          twinMarkWindows.add(simSeconds);
          lastTwinKey = key;
        }
      } else {
        lastTwinKey = null;
      }

      if (firstGladeAt == null && c.state.sunnyGladeAnnounced >= 1) {
        firstGladeAt = simSeconds;
      }

      // Flower taps ~ every 2.6–3.4s (cozy, not speedrun).
      if (flowerCooldown <= 0) {
        c.onFlowerTap();
        flowerCooldown = 3.4 + rng.nextDouble() * 1.2;
      }

      // Berry when available.
      if (berryCheckIn <= 0) {
        berryCheckIn = 4.0;
        if (!c.isBerryVisible && simSeconds > 10) {
          // Approx rare spawn — force periodically like basket cadence.
          if (rng.nextDouble() < 0.18) c.debugShowBerry();
        }
        if (c.isBerryVisible) {
          c.onBerryTap();
        }
      }

      // Mud wallow every ~18s.
      if (mudCooldown <= 0 && c.state.herd.isNotEmpty) {
        c.tryMudWallow(c.state.herd.first.id);
        mudCooldown = 28 + rng.nextDouble() * 12;
      }

      // Spend fork with human-like cooldown (~8–14s between spends).
      if (spendCooldown <= 0 && (c.canCallCapy || c.canGrassBoost)) {
        final preferCall = c.state.herdCount < 8 && c.canCallCapy;
        var spent = false;
        if (preferCall && rng.nextDouble() < 0.5) {
          spent = c.spendCallCapy();
          if (spent) calls++;
        } else if (c.canGrassBoost && rng.nextDouble() < 0.55) {
          spent = c.spendGrassBoost();
          if (spent) boosts++;
        } else if (c.canCallCapy) {
          spent = c.spendCallCapy();
          if (spent) calls++;
        }
        if (spent) {
          firstSpendAt ??= simSeconds;
          spendCooldown = 8.0 + rng.nextDouble() * 6.0;
        }
      }

      // Occasional merge (favor twins); keep early merges rare so herd can grow.
      final mergeChance = c.state.herdCount < 5 ? 0.03 : 0.07;
      if (c.state.herdCount >= 2 && rng.nextDouble() < mergeChance) {
        final herd = c.state.herd;
        String? a;
        String? b;
        if (c.state.twinIdA != null && c.state.twinIdB != null) {
          a = c.state.twinIdA;
          b = c.state.twinIdB;
        } else {
          final byLevel = <int, List<String>>{};
          for (final cap in herd) {
            byLevel.putIfAbsent(cap.level, () => []).add(cap.id);
          }
          final pairs =
              byLevel.values.where((ids) => ids.length >= 2).toList();
          if (pairs.isNotEmpty) {
            final pick = pairs[rng.nextInt(pairs.length)];
            a = pick[0];
            b = pick[1];
          }
        }
        if (a != null && b != null) {
          final beforeGrass = c.state.grass;
          final wasTwin = c.state.isTwinMarked(a) && c.state.isTwinMarked(b);
          if (c.tryMerge(a, b)) {
            mergesDone++;
            if (wasTwin && c.state.grass >= beforeGrass + BalanceV0.twinMergeBonusGrass) {
              twinMerges++;
              twinBonusAt ??= simSeconds;
            }
          }
        }
      }

      if (c.goalCompleteToast != null) {
        c.acknowledgeGoalComplete();
      }
      if (c.gladeUnlockToast != null) {
        c.acknowledgeGladeUnlock();
      }
    }

    // ignore: avoid_print
    print(
      'SIM firstGlade=${firstGladeAt?.toStringAsFixed(0)}s '
      'spend@${firstSpendAt?.toStringAsFixed(0)}s '
      'calls=$calls boosts=$boosts twinMerges=$twinMerges '
      'merges=$mergesDone goals=${c.state.sessionGoalIndex} '
      'gladeAnn=${c.state.sunnyGladeAnnounced} herd=${c.state.herdCount} '
      'grass=${c.state.grass} twinsMarked=${twinMarkWindows.length} '
      'goalProg=${c.sessionGoalProgress.toStringAsFixed(2)}',
    );

    // --- Assertions / balance gates ---
    expect(firstGladeAt, isNotNull, reason: 'Berry glade should unlock');
    expect(
      firstGladeAt!,
      inInclusiveRange(100, 320),
      reason: 'First glade ~2–5 min cozy (target 2–4); got ${firstGladeAt}s',
    );
    expect(firstSpendAt, isNotNull, reason: 'Spend fork should be used');
    expect(calls + boosts, greaterThan(0));
    // Meaningful fork: not always only spawn.
    expect(boosts, greaterThan(0), reason: 'Boost should be chosen sometimes');
    expect(calls, greaterThan(0), reason: 'Call should be chosen sometimes');

    expect(mergesDone, greaterThan(0));
    expect(twinMerges, greaterThan(0), reason: 'Twin merge bonus should fire');
    expect(twinBonusAt, isNotNull);

    // Twin rarity: appears several times per session, not permanent glow.
    expect(twinMarkWindows.length, greaterThanOrEqualTo(2));
    expect(
      twinMarkWindows.length,
      lessThan(20),
      reason: 'twinsMarked=${twinMarkWindows.length} looks spammy over 12 min',
    );
    if (twinMarkWindows.length >= 2) {
      final gaps = <double>[];
      for (var i = 1; i < twinMarkWindows.length; i++) {
        gaps.add(twinMarkWindows[i] - twinMarkWindows[i - 1]);
      }
      final avg = gaps.reduce((a, b) => a + b) / gaps.length;
      expect(avg, greaterThan(25), reason: 'avg twin gap $avg too spammy');
    }

    // Soft herd cap held.
    expect(c.state.herdCount, lessThanOrEqualTo(BalanceV0.maxHerdSize));
    expect(c.state.grass, greaterThanOrEqualTo(0));

    // Goal chain advanced past berry; sunny goal in progress or done.
    expect(c.state.sessionGoalIndex, greaterThanOrEqualTo(1));
    expect(
      c.state.sunnyGladeAnnounced >= 1 &&
          (c.sessionGoalProgress > 0.3 ||
              c.state.sessionGoalIndex >= 2 ||
              c.state.sunnyGladeAnnounced >= 2),
      isTrue,
      reason: '12 min should push toward Солнечный прогал '
          '(goalIdx=${c.state.sessionGoalIndex} glade=${c.state.sunnyGladeAnnounced} '
          'herd=${c.state.herdCount} progress=${c.sessionGoalProgress})',
    );

    c.dispose();
  });
}
