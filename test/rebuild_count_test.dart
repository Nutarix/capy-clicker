import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' as widgets show debugOnRebuildDirtyWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/audio/game_audio.dart';
import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/game_screen.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';
import 'package:capy_clicker/features/game/widgets/draggable_capybara.dart';
import 'package:capy_clicker/features/game/widgets/screen/game_hud.dart';
import 'package:capy_clicker/features/game/widgets/screen/meadow_layer.dart';
import 'package:capy_clicker/features/game/widgets/uyut/uyut_hub_sheet.dart';

/// Element rebuilds by widget type name while [body] runs.
Future<Map<String, int>> countBuilds(Future<void> Function() body) async {
  final counts = <String, int>{};
  widgets.debugOnRebuildDirtyWidget = (element, builtOnce) {
    final type = element.widget.runtimeType.toString();
    counts[type] = (counts[type] ?? 0) + 1;
  };
  try {
    await body();
  } finally {
    widgets.debugOnRebuildDirtyWidget = null;
  }
  return counts;
}

int _count(Map<String, int> counts, String prefix) {
  var n = 0;
  for (final e in counts.entries) {
    if (e.key.startsWith(prefix)) n += e.value;
  }
  return n;
}

/// Rebuilds on a quiet meadow and in the Уют sheet (spec 002, Т13, С1, С2).
///
/// Before the spec, 5 s of ticks rebuilt GameScreen 100 times (every 50 ms
/// tick), the five flowers 500, the Уют sheet on «Роли» 100.
void main() {
  const key = 'capy_clicker_game_state_v1';
  final base = DateTime(2026, 9, 21, 12);

  setUp(() {
    GameAudio.forceSilent = true;
    SharedPreferences.setMockInitialValues({
      BalanceV0.tipsSeenKey: true,
      key:
          '{"herdProgress":0.3,"nextId":4,"grass":2,'
          '"savedAtMs":${base.millisecondsSinceEpoch},'
          '"lastDailyClaimYmd":"${GameController.calendarDayKey(base)}",'
          '"herd":[{"id":"c1","level":2,"x":0.4,"y":0.7},'
          '{"id":"c2","level":1,"x":0.55,"y":0.66},'
          '{"id":"c3","level":1,"x":0.7,"y":0.74}]}',
    });
  });

  tearDown(() {
    GameAudio.forceSilent = false;
  });

  /// Game clock pinned to a midday, moving with the test's fake time.
  DateTime Function() gameClock(WidgetTester tester) {
    final start = tester.binding.clock.now();
    return () => base.add(tester.binding.clock.now().difference(start));
  }

  Future<void> quietSeconds(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds * 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('quiet meadow: 5 s of ticks leave the screen alone', (
    tester,
  ) async {
    final c = GameController(
      persistence: GamePersistence(),
      random: Random(1),
      now: gameClock(tester),
    );
    final audio = GameAudio(silent: true);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(controller: c, audio: audio),
      ),
    );
    // Load, the opening «Лужа!» plate comes and goes.
    await quietSeconds(tester, 4);

    var notices = 0;
    void onNotice() => notices++;
    c.addListener(onNotice);
    final topBar = tester.renderObject<RenderRepaintBoundary>(
      find
          .descendant(
            of: find.byType(GameTopBar),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    topBar.debugResetMetrics();
    final progressBefore = c.state.herdProgress;

    final counts = await countBuilds(() => quietSeconds(tester, 5));
    c.removeListener(onNotice);
    final screen = counts['GameScreen'] ?? 0;
    final meadow = _count(counts, 'GameSelector<({bool berry');
    final topBarBuilds = counts['MeadowGrassReadout'] ?? 0;
    final flowers = counts['FlowerDot'] ?? 0;
    final paints =
        topBar.debugSymmetricPaintCount + topBar.debugAsymmetricPaintCount;
    // ignore: avoid_print
    print(
      'REBUILDS quiet meadow 5 s: notices=$notices GameScreen=$screen '
      'meadow=$meadow topBar=$topBarBuilds flowers=$flowers '
      'topBarPaints=$paints',
    );

    // The game runs: the bar fills every tick.
    expect(notices, greaterThanOrEqualTo(90));
    expect(c.state.herdProgress, isNot(progressBefore));
    // The screen does not follow the tick.
    expect(screen, lessThanOrEqualTo(2), reason: 'GameScreen rebuilds');
    expect(meadow, lessThanOrEqualTo(10), reason: 'meadow rebuilds');
    expect(topBarBuilds, lessThanOrEqualTo(3), reason: 'top bar rebuilds');
    expect(flowers, lessThanOrEqualTo(50), reason: 'flower rebuilds');
    expect(paints, lessThanOrEqualTo(3), reason: 'top bar repaints');

    // A real change still reaches the meadow: a new capy shows up.
    final before = find.byType(MeadowDraggableCapybara).evaluate().length;
    c.addProgress(1.0, fromTap: false);
    await tester.pump();
    expect(find.byType(MeadowDraggableCapybara).evaluate().length, before + 1);
    expect(find.byType(MeadowLayer), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    c.dispose();
    audio.dispose();
  });

  testWidgets('Уют on «Роли»: ticks do not rebuild it, a role does', (
    tester,
  ) async {
    final c = GameController(
      persistence: GamePersistence(),
      random: Random(1),
      now: gameClock(tester),
    );
    await c.init();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UyutHubSheet(controller: c, initialTab: 1)),
      ),
    );
    await quietSeconds(tester, 1);

    final counts = await countBuilds(() => quietSeconds(tester, 5));
    final sheet = counts['UyutHubSheet'] ?? 0;
    final roles = counts['_RoleCard'] ?? 0;
    // ignore: avoid_print
    print('REBUILDS uyut roles 5 s: UyutHubSheet=$sheet roleCards=$roles');
    expect(sheet, lessThanOrEqualTo(1));
    expect(roles, lessThanOrEqualTo(3));

    expect(find.text('Снять'), findsNothing);
    c.assignRoleToFreeCapy(CapyRole.nanya);
    await tester.pump();
    expect(find.text('Снять'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
