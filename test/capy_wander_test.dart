import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/capy_wander.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/widgets/capybara_placeholder.dart';
import 'package:capy_clicker/features/game/widgets/draggable_capybara.dart';
import 'package:capy_clicker/features/game/widgets/flower_dot.dart';
import 'package:capy_clicker/features/game/widgets/uyut/cozy_place_marker.dart';
import 'package:capy_clicker/features/game/models/multipliers/cozy_place.dart';

void main() {
  group('CapyWander', () {
    test('phase01 is stable and in 0..1', () {
      expect(CapyWander.phase01('c1'), CapyWander.phase01('c1'));
      expect(CapyWander.phase01('c1'), isNot(CapyWander.phase01('c2')));
      expect(CapyWander.phase01('c1'), inInclusiveRange(0.0, 1.0));
    });

    test('idlePeriod is ~1.5–2.5s', () {
      for (final id in ['c1', 'c2', 'capy-9', 'x']) {
        final d = CapyWander.idlePeriod(id);
        expect(d.inMilliseconds, greaterThanOrEqualTo(1500));
        expect(d.inMilliseconds, lessThanOrEqualTo(2500));
      }
    });

    test('pickTarget stays clamped in meadow for herd', () {
      var i = 0;
      final seq = <double>[
        0.01, 0.99, 0.5, 0.5, 0.2, 0.8, 0.9, 0.1, 0.3, 0.7, 0.4, 0.6,
        0.15, 0.85, 0.55, 0.45,
      ];
      double rnd() => seq[i++ % seq.length];

      for (final herd in [1, 5, 8, 12]) {
        final from = WorldZones.clampToMeadow(
          const Offset(0.5, 0.7),
          herdCount: herd,
        );
        final t = CapyWander.pickTarget(
          from: from,
          random01: rnd,
          herdCount: herd,
        );
        expect(WorldZones.isInMeadow(t, herdCount: herd), isTrue);
        expect(
          WorldZones.clampToMeadow(t, herdCount: herd),
          t,
          reason: 'already clamped herd=$herd',
        );
      }
    });

    test('lerp endpoints and mid', () {
      const a = Offset(0.2, 0.6);
      const b = Offset(0.8, 0.8);
      expect(CapyWander.lerp(a, b, 0), a);
      expect(CapyWander.lerp(a, b, 1), b);
      final mid = CapyWander.lerp(a, b, 0.5);
      expect(mid.dx, closeTo(0.5, 0.01));
      expect(mid.dy, closeTo(0.7, 0.01));
    });

    test('faceRight follows horizontal delta', () {
      expect(
        CapyWander.faceRight(const Offset(0.2, 0.5), const Offset(0.5, 0.5)),
        isTrue,
      );
      expect(
        CapyWander.faceRight(const Offset(0.5, 0.5), const Offset(0.2, 0.5)),
        isFalse,
      );
    });
  });

  group('wander widget lifecycle', () {
    testWidgets('MeadowDraggableCapybara disposes tickers cleanly', (
      tester,
    ) async {
      final positions = <Offset>[];
      final capy = Capybara(
        id: 'c1',
        level: 1,
        position: const Offset(0.5, 0.7),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 640,
              child: Stack(
                children: [
                  MeadowDraggableCapybara(
                    capybara: capy,
                    herd: [capy],
                    herdCount: 1,
                    meadowSize: const Size(360, 640),
                    meadowOriginGlobal: Offset.zero,
                    onMerge: (a, b) => false,
                    onDropPosition: (id, p) => positions.add(p),
                    onMudDrop: (_) => false,
                    isOverMud: (_) => false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tear down — must not leave ticking AnimationControllers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('wander walk persists clamped position via onDropPosition', (
      tester,
    ) async {
      final positions = <Offset>[];
      final capy = Capybara(
        id: 'wander-c',
        level: 3,
        position: const Offset(0.5, 0.7),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 640,
              child: Stack(
                children: [
                  MeadowDraggableCapybara(
                    capybara: capy,
                    herd: [capy],
                    herdCount: 3,
                    meadowSize: const Size(360, 640),
                    meadowOriginGlobal: Offset.zero,
                    onMerge: (a, b) => false,
                    onDropPosition: (id, p) => positions.add(p),
                    onMudDrop: (_) => false,
                    isOverMud: (_) => false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Advance past initial delay + a full walk (worst case ~5s + 2.6s).
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (positions.isNotEmpty) break;
      }

      expect(positions, isNotEmpty, reason: 'wander should commit a position');
      final p = positions.first;
      expect(WorldZones.isInMeadow(p, herdCount: 3), isTrue);
      expect(WorldZones.clampToMeadow(p, herdCount: 3), p);
    });

    testWidgets('FlowerDot and CozyPlaceMarker dispose idle controllers', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FlowerDot(
                  color: Colors.pink,
                  swayPhase: 0.3,
                  onTap: (_) {},
                ),
                CozyPlaceMarker(
                  kind: CozyPlaceKind.pen,
                  active: false,
                  onCooldown: false,
                  cooldownSeconds: 0,
                  onTap: () {},
                ),
                const CapybaraPlaceholder(level: 2, twinSparkle: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
