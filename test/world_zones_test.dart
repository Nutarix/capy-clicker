
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';

void main() {
  group('WorldZones.clampToMeadow', () {
    test('leaves interior points unchanged', () {
      const interior = Offset(0.5, 0.7);
      expect(WorldZones.clampToMeadow(interior), interior);
      expect(WorldZones.isInMeadow(interior), isTrue);
    });

    test('clamps corners outside trees/canopy into meadow', () {
      expect(
        WorldZones.clampToMeadow(const Offset(0.0, 0.0)),
        const Offset(WorldZones.meadowLeft, WorldZones.meadowTop),
      );
      expect(
        WorldZones.clampToMeadow(const Offset(1.0, 1.0)),
        const Offset(WorldZones.meadowRight, WorldZones.meadowBottom),
      );
      expect(
        WorldZones.clampToMeadow(const Offset(0.05, 0.30)),
        const Offset(WorldZones.meadowLeft, WorldZones.meadowTop),
      );
      expect(
        WorldZones.clampToMeadow(const Offset(0.95, 0.40)),
        const Offset(WorldZones.meadowRight, WorldZones.meadowTop),
      );
    });

    test('preserves inclusive edges', () {
      final edge = Offset(WorldZones.meadowLeft, WorldZones.meadowBottom);
      expect(WorldZones.clampToMeadow(edge), edge);
      expect(WorldZones.isInMeadow(edge), isTrue);
    });
  });

  group('meadow occupancy', () {
    test('mud puddle center is on meadow', () {
      expect(
        WorldZones.isInMeadow(
          const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY),
        ),
        isTrue,
      );
    });

    test('berry basket is on meadow', () {
      expect(
        WorldZones.isInMeadow(
          const Offset(BalanceV0.berryPosX, BalanceV0.berryPosY),
        ),
        isTrue,
      );
    });

    test('all flower positions are on meadow', () {
      expect(WorldZones.flowerPositions, isNotEmpty);
      for (final (x, y) in WorldZones.flowerPositions) {
        expect(
          WorldZones.isInMeadow(Offset(x, y)),
          isTrue,
          reason: 'flower ($x, $y) must be inside meadow',
        );
      }
    });

    test('randomInMeadow stays inside rect', () {
      var i = 0;
      final samples = List.generate(40, (_) {
        return WorldZones.randomInMeadow(() {
          i += 1;
          return (i % 10) / 10.0;
        });
      });
      for (final p in samples) {
        expect(WorldZones.isInMeadow(p), isTrue);
      }
    });
  });
}
