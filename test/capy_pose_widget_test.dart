import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/capy_names.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/widgets/draggable_capybara.dart';

/// Low dice: every chance is taken, every length is the shortest.
class _LowDice implements math.Random {
  @override
  double nextDouble() => 0.0;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

/// Spec 004, Т9: a sleepyhead dozes with a bubble, a dreamer looks up; a
/// drag or a wallow ends it at once.
void main() {
  Finder asset(String part) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName.contains(part),
  );

  Future<void> pumpCapy(
    WidgetTester tester,
    Capybara capy, {
    bool wallowing = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: Stack(
              children: [
                MeadowDraggableCapybara(
                  key: const ValueKey('capy'),
                  capybara: capy,
                  herd: [capy],
                  herdCount: 1,
                  meadowSize: const Size(360, 640),
                  onMerge: (a, b) => false,
                  onDropPosition: (id, p) {},
                  onMudDrop: (_) => false,
                  isOverMud: (_) => false,
                  isWallowing: wallowing,
                  random: _LowDice(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Capybara named(CapyTrait trait) => Capybara(
    id: 'c1',
    level: 2,
    position: const Offset(0.5, 0.6),
    nameKey: 'button',
    trait: trait,
  );

  testWidgets('sleepyhead dozes: breath frames and a growing bubble', (
    tester,
  ) async {
    await pumpCapy(tester, named(CapyTrait.sleepyhead));
    expect(asset('traits/sleep_'), findsNothing);
    // Past the first wander delay (at most 2.6 s on low dice).
    await tester.pump(const Duration(seconds: 3));
    expect(asset('traits/sleep_base_'), findsWidgets);
    expect(find.byKey(const ValueKey('capy-sleep-bubble')), findsOneWidget);
    expect(asset('traits/bubble_0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(asset('traits/bubble_1'), findsOneWidget, reason: 'it grows');
    // The nap ends by itself (7 s on low dice) and walking resumes later.
    await tester.pump(const Duration(seconds: 7));
    expect(asset('traits/sleep_'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dreamer sits and looks up', (tester) async {
    await pumpCapy(tester, named(CapyTrait.dreamer));
    await tester.pump(const Duration(seconds: 3));
    expect(asset('traits/dream_base_'), findsWidgets);
    expect(find.byKey(const ValueKey('capy-sleep-bubble')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a drag wakes the sleepyhead at once', (tester) async {
    await pumpCapy(tester, named(CapyTrait.sleepyhead));
    await tester.pump(const Duration(seconds: 3));
    expect(asset('traits/sleep_'), findsWidgets);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('capy'))),
    );
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(asset('traits/sleep_'), findsNothing);
    await g.up();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a wallow wakes the sleepyhead at once', (tester) async {
    final capy = named(CapyTrait.sleepyhead);
    await pumpCapy(tester, capy);
    await tester.pump(const Duration(seconds: 3));
    expect(asset('traits/sleep_'), findsWidgets);
    await pumpCapy(tester, capy, wallowing: true);
    await tester.pump();
    expect(asset('traits/sleep_'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a baby and other traits never doze', (tester) async {
    await pumpCapy(
      tester,
      Capybara(id: 'c1', level: 1, position: const Offset(0.5, 0.6)),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(asset('traits/'), findsNothing);
    await pumpCapy(tester, named(CapyTrait.fidget));
    await tester.pump(const Duration(seconds: 3));
    expect(asset('traits/'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
