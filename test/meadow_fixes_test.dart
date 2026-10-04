import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/audio/game_audio.dart';
import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/game_screen.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/widgets/capybara_placeholder.dart';
import 'package:capy_clicker/features/game/widgets/draggable_capybara.dart';
import 'package:capy_clicker/features/game/widgets/floating_gain.dart';
import 'package:capy_clicker/features/game/widgets/flower_dot.dart';
import 'package:capy_clicker/features/game/widgets/morning_cozy_sheet.dart';
import 'package:capy_clicker/features/game/widgets/screen/place_slot.dart';
import 'package:capy_clicker/features/game/widgets/uyut/uyut_hub_sheet.dart';

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

  group('С5 вибрация', () {
    /// Counts haptic calls on the platform channel while [body] runs.
    Future<int> haptics(
      WidgetTester tester,
      Future<void> Function() body,
    ) async {
      var n = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') n++;
          return null;
        },
      );
      try {
        await body();
      } finally {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      }
      return n;
    }

    const herd = <SavedCapy>[
      ('c1', 1, 0.30, 0.72),
      ('c2', 1, 0.62, 0.72),
      ('c3', 2, 0.45, 0.86),
    ];

    testWidgets('merge by dropping on the peer: one', (tester) async {
      final h = await MeadowHarness.pump(tester, meadowPrefs(herd: herd));
      final n = await haptics(tester, () async {
        // Jump onto the peer's body, outside the snap band: the drop target
        // takes it, not the mid-drag magnet.
        final peer = tester.getCenter(h.capy('c2'));
        final g = await tester.startGesture(tester.getCenter(h.capy('c1')));
        await tester.pump(const Duration(milliseconds: 16));
        await g.moveBy(const Offset(0, 60));
        await tester.pump(const Duration(milliseconds: 16));
        await g.moveTo(peer + const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
        expect(h.controller.state.herd.length, 3, reason: 'no snap');
        await g.up();
        await tester.pump();
      });
      expect(h.controller.state.herd.length, 2);
      expect(n, 1);
      await h.dispose(tester);
    });

    testWidgets('merge by the magnet: one', (tester) async {
      final h = await MeadowHarness.pump(tester, meadowPrefs(herd: herd));
      final n = await haptics(tester, () async {
        await h.drag(
          tester,
          tester.getCenter(h.capy('c1')),
          tester.getCenter(h.capy('c2')),
        );
      });
      expect(h.controller.state.herd.length, 2);
      expect(n, 1);
      await h.dispose(tester);
    });

    testWidgets('puddle: one', (tester) async {
      final h = await MeadowHarness.pump(tester, meadowPrefs(herd: herd));
      const mud = Offset(0.75, 0.86);
      h.controller.debugPlaceMud(mud, seconds: 60);
      await tester.pump();
      final n = await haptics(tester, () async {
        await h.drag(
          tester,
          tester.getCenter(h.capy('c3')),
          h.screenAt(tester, mud),
        );
      });
      expect(h.controller.wallowingCapyId, 'c3');
      expect(n, 1);
      await h.dispose(tester);
    });

    testWidgets('place by drop: one', (tester) async {
      final h = await MeadowHarness.pump(tester, meadowPrefs(herd: herd));
      final pen = find.byWidgetPredicate(
        (w) => w is PlaceSlot && w.kind == CozyPlaceKind.pen,
      );
      final n = await haptics(tester, () async {
        await h.drag(
          tester,
          tester.getCenter(h.capy('c3')),
          tester.getCenter(pen),
        );
      });
      expect(h.controller.activePlaceBoost, CozyPlaceKind.pen);
      expect(n, 1);
      await h.dispose(tester);
    });
  });

  group('С6 утренний уют', () {
    testWidgets('🎁 right after the start: one sheet', (tester) async {
      GameAudio.forceSilent = true;
      SharedPreferences.setMockInitialValues(
        meadowPrefs(herd: const [('c1', 1, 0.4, 0.7)], dailyTaken: false),
      );
      final c = GameController(
        persistence: GamePersistence(),
        now: () => meadowNow,
        autoTick: false,
      );
      final audio = GameAudio(silent: true);
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(controller: c, audio: audio),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.isDailyBonusAvailable, isTrue);
      expect(find.byType(MorningCozySheet), findsNothing);

      // The sheet would open by itself at ~700 ms; the player is faster.
      await tester.tap(find.byTooltip('Утренний уют'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MorningCozySheet), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(MorningCozySheet), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
      audio.dispose();
      await tester.pump(const Duration(seconds: 1));
      GameAudio.forceSilent = false;
    });
  });

  group('С7 роли в «Уюте»', () {
    Future<GameController> openRoles(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(
        meadowPrefs(herd: const [('c1', 1, 0.4, 0.7), ('c2', 2, 0.6, 0.7)]),
      );
      final c = GameController(
        persistence: GamePersistence(),
        now: () => meadowNow,
        autoTick: false,
      );
      await c.init();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () =>
                      UyutHubSheet.show(context, controller: c, initialTab: 1),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(UyutHubSheet), findsOneWidget);
      return c;
    }

    Finder inSheet(Finder f) =>
        find.descendant(of: find.byType(UyutHubSheet), matching: f);

    testWidgets('a role plate shows over the sheet', (tester) async {
      final c = await openRoles(tester);
      await tester.tap(find.text('Назначить').first);
      // The role's message goes out with the next tick.
      c.debugAdvance(0.05);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(inSheet(find.text(CapyRole.nanya.assignToastRu)), findsOneWidget);
      // Visible: it is the top hit where it is drawn.
      final at = tester.getCenter(
        inSheet(find.text(CapyRole.nanya.assignToastRu)),
      );
      final hit = tester.hitTestOnBinding(at);
      final plate = tester.renderObject(
        inSheet(find.text(CapyRole.nanya.assignToastRu)),
      );
      expect(hit.path.first.target, plate);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('no free slot: the reason shows over the sheet', (
      tester,
    ) async {
      final c = await openRoles(tester);
      await tester.tap(find.text('Назначить').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(c.state.roleSlots, 1);
      await tester.tap(find.text('Назначить').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(inSheet(find.textContaining('слот')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  });

  group('С9 держать и тянуть', () {
    const herd = <SavedCapy>[('c1', 1, 0.35, 0.72), ('c2', 2, 0.65, 0.80)];

    testWidgets('hold, then move: a drag, no sheet', (tester) async {
      final h = await MeadowHarness.pump(tester, meadowPrefs(herd: herd));
      final from = tester.getCenter(h.capy('c1'));
      final to = h.screenAt(tester, const Offset(0.55, 0.60));
      await h.drag(
        tester,
        from,
        to,
        holdFirst: const Duration(milliseconds: 800),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(UyutHubSheet), findsNothing);
      final pos = h.controller.state.herd.firstWhere((c) => c.id == 'c1');
      expect(
        (pos.position - const Offset(0.55, 0.60)).distance,
        lessThan(0.05),
      );
      await h.dispose(tester);
    });

    testWidgets('hold still and let go: the «Уют» sheet', (tester) async {
      final h = await MeadowHarness.pump(tester, meadowPrefs(herd: herd));
      final g = await tester.startGesture(tester.getCenter(h.capy('c1')));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(UyutHubSheet), findsNothing, reason: 'not yet');
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(UyutHubSheet), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('a short tap opens nothing', (tester) async {
      final h = await MeadowHarness.pump(tester, meadowPrefs(herd: herd));
      await tester.tap(h.capy('c1'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(UyutHubSheet), findsNothing);
      await h.dispose(tester);
    });
  });

  group('Т10 темп анимации', () {
    Future<double> stepAfterRetime(
      WidgetTester tester, {
      required bool reverse,
    }) async {
      final c = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      c.repeat(reverse: reverse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      retimeLoop(c, const Duration(milliseconds: 200), reverse: reverse);
      await tester.pump();
      final before = c.value;
      await tester.pump(const Duration(milliseconds: 40));
      final step = (c.value - before).abs();
      c.dispose();
      return step;
    }

    testWidgets('a running loop takes the new period at once', (tester) async {
      // 40 ms of a 200 ms loop: 0.2. The old 1 s loop would move 0.04.
      expect(await stepAfterRetime(tester, reverse: false), closeTo(0.2, 0.01));
      expect(await stepAfterRetime(tester, reverse: true), closeTo(0.2, 0.01));
    });

    testWidgets('a stopped loop stays stopped', (tester) async {
      final c = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      retimeLoop(c, const Duration(milliseconds: 200));
      expect(c.isAnimating, isFalse);
      expect(c.duration, const Duration(milliseconds: 200));
      c.dispose();
    });
  });
}
