import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/pile_magnet.dart';

/// Spec 006, Т6: the drag magnet pulls toward capys and piles.
void main() {
  Capybara capy(String id, int level, double x, double y, {String? pile}) =>
      Capybara(id: id, level: level, position: Offset(x, y), pileId: pile);

  group('PileMagnet.nearest', () {
    test('nearest capy within the radius, any level', () {
      final herd = [
        capy('a', 1, 0.40, 0.50),
        capy('b', 3, 0.48, 0.50), // 0.08 < radius, another level
        capy('c', 1, 0.70, 0.50),
      ];
      final hit = PileMagnet.nearest(
        draggedId: 'a',
        dragNormalized: const Offset(0.40, 0.50),
        herd: herd,
      );
      expect(hit!.target.id, 'b');
      expect(hit.distance, closeTo(0.08, 0.001));
      expect(hit.full, isFalse);
    });

    test('a pile pulls too', () {
      final herd = [
        capy('a', 1, 0.40, 0.50),
        capy('p1', 2, 0.45, 0.50, pile: 'p'),
        capy('p2', 1, 0.45, 0.50, pile: 'p'),
      ];
      final hit = PileMagnet.nearest(
        draggedId: 'a',
        dragNormalized: const Offset(0.40, 0.50),
        herd: herd,
      );
      expect(hit!.target.pileId, 'p');
    });

    test('never self, never its own pile', () {
      final herd = [
        capy('a', 1, 0.40, 0.50, pile: 'p'),
        capy('b', 1, 0.40, 0.50, pile: 'p'),
      ];
      expect(
        PileMagnet.nearest(
          draggedId: 'a',
          draggedPileId: 'p',
          dragNormalized: const Offset(0.40, 0.50),
          herd: herd,
        ),
        isNull,
      );
    });

    test('a full pile: skipped mid-drag, found on release', () {
      final herd = [
        capy('a', 1, 0.30, 0.50),
        for (var i = 0; i < BalanceV0.pileMaxSize; i++)
          capy('f$i', 1, 0.35, 0.50, pile: 'full'),
      ];
      expect(
        PileMagnet.nearest(
          draggedId: 'a',
          dragNormalized: const Offset(0.30, 0.50),
          herd: herd,
        ),
        isNull,
      );
      final hit = PileMagnet.nearest(
        draggedId: 'a',
        dragNormalized: const Offset(0.30, 0.50),
        herd: herd,
        includeFull: true,
      );
      expect(hit!.full, isTrue);
    });

    test('rejects candidates beyond the radius (no map-wide magnet)', () {
      final herd = [capy('a', 1, 0.30, 0.50), capy('b', 1, 0.45, 0.50)];
      expect(BalanceV0.magnetRadius, lessThanOrEqualTo(0.10));
      expect(
        PileMagnet.nearest(
          draggedId: 'a',
          dragNormalized: const Offset(0.30, 0.50),
          herd: herd,
        ),
        isNull,
      );
    });
  });

  test('snap band and pull', () {
    final snapAt = BalanceV0.magnetRadius * BalanceV0.magnetSnapFraction;
    expect(PileMagnet.withinSnapDistance(snapAt), isTrue);
    expect(PileMagnet.withinSnapDistance(snapAt + 0.01), isFalse);
    final mid = PileMagnet.lerpToward(Offset.zero, const Offset(1, 0), 0.28);
    expect(mid.dx, closeTo(0.28, 0.0001));
  });
}
