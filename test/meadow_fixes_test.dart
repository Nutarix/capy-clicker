import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/widgets/capybara_placeholder.dart';
import 'package:capy_clicker/features/game/widgets/draggable_capybara.dart';
import 'package:capy_clicker/features/game/widgets/floating_gain.dart';
import 'package:capy_clicker/features/game/widgets/flower_dot.dart';
import 'package:capy_clicker/features/game/widgets/screen/place_slot.dart';

import 'support/meadow_harness.dart';

/// Spec 003 scenarios that a widget test can see (Т16).
void main() {
  group('С4 магнит', () {
    const herd = <SavedCapy>[
      ('c1', 1, 0.30, 0.72),
      ('c2', 1, 0.62, 0.72),
      ('c3', 2, 0.45, 0.58),
    ];
    // The sprite inside the feedback: its transform holds scale and lean.
    final feedback = find.descendant(
      of: find.byKey(const ValueKey('capy-drag-feedback')),
      matching: find.byType(CapybaraPlaceholder),
    );

    testWidgets('the dragged capy leans to its peer, release merges', (
      tester,
    ) async {
      final h = await MeadowHarness.pump(tester, meadowPrefs(herd: herd));
      final radius = h.controller.effectiveMagnetRadius;

      final from = tester.getCenter(h.capy('c1'));
      final g = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 16));

      // Far from c2: the feedback rides with the finger.
      var finger = h.screenAt(tester, const Offset(0.40, 0.80));
      await g.moveTo(finger);
      await tester.pump(const Duration(milliseconds: 300));
      expect(feedback, findsOneWidget);
      final rest = tester.getCenter(feedback) - finger;

      // Inside the magnet, outside the snap band: it leans toward c2.
      final peer = h.controller.state.herd.firstWhere((c) => c.id == 'c2');
      final near = peer.position - Offset(radius * 0.7, 0);
      finger = h.screenAt(tester, near);
      await g.moveTo(finger);
      // A frame to rebuild, then the ease runs.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.controller.state.herd.length, 3, reason: 'no snap yet');
      final lean = tester.getCenter(feedback) - finger - rest;
      expect(lean.dx, greaterThan(4), reason: 'pull toward c2: $lean');
      expect(lean.dy.abs(), lessThan(2));

      await g.up();
      await tester.pump();
      expect(h.controller.state.herd.length, 2, reason: 'merged on release');
      await h.dispose(tester);
    });
  });

  group('С3 всплывашки', () {
    const herd = <SavedCapy>[('c1', 1, 0.30, 0.80), ('c2', 2, 0.62, 0.84)];

    /// The game sits away from the screen origin (a desktop frame, say).
    Widget offset(Widget screen) => Padding(
      padding: const EdgeInsets.only(left: 120, top: 100),
      child: screen,
    );

    Finder floatText(String text) => find.descendant(
      of: find.byType(FloatingGainLayer),
      matching: find.textContaining(text),
    );

    testWidgets('«+N%» rises from the flower and does not jump', (
      tester,
    ) async {
      final h = await MeadowHarness.pump(
        tester,
        meadowPrefs(herd: herd),
        wrap: offset,
      );
      final flowers = find.byType(FlowerDot);
      final first = tester.getCenter(flowers.at(0));
      await tester.tap(flowers.at(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(floatText('%'), findsOneWidget);
      final start = tester.getCenter(floatText('%'));
      expect(
        (start - first).distance,
        lessThan(60),
        reason: 'flower $first, label $start',
      );

      // A second label makes the layer rebuild: the first stays on track.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(flowers.at(1));
      var prev = tester.getCenter(floatText('%').first);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final labels = floatText('%');
        if (labels.evaluate().isEmpty) break;
        final now = tester.getCenter(labels.first);
        expect((now.dx - prev.dx).abs(), lessThan(2), reason: 'frame $i');
        expect(now.dy, lessThanOrEqualTo(prev.dy + 0.5), reason: 'frame $i');
        expect(prev.dy - now.dy, lessThan(15), reason: 'frame $i');
        prev = now;
      }
      await h.dispose(tester);
    });

    testWidgets('«+капи» shows over the new capy', (tester) async {
      final h = await MeadowHarness.pump(
        tester,
        meadowPrefs(herd: herd, grass: 40),
        wrap: offset,
      );
      await tester.tap(find.text('Позвать'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final newcomer = h.controller.state.herd.last;
      expect(newcomer.id, isNot(anyOf('c1', 'c2')));
      final capy = tester.getCenter(
        find.byWidgetPredicate(
          (w) => w is MeadowDraggableCapybara && w.capybara.id == newcomer.id,
        ),
      );
      final label = tester.getCenter(floatText('+капи'));
      expect((label - capy).distance, lessThan(70), reason: '$capy $label');
      await h.dispose(tester);
    });

    testWidgets('the place sign shows over the place', (tester) async {
      final h = await MeadowHarness.pump(
        tester,
        meadowPrefs(herd: herd),
        wrap: offset,
      );
      final pen = find.byWidgetPredicate(
        (w) => w is PlaceSlot && w.kind == CozyPlaceKind.pen,
      );
      final at = tester.getCenter(pen);
      await tester.tap(pen);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(h.controller.activePlaceBoost, CozyPlaceKind.pen);
      final label = tester.getCenter(floatText(CozyPlaceKind.pen.emoji));
      expect((label - at).distance, lessThan(60), reason: '$at $label');
      await h.dispose(tester);
    });
  });
}
