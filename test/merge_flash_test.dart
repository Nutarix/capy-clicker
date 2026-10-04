import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/widgets/draggable_capybara.dart';
import 'package:capy_clicker/features/game/widgets/floating_gain.dart';

import 'support/meadow_harness.dart';

/// The gray box after a merge (spec 003, Т12).
///
/// An overshooting curve fed a [TweenSequence] a value above 1: an assert in
/// debug, a `StateError` in release. The failed build became an
/// [ErrorWidget] — light gray in release, as big as its loose constraints.
void main() {
  Future<void> everyFrame(
    WidgetTester tester,
    Duration total, {
    Duration step = const Duration(milliseconds: 16),
  }) async {
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
      expect(tester.takeException(), isNull, reason: 'at $t');
      expect(find.byType(ErrorWidget), findsNothing, reason: 'at $t');
    }
  }

  testWidgets('merge punch of a new capy builds on every frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: Stack(
              children: [
                MeadowDraggableCapybara(
                  capybara: Capybara(
                    id: 'c9',
                    level: 2,
                    position: Offset(0.5, 0.7),
                  ),
                  herd: const [],
                  meadowSize: const Size(400, 600),
                  onMerge: (_, _) => false,
                  onDropPosition: (_, _) {},
                  onMudDrop: (_) => false,
                  isOverMud: (_) => false,
                  mergeFlash: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await everyFrame(
      tester,
      BalanceV0.mergeFlashDuration + const Duration(milliseconds: 100),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a floating label builds on every frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            FloatingGainLayer(
              events: [
                FloatingGainEvent(
                  id: 1,
                  label: '+5%',
                  globalAnchor: const Offset(200, 300),
                ),
              ],
              onFinished: (_) {},
            ),
          ],
        ),
      ),
    );
    await everyFrame(tester, const Duration(milliseconds: 1000));
  });

  testWidgets('a merge on the meadow leaves no error box', (tester) async {
    final h = await MeadowHarness.pump(
      tester,
      meadowPrefs(herd: const [('c1', 1, 0.30, 0.72), ('c2', 1, 0.62, 0.72)]),
    );
    final from = tester.getCenter(h.capy('c1'));
    final to = tester.getCenter(h.capy('c2'));
    await h.drag(tester, from, to);
    expect(h.controller.state.herd.length, 1, reason: 'merged');
    await everyFrame(tester, const Duration(milliseconds: 700));
    await h.dispose(tester);
  });
}
