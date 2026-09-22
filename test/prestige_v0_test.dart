import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/models/meadow_snapshot.dart';
import 'package:capy_clicker/features/game/models/session_goals.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('session goals never end — soft uyut horizon', () {
    expect(SessionGoals.at(0)?.id, 'berry_glade');
    expect(SessionGoals.at(SessionGoals.sequence.length)?.id, 'uyut_sparks');
    expect(SessionGoals.at(99)?.id, 'uyut_sparks');
    final soft = SessionGoals.sequence.last;
    expect(
      SessionGoals.isComplete(
        goal: soft,
        sunnyGladeAnnounced: 3,
        maxCapyLevel: 6,
        mistyBiomeUnlocked: true,
        activeMeadowId: WorldZones.mistEdgeMeadowId,
      ),
      isFalse,
    );
  });

  test('uyut + misty round-trip in GameState JSON', () {
    final state = GameState(
      herdProgress: 0.1,
      herd: [
        Capybara(id: 'c1', level: 4, position: const Offset(0.4, 0.7)),
      ],
      nextId: 5,
      sunnyGladeAnnounced: 3,
      grass: 8,
      sessionGoalIndex: 5,
      uyut: 2,
      mistyBiomeUnlocked: true,
      activeMeadowId: WorldZones.mistEdgeMeadowId,
      meadows: {
        'warm_edge': MeadowSnapshot(
          herd: [
            Capybara(id: 'c2', level: 2, position: const Offset(0.5, 0.7)),
          ],
        ),
        WorldZones.mistEdgeMeadowId: MeadowSnapshot(
          herd: [
            Capybara(id: 'c1', level: 4, position: const Offset(0.4, 0.7)),
          ],
        ),
      },
    );
    final back = GameState.fromJson(state.toJson());
    expect(back.uyut, 2);
    expect(back.mistyBiomeUnlocked, isTrue);
    expect(back.isMeadowUnlocked(WorldZones.mistEdgeMeadowId), isTrue);
    expect(back.unlockedMeadowIds, contains(WorldZones.mistEdgeMeadowId));
    expect(back.activeMeadowId, WorldZones.mistEdgeMeadowId);
  });

  test('Great Glade + Lv.4 grants first Уют and unlocks Туманный бор', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 30,
        'sunnyGladeAnnounced': 3,
        'grass': 12,
        'sessionGoalIndex': 3, // capy_lv4 pending
        'activeMeadowId': 'warm_edge',
        'uyut': 0,
        'mistyBiomeUnlocked': false,
        'herd': [
          {'id': 'c1', 'level': 4, 'x': 0.5, 'y': 0.7},
          {'id': 'c2', 'level': 1, 'x': 0.4, 'y': 0.65},
        ],
        'meadows': {
          'warm_edge': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c1', 'level': 4, 'x': 0.5, 'y': 0.7},
              {'id': 'c2', 'level': 1, 'x': 0.4, 'y': 0.65},
            ],
          },
          'berry_glade': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c3', 'level': 1, 'x': 0.3, 'y': 0.6},
              {'id': 'c4', 'level': 1, 'x': 0.5, 'y': 0.6},
            ],
          },
          'sunny_clearing': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c5', 'level': 1, 'x': 0.3, 'y': 0.6},
              {'id': 'c6', 'level': 1, 'x': 0.5, 'y': 0.6},
            ],
          },
          'great_meadow': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c7', 'level': 1, 'x': 0.3, 'y': 0.6},
              {'id': 'c8', 'level': 1, 'x': 0.5, 'y': 0.6},
            ],
          },
        },
      }),
    });

    final c = GameController(persistence: GamePersistence());
    await c.init();

    expect(c.state.mistyBiomeUnlocked, isTrue);
    expect(c.state.uyut, BalanceV0.firstMistyUyutGrant);
    expect(c.state.isMeadowUnlocked(WorldZones.mistEdgeMeadowId), isTrue);
    expect(
      c.herdCountForMeadow(WorldZones.mistEdgeMeadowId),
      BalanceV0.meadowStarterHerdSize,
    );
    // Goals advanced past unlock; not «closed».
    expect(c.currentSessionGoal, isNotNull);
    expect(c.currentSessionGoal!.id, isNot('capy_lv4'));
    expect(c.currentSessionGoal!.titleRu, isNot('Цели закрыты'));

    // Enter misty — fresh starter family; sunny meadows keep theirs.
    final warmCount = c.herdCountForMeadow('warm_edge');
    expect(c.switchToMeadow(WorldZones.mistEdgeMeadowId), isTrue);
    expect(c.state.herdCount, BalanceV0.meadowStarterHerdSize);
    expect(c.state.herd.every((e) => e.level == 1), isTrue);
    expect(c.herdCountForMeadow('warm_edge'), warmCount);
    expect(c.state.uyut, BalanceV0.firstMistyUyutGrant); // global, not wiped

    // Visit goal can complete.
    expect(
      c.state.sessionGoalIndex,
      greaterThanOrEqualTo(
        SessionGoals.sequence.indexWhere((g) => g.id == 'visit_misty'),
      ),
    );
    c.dispose();
  });

  test('Уют mildly boosts auto progress rate', () async {
    final base = BalanceV0.autoProgressPerSecond;
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 4,
        'sunnyGladeAnnounced': 3,
        'grass': 0,
        'sessionGoalIndex': 6,
        'uyut': 2,
        'mistyBiomeUnlocked': true,
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
          'mist_edge': {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c2', 'level': 1, 'x': 0.4, 'y': 0.7},
              {'id': 'c3', 'level': 1, 'x': 0.55, 'y': 0.7},
            ],
          },
        },
      }),
    });
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.state.uyut, 2);
    expect(
      c.autoRatePerSecond,
      closeTo(base * (1 + 2 * BalanceV0.uyutAutoBoostPerPoint), 0.0001),
    );
    expect(c.autoRatePerSecond, greaterThan(base));
    c.dispose();
  });

  test('misty stays locked before prestige trigger', () async {
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.state.mistyBiomeUnlocked, isFalse);
    expect(c.switchToMeadow(WorldZones.mistEdgeMeadowId), isFalse);
    expect(c.state.uyut, 0);
    // Fill soft-cap, then merge+refill until Great (power ≥16) — no Lv.4 yet.
    for (var i = 0; i < 11; i++) {
      c.addProgress(1.0, fromTap: true);
    }
    var guard = 0;
    while (c.state.familyPower < 16 && guard < 40) {
      guard++;
      final ones = c.state.herd.where((e) => e.level == 1).toList();
      if (ones.length >= 2) {
        c.tryMerge(ones[0].id, ones[1].id);
      } else {
        final twos = c.state.herd.where((e) => e.level == 2).toList();
        if (twos.length < 2) break;
        c.tryMerge(twos[0].id, twos[1].id);
      }
      if (c.state.herdCount < BalanceV0.maxHerdSize) {
        c.addProgress(1.0, fromTap: true);
      }
    }
    expect(c.state.sunnyGladeAnnounced, 3);
    expect(c.state.maxCapyLevel, lessThan(4));
    expect(c.state.mistyBiomeUnlocked, isFalse);
    expect(c.state.uyut, 0);
    c.dispose();
  });

  test('no soft-lock after misty unlock — warm_edge still playable', () async {
    SharedPreferences.setMockInitialValues({
      'capy_clicker_game_state_v1': jsonEncode({
        'herdProgress': 0.0,
        'nextId': 10,
        'sunnyGladeAnnounced': 3,
        'grass': 5,
        'sessionGoalIndex': 6,
        'uyut': 1,
        'mistyBiomeUnlocked': true,
        'activeMeadowId': WorldZones.mistEdgeMeadowId,
        'herd': [
          {'id': 'c1', 'level': 1, 'x': 0.4, 'y': 0.7},
          {'id': 'c2', 'level': 1, 'x': 0.5, 'y': 0.7},
        ],
        'meadows': {
          'warm_edge': {
            'herdProgress': 0.2,
            'herd': [
              {'id': 'c9', 'level': 3, 'x': 0.5, 'y': 0.7},
            ],
          },
          WorldZones.mistEdgeMeadowId: {
            'herdProgress': 0.0,
            'herd': [
              {'id': 'c1', 'level': 1, 'x': 0.4, 'y': 0.7},
              {'id': 'c2', 'level': 1, 'x': 0.5, 'y': 0.7},
            ],
          },
        },
      }),
    });
    final c = GameController(persistence: GamePersistence());
    await c.init();
    expect(c.switchToMeadow('warm_edge'), isTrue);
    expect(c.state.herdCount, greaterThanOrEqualTo(1));
    expect(c.state.grass, greaterThanOrEqualTo(0));
    c.addProgress(1.0, fromTap: true);
    expect(c.state.herdCount, greaterThanOrEqualTo(1));
    expect(c.currentSessionGoal, isNotNull);
    c.dispose();
  });
}
