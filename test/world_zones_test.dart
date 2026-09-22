import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';

void main() {
  group('Солнечные поляны — glade selection', () {
    test('four named glades in order', () {
      expect(WorldZones.glades, hasLength(4));
      expect(WorldZones.glades[0].nameRu, 'Тёплая опушка');
      expect(WorldZones.glades[1].nameRu, 'Ягодная поляна');
      expect(WorldZones.glades[2].nameRu, 'Солнечный прогал');
      expect(WorldZones.glades[3].nameRu, 'Большой луг');
    });

    test('tier table: family power → glade + rect + zoom', () {
      final cases = <(int herd, String id, Rect rect, double zoom)>[
        (0, 'warm_edge', const Rect.fromLTRB(0.10, 0.52, 0.86, 0.92), 1.0),
        (4, 'warm_edge', const Rect.fromLTRB(0.10, 0.52, 0.86, 0.92), 1.0),
        (5, 'berry_glade', const Rect.fromLTRB(0.06, 0.50, 0.90, 0.93), 0.82),
        (9, 'berry_glade', const Rect.fromLTRB(0.06, 0.50, 0.90, 0.93), 0.82),
        (10, 'sunny_clearing', const Rect.fromLTRB(0.05, 0.40, 0.91, 0.945), 0.66),
        (15, 'sunny_clearing', const Rect.fromLTRB(0.05, 0.40, 0.91, 0.945), 0.66),
        (16, 'great_meadow', const Rect.fromLTRB(0.03, 0.34, 0.94, 0.96), 0.50),
        (20, 'great_meadow', const Rect.fromLTRB(0.03, 0.34, 0.94, 0.96), 0.50),
        (12, 'sunny_clearing', const Rect.fromLTRB(0.05, 0.40, 0.91, 0.945), 0.66),
];
      for (final (herd, id, rect, zoom) in cases) {
        final g = WorldZones.gladeForHerd(herd);
        expect(g.id, id, reason: 'power $herd');
        expect(g.rect, rect, reason: 'power $herd rect');
        expect(g.baseZoom, zoom, reason: 'power $herd zoom');
        expect(BalanceV0.zoomForHerdCount(herd), zoom);
      }
    });

    test('each glade is strictly larger than the previous', () {
      for (var i = 1; i < WorldZones.glades.length; i++) {
        final a = WorldZones.glades[i - 1];
        final b = WorldZones.glades[i];
        expect(b.width, greaterThan(a.width), reason: '${b.id} wider');
        expect(b.height, greaterThan(a.height), reason: '${b.id} taller');
        expect(b.baseZoom, lessThan(a.baseZoom), reason: '${b.id} zooms out');
      }
    });

    test('Ягодная поляна widens sides; Солнечный прогал goes deeper', () {
      final warm = WorldZones.glades[0];
      final berry = WorldZones.glades[1];
      final sunny = WorldZones.glades[2];
      expect(berry.left, lessThan(warm.left));
      expect(berry.right, greaterThan(warm.right));
      expect(sunny.top, lessThan(berry.top)); // deeper into forest
    });

    test('Большой луг covers most of lower 2/3; canopy wall remains', () {
      final great = WorldZones.glades[3];
      expect(great.top, lessThanOrEqualTo(0.36));
      expect(great.top, greaterThanOrEqualTo(0.30)); // canopy stays wall
      expect(great.bottom - great.top, greaterThan(0.55));
    });
  });

  group('WorldZones.clampToMeadow', () {
    test('leaves interior points unchanged on starter glade', () {
      const interior = Offset(0.5, 0.7);
      expect(WorldZones.clampToMeadow(interior), interior);
      expect(WorldZones.isInMeadow(interior), isTrue);
    });

    test('clamps corners outside trees/canopy into active glade', () {
      expect(
        WorldZones.clampToMeadow(const Offset(0.0, 0.0), herdCount: 1),
        const Offset(WorldZones.meadowLeft, WorldZones.meadowTop),
      );
      expect(
        WorldZones.clampToMeadow(const Offset(1.0, 1.0), herdCount: 1),
        const Offset(WorldZones.meadowRight, WorldZones.meadowBottom),
      );
      final great = WorldZones.gladeForHerd(16);
      expect(
        WorldZones.clampToMeadow(const Offset(0.0, 0.0), herdCount: 16),
        Offset(great.left, great.top),
      );
    });

    test('preserves inclusive edges', () {
      final edge = Offset(WorldZones.meadowLeft, WorldZones.meadowBottom);
      expect(WorldZones.clampToMeadow(edge), edge);
      expect(WorldZones.isInMeadow(edge), isTrue);
    });

    test('expanded glade accepts points outside starter rect', () {
      const side = Offset(0.04, 0.70); // left of starter, inside great meadow
      expect(WorldZones.isInMeadow(side), isFalse);
      expect(WorldZones.isInMeadow(side, herdCount: 16), isTrue);
      expect(
        WorldZones.clampToMeadow(side, herdCount: 16),
        side,
      );
    });
  });

  group('meadow occupancy', () {
    test('mud puddle center is on every glade', () {
      final mud = const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY);
      expect(WorldZones.isInMeadow(mud), isTrue);
      for (final g in WorldZones.glades) {
        expect(
          WorldZones.isInMeadow(mud, herdCount: g.maxHerd),
          isTrue,
          reason: g.nameRu,
        );
      }
    });

    test('berry basket is on every glade', () {
      final berry = const Offset(BalanceV0.berryPosX, BalanceV0.berryPosY);
      expect(WorldZones.isInMeadow(berry), isTrue);
      for (final g in WorldZones.glades) {
        expect(
          WorldZones.isInMeadow(berry, herdCount: g.maxHerd),
          isTrue,
          reason: g.nameRu,
        );
      }
    });

    test('all flower positions are on starter glade', () {
      expect(WorldZones.flowerPositions, isNotEmpty);
      for (final (x, y) in WorldZones.flowerPositions) {
        expect(
          WorldZones.isInMeadow(Offset(x, y)),
          isTrue,
          reason: 'flower ($x, $y) must be inside Тёплая опушка',
        );
      }
    });

    test('randomInMeadow stays inside active glade', () {
      for (final herd in [1, 4, 9, 16]) {
        var i = 0;
        final samples = List.generate(40, (_) {
          return WorldZones.randomInMeadow(
            () {
              i += 1;
              return (i % 10) / 10.0;
            },
            herdCount: herd,
          );
        });
        for (final p in samples) {
          expect(WorldZones.isInMeadow(p, herdCount: herd), isTrue);
        }
      }
    });
  });

  group('camera fit zoom', () {
    test('tight cluster keeps glade baseline', () {
      final positions = [
        const Offset(0.5, 0.7),
        const Offset(0.52, 0.72),
      ];
      final zoom = BalanceV0.cameraZoomForHerd(2, positions);
      expect(zoom, BalanceV0.zoomClose);
    });

    test('spread herd pulls camera back below glade baseline', () {
      // At Тёплая опушка (baseline 1.0), a wide bbox must step the camera back.
      final positions = [
        const Offset(0.12, 0.55),
        const Offset(0.84, 0.90),
      ];
      final tier = BalanceV0.zoomForHerdCount(2);
      final fit = BalanceV0.zoomToFitPositions(positions);
      final zoom = BalanceV0.cameraZoomForHerd(2, positions);
      expect(tier, BalanceV0.zoomClose);
      expect(fit, lessThan(tier));
      expect(zoom, fit);
      expect(zoom, greaterThanOrEqualTo(BalanceV0.zoomWidest));
    });

    test('cameraZoomForHerd never exceeds glade baseline', () {
      final positions = [
        const Offset(0.04, 0.36),
        const Offset(0.92, 0.94),
      ];
      final zoom = BalanceV0.cameraZoomForHerd(16, positions);
      expect(zoom, lessThanOrEqualTo(BalanceV0.zoomForHerdCount(16)));
      expect(zoom, greaterThanOrEqualTo(BalanceV0.zoomWidest));
    });

    test('empty herd returns close zoom', () {
      expect(BalanceV0.zoomToFitPositions(const []), BalanceV0.zoomClose);
    });
  });
}
