import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GameScreen shows progress label after init',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CapyClickerApp());
    // Allow GameController.init() to complete.
    await tester.pumpAndSettle();

    expect(find.textContaining('Прогресс стада'), findsOneWidget);
    expect(find.textContaining('Lv.'), findsWidgets);
  });
}
