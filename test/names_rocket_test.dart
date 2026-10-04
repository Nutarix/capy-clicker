import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/models/meadow_snapshot.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';
import 'package:capy_clicker/features/game/widgets/rocket_chapter.dart';

import 'support/test_game.dart';

/// Spec 004, Т10: the rocket chapter calls a named traveler by name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> saveGrown(GamePersistence persistence) async {
    final mist = [
      Capybara(id: 'c2', level: 4, position: const Offset(0.6, 0.7)),
      Capybara(id: 'c3', level: 2, position: const Offset(0.45, 0.75)),
    ];
    await persistence.save(
      GameState(
        herdProgress: 0.2,
        herd: mist,
        nextId: 11,
        grass: 50,
        uyut: 2,
        sunnyGladeAnnounced: 3,
        mistyBiomeUnlocked: true,
        visitedMist: true,
        activeMeadowId: WorldZones.mistEdgeMeadowId,
        meadows: {
          WorldZones.starterMeadowId: MeadowSnapshot(
            herd: [
              Capybara(id: 'c9', level: 3, position: const Offset(0.4, 0.7)),
            ],
          ),
          // Every unlocked meadow lived in: no starter babies on load.
          for (final (i, g) in WorldZones.glades.skip(1).indexed)
            g.id: MeadowSnapshot(
              herd: [
                Capybara(id: 'g$i', level: 3, position: const Offset(0.5, 0.7)),
              ],
            ),
          WorldZones.mistEdgeMeadowId: MeadowSnapshot(herd: mist),
        },
      ),
    );
  }

  test('who flies is unchanged; the name goes along', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = GamePersistence();
    await saveGrown(persistence);
    final c = testController(persistence: persistence);
    await c.init();
    expect(c.rocketUnlocked, isTrue);
    final traveler = c.nextTraveler!;
    expect(traveler.id, 'c3', reason: 'the youngest, as before');
    expect(traveler.isNamed, isTrue);
    expect(c.nextTravelerName, traveler.displayNameRu);
    expect(c.launchToNewLand(), isTrue);
    final arrived = c.state.herd.firstWhere((x) => x.id == 'c3');
    expect(arrived.displayNameRu, traveler.displayNameRu);
    expect(arrived.trait, traveler.trait);
    c.dispose();
  });

  test('a baby flies: no name in the chapter', () async {
    SharedPreferences.setMockInitialValues({});
    final c = testController();
    await c.init();
    expect(c.nextTraveler, isNotNull);
    expect(c.nextTravelerName, isNull);
    c.dispose();
  });

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('farewell and flight say the name', (tester) async {
    await tester.pumpWidget(
      host(
        RocketFarewell(travelerName: 'Пуговка', onSend: () {}, onStay: () {}),
      ),
    );
    expect(find.textContaining('Летит Пуговка.'), findsOneWidget);
    await tester.pumpWidget(
      host(RocketFlight(travelerName: 'Пуговка', onArrive: () {})),
    );
    expect(find.text('Пуговка в пути'), findsOneWidget);
  });

  testWidgets('no name: the chapter reads as before', (tester) async {
    await tester.pumpWidget(host(RocketFarewell(onSend: () {}, onStay: () {})));
    expect(find.textContaining('Один улетает.'), findsOneWidget);
    await tester.pumpWidget(host(RocketFlight(onArrive: () {})));
    expect(find.text('Один в пути'), findsOneWidget);
  });
}
