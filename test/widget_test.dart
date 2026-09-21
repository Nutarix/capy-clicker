import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/app.dart';

void main() {
  testWidgets('GameScreen shows progress label and capybara placeholder',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CapyClickerApp());

    expect(find.text('Прогресс стада'), findsOneWidget);
    expect(find.text('капибара'), findsOneWidget);
  });
}
