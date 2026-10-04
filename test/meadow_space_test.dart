import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/widgets/meadow_space.dart';

/// Screen ↔ meadow (spec 003, Т13): the meadow sits away from the screen
/// edge (a top bar, a side gutter) and is zoomed out around its center.
void main() {
  const marker = Offset(0.25, 0.75);
  const points = <Offset>[
    Offset(0, 0),
    Offset(1, 1),
    Offset(0.5, 0.5),
    Offset(0.1, 0.9),
    Offset(0.84, 0.31),
    marker,
  ];

  Widget meadow(MeadowSpace space, double zoom) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 87),
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 31),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => ClipRect(
                        child: AnimatedScale(
                          scale: zoom,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeInOut,
                          alignment: Alignment.center,
                          child: MeadowSpaceAnchor(
                            space: space,
                            child: SizedBox(
                              width: c.maxWidth,
                              height: c.maxHeight,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: marker.dx * c.maxWidth - 5,
                                    top: marker.dy * c.maxHeight - 5,
                                    child: const SizedBox(
                                      key: ValueKey('marker'),
                                      width: 10,
                                      height: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void expectRoundTrip(MeadowSpace space, WidgetTester tester) {
    final size = space.size!;
    for (final p in points) {
      final g = space.toGlobal(p)!;
      final back = space.toNormalized(g)!;
      final errPx = Offset(
        (back.dx - p.dx) * size.width,
        (back.dy - p.dy) * size.height,
      ).distance;
      expect(errPx, lessThan(1), reason: 'round trip of $p');
    }
    // The point is where the meadow really draws it.
    final drawn = tester.getCenter(find.byKey(const ValueKey('marker')));
    expect((space.toGlobal(marker)! - drawn).distance, lessThan(1));
    final n = space.toNormalized(drawn)!;
    expect((n.dx - marker.dx) * size.width, closeTo(0, 1));
    expect((n.dy - marker.dy) * size.height, closeTo(0, 1));
  }

  for (final zoom in const [1.0, 0.66, 0.5]) {
    testWidgets('zoom $zoom: finger → meadow → finger < 1 px', (tester) async {
      final space = MeadowSpace();
      expect(space.isReady, isFalse);
      expect(space.toNormalized(Offset.zero), isNull);
      await tester.pumpWidget(meadow(space, zoom));
      await tester.pumpAndSettle();

      expect(space.isReady, isTrue);
      expect(space.scale, closeTo(zoom, 1e-6));
      expectRoundTrip(space, tester);

      // Meadow center stays put; the top-left corner moves in with the zoom.
      final size = space.size!;
      final center = space.toGlobal(const Offset(0.5, 0.5))!;
      expect(center.dx, closeTo(31 + size.width / 2, 1e-6));
      expect(center.dy, closeTo(87 + size.height / 2, 1e-6));
      final corner = space.toGlobal(Offset.zero)!;
      expect(corner.dx, closeTo(31 + size.width * (1 - zoom) / 2, 1e-6));
      expect(corner.dy, closeTo(87 + size.height * (1 - zoom) / 2, 1e-6));
    });
  }

  testWidgets('camera mid-ease: the current frame, not the target', (
    tester,
  ) async {
    final space = MeadowSpace();
    await tester.pumpWidget(meadow(space, 1.0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(meadow(space, 0.5));
    await tester.pump(const Duration(milliseconds: 200));

    final s = space.scale;
    expect(s, greaterThan(0.5));
    expect(s, lessThan(1.0));
    expectRoundTrip(space, tester);
  });

  testWidgets('a removed meadow is not read', (tester) async {
    final space = MeadowSpace();
    await tester.pumpWidget(meadow(space, 1.0));
    expect(space.isReady, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(space.isReady, isFalse);
    expect(space.toGlobal(marker), isNull);
    expect(space.scale, 1);
  });
}
