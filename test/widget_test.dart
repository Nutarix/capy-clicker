import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/app.dart';
import 'package:capy_clicker/features/game/models/balance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Skip tip overlay so pumpAndSettle is not blocked by tips.
    SharedPreferences.setMockInitialValues({BalanceV0.tipsSeenKey: true});
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
    SharedPreferences.setMockInitialValues({});
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
