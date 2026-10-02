import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capy_wander.dart';
import 'package:capy_clicker/features/game/models/meadow_occupancy.dart';

void main() {
  test('a flower rect does not intersect the puddle ring', () {
    const mud = Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY);
    const anchors = <Offset>[
      Offset(0.20, 0.68),
      Offset(0.46, 0.62),
      Offset(0.78, 0.58),
    ];
    final widths = <double>[
      BalanceV0.capySizeForLevel(1),
      BalanceV0.capySizeForLevel(1),
      BalanceV0.capySizeForLevel(2),
    ];

    for (final meadow in const <Size>[
      CapyWander.fallbackMeadow,
      Size(432, 640),
    ]) {
      final props = MeadowOccupancy.layout(
        meadow: meadow,
        herdCount: 0,
        mud: mud,
        capyAnchors: anchors,
        capyWidths: widths,
        tentUnlocked: false,
      );
      final puddle = MeadowOccupancy.puddleRect(mud, meadow);
      final bodies = <Rect>[
        for (var i = 0; i < anchors.length; i++)
          MeadowOccupancy.capyRect(anchors[i], meadow, widths[i]),
      ];
      expect(props.flowers, isNotEmpty);
      for (final flower in props.flowers) {
        final rect = MeadowOccupancy.flowerRect(flower, meadow);
        expect(
          rect.overlaps(puddle),
          isFalse,
          reason: 'flower $flower intersects puddle on $meadow',
        );
        for (final body in bodies) {
          expect(
            rect.overlaps(body),
            isFalse,
            reason: 'flower $flower intersects a capy on $meadow',
          );
        }
      }
      for (final place in props.places.entries) {
        final rect = MeadowOccupancy.placeRect(place.value, meadow);
        expect(
          rect.overlaps(puddle),
          isFalse,
          reason: '${place.key} intersects puddle on $meadow',
        );
        for (final body in bodies) {
          expect(
            rect.overlaps(body),
            isFalse,
            reason: '${place.key} intersects a capy on $meadow',
          );
        }
      }
    }
  });
}
