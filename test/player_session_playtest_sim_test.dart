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

import 'support/fingerprint.dart';
import 'support/test_game.dart';

/// Headless player-perspective session for Game Lead playtest report, over
/// the first forest with the pile (spec 006, Т9, Т14).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'player session: flowers→spend→food→places→roles→research→piles→'
    'meadows→mist',
    () async {
      final rng = Random(7);
      var clock = DateTime.utc(2026, 9, 22, 12);
      final c = GameController(
        persistence: GamePersistence(),
        random: rng,
        now: () => clock,
        autoTick: false,
      );
      await c.init();
      final fp = Fingerprint('sim_player_session')..mark('init', c);

      var simSeconds = 0.0;
      var flowerCd = 0.0;
      var mudCd = 0.0;
      var placeCd = 0.0;
      var spendCd = 0.0;
      var uyutCd = 0.0;
      var berryCheck = 10.0;
      var feeds = 0,
          placeActs = 0,
          roles = 0,
          decorBuys = 0,
          researchUnlocks = 0;
      var calls = 0, boosts = 0, merges = 0;
      var pileCd = 6.0, nannyCd = 60.0;
      double? berryVisitAt;
      final milestones = <String, double>{};
      final goalHits = <String>[];
      final snapshots = <String>[];

      void note(String k) {
        milestones.putIfAbsent(k, () => simSeconds);
      }

      void snap(String label) {
        snapshots.add(
          '${simSeconds.round()}s $label goal=${c.state.sessionGoalIndex}:'
          '${SessionGoals.at(c.state.sessionGoalIndex)?.id} '
          'glade=${c.state.sunnyGladeAnnounced} herd=${c.state.herdCount} '
          'lv=${c.state.maxCapyLevel} grass=${c.state.grass} '
          'food=${c.state.food.total} decor=${c.state.ownedDecor.length} '
          'res=${c.state.researched.length} uyut=${c.state.uyut} '
          'mist=${c.state.mistyBiomeUnlocked} active=${c.state.activeMeadowId} '
          'auto=${c.autoRatePerSecond.toStringAsFixed(4)}',
        );
      }

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
        pileCd -= dt;
        nannyCd -= dt;
      }

      snap('start');

      // Two and a half hours of active play probing the full horizon.
      while (simSeconds < 9000) {
        step(0.25);
        if ((simSeconds * 4).round() % 2400 == 0) fp.mark('t=$simSeconds', c);

        if (c.goalCompleteToast != null) {
          final g = SessionGoals.at(c.state.sessionGoalIndex);
          goalHits.add('${simSeconds.round()}s:${g?.id}');
          c.acknowledgeGoalComplete();
        }
        if (c.gladeUnlockToast != null) c.acknowledgeGladeUnlock();

        if (c.state.sunnyGladeAnnounced >= 1) note('berry_glade');
        if (c.state.sunnyGladeAnnounced >= 2) note('sunny');
        if (c.state.sunnyGladeAnnounced >= 3) note('great');
        if (c.state.maxCapyLevel >= BalanceV0.goalCapyLevel) note('goalLevel');
        if (c.state.mistyBiomeUnlocked) note('mist_unlock');
        if (c.state.activeMeadowId == WorldZones.mistEdgeMeadowId) {
          note('mist_visit');
        }

        if ((simSeconds - 180).abs() < 0.2 ||
            (simSeconds - 600).abs() < 0.2 ||
            (simSeconds - 1800).abs() < 0.2 ||
            (simSeconds - 3600).abs() < 0.2 ||
            (simSeconds - 5400).abs() < 0.2 ||
            (simSeconds - 7200).abs() < 0.2) {
          snap('t=${simSeconds.round()}');
        }

        if (flowerCd <= 0) {
          c.onFlowerTap();
          flowerCd = 2.2 + rng.nextDouble() * 1.0;
        }

        if (berryCheck <= 0) {
          berryCheck = 3.5;
          if (!c.isBerryVisible && rng.nextDouble() < 0.22) c.debugShowBerry();
          if (c.isBerryVisible) c.onBerryTap();
        }

        if (mudCd <= 0) {
          final single = c.state.herd.where((x) => x.pileId == null);
          if (single.isNotEmpty) c.tryMudWallow(single.first.id);
          mudCd = 20 + rng.nextDouble() * 10;
        }

        if (placeCd <= 0) {
          var acted = false;
          for (final k in CozyPlaceKind.values) {
            if (c.tryActivatePlace(k)) {
              placeActs++;
              placeCd = 6;
              acted = true;
              break;
            }
          }
          if (!acted) placeCd = 4;
        }

        if (spendCd <= 0) {
          var spent = false;
          if (c.canCallCapy && rng.nextDouble() < 0.55) {
            spent = c.spendCallCapy();
            if (spent) calls++;
          } else if (c.canGrassBoost && rng.nextDouble() < 0.5) {
            spent = c.spendGrassBoost();
            if (spent) boosts++;
          } else if (c.canCallCapy) {
            spent = c.spendCallCapy();
            if (spent) calls++;
          }
          if (spent) spendCd = 5 + rng.nextDouble() * 5;
        }

        if (uyutCd <= 0 && c.state.grass >= 4) {
          for (final f in FamilyFood.values) {
            if (c.state.food.countOf(f) == 0) c.buyFood(f);
          }
          c.selectFood(FamilyFood.travka);
          if (c.feedFamily()) feeds++;
          c.selectFood(FamilyFood.yagody);
          if (c.feedFamily()) feeds++;

          if (c.state.herd.isNotEmpty && roles == 0) {
            if (c.assignRole(c.state.herd.first.id, CapyRole.nanya)) roles++;
          }

          for (final d in HomeDecor.values) {
            if (!c.state.ownedDecor.contains(d.id) && c.buyDecor(d)) {
              decorBuys++;
              break;
            }
          }

          for (final n in UyutResearch.all) {
            if (c.unlockResearch(n.id)) {
              researchUnlocks++;
              break;
            }
          }
          uyutCd = 10 + rng.nextDouble() * 6;
        }

        // The pile: a look every 5–9 s; the pair first; the nanny moves
        // to the top pile now and then.
        if (pileCd <= 0) {
          pileCd = 5 + rng.nextDouble() * 4;
          if (sitThePair(c) ||
              ((c.placesUsed >= c.effectiveMaxHerdSize - 1 ||
                      rng.nextDouble() < 0.5) &&
                  pileStep(c))) {
            merges++;
          }
        }
        if (nannyCd <= 0) {
          nannyCd = 120;
          if (nannyToTopPile(c)) roles++;
        }

        if (c.state.mistyBiomeUnlocked &&
            c.state.activeMeadowId != WorldZones.mistEdgeMeadowId &&
            simSeconds > (milestones['mist_unlock'] ?? 99999) + 2) {
          c.switchToMeadow(WorldZones.mistEdgeMeadowId);
        }

        // A short visit to Ягодная once it opens, then home again.
        if (c.state.sunnyGladeAnnounced >= 1 && berryVisitAt == null) {
          if (c.switchToMeadow('berry_glade')) {
            berryVisitAt = simSeconds;
            note('berry_visit');
          }
        }
        if (berryVisitAt != null &&
            c.state.activeMeadowId == 'berry_glade' &&
            simSeconds > berryVisitAt + 30) {
          c.switchToMeadow('warm_edge');
        }
      }

      snap('end');
      fp
        ..mark(
          'end',
          c,
          extra: {
            'milestones': milestones,
            'goalHits': goalHits,
            'snapshots': snapshots,
            'counts': [
              feeds,
              placeActs,
              roles,
              decorBuys,
              researchUnlocks,
              calls,
              boosts,
              merges,
            ],
          },
        )
        ..verify();

      // ignore: avoid_print
      print(
        'PLAYER_SIM milestones(min)='
        '${milestones.map((k, v) => MapEntry(k, (v / 60).toStringAsFixed(1)))}',
      );
      // ignore: avoid_print
      print('PLAYER_SIM goalHits=$goalHits');
      // ignore: avoid_print
      print(
        'PLAYER_SIM counts feeds=$feeds places=$placeActs roles=$roles '
        'decorBuys=$decorBuys research=$researchUnlocks '
        'calls=$calls boosts=$boosts merges=$merges',
      );
      for (final s in snapshots) {
        // ignore: avoid_print
        print('SNAP $s');
      }

      expect(c.state.grass, greaterThanOrEqualTo(0));
      expect(c.state.uyut, greaterThanOrEqualTo(0));
      expect(
        milestones['berry_glade'],
        isNotNull,
        reason: 'the first session unlocks berry',
      );
      expect(milestones['berry_glade']!, inInclusiveRange(6 * 60, 15 * 60));
      expect(milestones.containsKey('berry_visit'), isTrue);
      expect(milestones['great'], isNotNull, reason: 'all four glades');
      expect(milestones['great']!, inInclusiveRange(60 * 60, 120 * 60));
      expect(milestones['mist_visit'], isNotNull);
      expect(milestones['mist_unlock']!, lessThanOrEqualTo(150 * 60));
      expect(merges, greaterThan(20), reason: 'the pile is played');
      c.dispose();
    },
  );
}
