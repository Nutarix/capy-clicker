import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/test_game.dart';

const _key = 'capy_clicker_game_state_v1';

/// A real save written by the 1.0.7 build (pretty-printed for review).
Map<String, dynamic> _snapshot() =>
    jsonDecode(File('test/fixtures/save_v1_snapshot.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('save format v1 (Т9)', () {
    test('snapshot of a real save loads without losses', () async {
      final snap = _snapshot();
      SharedPreferences.setMockInitialValues({_key: jsonEncode(snap)});

      final state = await GamePersistence().load();

      expect(state, isNotNull);
      expect(state!.toJson(), snap, reason: 'reads and writes back the same');
      expect(state.herdCount, 5);
      expect(state.grass, 175);
      expect(state.uyut, 1);
      expect(state.landChapter, 1);
      expect(state.food.yagody, 4);
      expect(state.ownedDecor, {'fonarik'});
      expect(state.researched, {'more_flowers'});
      expect(state.herd.first.role, CapyRole.nanya);
      expect(state.otherLands.single.chapter, 0);
      expect(state.otherLands.single.mistyBiomeUnlocked, isTrue);
    });

    test('controller continues the same family from the snapshot', () async {
      final snap = _snapshot();
      SharedPreferences.setMockInitialValues({_key: jsonEncode(snap)});
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
        snap['savedAtMs'] as int,
      );

      final c = testController(now: () => savedAt);
      await c.init();

      final meadows = (snap['meadows'] as Map).values;
      final herd = meadows.fold<int>(
        0,
        (n, m) => n + (m['herd'] as List).length,
      );
      expect(c.state.totalHerdAcrossMeadows, herd);
      expect(c.state.grass, 175);
      expect(c.state.otherLands, hasLength(1));
      expect(c.hasOfflineWelcome, isFalse);
      c.dispose();
    });
  });
}
