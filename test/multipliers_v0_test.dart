import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/models/meadow_snapshot.dart';
import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('food / decor / research / roles round-trip in GameState JSON', () {
    final state = GameState(
      herdProgress: 0.2,
      herd: [
        Capybara(
          id: 'c1',
          level: 2,
          position: const Offset(0.4, 0.7),
          role: CapyRole.nanya,
        ),
      ],
      nextId: 3,
      grass: 40,
      uyut: 2,
      food: const FoodInventory(travka: 2, yagody: 1, oreshki: 1),
      ownedDecor: {HomeDecor.fonarik.id, HomeDecor.kovrik.id},
      placedDecor: {HomeDecor.fonarik.id},
      researched: {'more_flowers', 'longer_mud'},
      roleSlots: 2,
      tentUnlocked: true,
      activeMeadowId: WorldZones.starterMeadowId,
      meadows: {
        WorldZones.starterMeadowId: MeadowSnapshot(
          herd: [
            Capybara(
              id: 'c1',
              level: 2,
              position: const Offset(0.4, 0.7),
              role: CapyRole.nanya,
            ),
          ],
          herdProgress: 0.2,
        ),
      },
    );
    final back = GameState.fromJson(state.toJson());
    expect(back.food.travka, 2);
    expect(back.food.yagody, 1);
    expect(back.food.oreshki, 1);
    expect(back.ownedDecor, contains(HomeDecor.fonarik.id));
    expect(back.placedDecor, contains(HomeDecor.fonarik.id));
    expect(back.researched, containsAll(['more_flowers', 'longer_mud']));
    expect(back.roleSlots, 2);
    expect(back.tentUnlocked, isTrue);
    expect(back.herd.single.role, CapyRole.nanya);
    expect(back.grass, 40);
    expect(back.uyut, 2);
  });

  test('feedFamily applies travka auto boost (food category)', () async {
    await GamePersistence().save(
      GameState(
        herdProgress: 0,
        herd: [
          Capybara(id: 'c1', level: 1, position: const Offset(0.5, 0.7)),
        ],
        nextId: 2,
        grass: 20,
        food: const FoodInventory(travka: 1),
        meadows: {
          WorldZones.starterMeadowId: MeadowSnapshot(
            herd: [
              Capybara(id: 'c1', level: 1, position: const Offset(0.5, 0.7)),
            ],
          ),
        },
      ),
    );
    final c = GameController(random: _FixedRandom(0.99));
    await c.init();
    final base = c.autoRatePerSecond;
    expect(c.feedFamily(FamilyFood.travka), isTrue);
    expect(c.state.food.travka, 0);
    expect(c.isFoodBoostActive, isTrue);
    expect(c.autoRatePerSecond, greaterThan(base));
    expect(c.state.grass, greaterThanOrEqualTo(0));
    expect(c.state.uyut, greaterThanOrEqualTo(0));
    c.dispose();
  });

  test('warm stone place boost (places category)', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 2,
        'grass': 10,
        'activeMeadowId': 'warm_edge',
        'herd': [
          {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7},
        ],
        'meadows': {
          'warm_edge': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7},
            ],
          },
        },
      }),
    });
    final c = GameController(random: _FixedRandom(0.5));
    await c.init();
    final before = c.autoRatePerSecond;
    expect(c.tryActivatePlace(CozyPlaceKind.warmStone, capyId: 'c1'), isTrue);
    expect(c.isPlaceBoostActive, isTrue);
    expect(c.activePlaceBoost, CozyPlaceKind.warmStone);
    expect(c.isPlaceOnCooldown(CozyPlaceKind.warmStone), isTrue);
    expect(c.autoRatePerSecond, greaterThan(before * 0.99));
    expect(c.tryActivatePlace(CozyPlaceKind.warmStone), isFalse);
    c.dispose();
  });

  test('assignRole nanya boosts auto (roles category)', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 3,
        'grass': 10,
        'roleSlots': 1,
        'activeMeadowId': 'warm_edge',
        'herd': [
          {'id': 'c1', 'level': 1, 'x': 0.4, 'y': 0.7},
          {'id': 'c2', 'level': 1, 'x': 0.55, 'y': 0.7},
        ],
        'meadows': {
          'warm_edge': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c1', 'level': 1, 'x': 0.4, 'y': 0.7},
              {'id': 'c2', 'level': 1, 'x': 0.55, 'y': 0.7},
            ],
          },
        },
      }),
    });
    final c = GameController(random: _FixedRandom(0.5));
    await c.init();
    final base = c.autoRatePerSecond;
    expect(c.assignRole('c1', CapyRole.nanya), isTrue);
    expect(c.state.herd.firstWhere((x) => x.id == 'c1').role, CapyRole.nanya);
    expect(c.autoRatePerSecond, greaterThan(base));
    expect(c.assignRole('c2', CapyRole.sobiratel), isFalse);
    c.dispose();
  });

  test('buyDecor fonarik stacks permanent auto (decor category)', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 2,
        'grass': 100,
        'uyut': 0,
        'activeMeadowId': 'warm_edge',
        'herd': [
          {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7},
        ],
        'meadows': {
          'warm_edge': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7},
            ],
          },
        },
      }),
    });
    final c = GameController(random: _FixedRandom(0.5));
    await c.init();
    final base = c.autoRatePerSecond;
    expect(c.buyDecor(HomeDecor.fonarik), isTrue);
    expect(c.state.ownsDecor(HomeDecor.fonarik), isTrue);
    expect(c.state.grass, 100 - HomeDecor.fonarik.grassCost);
    expect(c.autoRatePerSecond, closeTo(base * 1.03, 1e-9));
    expect(c.state.grass, greaterThanOrEqualTo(0));
    c.dispose();
  });

  test('unlockResearch more_flowers then longer_mud (research category)',
      () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 2,
        'grass': 200,
        'uyut': 2,
        'activeMeadowId': 'warm_edge',
        'herd': [
          {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7},
        ],
        'meadows': {
          'warm_edge': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7},
            ],
          },
        },
      }),
    });
    final c = GameController(random: _FixedRandom(0.5));
    await c.init();
    expect(c.unlockResearch('longer_mud'), isFalse);
    expect(c.unlockResearch('more_flowers'), isTrue);
    expect(c.state.hasResearch('more_flowers'), isTrue);
    expect(c.unlockResearch('longer_mud'), isTrue);
    expect(c.state.hasResearch('longer_mud'), isTrue);
    expect(c.state.grass, greaterThanOrEqualTo(0));
    expect(c.state.uyut, greaterThanOrEqualTo(0));
    c.dispose();
  });

  test('stacking order: decor + role + uyut multiply base', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 2,
        'grass': 100,
        'uyut': 1,
        'ownedDecor': ['fonarik'],
        'activeMeadowId': 'warm_edge',
        'herd': [
          {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7, 'role': 'nanya'},
        ],
        'meadows': {
          'warm_edge': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7, 'role': 'nanya'},
            ],
          },
        },
      }),
    });
    final c = GameController(random: _FixedRandom(0.5));
    await c.init();
    final expected = BalanceV0.autoProgressPerSecond *
        1.0 *
        (1.0 + BalanceV0.roleNanyaAutoBonus) *
        (1.0 + HomeDecor.fonarik.autoBonus) *
        (1.0 + BalanceV0.uyutAutoBoostPerPoint);
    expect(c.autoRatePerSecond, closeTo(expected, 1e-9));
    c.dispose();
  });

  test('no soft-lock: grass/uyut never negative after spends', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 2,
        'grass': 3,
        'uyut': 0,
        'food': {'travka': 0, 'yagody': 0, 'oreshki': 0},
        'activeMeadowId': 'warm_edge',
        'herd': [
          {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7},
        ],
        'meadows': {
          'warm_edge': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c1', 'level': 1, 'x': 0.5, 'y': 0.7},
            ],
          },
        },
      }),
    });
    final c = GameController(random: _FixedRandom(0.5));
    await c.init();
    expect(c.buyFood(FamilyFood.oreshki), isFalse);
    expect(c.buyDecor(HomeDecor.fonarik), isFalse);
    expect(c.feedFamily(FamilyFood.travka), isFalse);
    expect(c.state.grass, 3);
    expect(c.state.uyut, 0);
    c.dispose();
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => value;
  @override
  bool nextBool() => false;
}
