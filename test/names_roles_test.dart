import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';
import 'package:capy_clicker/features/game/widgets/uyut/uyut_hub_sheet.dart';

import 'support/test_game.dart';

const _key = 'capy_clicker_game_state_v1';

/// Spec 004, С3 and Т7: «Роли» by name; the player's own name.
void main() {
  Map<String, Object> save() => {
    _key: jsonEncode({
      'nextId': 20,
      'activeMeadowId': 'warm_edge',
      'meadows': {
        'warm_edge': {
          'herdProgress': 0.0,
          'herd': [
            {
              'id': 'c1',
              'level': 2,
              'x': 0.3,
              'y': 0.7,
              'role': 'nanya',
              'name': 'button',
              'trait': 'fidget',
            },
            {'id': 'c2', 'level': 1, 'x': 0.6, 'y': 0.7},
            {
              'id': 'c3',
              'level': 3,
              'x': 0.5,
              'y': 0.8,
              'name': 'pinecone',
              'epithet': true,
              'trait': 'sleepyhead',
            },
          ],
        },
      },
    }),
  };

  Future<GameController> open(
    WidgetTester tester, {
    GamePersistence? persistence,
    String? focus,
  }) async {
    // A tall phone: the whole list is laid out.
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = testController(persistence: persistence ?? GamePersistence());
    await tester.runAsync(c.init);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UyutHubSheet(controller: c, initialTab: 1, focusCapyId: focus),
        ),
      ),
    );
    await tester.pump();
    return c;
  }

  Future<void> close(WidgetTester tester, GameController c) async {
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  }

  testWidgets('names in the list, «Малыш» for a baby, holder on the role', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(save());
    final c = await open(tester);
    expect(find.text('Пуговка — няня'), findsOneWidget);
    expect(find.text('Lv.2 · непоседа'), findsOneWidget);
    expect(find.text('Малыш'), findsOneWidget);
    expect(find.text('Шишка-соня'), findsOneWidget);
    expect(find.text('Lv.3 · соня'), findsOneWidget);
    expect(find.textContaining('Сейчас: Пуговка'), findsOneWidget);
    await close(tester, c);
  });

  testWidgets('tap the name, type your own: saved at once, free', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(save());
    final persistence = GamePersistence();
    final c = await open(tester, persistence: persistence);
    final grass = c.state.grass;
    await tester.tap(find.text('Шишка-соня'));
    await tester.pump();
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    await tester.enterText(field, '  Пух  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Пух'), findsOneWidget);
    expect(c.state.herd.firstWhere((x) => x.id == 'c3').customName, 'Пух');
    expect(c.state.grass, grass);
    await tester.runAsync(c.flushSave);
    await close(tester, c);

    // After a restart the name is still there.
    final again = await open(tester, persistence: persistence);
    expect(find.text('Пух'), findsOneWidget);
    await close(tester, again);
  });

  testWidgets('empty is refused; at most 16 characters', (tester) async {
    SharedPreferences.setMockInitialValues(save());
    final c = await open(tester);
    await tester.tap(find.text('Пуговка — няня'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Пуговка — няня'), findsOneWidget, reason: 'old stays');

    await tester.tap(find.text('Пуговка — няня'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Абвгдеёжзийклмнопрст');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final name = c.state.herd.firstWhere((x) => x.id == 'c1').customName!;
    expect(name.length, 16);
    expect(find.text('$name — няня'), findsOneWidget);
    await close(tester, c);
  });

  testWidgets('a baby has nothing to rename', (tester) async {
    SharedPreferences.setMockInitialValues(save());
    final c = await open(tester);
    await tester.tap(find.text('Малыш'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    await close(tester, c);
  });

  testWidgets('the long-pressed capy comes first', (tester) async {
    SharedPreferences.setMockInitialValues(save());
    final c = await open(tester, focus: 'c3');
    final first = tester.getTopLeft(find.text('Шишка-соня')).dy;
    final other = tester.getTopLeft(find.text('Пуговка — няня')).dy;
    expect(first, lessThan(other));
    await close(tester, c);
  });
}
