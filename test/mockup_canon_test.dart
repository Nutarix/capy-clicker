import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/models/meadow_snapshot.dart';
import 'package:capy_clicker/features/game/models/multipliers/home_decor.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';
import 'package:capy_clicker/features/game/widgets/home_meadow_scene.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('home slots keep the picture from 15, 16 and 17', () {
    final lantern = HomeMeadowLayout.slotOf(HomeDecor.fonarik);
    final pot = HomeMeadowLayout.slotOf(HomeDecor.vazon);
    final bird = HomeMeadowLayout.slotOf(HomeDecor.skvorechnik);
    final lights = HomeMeadowLayout.slotOf(HomeDecor.girlyanda);
    final rug = HomeMeadowLayout.slotOf(HomeDecor.kovrik);
    final pillow = HomeMeadowLayout.slotOf(HomeDecor.podushka);
    final lamp = HomeMeadowLayout.slotOf(HomeDecor.lampa);
    final feeder = HomeMeadowLayout.slotOf(HomeDecor.kormushka);

    expect(lantern.x, lessThan(pot.x));
    expect(pot.x, lessThan(bird.x));
    expect(lights.y, lessThan(lantern.y));
    expect(pillow.y, lessThan(rug.y));
    expect((pillow.x - rug.x).abs(), lessThan(0.05));
    expect(feeder.x, lessThan(rug.x));
    expect(feeder.y, greaterThan(lantern.y));
    expect(lamp.x, greaterThan(pot.x));
    expect(lamp.x, lessThan(bird.x));
    expect(HomeDecor.lampa.grassCost, 42);
    expect(HomeDecor.lampa.uyutCost, 1);
    expect(HomeDecor.kormushka.grassCost, 48);
    expect(HomeDecor.kormushka.uyutCost, 1);
  });

  test('rocket keeps grass and the old land', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = GamePersistence();
    const grass = 186;
    const uyut = 4;
    final before = GameState(
      herdProgress: 0.2,
      herd: [
        Capybara(id: 'c1', level: 1, position: const Offset(0.3, 0.7)),
        Capybara(id: 'c2', level: 4, position: const Offset(0.6, 0.7)),
        Capybara(id: 'c3', level: 2, position: const Offset(0.45, 0.75)),
      ],
      nextId: 4,
      grass: grass,
      uyut: uyut,
      sunnyGladeAnnounced: 3,
      mistyBiomeUnlocked: true,
      visitedMist: true,
      activeMeadowId: WorldZones.mistEdgeMeadowId,
      meadows: {
        WorldZones.starterMeadowId: MeadowSnapshot(
          herd: [
            Capybara(id: 'c9', level: 3, position: const Offset(0.4, 0.7)),
            Capybara(id: 'c10', level: 3, position: const Offset(0.5, 0.7)),
          ],
        ),
        WorldZones.mistEdgeMeadowId: MeadowSnapshot(
          herd: [
            Capybara(id: 'c1', level: 1, position: const Offset(0.3, 0.7)),
            Capybara(id: 'c2', level: 4, position: const Offset(0.6, 0.7)),
            Capybara(id: 'c3', level: 2, position: const Offset(0.45, 0.75)),
          ],
        ),
      },
    );
    await persistence.save(before);
    final c = testController(persistence: persistence);
    await c.init();
    expect(c.rocketUnlocked, isTrue);
    final oldCount = c.state.totalHerdAcrossMeadows;
    expect(c.launchToNewLand(), isTrue);
    expect(c.state.grass, grass);
    expect(c.state.uyut, uyut);
    expect(c.state.mistyBiomeUnlocked, isFalse);
    expect(c.state.landChapter, 1);
    expect(c.onFreshNewLand, isTrue);
    expect(c.state.herd.length, 2);
    expect(c.state.otherLands, isNotEmpty);
    final previous = c.state.otherLands.single;
    expect(previous.familyCount, oldCount - 1);
    expect(previous.mistyBiomeUnlocked, isTrue);
    expect(c.visitLand(0), isTrue);
    expect(c.state.grass, grass);
    expect(c.state.uyut, uyut);
    expect(c.state.mistyBiomeUnlocked, isTrue);
    expect(c.state.totalHerdAcrossMeadows, oldCount - 1);
    expect(c.playingNewestLand, isFalse);
    expect(c.rocketUnlocked, isFalse);
    c.dispose();
  });
}
