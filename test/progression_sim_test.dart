import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/multipliers/cozy_place.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/fingerprint.dart';
import 'support/test_game.dart';

/// Headless cozy player over the first forest (spec 006, Т9, Т14): flowers,
/// berries, puddle, spending, and the pile — babies to an elder (nursery),
/// peers together, the pair «хотят посидеть рядом», the nanny on the top
/// pile. Targets (WBS 1.4): Ягодная in the first session (10–15 min), all
/// four glades in 1–2 hours.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cozy player: berry in the first session, the forest in 1–2 h',
      () async {
    final rng = Random(42);
    var clock = DateTime.utc(2026, 9, 22, 7);
    final c = GameController(
      persistence: GamePersistence(),
      random: rng,
      now: () => clock,
      autoTick: false,
    );
    await c.init();
    final fp = Fingerprint('sim_cozy_session')..mark('init', c);

    var t = 0.0;
    var flowerCd = 0.0;
    var mudCd = 0.0;
    var berryCheckIn = 12.0;
    var spendCd = 0.0;
    var pileCd = 6.0;
    var placeCd = 10.0;
    var nannyCd = 60.0;
    var calls = 0, boosts = 0, seats = 0, pairBonuses = 0;
    final ms = <String, double>{};
    void note(String k) => ms.putIfAbsent(k, () => t);
    final pairMarks = <double>[];
    String? lastPair;

    // Two and a half hours of play, in quarter seconds.
    while (t < 9000) {
      clock = clock.add(const Duration(milliseconds: 250));
      t += 0.25;
      c.debugAdvance(0.25);
      flowerCd -= 0.25;
      mudCd -= 0.25;
      berryCheckIn -= 0.25;
      spendCd -= 0.25;
      pileCd -= 0.25;
      placeCd -= 0.25;
      nannyCd -= 0.25;
      if ((t * 4).round() % 2400 == 0) fp.mark('t=$t', c);

      if (c.goalCompleteToast != null) c.acknowledgeGoalComplete();
      if (c.gladeUnlockToast != null) c.acknowledgeGladeUnlock();

      final s = c.state;
      if (s.sunnyGladeAnnounced >= 1) note('berry');
      if (s.sunnyGladeAnnounced >= 2) note('sunny');
      if (s.sunnyGladeAnnounced >= 3) note('great');
      if (s.maxCapyLevel >= BalanceV0.goalCapyLevel) note('goalLevel');
      if (s.mistyBiomeUnlocked) note('mist');

      final tA = s.twinIdA;
      final tB = s.twinIdB;
      if (tA != null && tB != null) {
        final key = ([tA, tB]..sort()).join(':');
        if (key != lastPair) {
          pairMarks.add(t);
          lastPair = key;
        }
      } else {
        lastPair = null;
      }

      // Flower taps every ~3.4–4.6 s (cozy, not speedrun).
      if (flowerCd <= 0) {
        c.onFlowerTap();
        flowerCd = 3.4 + rng.nextDouble() * 1.2;
      }

      if (berryCheckIn <= 0) {
        berryCheckIn = 4.0;
        if (!c.isBerryVisible && t > 10 && rng.nextDouble() < 0.18) {
          c.debugShowBerry();
        }
        if (c.isBerryVisible) c.onBerryTap();
      }

      // A capy on its own goes for the puddle every ~30 s.
      if (mudCd <= 0) {
        final single = s.herd.where((x) => x.pileId == null);
        if (single.isNotEmpty) c.tryMudWallow(single.first.id);
        mudCd = 28 + rng.nextDouble() * 12;
      }

      if (placeCd <= 0) {
        for (final k in CozyPlaceKind.values) {
          if (c.tryActivatePlace(k)) break;
        }
        placeCd = 10 + rng.nextDouble() * 6;
      }

      // Spend fork with a human cooldown: call a capy or a short boost.
      if (spendCd <= 0 && (c.canCallCapy || c.canGrassBoost)) {
        var spent = false;
        if (c.canCallCapy && rng.nextDouble() < 0.5) {
          spent = c.spendCallCapy();
          if (spent) calls++;
        } else if (c.canGrassBoost && rng.nextDouble() < 0.55) {
          spent = c.spendGrassBoost();
          if (spent) boosts++;
        }
        if (spent) spendCd = 8.0 + rng.nextDouble() * 6.0;
      }

      // The pile: a look at the meadow every 5–10 s.
      if (pileCd <= 0) {
        pileCd = 5 + rng.nextDouble() * 5;
        final grass = c.state.grass;
        if (sitThePair(c)) {
          seats++;
          if (c.state.grass >= grass + BalanceV0.pairBonusGrass) {
            pairBonuses++;
            note('pairBonus');
          }
        } else if (c.placesUsed >= c.effectiveMaxHerdSize - 1 ||
            rng.nextDouble() < 0.4) {
          if (pileStep(c)) seats++;
        }
      }

      if (nannyCd <= 0) {
        nannyCd = 90;
        nannyToTopPile(c);
      }
    }

    fp
      ..mark(
        'end',
        c,
        extra: {
          'milestones': ms,
          'calls': calls,
          'boosts': boosts,
          'seats': seats,
          'pairBonuses': pairBonuses,
          'pairMarks': pairMarks.length,
        },
      )
      ..verify();

    String min(String k) => ms[k] == null ? '-' : (ms[k]! / 60).toStringAsFixed(1);
    // ignore: avoid_print
    print(
      'SIM cozy berry=${min('berry')}m sunny=${min('sunny')}m '
      'great=${min('great')}m lv${BalanceV0.goalCapyLevel}=${min('goalLevel')}m '
      'mist=${min('mist')}m calls=$calls boosts=$boosts seats=$seats '
      'pairBonuses=$pairBonuses pairMarks=${pairMarks.length} '
      'herd=${c.state.herdCount} places=${c.placesUsed} '
      'power=${c.state.familyPower}',
    );

    // --- Т9 targets (WBS 1.4) ---
    expect(ms['berry'], isNotNull, reason: 'Ягодная поляна opens');
    expect(
      ms['berry']!,
      inInclusiveRange(8 * 60, 15 * 60),
      reason: 'Ягодная in the first session (10–15 min)',
    );
    expect(ms['sunny'], isNotNull);
    expect(ms['sunny']!, inInclusiveRange(15 * 60, 60 * 60));
    expect(ms['great'], isNotNull, reason: 'all four glades');
    expect(
      ms['great']!,
      inInclusiveRange(60 * 60, 120 * 60),
      reason: 'the first forest in 1–2 hours',
    );
    expect(ms['mist'], isNotNull, reason: 'Туманный бор after the forest');
    expect(ms['mist']!, greaterThanOrEqualTo(ms['great']!));
    expect(ms['mist']!, lessThanOrEqualTo(150 * 60));

    // The fork and the pile are used.
    expect(calls, greaterThan(0));
    expect(boosts, greaterThan(0));
    expect(seats, greaterThan(20));
    expect(pairBonuses, greaterThan(0), reason: 'the pair bonus fires');
    // The pair is a window, not a permanent glow (~36 s rerolls).
    expect(pairMarks.length, greaterThanOrEqualTo(10));
    expect(pairMarks.length, lessThan(9000 ~/ 36));

    // Places held; more capys than places.
    expect(c.placesUsed, lessThanOrEqualTo(c.effectiveMaxHerdSize));
    expect(c.state.herdCount, greaterThan(BalanceV0.maxHerdSize));
    expect(c.state.grass, greaterThanOrEqualTo(0));
    c.dispose();
  });
}
