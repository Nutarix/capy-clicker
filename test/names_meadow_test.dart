import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/widgets/draggable_capybara.dart';

import 'support/meadow_harness.dart';

/// Spec 004, С2 and Т6: the name shows on touch and drag, not all the time.
void main() {
  const chip = ValueKey('capy-name-chip');

  Map<String, Object> prefs() => meadowPrefs(
    herd: const [
      ('c1', 2, 0.30, 0.66),
      ('c2', 2, 0.70, 0.66),
      ('c3', 1, 0.50, 0.90),
    ],
    extra: {
      'c1': {'name': 'button', 'trait': 'fidget'},
      'c2': {'name': 'pip', 'trait': 'cuddler'},
    },
  );

  testWidgets('touch shows the name by the level; gone 2 s after', (
    tester,
  ) async {
    final h = await MeadowHarness.pump(tester, prefs());
    expect(find.byKey(chip), findsNothing, reason: 'no labels at rest');

    final g = await tester.startGesture(tester.getCenter(h.capy('c1')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Пуговка · Lv.2'), findsOneWidget);
    await g.up();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Пуговка · Lv.2'), findsOneWidget, reason: 'lingers');
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Пуговка · Lv.2'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the touched capy paints over the others: chip never covered', (
    tester,
  ) async {
    final h = await MeadowHarness.pump(tester, prefs());
    List<String> order() => [
      for (final e in find.byType(MeadowDraggableCapybara).evaluate())
        (e.widget as MeadowDraggableCapybara).capybara.id,
    ];
    expect(order().last, isNot('c1'), reason: 'c1 is not last at rest');

    final g = await tester.startGesture(tester.getCenter(h.capy('c1')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(order().last, 'c1', reason: 'touched: painted last');
    await g.up();
    await tester.pump(const Duration(milliseconds: 2500));
    expect(order().last, isNot('c1'), reason: 'chip gone: back in line');
    await h.dispose(tester);
  });

  testWidgets('a baby shows only its level', (tester) async {
    final h = await MeadowHarness.pump(tester, prefs());
    final g = await tester.startGesture(tester.getCenter(h.capy('c3')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(chip), findsNothing);
    await g.up();
    await h.dispose(tester);
  });

  testWidgets('dragging: own name under the finger, the target shows its', (
    tester,
  ) async {
    final h = await MeadowHarness.pump(tester, prefs());
    Offset nearC2() {
      // Inside the magnet (0.085), short of the snap (0.036). The other one
      // may have wandered: aim at where it is now.
      final c2 = h.controller.state.herd.firstWhere((x) => x.id == 'c2');
      return h.screenAt(tester, c2.position - const Offset(0.07, 0));
    }

    final from = tester.getCenter(h.capy('c1'));
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 16));
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await g.moveTo(Offset.lerp(from, nearC2(), i / steps)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.moveTo(nearC2());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Пуговка · Lv.2'), findsOneWidget, reason: 'dragged');
    expect(find.text('Кнопка · Lv.2'), findsOneWidget, reason: 'target');
    // Back away and let go: no merge, the target's name goes.
    await g.moveTo(from);
    await tester.pump(const Duration(milliseconds: 16));
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.controller.state.herd, hasLength(3));
    expect(find.text('Кнопка · Lv.2'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('two babies merged: the plate says who grew up', (tester) async {
    final h = await MeadowHarness.pump(
      tester,
      meadowPrefs(herd: const [('c1', 1, 0.30, 0.66), ('c2', 1, 0.70, 0.66)]),
    );
    expect(h.controller.tryMerge('c1', 'c2'), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final grown = h.controller.state.herd.single;
    expect(
      find.text('Малыш подрос — теперь это ${grown.displayNameRu}'),
      findsOneWidget,
    );
    await h.dispose(tester);
  });

  test('no event type left unhandled', () {
    // The screen switch over GameEvent is exhaustive (sealed): a new event
    // without a case does not compile. Here only the text of the new one.
    const e = CapyNamed(text: 'Малыш подрос — теперь это Шишка', capyId: 'c1');
    expect(e.text, startsWith('Малыш подрос — теперь это '));
  });
}
