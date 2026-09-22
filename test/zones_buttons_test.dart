import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/widgets/meadow_background.dart';
import 'package:capy_clicker/widgets/cozy_pixel_button.dart';

void main() {
  group('Zone background asset keys', () {
    test('each Sunny Glade maps to its unique plate', () {
      expect(
        WorldZones.backgroundAssetForMeadow('warm_edge'),
        'assets/images/bg_warm_edge.png',
      );
      expect(
        WorldZones.backgroundAssetForMeadow('berry_glade'),
        'assets/images/bg_berry_glade.png',
      );
      expect(
        WorldZones.backgroundAssetForMeadow('sunny_clearing'),
        'assets/images/bg_sunny_clearing.png',
      );
      expect(
        WorldZones.backgroundAssetForMeadow('great_meadow'),
        'assets/images/bg_great_meadow.png',
      );
    });

    test('mist biome meadow uses misty woods plate', () {
      expect(
        WorldZones.backgroundAssetForMeadow(WorldZones.mistEdgeMeadowId),
        'assets/images/bg_misty_woods.png',
      );
      expect(WorldZones.isMistyMeadow(WorldZones.mistEdgeMeadowId), isTrue);
    });

    test('unknown id falls back to legacy bg_forest only', () {
      expect(
        WorldZones.backgroundAssetForMeadow('no_such_meadow'),
        WorldZones.fallbackBackgroundAsset,
      );
      expect(
        WorldZones.fallbackBackgroundAsset,
        'assets/images/bg_forest.png',
      );
    });

    test('gladeForHerd ids stay aligned with background map', () {
      final expected = {
        'warm_edge': 'assets/images/bg_warm_edge.png',
        'berry_glade': 'assets/images/bg_berry_glade.png',
        'sunny_clearing': 'assets/images/bg_sunny_clearing.png',
        'great_meadow': 'assets/images/bg_great_meadow.png',
      };
      for (final g in WorldZones.glades) {
        expect(
          WorldZones.backgroundAssetForMeadow(g.id),
          expected[g.id],
          reason: g.id,
        );
      }
    });
  });

  group('CozyPixelButton smoke', () {
    testWidgets('primary / secondary / disabled build and tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CozyPixelButton(
                  label: 'Primary',
                  onPressed: () => taps++,
                ),
                CozyPixelButton(
                  label: 'Secondary',
                  variant: CozyPixelButtonVariant.secondary,
                  onPressed: () => taps++,
                ),
                const CozyPixelButton(
                  label: 'Disabled',
                  onPressed: null,
                ),
                CozyPixelIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () => taps++,
                  tooltip: 'close',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);

      await tester.tap(find.text('Primary'));
      await tester.tap(find.text('Secondary'));
      await tester.tap(find.text('Disabled')); // no-op
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(taps, 3);
    });
  });

  group('MeadowBackground meadowId', () {
    testWidgets('builds with mist meadow id without throw', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MeadowBackground(
            meadowId: WorldZones.mistEdgeMeadowId,
            child: SizedBox.shrink(),
          ),
        ),
      );
      // Allow asset load / errorBuilder path.
      await tester.pump();
      expect(find.byType(MeadowBackground), findsOneWidget);
    });
  });
}
