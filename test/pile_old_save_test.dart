import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/capy_pile.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';

import 'support/test_game.dart';

/// Spec 006, С10, Т11: a save from before the pile (1.0.7 build snapshot).
void main() {
  late Map<String, dynamic> snap;

  setUp(() {
    snap =
        jsonDecode(
              File('test/fixtures/save_v1_snapshot.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    SharedPreferences.setMockInitialValues({testSaveKey: jsonEncode(snap)});
  });

  List<Map<String, dynamic>> meadowHerd(Map<String, dynamic> land, String id) =>
      [
        for (final c in ((land['meadows'] as Map)[id] as Map)['herd'] as List)
          Map<String, dynamic>.from(c as Map),
      ];

  test('everyone in place with levels; no piles; places = bodies; quiet',
      () async {
    final c = testController();
    final got = <GameEvent>[];
    c.events.listen(got.add);
    await c.init();

    final synced = c.state.withActiveSynced();
    for (final entry in (snap['meadows'] as Map).entries) {
      final before = meadowHerd(snap, entry.key as String);
      final after = synced.meadows[entry.key]!.herd;
      expect(
        [for (final x in after) (x.id, x.level)],
        [for (final x in before) (x['id'], x['level'])],
        reason: 'meadow ${entry.key}',
      );
      for (final x in after) {
        expect(x.pileId, isNull);
        expect(x.growth, 0);
      }
    }
    expect(c.placesUsed, c.state.herdCount);
    expect(CapyPiles.placesOf(c.state.herd), c.state.herdCount);
    expect(got.whereType<CapyNamed>(), isEmpty);
    expect(got.whereType<CapyGrew>(), isEmpty);
    expect(got.whereType<GladeUnlocked>(), isEmpty);
    expect(c.pileFlashId, isNull);

    // Written back: capys without pile fields read exactly as before.
    await c.flushSave();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(testSaveKey)!;
    expect(raw.contains('"pile"'), isFalse);
    expect(raw.contains('"grow"'), isFalse);
    c.dispose();
  });

  test('old capy JSON reads as a capy on its own', () {
    final json = (snap['herd'] as List).first as Map;
    final capy = Capybara.fromJson(Map<String, dynamic>.from(json));
    expect(capy.inPile, isFalse);
    expect(capy.growth, 0);
    expect(capy.toJson(), json);
  });
}
