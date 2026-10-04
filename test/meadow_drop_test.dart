import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/widgets/screen/place_slot.dart';

import 'support/meadow_harness.dart';

/// Drops with the camera zoomed out to 0.5 (spec 003, Т14, С1, С2).
///
/// «Большой луг» keeps the camera at 0.5. The meadow sits under the top bar,
/// so its origin is not the screen origin either.
void main() {
  // Different levels: no merge, no magnet in the way.
  const herd = <SavedCapy>[
    ('c1', 1, 0.30, 0.55),
    ('c2', 2, 0.55, 0.45),
    ('c3', 3, 0.20, 0.85),
  ];

  Map<String, Object> prefs() =>
      meadowPrefs(meadowId: 'great_meadow', announced: 3, herd: herd);

  testWidgets('camera at 0.5 on «Большой луг»', (tester) async {
    final h = await MeadowHarness.pump(tester, prefs());
    expect(h.controller.cameraZoom, 0.5);
    final r = h.meadowRect(tester);
    expect(r.top, greaterThan(20), reason: 'meadow under the top bar');
    await h.dispose(tester);
  });

  testWidgets('drop over the puddle → wallow (С1)', (tester) async {
    final h = await MeadowHarness.pump(tester, prefs());
    const mud = Offset(0.82, 0.88);
    h.controller.debugPlaceMud(mud, seconds: 60);
    await tester.pump();

    final from = tester.getCenter(h.capy('c1'));
    await h.drag(tester, from, h.screenAt(tester, mud));

    expect(h.controller.wallowingCapyId, 'c1');
    expect(h.controller.isMudBoostActive, isTrue);
    await h.dispose(tester);
  });

  testWidgets('drop over the stump → place (С1)', (tester) async {
    final h = await MeadowHarness.pump(tester, prefs());
    final pen = find.byWidgetPredicate(
      (w) => w is PlaceSlot && w.kind == CozyPlaceKind.pen,
    );
    expect(pen, findsOneWidget);

    final from = tester.getCenter(h.capy('c1'));
    await h.drag(tester, from, tester.getCenter(pen));

    expect(h.controller.activePlaceBoost, CozyPlaceKind.pen);
    await h.dispose(tester);
  });

  testWidgets('drop on grass → the capy stays under the finger (С2)', (
    tester,
  ) async {
    final h = await MeadowHarness.pump(tester, prefs());
    final from = tester.getCenter(h.capy('c1'));
    const target = Offset(0.75, 0.62);
    final to = h.screenAt(tester, target);
    await h.drag(tester, from, to);

    final pos = h.controller.state.herd.firstWhere((c) => c.id == 'c1');
    final r = h.meadowRect(tester);
    final errPx = Offset(
      (pos.position.dx - target.dx) * r.width,
      (pos.position.dy - target.dy) * r.height,
    ).distance;
    // A fingertip, on screen.
    expect(errPx, lessThan(16), reason: 'landed at ${pos.position}');
    final drawn = tester.getCenter(h.capy('c1'));
    expect((drawn - to).distance, lessThan(16));
    await h.dispose(tester);
  });
}
