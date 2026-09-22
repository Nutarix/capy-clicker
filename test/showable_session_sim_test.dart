import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/multipliers/capy_role.dart';
import 'package:capy_clicker/features/game/models/multipliers/cozy_place.dart';
import 'package:capy_clicker/features/game/models/multipliers/family_food.dart';
import 'package:capy_clicker/features/game/models/multipliers/home_decor.dart';
import 'package:capy_clicker/features/game/models/multipliers/uyut_research.dart';
import 'package:capy_clicker/features/game/models/session_goals.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

/// Showable cozy session (~12–15′) — balance gates for Game Lead demo.
///
/// Casual priority after berry: first permanent (Дом или Наука), then food/call.
/// Goal-oriented mist horizon checked in a separate probe within the same file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('showable cozy 14′: berry → permanent → twin → no grass despair', () async {
    final rng = Random(42);
    var clock = DateTime(2026, 9, 22, 16, 0, 0);
    final c = GameController(
      persistence: GamePersistence(),
      random: rng,
      now: () => clock,
    );
    await c.init();

    var simSeconds = 0.0;
    var flowerCd = 0.0;
    var mudCd = 0.0;
    var placeCd = 0.0;
    var spendCd = 0.0;
    var uyutCd = 0.0;
    var berryCheck = 10.0;
    var calls = 0, boosts = 0, twinMerges = 0, merges = 0;
    var feeds = 0, decorBuys = 0, researchUnlocks = 0;
    double? firstGladeAt;
    double? firstPermanentAt;
    double? twinBonusAt;
    final twinMarks = <double>[];
    String? lastTwinKey;

    var grassSamples = 0;
    var grassSum = 0;
    var grassZeroSamples = 0;
    var midGrassSum = 0;
    var midGrassSamples = 0;

    void step(double dt) {
      clock = clock.add(Duration(milliseconds: (dt * 1000).round()));
      simSeconds += dt;
      c.debugAdvance(dt);
      flowerCd -= dt;
      mudCd -= dt;
      placeCd -= dt;
      spendCd -= dt;
      uyutCd -= dt;
      berryCheck -= dt;
    }

    // ~14 min cozy showable session.
    while (simSeconds < 840) {
      step(0.25);

      if (c.goalCompleteToast != null) c.acknowledgeGoalComplete();
      if (c.gladeUnlockToast != null) c.acknowledgeGladeUnlock();

      final tA = c.state.twinIdA;
      final tB = c.state.twinIdB;
      if (tA != null && tB != null) {
        final key = ([tA, tB]..sort()).join(':');
        if (key != lastTwinKey) {
          twinMarks.add(simSeconds);
          lastTwinKey = key;
        }
      } else {
        lastTwinKey = null;
      }

      if (firstGladeAt == null && c.state.sunnyGladeAnnounced >= 1) {
        firstGladeAt = simSeconds;
      }
      if (firstPermanentAt == null &&
          (c.state.ownedDecor.isNotEmpty || c.state.researched.isNotEmpty)) {
        firstPermanentAt = simSeconds;
      }

      // Sample grass every 5s.
      if ((simSeconds * 4).round() % 20 == 0) {
        grassSamples++;
        grassSum += c.state.grass;
        if (c.state.grass == 0) grassZeroSamples++;
        if (simSeconds >= 300 && simSeconds <= 720) {
          midGrassSamples++;
          midGrassSum += c.state.grass;
        }
      }

      // Cozy flower cadence ~2.8–4.0s.
      if (flowerCd <= 0) {
        c.onFlowerTap();
        flowerCd = 2.8 + rng.nextDouble() * 1.2;
      }

      if (berryCheck <= 0) {
        berryCheck = 3.5;
        if (!c.isBerryVisible && simSeconds > 8 && rng.nextDouble() < 0.20) {
          c.debugShowBerry();
        }
        if (c.isBerryVisible) c.onBerryTap();
      }

      if (mudCd <= 0 && c.state.herd.isNotEmpty) {
        c.tryMudWallow(c.state.herd.first.id);
        mudCd = 24 + rng.nextDouble() * 12;
      }

      if (placeCd <= 0) {
        var acted = false;
        for (final k in CozyPlaceKind.values) {
          if (c.tryActivatePlace(k)) {
            placeCd = 8;
            acted = true;
            break;
          }
        }
        if (!acted) placeCd = 4;
      }

      // Spend fork: call prefers growth; boost sometimes — keep both used.
      if (spendCd <= 0 && (c.canCallCapy || c.canGrassBoost)) {
        final preferCall = c.state.herdCount < 9 && c.canCallCapy;
        var spent = false;
        if (preferCall && rng.nextDouble() < 0.55) {
          spent = c.spendCallCapy();
          if (spent) calls++;
        } else if (c.canGrassBoost && rng.nextDouble() < 0.5) {
          spent = c.spendGrassBoost();
          if (spent) boosts++;
        } else if (c.canCallCapy) {
          spent = c.spendCallCapy();
          if (spent) calls++;
        } else if (c.canGrassBoost) {
          spent = c.spendGrassBoost();
          if (spent) boosts++;
        }
        if (spent) spendCd = 7.0 + rng.nextDouble() * 5.0;
      }

      // Casual Уют priority after berry: permanent first, then light food.
      if (uyutCd <= 0 && c.state.sunnyGladeAnnounced >= 1) {
        var did = false;
        if (c.state.ownedDecor.isEmpty && c.state.researched.isEmpty) {
          // Prefer cheapest permanent available.
          if (c.buyDecor(HomeDecor.fonarik)) {
            decorBuys++;
            did = true;
          } else if (c.unlockResearch(UyutResearch.moreFlowers.id)) {
            researchUnlocks++;
            did = true;
          }
        } else {
          if (c.state.grass >= 14 && c.state.ownedDecor.isEmpty) {
            if (c.buyDecor(HomeDecor.fonarik)) {
              decorBuys++;
              did = true;
            }
          }
          if (!did && c.state.grass >= 14 && c.state.researched.isEmpty) {
            if (c.unlockResearch(UyutResearch.moreFlowers.id)) {
              researchUnlocks++;
              did = true;
            }
          }
          if (!did && c.state.grass >= 18) {
            for (final d in HomeDecor.values) {
              if (!c.state.ownedDecor.contains(d.id) && c.buyDecor(d)) {
                decorBuys++;
                did = true;
                break;
              }
            }
          }
          if (!did && c.state.grass >= 18) {
            for (final n in UyutResearch.all) {
              if (c.unlockResearch(n.id)) {
                researchUnlocks++;
                did = true;
                break;
              }
            }
          }
        }

        if (c.state.grass >= BalanceV0.callCapyGrassCost + 4) {
          if (c.state.food.countOf(FamilyFood.travka) == 0) {
            c.buyFood(FamilyFood.travka);
          }
          c.selectFood(FamilyFood.travka);
          if (c.feedFamily()) feeds++;
        }
        if (c.state.herd.isNotEmpty) {
          c.assignRole(c.state.herd.first.id, CapyRole.nanya);
        }
        uyutCd = 9.0 + rng.nextDouble() * 6.0;
      }

      // Occasional merges; favor twins; keep early merges rare.
      final mergeChance = c.state.herdCount < 5 ? 0.03 : 0.065;
      if (c.state.herdCount >= 2 && rng.nextDouble() < mergeChance) {
        String? a;
        String? b;
        if (c.state.twinIdA != null && c.state.twinIdB != null) {
          a = c.state.twinIdA;
          b = c.state.twinIdB;
        } else {
          final byLevel = <int, List<String>>{};
          for (final cap in c.state.herd) {
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
            merges++;
            if (wasTwin &&
                c.state.grass >=
                    beforeGrass + BalanceV0.twinMergeBonusGrass) {
              twinMerges++;
              twinBonusAt ??= simSeconds;
            }
          }
        }
      }
    }

    final grassAvg =
        grassSamples == 0 ? 0.0 : grassSum / grassSamples;
    final midAvg =
        midGrassSamples == 0 ? 0.0 : midGrassSum / midGrassSamples;
    final zeroFrac =
        grassSamples == 0 ? 1.0 : grassZeroSamples / grassSamples;

    // ignore: avoid_print
    print(
      'SHOWABLE cozy14 firstGlade=${firstGladeAt?.toStringAsFixed(0)}s '
      'permanent@${firstPermanentAt?.toStringAsFixed(0)}s '
      'calls=$calls boosts=$boosts twinMerges=$twinMerges merges=$merges '
      'feeds=$feeds decor=$decorBuys res=$researchUnlocks '
      'herd=${c.state.herdCount} grass=${c.state.grass} '
      'grassAvg=${grassAvg.toStringAsFixed(1)} midAvg=${midAvg.toStringAsFixed(1)} '
      'zeroFrac=${zeroFrac.toStringAsFixed(2)} '
      'goals=${c.state.sessionGoalIndex} glade=${c.state.sunnyGladeAnnounced} '
      'twinsMarked=${twinMarks.length} '
      'goal=${SessionGoals.at(c.state.sessionGoalIndex)?.id}',
    );

    expect(firstGladeAt, isNotNull, reason: 'Berry glade should unlock');
    expect(
      firstGladeAt!,
      inInclusiveRange(45, 360),
      reason: 'First berry glade ~1–6 min cozy (family power ≥5); got ${firstGladeAt}s',
    );

    expect(calls, greaterThan(0));
    expect(boosts, greaterThan(0), reason: 'Call vs boost fork must fire');
    expect(twinMerges, greaterThan(0));
    expect(twinBonusAt, isNotNull);
    expect(twinMarks.length, greaterThanOrEqualTo(2));
    expect(twinMarks.length, lessThan(22), reason: 'twin not spammy');

    expect(
      decorBuys + researchUnlocks,
      greaterThanOrEqualTo(1),
      reason: 'After berry: ≥1 decor OR research in showable 14′',
    );
    expect(firstPermanentAt, isNotNull);
    expect(
      firstPermanentAt!,
      lessThan(720),
      reason: 'First permanent should land within ~12′',
    );

    // Soft anti-despair: mid-session average grass not stuck near 0.
    expect(
      midAvg,
      greaterThanOrEqualTo(3.0),
      reason: 'Mid-session grass avg $midAvg too starved (P2.4)',
    );
    expect(
      zeroFrac,
      lessThan(0.35),
      reason: 'Grass=0 too often ($zeroFrac) — mid-session despair',
    );

    expect(c.state.herdCount, lessThanOrEqualTo(c.effectiveMaxHerdSize));
    expect(c.state.grass, greaterThanOrEqualTo(0));
    expect(c.state.sessionGoalIndex, greaterThanOrEqualTo(1));

    c.dispose();
  });

  test('showable goal-oriented ~18′: mist + uyut reachable', () async {
    final rng = Random(99);
    var clock = DateTime(2026, 9, 22, 17, 0, 0);
    final c = GameController(
      persistence: GamePersistence(),
      random: rng,
      now: () => clock,
    );
    await c.init();

    var t = 0.0;
    var flowerCd = 0.0, mudCd = 0.0, placeCd = 0.0, spendCd = 0.0;
    var uyutCd = 0.0, berryCheck = 8.0;
    final ms = <String, double>{};
    void note(String k) => ms.putIfAbsent(k, () => t);

    while (t < 1200) {
      clock = clock.add(const Duration(milliseconds: 250));
      t += 0.25;
      c.debugAdvance(0.25);
      flowerCd -= 0.25;
      mudCd -= 0.25;
      placeCd -= 0.25;
      spendCd -= 0.25;
      uyutCd -= 0.25;
      berryCheck -= 0.25;

      if (c.goalCompleteToast != null) c.acknowledgeGoalComplete();
      if (c.gladeUnlockToast != null) c.acknowledgeGladeUnlock();

      if (c.state.sunnyGladeAnnounced >= 1) note('berry');
      if (c.state.sunnyGladeAnnounced >= 2) note('sunny');
      if (c.state.sunnyGladeAnnounced >= 3) note('great');
      if (c.state.maxCapyLevel >= 4) note('lv4');
      if (c.state.mistyBiomeUnlocked) note('mist');
      if (c.state.activeMeadowId == WorldZones.mistEdgeMeadowId) note('visit');
      if (c.state.ownedDecor.isNotEmpty) note('decor');
      if (c.state.researched.isNotEmpty) note('research');

      if (flowerCd <= 0) {
        c.onFlowerTap();
        flowerCd = 2.0 + rng.nextDouble() * 0.8;
      }
      if (berryCheck <= 0) {
        berryCheck = 3.0;
        if (!c.isBerryVisible && rng.nextDouble() < 0.28) c.debugShowBerry();
        if (c.isBerryVisible) c.onBerryTap();
      }
      if (mudCd <= 0 && c.state.herd.isNotEmpty) {
        c.tryMudWallow(c.state.herd.first.id);
        mudCd = 18 + rng.nextDouble() * 8;
      }
      if (placeCd <= 0) {
        var acted = false;
        for (final k in CozyPlaceKind.values) {
          if (c.tryActivatePlace(k)) {
            placeCd = 8;
            acted = true;
            break;
          }
        }
        if (!acted) placeCd = 3;
      }
      if (spendCd <= 0) {
        var spent = false;
        if (c.state.herdCount < 11 && c.canCallCapy) {
          spent = c.spendCallCapy();
        } else if (c.canGrassBoost) {
          spent = c.spendGrassBoost();
        }
        if (spent) spendCd = 4 + rng.nextDouble() * 3;
      }
      if (uyutCd <= 0) {
        if (c.state.sunnyGladeAnnounced >= 1) {
          if (c.state.ownedDecor.isEmpty) {
            for (final d in HomeDecor.values) {
              if (c.buyDecor(d)) break;
            }
          }
          if (c.state.researched.isEmpty) {
            for (final n in UyutResearch.all) {
              if (c.unlockResearch(n.id)) break;
            }
          }
        }
        if (c.state.grass >= BalanceV0.callCapyGrassCost + 6) {
          if (c.state.food.countOf(FamilyFood.travka) == 0) {
            c.buyFood(FamilyFood.travka);
          }
          c.selectFood(FamilyFood.travka);
          c.feedFamily();
        }
        if (c.state.herd.isNotEmpty) {
          c.assignRole(c.state.herd.first.id, CapyRole.nanya);
        }
        if (c.state.grass >= 22) {
          for (final d in HomeDecor.values) {
            if (!c.state.ownedDecor.contains(d.id) && c.buyDecor(d)) break;
          }
          for (final n in UyutResearch.all) {
            if (c.unlockResearch(n.id)) break;
          }
        }
        uyutCd = 8 + rng.nextDouble() * 5;
      }

      final mergeP = c.state.herdCount >= 8
          ? 0.06
          : (c.state.maxCapyLevel < 4 && c.state.herdCount >= 5 ? 0.04 : 0.015);
      if (c.state.herdCount >= 2 && rng.nextDouble() < mergeP) {
        String? a;
        String? b;
        if (c.state.twinIdA != null) {
          a = c.state.twinIdA;
          b = c.state.twinIdB;
        } else {
          final by = <int, List<String>>{};
          for (final cap in c.state.herd) {
            by.putIfAbsent(cap.level, () => []).add(cap.id);
          }
          final pairs = by.values.where((x) => x.length >= 2).toList();
          if (pairs.isNotEmpty) {
            final p = pairs[rng.nextInt(pairs.length)];
            a = p[0];
            b = p[1];
          }
        }
        if (a != null && b != null) c.tryMerge(a, b);
      }

      if (c.state.mistyBiomeUnlocked &&
          c.state.activeMeadowId != WorldZones.mistEdgeMeadowId &&
          t > (ms['mist'] ?? 9999) + 2) {
        c.switchToMeadow(WorldZones.mistEdgeMeadowId);
      }
    }

    // ignore: avoid_print
    print(
      'SHOWABLE goal18 ms=$ms herd=${c.state.herdCount} grass=${c.state.grass} '
      'decor=${c.state.ownedDecor.length} res=${c.state.researched.length} '
      'uyut=${c.state.uyut}',
    );

    expect(ms.containsKey('berry'), isTrue);
    expect(ms.containsKey('decor') || ms.containsKey('research'), isTrue);
    expect(ms.containsKey('sunny'), isTrue, reason: 'sunny for show run');
    expect(ms['mist'], isNotNull, reason: 'mist within ~20′ goal-oriented');
    expect(ms['mist']!, lessThanOrEqualTo(1200));
    expect(c.state.uyut, greaterThanOrEqualTo(1));
    expect(ms.containsKey('visit'), isTrue);

    c.dispose();
  });
}
