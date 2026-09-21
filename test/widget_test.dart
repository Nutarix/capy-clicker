import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/app.dart';
import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';

String _todayYmd() => GameController.calendarDayKey(DateTime.now());

/// Prefs that skip tips and already claimed today's soft daily (stable pumps).
Map<String, Object> _quietPrefs({bool tipsSeen = true}) {
  final ymd = _todayYmd();
  return {
    if (tipsSeen) BalanceV0.tipsSeenKey: true,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(_quietPrefs());
  });

  testWidgets('GameScreen shows progress label after init', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CapyClickerApp());
    await _pumpReady(tester);

    expect(find.text('Прогресс'), findsOneWidget);
    expect(find.textContaining('стадо'), findsOneWidget);
    expect(find.textContaining('поляна:'), findsOneWidget);
    // Idle badges are compact digits; at least one level mark is present.
    expect(find.textContaining('1'), findsWidgets);
  });

  testWidgets('first-launch tip overlay shows merge tip', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(_quietPrefs(tipsSeen: false));
    await tester.pumpWidget(const CapyClickerApp());
    await _pumpReady(tester);

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
