import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/app.dart';
import 'package:capy_clicker/features/game/audio/game_audio.dart';
import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';

String _todayYmd() => GameController.calendarDayKey(DateTime.now());

/// Prefs that skip tips and already claimed today's soft daily (stable pumps).
Map<String, Object> _quietPrefs({bool tipsSeen = true, bool withSave = true}) {
  final ymd = _todayYmd();
  return {
    if (tipsSeen) BalanceV0.tipsSeenKey: true,
    if (withSave)
      'capy_clicker_game_state_v1':
          '{"herdProgress":0.0,"nextId":2,"lastDailyClaimYmd":"$ymd",'
          '"herd":[{"id":"c1","level":1,"x":0.5,"y":0.5}]}',
  };
}

/// Repeating shimmer/bob/glow animations never "settle" — pump frames instead.
Future<void> _pumpReady(WidgetTester tester) async {
  await tester.pump(); // schedule init
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _enterGameFromMenu(WidgetTester tester) async {
  await _pumpReady(tester);
  // Saved prefs → «Продолжить»; empty → «Играть».
  final play = find.text('Продолжить');
  final fresh = find.text('Играть');
  if (play.evaluate().isNotEmpty) {
    await tester.tap(play);
  } else {
    await tester.tap(fresh);
  }
  await _pumpReady(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GameAudio.forceSilent = true;
    SharedPreferences.setMockInitialValues(_quietPrefs());
  });

  tearDown(() {
    GameAudio.forceSilent = false;
  });

  testWidgets('main menu shows title before game', (WidgetTester tester) async {
    await tester.pumpWidget(const CapyClickerApp());
    await _pumpReady(tester);

    expect(find.text('Grow! Capy!'), findsOneWidget);
    expect(find.text('цветы · стадо · уют'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Заново'), findsOneWidget);
    expect(find.text('Прогресс'), findsNothing);
  });

  testWidgets('Играть on empty save opens game', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(_quietPrefs(withSave: false));
    await tester.pumpWidget(const CapyClickerApp());
    await _pumpReady(tester);

    expect(find.text('Играть'), findsOneWidget);
    expect(find.text('Продолжить'), findsNothing);
    await tester.tap(find.text('Играть'));
    await _pumpReady(tester);

    expect(find.text('Прогресс'), findsOneWidget);
    expect(find.textContaining('стадо'), findsOneWidget);

    // Back to menu; pump past soft daily Future.delayed so no pending timer.
    await tester.tap(find.text('меню'));
    await _pumpReady(tester);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Grow! Capy!'), findsOneWidget);
  });

  testWidgets('GameScreen shows progress label after init', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CapyClickerApp());
    await _enterGameFromMenu(tester);

    expect(find.text('Прогресс'), findsOneWidget);
    expect(find.textContaining('стадо'), findsOneWidget);
    expect(find.textContaining('поляна:'), findsOneWidget);
    expect(find.text('меню'), findsOneWidget);
    // Idle badges are compact digits; at least one level mark is present.
    expect(find.textContaining('1'), findsWidgets);
  });

  testWidgets('меню chip returns to main menu without wiping save', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CapyClickerApp());
    await _enterGameFromMenu(tester);
    expect(find.text('Прогресс'), findsOneWidget);

    await tester.tap(find.text('меню'));
    await _pumpReady(tester);

    expect(find.text('Grow! Capy!'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Прогресс'), findsNothing);
  });

  testWidgets('first-launch tip overlay shows merge tip', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(_quietPrefs(tipsSeen: false));
    await tester.pumpWidget(const CapyClickerApp());
    await _enterGameFromMenu(tester);

    expect(
      find.textContaining('Перетащи капибар друг на друга'),
      findsOneWidget,
    );
    await tester.tap(find.text('Далее'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Перетащи на лужу'), findsOneWidget);
    await tester.tap(find.text('Далее'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Корзина ягод'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Корзина ягод'), findsNothing);
  });
}
