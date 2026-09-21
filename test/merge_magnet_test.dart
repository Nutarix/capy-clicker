
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/merge_magnet.dart';

void main() {
  Capybara capy(String id, int level, double x, double y) =>
      Capybara(id: id, level: level, position: Offset(x, y));

  group('MergeMagnet.nearestEligible', () {
    test('returns nearest same-level within magnetRadius', () {
      final herd = [
        capy('a', 1, 0.40, 0.50),
        capy('b', 1, 0.48, 0.50), // dist 0.08 < magnetRadius
        capy('c', 1, 0.70, 0.50), // far
      ];
      final hit = MergeMagnet.nearestEligible(
        draggedId: 'a',
        draggedLevel: 1,
        dragNormalized: const Offset(0.40, 0.50),
        herd: herd,
      );
      expect(hit, isNotNull);
      expect(hit!.target.id, 'b');
      expect(hit.distance, closeTo(0.08, 0.001));
    });

    test('ignores different levels', () {
      final herd = [
        capy('a', 1, 0.40, 0.50),
        capy('b', 2, 0.45, 0.50), // close but Lv.2
      ];
      final hit = MergeMagnet.nearestEligible(
        draggedId: 'a',
        draggedLevel: 1,
        dragNormalized: const Offset(0.40, 0.50),
        herd: herd,
      );
      expect(hit, isNull);
    });

    test('ignores self id', () {
      final herd = [capy('a', 1, 0.40, 0.50)];
      final hit = MergeMagnet.nearestEligible(
        draggedId: 'a',
        draggedLevel: 1,
        dragNormalized: const Offset(0.40, 0.50),
        herd: herd,
      );
      expect(hit, isNull);
    });

    test('rejects candidates beyond magnetRadius (no map-wide magnet)', () {
      // 0.15 > magnetRadius (tightened playtest P1)
      final herd = [
        capy('a', 1, 0.30, 0.50),
        capy('b', 1, 0.45, 0.50),
      ];
      final hit = MergeMagnet.nearestEligible(
        draggedId: 'a',
        draggedLevel: 1,
        dragNormalized: const Offset(0.30, 0.50),
        herd: herd,
        radius: BalanceV0.magnetRadius,
      );
      expect(BalanceV0.magnetRadius, lessThanOrEqualTo(0.10));
      expect(hit, isNull);
    });

    test('picks nearest among several eligible', () {
      final herd = [
        capy('a', 2, 0.50, 0.50),
        capy('near', 2, 0.56, 0.50), // 0.06
        capy('farther', 2, 0.58, 0.50), // 0.08
      ];
      final hit = MergeMagnet.nearestEligible(
        draggedId: 'a',
        draggedLevel: 2,
        dragNormalized: const Offset(0.50, 0.50),
        herd: herd,
      );
      expect(hit!.target.id, 'near');
    });
  });

  group('MergeMagnet.withinSnapDistance', () {
    test('true inside snap fraction of radius', () {
      final snapAt = BalanceV0.magnetRadius * BalanceV0.magnetSnapFraction;
      expect(MergeMagnet.withinSnapDistance(snapAt), isTrue);
      expect(MergeMagnet.withinSnapDistance(snapAt - 0.001), isTrue);
    });

    test('false between snap band and full radius', () {
      final justOutsideSnap =
          BalanceV0.magnetRadius * BalanceV0.magnetSnapFraction + 0.01;
      expect(justOutsideSnap, lessThanOrEqualTo(BalanceV0.magnetRadius));
      expect(MergeMagnet.withinSnapDistance(justOutsideSnap), isFalse);
      // Still eligible for drag-end merge via nearestEligible.
      expect(justOutsideSnap, lessThanOrEqualTo(BalanceV0.magnetRadius));
    });
  });

  group('MergeMagnet.lerpToward', () {
    test('pulls drag position toward target by t', () {
      const from = Offset(0.0, 0.0);
      const to = Offset(1.0, 0.0);
      final mid = MergeMagnet.lerpToward(from, to, 0.28);
      expect(mid.dx, closeTo(0.28, 0.0001));
      expect(mid.dy, 0);
    });
  });
}
