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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Skip tip overlay + daily sheet so pumpAndSettle stays stable.
    SharedPreferences.setMockInitialValues(_quietPrefs());
  });

  testWidgets('GameScreen shows progress label after init', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CapyClickerApp());
    // Allow GameController.init() to complete.
    await tester.pumpAndSettle();

    expect(find.textContaining('Прогресс стада'), findsOneWidget);
    expect(find.textContaining('Lv.'), findsWidgets);
  });

  testWidgets('first-launch tip overlay shows merge tip', (
    WidgetTester tester,
  ) async {
    // Tips unseen, but daily already claimed so sheets do not stack.
    SharedPreferences.setMockInitialValues(_quietPrefs(tipsSeen: false));
    await tester.pumpWidget(const CapyClickerApp());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Перетащи капибар друг на друга'),
      findsOneWidget,
    );
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Перетащи на лужу'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Перетащи на лужу'), findsNothing);
  });
}
