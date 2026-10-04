import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/test_game.dart';

const _key = 'capy_clicker_game_state_v1';

/// A real save of the 1.0.7 build, with a few levels raised so the live land
/// has grown capys on two meadows and the old land's active herd too.
Map<String, dynamic> _save() {
  final snap = jsonDecode(
    File('test/fixtures/save_v1_snapshot.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  void raise(List<dynamic> herd, String id, int level) {
    for (final c in herd) {
      if ((c as Map)['id'] == id) c['level'] = level;
    }
  }

  final meadows = snap['meadows'] as Map<String, dynamic>;
  raise(snap['herd'] as List, 'c85', 2);
  raise((meadows['warm_edge'] as Map)['herd'] as List, 'c85', 2);
  raise((meadows['berry_glade'] as Map)['herd'] as List, 'c89', 3);
  final old = (snap['otherLands'] as List).single as Map<String, dynamic>;
  raise(old['herd'] as List, 'c82', 2);
  raise(
    ((old['meadows'] as Map)['mist_edge'] as Map)['herd'] as List,
    'c82',
    2,
  );
  return snap;
}

/// Every capy of every meadow of [land] (`meadows` of a state or a land).
List<Capybara> _all(Map<String, dynamic> land) => [
  for (final m in (land['meadows'] as Map).values)
    for (final c in (m as Map)['herd'] as List)
      Capybara.fromJson(Map<String, dynamic>.from(c as Map)),
];

/// Spec 004, С5: an old save gets names and traits quietly.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({_key: jsonEncode(_save())});
  });

  test('every grown capy on every meadow and old land is named', () async {
    final c = testController();
    final got = <GameEvent>[];
    c.events.listen(got.add);
    await c.init();
    expect(got.whereType<CapyNamed>(), isEmpty, reason: 'quietly');

    final json = c.state.toJson();
    final lands = [json, ...(json['otherLands'] as List).cast<Map>()];
    var grown = 0;
    for (final land in lands) {
      final capys = _all(Map<String, dynamic>.from(land));
      final shown = <String>{};
      for (final capy in capys) {
        if (capy.level < 2) {
          expect(capy.isNamed, isFalse, reason: '${capy.id} is a baby');
          continue;
        }
        grown++;
        expect(capy.isNamed, isTrue, reason: capy.id);
        expect(capy.trait, isNotNull, reason: capy.id);
        expect(shown.add(capy.displayNameRu!), isTrue, reason: 'repeat');
      }
    }
    // Live: c85, c89. Old land: eight of level 3, c79, c81, c82.
    expect(grown, 13);

    // Active herd and its meadow copy agree, on both lands.
    final live = {for (final capy in c.state.herd) capy.id: capy};
    for (final capy in c.state.meadows[c.state.activeMeadowId]!.herd) {
      expect(capy, live[capy.id]);
    }
    final old = c.state.otherLands.single;
    final oldActive = old.meadows[old.activeMeadowId]!.herd;
    expect(old.herd, oldActive);
    expect(old.herd.firstWhere((x) => x.id == 'c82').isNamed, isTrue);
    c.dispose();
  });

  test('nothing else changes; names stay after the next load', () async {
    final persistence = GamePersistence();
    final c = testController(persistence: persistence);
    await c.init();
    final first = c.state.toJson();
    await c.flushSave();
    c.dispose();

    // Strip the new keys: the rest is the save as it was (plus the offline
    // and load bookkeeping that ran before spec 004 too).
    final plain = testController(
      persistence: GamePersistence(),
      debugNames: false,
    );
    SharedPreferences.setMockInitialValues({_key: jsonEncode(_save())});
    await plain.init();
    expect(_strip(first), plain.state.toJson());
    plain.dispose();

    final again = testController(persistence: persistence);
    SharedPreferences.setMockInitialValues({_key: jsonEncode(first)});
    await again.init();
    expect(_names(again.state), _names(GameState.fromJson(first)));
    again.dispose();
  });
}

Object? _strip(Object? v) {
  if (v is Map) {
    return {
      for (final e in v.entries)
        if (!const {'name', 'epithet', 'customName', 'trait'}.contains(e.key))
          e.key: _strip(e.value),
    };
  }
  if (v is List) return [for (final e in v) _strip(e)];
  return v;
}

Map<String, String?> _names(GameState s) => {
  for (final capy in _all(s.toJson())) capy.id: capy.displayNameRu,
  for (final land in s.otherLands)
    for (final capy in _all(land.toJson()))
      'old ${capy.id}': capy.displayNameRu,
};
