import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/models/meadow_snapshot.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('GameState multi-meadow round-trip preserves herds', () {
    final warm = MeadowSnapshot(
      herdProgress: 0.3,
      herd: [
        Capybara(id: 'c1', level: 2, position: const Offset(0.4, 0.7)),
        Capybara(id: 'c2', level: 1, position: const Offset(0.5, 0.7)),
      ],
    );
    final berry = MeadowSnapshot(
      herd: [
        Capybara(id: 'c3', level: 1, position: const Offset(0.3, 0.6)),
      ],
    );
    final state = GameState(
      herdProgress: warm.herdProgress,
      herd: warm.herd,
      nextId: 10,
      grass: 42,
      sunnyGladeAnnounced: 1,
      activeMeadowId: 'warm_edge',
      meadows: {
        'warm_edge': warm,
        'berry_glade': berry,
      },
    );

    final back = GameState.fromJson(state.toJson());
    expect(back.activeMeadowId, 'warm_edge');
    expect(back.herdCount, 2);
    expect(back.grass, 42);
    expect(back.meadows['berry_glade']!.herdCount, 1);
    expect(back.meadows['warm_edge']!.herd.first.level, 2);
    expect(back.totalHerdAcrossMeadows, 3);
  });

  test('legacy single-herd save migrates into warm_edge', () {
    final legacy = {
      'herdProgress': 0.2,
      'nextId': 6,
      'sunnyGladeAnnounced': 2,
      'grass': 9,
      'herd': [
        {'id': 'c1', 'level': 3, 'x': 0.5, 'y': 0.7},
        {'id': 'c2', 'level': 1, 'x': 0.4, 'y': 0.65},
      ],
    };
    final state = GameState.fromJson(legacy);
    expect(state.activeMeadowId, WorldZones.starterMeadowId);
    expect(state.herdCount, 2);
    expect(state.herd.first.level, 3);
    expect(state.sunnyGladeAnnounced, 2);
    expect(state.meadows.containsKey('berry_glade'), isTrue);
    expect(state.meadows.containsKey('sunny_clearing'), isTrue);
  });

  test('switch meadow restores each herd; grass stays shared', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();

    // Grow warm herd to 5 → unlock berry with starter.
    for (var i = 0; i < 4; i++) {
      c.addProgress(1.0, fromTap: true);
    }
    expect(c.state.herdCount, 5);
    expect(c.state.sunnyGladeAnnounced, 1);
    while (c.state.grass < 5) {
      c.onFlowerTap();
    }
    final grassBefore = c.state.grass;
    final warmIds = c.state.herd.map((e) => e.id).toSet();

    expect(c.switchToMeadow('berry_glade'), isTrue);
    expect(c.currentGlade.id, 'berry_glade');
    expect(c.state.herdCount, BalanceV0.meadowStarterHerdSize);
    expect(c.state.grass, grassBefore); // shared wallet
    final berryIds = c.state.herd.map((e) => e.id).toSet();
    expect(berryIds.intersection(warmIds), isEmpty);

    // Grow berry a bit, then return — warm herd intact.
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, BalanceV0.meadowStarterHerdSize + 1);

    expect(c.switchToMeadow('warm_edge'), isTrue);
    expect(c.state.herdCount, 5);
    expect(c.state.herd.map((e) => e.id).toSet(), warmIds);
    expect(c.state.grass, greaterThanOrEqualTo(grassBefore));
    expect(c.herdCountForMeadow('berry_glade'), BalanceV0.meadowStarterHerdSize + 1);
    c.dispose();
  });

  test('unlock adds meadow with starter herd', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.unlockedMeadowIds, ['warm_edge']);

    for (var i = 0; i < 4; i++) {
      c.addProgress(1.0, fromTap: true);
    }
    expect(c.unlockedMeadowIds, ['warm_edge', 'berry_glade']);
    expect(c.herdCountForMeadow('berry_glade'), BalanceV0.meadowStarterHerdSize);
    expect(c.state.meadows['berry_glade']!.herd.every((e) => e.level == 1), isTrue);
    // Active meadow unchanged.
    expect(c.state.activeMeadowId, 'warm_edge');
    expect(c.state.herdCount, 5);
    c.dispose();
  });

  test('persistence save/load keeps multi-meadow herds', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = GamePersistence();
    final c = GameController(persistence: persistence);
    await c.init();
    for (var i = 0; i < 4; i++) {
      c.addProgress(1.0, fromTap: true);
    }
    expect(c.switchToMeadow('berry_glade'), isTrue);
    c.addProgress(1.0, fromTap: true);
    final berryCount = c.state.herdCount;
    final grass = c.state.grass;
    await persistence.save(c.state.withActiveSynced());
    c.dispose();

    final c2 = GameController(persistence: GamePersistence());
    await c2.init();
    expect(c2.state.activeMeadowId, 'berry_glade');
    expect(c2.state.herdCount, berryCount);
    expect(c2.state.grass, grass);
    expect(c2.herdCountForMeadow('warm_edge'), 5);
    c2.dispose();
  });

  test('legacy save loads and fills starters for unlocked meadows', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 8,
        'sunnyGladeAnnounced': 1,
        'grass': 4,
        'herd': [
          {'id': 'c1', 'level': 2, 'x': 0.5, 'y': 0.7},
          {'id': 'c2', 'level': 1, 'x': 0.45, 'y': 0.72},
          {'id': 'c3', 'level': 1, 'x': 0.55, 'y': 0.68},
        ],
      }),
    });
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.state.activeMeadowId, 'warm_edge');
    expect(c.state.herdCount, 3);
    expect(c.state.isMeadowUnlocked('berry_glade'), isTrue);
    expect(c.herdCountForMeadow('berry_glade'), BalanceV0.meadowStarterHerdSize);
    expect(c.state.grass, 4);
    c.dispose();
  });

  test('grass never goes negative when switching meadows', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    for (var i = 0; i < 4; i++) {
      c.addProgress(1.0, fromTap: true);
    }
    expect(c.state.grass, greaterThanOrEqualTo(0));
    c.switchToMeadow('berry_glade');
    expect(c.state.grass, greaterThanOrEqualTo(0));
    while (c.state.grass < BalanceV0.callCapyGrassCost) {
      c.onFlowerTap();
    }
    final g = c.state.grass;
    c.switchToMeadow('warm_edge');
    expect(c.state.grass, g);
    c.dispose();
  });
}
