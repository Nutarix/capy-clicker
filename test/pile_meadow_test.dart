import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/pile_layout.dart';
import 'package:capy_clicker/features/game/widgets/draggable_capybara.dart';

import 'support/meadow_harness.dart';

/// Spec 006, Т8: the pile on the meadow — dozing capys stacked in their
/// seats, the caption, names on touch, a drag takes one out.
void main() {
  group('PileLayout', () {
    Capybara capy(String id, int level) =>
        Capybara(id: id, level: level, position: const Offset(0.5, 0.7));

    test('eldest behind, the young in front and on top', () {
      for (final n in [2, 3, 4]) {
        final members = [
          for (var i = 0; i < n; i++) capy('c$i', i == 1 ? 3 : 1),
        ];
        final seats = PileLayout.seats(members);
        expect(seats, hasLength(n));
        expect(seats['c1']!.order, 0, reason: 'the eldest is drawn first');
        final orders = {for (final s in seats.values) s.order};
        expect(orders, hasLength(n));
        if (n >= 3) {
          final last = seats.values.firstWhere((s) => s.order == n - 1);
          final eldestFeet =
              seats['c1']!.offset.dy +
              PileLayout.feetFromCenter(BalanceV0.capySizeForLevel(3));
          final topFeet =
              last.offset.dy +
              PileLayout.feetFromCenter(BalanceV0.capySizeForLevel(1));
          expect(topFeet, lessThan(eldestFeet), reason: 'on top: higher');
        }
      }
    });

    test('breathing is out of phase', () {
      final seats = PileLayout.seats([capy('a', 2), capy('b', 2)]);
      expect(seats['a']!.breathPhase, isNot(seats['b']!.breathPhase));
    });
  });

  Map<String, Object> prefs() => meadowPrefs(
    herd: const [
      ('c1', 3, 0.50, 0.75),
      ('c2', 1, 0.50, 0.75),
      ('c3', 1, 0.50, 0.75),
      ('c4', 2, 0.20, 0.62),
    ],
    extra: {
      'c1': {'name': 'button', 'trait': 'fidget', 'pile': 'p1'},
      'c2': {'pile': 'p1'},
      'c3': {'pile': 'p1'},
      'c4': {'name': 'pip', 'trait': 'cuddler'},
    },
  );

  MeadowDraggableCapybara widgetOf(WidgetTester tester, String id) =>
      tester.widget<MeadowDraggableCapybara>(
        find.byKey(ValueKey(id)).first,
      );

  testWidgets('a pile dozes in its seats; the caption shows levels', (
    tester,
  ) async {
    final h = await MeadowHarness.pump(tester, prefs());
    for (final id in ['c1', 'c2', 'c3']) {
      expect(widgetOf(tester, id).pileSeat, isNotNull, reason: id);
    }
    expect(widgetOf(tester, 'c4').pileSeat, isNull);

    // Sleep frames of the trait pack, not walk frames.
    final sleeping = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('traits/sleep_'),
    );
    expect(sleeping, findsAtLeastNWidgets(3));
    expect(find.text('3·1·1'), findsOneWidget);
    // The eldest is painted first in the pile.
    final order = [
      for (final e in find.byType(MeadowDraggableCapybara).evaluate())
        (e.widget as MeadowDraggableCapybara).capybara.id,
    ];
    expect(order.indexOf('c1'), lessThan(order.indexOf('c2')));
    expect(order.indexOf('c1'), lessThan(order.indexOf('c3')));
    await h.dispose(tester);
  });

  testWidgets('touch a pile: everyone\'s names, gone 2 s after', (
    tester,
  ) async {
    final h = await MeadowHarness.pump(tester, prefs());
    final g = await tester.startGesture(tester.getCenter(h.capy('c3')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Пуговка · Lv.3'), findsOneWidget);
    expect(find.text('Малыш · Lv.1'), findsNWidgets(2));
    expect(find.text('Кнопка · Lv.2'), findsNothing, reason: 'not in it');
    await g.up();
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('Пуговка · Lv.3'), findsNothing);
    expect(find.text('3·1·1'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('drag one out onto the grass: it stands there', (tester) async {
    final h = await MeadowHarness.pump(tester, prefs());
    final from = tester.getCenter(h.capy('c3'));
    final to = h.screenAt(tester, const Offset(0.75, 0.86));
    await h.drag(tester, from, to);
    await tester.pump(const Duration(milliseconds: 100));
    final c3 = h.controller.state.herd.firstWhere((c) => c.id == 'c3');
    expect(c3.pileId, isNull);
    expect(h.controller.placesUsed, 3);
    expect(widgetOf(tester, 'c3').pileSeat, isNull);
    // Names fade 2 s after the touch; then the quiet caption.
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('3·1'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('drag a capy onto the pile: it sits in', (tester) async {
    final h = await MeadowHarness.pump(tester, prefs());
    await h.drag(
      tester,
      tester.getCenter(h.capy('c4')),
      h.screenAt(tester, const Offset(0.50, 0.75)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.controller.pileMembers('p1'), hasLength(4));
    // Who sits here now: names for a moment, then the levels.
    expect(find.text('Кнопка · Lv.2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('3·2·1·1'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a full pile says no: the fifth stands beside it', (
    tester,
  ) async {
    final h = await MeadowHarness.pump(
      tester,
      meadowPrefs(
        herd: const [
          ('c1', 2, 0.50, 0.75),
          ('c2', 1, 0.50, 0.75),
          ('c3', 1, 0.50, 0.75),
          ('c4', 1, 0.50, 0.75),
          ('c5', 1, 0.20, 0.62),
        ],
        extra: {
          for (final id in ['c1', 'c2', 'c3', 'c4']) id: {'pile': 'p1'},
        },
      ),
    );
    await h.drag(
      tester,
      tester.getCenter(h.capy('c5')),
      h.screenAt(tester, const Offset(0.50, 0.75)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final five = h.controller.state.herd.firstWhere((c) => c.id == 'c5');
    expect(five.pileId, isNull);
    expect(h.controller.pileMembers('p1'), hasLength(4));
    final d = (five.position - const Offset(0.50, 0.75)).distance;
    expect(d, greaterThan(0.1));
    expect(d, lessThan(0.5));
    await h.dispose(tester);
  });
}
