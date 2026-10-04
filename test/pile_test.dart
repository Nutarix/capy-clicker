import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capy_pile.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/models/multipliers/capy_role.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/test_game.dart';

/// Spec 006: sitting down in a pile, the fifth one, standing up, places,
/// the pair «хотят посидеть рядом», the bath, the rocket, the save.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<GameController> load(
    List<Capybara> herd, {
    Map<String, Object?> extra = const {},
  }) async {
    SharedPreferences.setMockInitialValues(herdSave(herd, extra: extra));
    final c = testController();
    await c.init();
    return c;
  }

  Capybara get(GameController c, String id) =>
      c.state.herd.firstWhere((e) => e.id == id);

  group('С1. First pile', () {
    test('two babies sit in one pile, one place, flash', () async {
      final c = await load([
        testCapy('c1', 1, x: 0.3),
        testCapy('c2', 1, x: 0.6),
      ]);
      expect(c.placesUsed, 2);
      expect(c.joinPile('c1', 'c2'), isTrue);
      final a = get(c, 'c1');
      final b = get(c, 'c2');
      expect(a.pileId, isNotNull);
      expect(a.pileId, b.pileId);
      expect(a.position, b.position, reason: 'they sit at the target');
      expect(c.state.herdCount, 2, reason: 'nobody disappears');
      expect(c.placesUsed, 1);
      expect(c.pileFlashId, 'c1');
      expect(c.pileMembers(a.pileId!).map((e) => e.id), ['c1', 'c2']);
      c.dispose();
    });

    test('any levels sit together; a third joins the pile', () async {
      final c = await load([
        testCapy('c1', 3),
        testCapy('c2', 1, x: 0.3),
        testCapy('c3', 2, x: 0.7),
      ]);
      expect(c.joinPile('c2', 'c1'), isTrue);
      expect(c.joinPile('c3', 'c2'), isTrue);
      final pile = get(c, 'c1').pileId!;
      expect(c.pileMembers(pile), hasLength(3));
      expect(c.placesUsed, 1);
      c.dispose();
    });

    test('nothing to do: self, same pile, missing', () async {
      final c = await load([testCapy('c1', 1), testCapy('c2', 1, x: 0.3)]);
      expect(c.joinPile('c1', 'c1'), isFalse);
      expect(c.joinPile('c1', 'nope'), isFalse);
      expect(c.joinPile('c1', 'c2'), isTrue);
      final before = c.state;
      expect(c.joinPile('c2', 'c1'), isFalse);
      expect(c.state.herd, before.herd);
      c.dispose();
    });
  });

  group('С4. The fifth', () {
    test('a full pile says no; the capy stands beside it', () async {
      final c = await load([
        for (var i = 1; i <= 4; i++) testCapy('c$i', 1, pile: 'p1'),
        testCapy('c5', 2, x: 0.25, y: 0.6),
      ]);
      expect(c.placesUsed, 2);
      final grass = c.state.grass;
      expect(c.joinPile('c5', 'c2'), isFalse);
      final five = get(c, 'c5');
      expect(five.pileId, isNull);
      expect(c.pileMembers('p1'), hasLength(BalanceV0.pileMaxSize));
      final pileAt = get(c, 'c1').position;
      final d = (five.position - pileAt).distance;
      expect(d, greaterThan(0.1), reason: 'beside, not on top');
      expect(d, lessThan(0.5), reason: 'nearby');
      expect(
        WorldZones.isInMeadow(five.position, herdCount: 0),
        isTrue,
      );
      expect(c.state.grass, grass);
      expect(c.pileFlashId, isNull, reason: 'no flash for a refusal');
      c.dispose();
    });

    test('from another pile: stands up and beside', () async {
      final c = await load([
        for (var i = 1; i <= 4; i++) testCapy('c$i', 1, pile: 'p1'),
        testCapy('c5', 1, x: 0.3, pile: 'p2'),
        testCapy('c6', 1, x: 0.3, pile: 'p2'),
      ]);
      expect(c.joinPile('c5', 'c1'), isFalse);
      expect(get(c, 'c5').pileId, isNull);
      expect(get(c, 'c6').pileId, isNull, reason: 'a pile of one dissolves');
      c.dispose();
    });
  });

  group('С5. Standing up', () {
    test('drag to the grass: out of the pile, growth kept', () async {
      final c = await load([
        testCapy('c1', 3, pile: 'p1'),
        testCapy('c2', 1, pile: 'p1', growth: 0.6),
        testCapy('c3', 1, pile: 'p1'),
      ]);
      c.updatePosition('c2', const Offset(0.2, 0.8));
      final two = get(c, 'c2');
      expect(two.pileId, isNull);
      expect(two.growth, 0.6);
      expect(two.position, const Offset(0.2, 0.8));
      expect(c.pileMembers('p1'), hasLength(2));
      expect(c.placesUsed, 2);
      c.updatePosition('c3', const Offset(0.7, 0.8));
      expect(get(c, 'c1').pileId, isNull, reason: 'one left: no pile');
      expect(c.placesUsed, 3);
      c.dispose();
    });

    test('moving to another pile leaves the old one', () async {
      final c = await load([
        testCapy('c1', 1, pile: 'p1'),
        testCapy('c2', 1, pile: 'p1'),
        testCapy('c3', 2, x: 0.3),
      ]);
      expect(c.joinPile('c2', 'c3'), isTrue);
      expect(get(c, 'c1').pileId, isNull);
      expect(get(c, 'c2').pileId, get(c, 'c3').pileId);
      c.dispose();
    });
  });

  group('С6. Places', () {
    test('every place taken: no baby, the bar waits full', () async {
      final c = await load([
        for (var i = 0; i < 12; i++)
          testCapy('c$i', 1, x: 0.15 + 0.06 * i),
      ]);
      expect(c.placesUsed, c.effectiveMaxHerdSize);
      c.addProgress(1.5, fromTap: false);
      expect(c.state.herdCount, 12);
      expect(c.state.herdProgress, BalanceV0.spawnThreshold);
      expect(c.canCallCapy, isFalse);
      expect(c.callCapyBlockedReason, isNotNull);

      // Two sit together: a place frees, the full bar brings a baby.
      expect(c.joinPile('c0', 'c1'), isTrue);
      c.addProgress(0.01, fromTap: false);
      expect(c.state.herdCount, 13);
      expect(c.placesUsed, 12);
      c.dispose();
    });

    test('piles let more capys live on twelve places', () async {
      final c = await load([
        for (var p = 0; p < 12; p++)
          for (var k = 0; k < 3; k++) testCapy('c${p}_$k', 1, pile: 'p$p'),
      ]);
      expect(c.state.herdCount, 36);
      expect(c.placesUsed, 12);
      expect(c.canCallCapy, isFalse);
      c.dispose();
    });

    test('the guard gives one more place', () async {
      final c = await load([
        for (var i = 0; i < 11; i++) testCapy('c$i', 1, x: 0.15 + 0.06 * i),
        testCapy('g', 1, role: CapyRole.storozh),
      ]);
      expect(c.effectiveMaxHerdSize, BalanceV0.maxHerdSize + 1);
      c.addProgress(1.0, fromTap: false);
      expect(c.placesUsed, 13);
      c.dispose();
    });

    test('call a capy needs a free place, not a free body', () async {
      final c = await load([
        for (var p = 0; p < 11; p++)
          for (var k = 0; k < 2; k++) testCapy('c${p}_$k', 1, pile: 'p$p'),
      ], extra: {'grass': 40});
      expect(c.state.herdCount, 22);
      expect(c.canCallCapy, isTrue);
      expect(c.spendCallCapy(), isTrue);
      expect(c.placesUsed, 12);
      expect(c.spendCallCapy(), isFalse);
      c.dispose();
    });
  });

  group('С7. Хотят посидеть рядом', () {
    test('the pair in one pile pays the grass bonus', () async {
      final c = await load([
        testCapy('c1', 1, x: 0.3),
        testCapy('c2', 1, x: 0.6),
        testCapy('c3', 1, x: 0.8),
      ]);
      c.debugMarkTwins('c1', 'c2');
      final grass = c.state.grass;
      expect(c.joinPile('c1', 'c2'), isTrue);
      expect(c.state.grass, grass + BalanceV0.twinMergeBonusGrass);
      expect(c.state.twinIdA, isNull);
      c.dispose();
    });

    test('also when one already sits in a pile', () async {
      final c = await load([
        testCapy('c1', 2, pile: 'p1'),
        testCapy('c2', 1, pile: 'p1'),
        testCapy('c3', 1, x: 0.8),
      ]);
      c.debugMarkTwins('c2', 'c3');
      final grass = c.state.grass;
      expect(c.joinPile('c3', 'c1'), isTrue);
      expect(c.state.grass, grass + BalanceV0.twinMergeBonusGrass);
      c.dispose();
    });

    test('another pair: no bonus; marks never pick two of one pile', () async {
      final c = await load([
        testCapy('c1', 1, pile: 'p1'),
        testCapy('c2', 1, pile: 'p1'),
        testCapy('c3', 1, x: 0.8),
      ]);
      final grass = c.state.grass;
      c.debugMarkTwins('c1', 'c2');
      expect(c.state.twinIdA, isNull, reason: 'already together');
      for (var i = 0; i < 400; i++) {
        c.debugAdvance(1);
        final a = c.state.twinIdA;
        final b = c.state.twinIdB;
        if (a == null || b == null) continue;
        expect({a, b}, isNot({'c1', 'c2'}));
      }
      expect(c.state.grass, greaterThanOrEqualTo(grass));
      c.dispose();
    });
  });

  group('С8. Bath as a pile', () {
    test('dropped on a wallowing capy: both bathe, the boost is the same',
        () async {
      final c = await load([
        testCapy('c1', 1, x: 0.3),
        testCapy('c2', 1, x: 0.7),
      ]);
      c.debugPlaceMud(const Offset(0.48, 0.84), seconds: 30);
      expect(c.tryMudWallow('c1'), isTrue);
      final rate = c.autoRatePerSecond;
      final left = c.mudBoostRemainingSeconds;
      expect(c.joinPile('c2', 'c1'), isTrue);
      expect(c.wallowingIds, {'c1', 'c2'});
      expect(get(c, 'c2').pileId, get(c, 'c1').pileId);
      expect(get(c, 'c2').position, get(c, 'c1').position);
      expect(c.autoRatePerSecond, rate, reason: 'not stacked');
      expect(c.mudBoostRemainingSeconds, left, reason: 'not restarted');
      c.dispose();
    });
  });

  group('Rocket', () {
    test('the traveler leaves its pile; one left → no pile', () async {
      final c = await load(
        [
          testCapy('c1', 1, pile: 'p1'),
          testCapy('c2', 4, pile: 'p1'),
          testCapy('c3', 4, x: 0.8),
        ],
        extra: {
          'sunnyGladeAnnounced': 3,
          'mistyBiomeUnlocked': true,
          'visitedMist': true,
          'uyut': 1,
        },
      );
      expect(c.nextTraveler?.id, 'c1');
      expect(c.launchToNewLand(), isTrue);
      final arrived = c.state.herd.firstWhere((e) => e.id == 'c1');
      expect(arrived.pileId, isNull);
      final old = c.state.otherLands.single;
      final home = old.meadows[WorldZones.starterMeadowId]!.herd;
      expect(home.firstWhere((e) => e.id == 'c2').pileId, isNull);
      c.dispose();
    });
  });

  group('Save', () {
    test('piles and growth survive save and load', () async {
      final persistence = GamePersistence();
      SharedPreferences.setMockInitialValues(
        herdSave([
          testCapy('c1', 2),
          testCapy('c2', 1, x: 0.3, growth: 0.2),
          testCapy('c3', 1, x: 0.7),
        ]),
      );
      var c = testController(persistence: persistence);
      await c.init();
      expect(c.joinPile('c2', 'c1'), isTrue);
      expect(c.joinPile('c3', 'c1'), isTrue);
      final before = c.state.herd;
      await c.flushSave();
      c.dispose();
      c = testController(persistence: persistence);
      await c.init();
      expect(c.state.herd, before);
      expect(CapyPiles.placesOf(c.state.herd), 1);
      c.dispose();
    });

    test('a damaged pile of one stands up quietly', () async {
      final c = await load([
        testCapy('c1', 1, pile: 'p1'),
        testCapy('c2', 1, x: 0.3),
      ]);
      expect(get(c, 'c1').pileId, isNull);
      c.dispose();
    });

    test('state JSON round trip keeps pile fields on every meadow', () {
      final s = GameState.initial().copyWith(
        herd: [testCapy('c1', 1, pile: 'p1'), testCapy('c2', 2, pile: 'p1')],
      );
      final back = GameState.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back.herd, s.herd);
    });
  });
}
