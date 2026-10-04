import 'dart:math';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capy_trait_wander.dart';
import 'package:capy_clicker/features/game/models/capy_wander.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';

/// Spec 004, Т8: four traits change only where a capy walks.
void main() {
  const meadow = Size(411, 600);
  // Great meadow: the widest grass plate.
  final herdCount = WorldZones.glades.last.minHerd;

  bool clear(Offset t, List<Offset> others, {Offset? mud}) =>
      CapyWander.onGrass(t, herdCount) &&
      !CapyWander.hitsProp(t, mudCenter: mud, meadowSize: meadow) &&
      !CapyWander.overlapsPeer(t, others, meadowSize: meadow);

  test('sweet tooth: a spot by the basket, not on it', () {
    final rng = Random(1);
    const from = Offset(0.3, 0.55);
    final others = [const Offset(0.5, 0.6)];
    var near = 0;
    for (var i = 0; i < 40; i++) {
      final t = CapyTraitWander.sweetToothTarget(
        from: from,
        random01: rng.nextDouble,
        herdCount: herdCount,
        others: others,
        meadowSize: meadow,
      );
      if (t == null) continue;
      expect(clear(t, others), isTrue);
      final d = (t - CapyWander.berryCenter).distance;
      expect(d, lessThan(0.26));
      near++;
    }
    expect(near, greaterThan(30));
  });

  test('splasher: the puddle edge, never inside the wallow circle', () {
    final rng = Random(2);
    const mud = Offset(0.45, 0.62);
    final others = <Offset>[];
    var found = 0;
    for (var i = 0; i < 40; i++) {
      final t = CapyTraitWander.splasherTarget(
        from: const Offset(0.25, 0.45),
        random01: rng.nextDouble,
        herdCount: herdCount,
        mudCenter: mud,
        others: others,
        meadowSize: meadow,
      );
      if (t == null) continue;
      found++;
      final d = (t - mud).distance;
      expect(d, greaterThan(BalanceV0.mudHitRadius), reason: 'no wallow');
      expect(d, lessThan(BalanceV0.mudHitRadius + 0.14), reason: 'edge');
      expect(clear(t, others, mud: mud), isTrue);
    }
    expect(found, greaterThan(30));
  });

  test('cuddler: picks one buddy and stands next to it', () {
    final ids = ['c1', 'c2', 'c3', 'c4'];
    final buddy = CapyTraitWander.buddyFor('c2', ids);
    expect(buddy, isNotNull);
    expect(buddy, isNot('c2'));
    expect(CapyTraitWander.buddyFor('c2', ids), buddy, reason: 'stable');
    expect(CapyTraitWander.buddyFor('c2', ['c2']), isNull);
    // The buddy stays while it is around, whoever else leaves.
    final rest = ids.where((id) => id != buddy && id != 'c2').first;
    expect(
      CapyTraitWander.buddyFor('c2', ids.where((id) => id != rest).toList()),
      buddy,
    );

    const mate = Offset(0.5, 0.6);
    final others = [mate, const Offset(0.2, 0.4)];
    final t = CapyTraitWander.cuddlerTarget(
      from: const Offset(0.8, 0.45),
      buddy: mate,
      herdCount: herdCount,
      others: others,
      meadowSize: meadow,
    );
    expect(t, isNotNull);
    expect(clear(t!, others), isTrue);
    // Closer than the herd spreads: a body and a strip of grass away.
    final gap = CapyWander.minPeerGapPx(t, [mate], meadowSize: meadow);
    expect(gap, lessThan(CapyWander.peerGrassPx + 12));
  });

  test('fidget: the farther of two picks; quicker walk and pauses', () {
    var n = 0;
    final picks = [const Offset(0.4, 0.6), const Offset(0.8, 0.7)];
    final t = CapyTraitWander.fidgetTarget(
      from: const Offset(0.35, 0.6),
      pick: () => picks[n++],
    );
    expect(t, picks[1]);
    expect(n, 2);
    expect(CapyTraitWander.fidgetWalkScale, lessThan(1));
    expect(CapyTraitWander.fidgetPauseScale, lessThan(1));
    expect(
      CapyTraitWander.walkDuration(
        const Offset(0.2, 0.5),
        const Offset(0.6, 0.6),
        fidget: true,
      ),
      lessThan(
        CapyWander.walkDuration(const Offset(0.2, 0.5), const Offset(0.6, 0.6)),
      ),
    );
  });
}
