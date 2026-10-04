import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/widgets/capybara_placeholder.dart';

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
}
