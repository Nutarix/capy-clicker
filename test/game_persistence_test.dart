import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/test_game.dart';

const _key = 'capy_clicker_game_state_v1';
const _prevKey = 'capy_clicker_game_state_v1_prev';
const _brokenKey = 'capy_clicker_game_state_v1_broken';

const _garbage = '{"herdProgress":0.3,"herd":[{"id":"c1","lev';
const _garbage2 = '[1,2,3]';

GameState _family(int grass, {int capys = 2}) => GameState(
  herdProgress: 0.25,
  nextId: capys + 1,
  grass: grass,
  herd: [
    for (var i = 1; i <= capys; i++)
      Capybara(id: 'c$i', level: 1, position: Offset(0.3 + i * 0.1, 0.7)),
  ],
);

String _raw(GameState s) => jsonEncode(s.toJson());

/// Prefs like on a phone: the value is visible at once, the disk write
/// takes a moment (a removal less than a big write). Lets two operations
/// overlap the way they do on device.
class _SlowPrefs extends Fake implements SharedPreferences {
  final Map<String, Object> values = {};

  Future<bool> _disk(int ms) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return true;
  }

  @override
  Object? get(String key) => values[key];

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<bool> setString(String key, String value) {
    values[key] = value;
    return _disk(6);
  }

  @override
  Future<bool> remove(String key) {
    values.remove(key);
    return _disk(1);
  }
}

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

/// Raw blobs set aside for a look later, oldest first.
Future<List<String>> _setAside() async {
  final raw = (await _prefs()).getString(_brokenKey);
  if (raw == null) return const [];
  return [for (final e in jsonDecode(raw) as List) (e as Map)['raw'] as String];
}

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

    test('the written map reads back as its JSON string does (002, Т5)', () {
      // The save checks readability on the map it encodes, not on a parse
      // of the string. Both must read the same family.
      final map = GameState.fromJson(_snapshot()).toJson();
      final viaMap = GameState.fromJson(map).toJson();
      final viaString = GameState.fromJson(
        jsonDecode(jsonEncode(map)) as Map<String, dynamic>,
      ).toJson();
      expect(jsonEncode(viaMap), jsonEncode(viaString));
      expect(jsonEncode(viaMap), jsonEncode(map));
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

  group('two copies (Т5, Т6)', () {
    test('each save keeps the previous one as the copy', () async {
      final p = GamePersistence();
      await p.save(_family(1));
      await p.save(_family(2));
      final prefs = await _prefs();
      expect(prefs.getString(_key), _raw(_family(2)));
      expect(prefs.getString(_prevKey), _raw(_family(1)));
    });

    test('copy is taken from a readable main on the first save', () async {
      SharedPreferences.setMockInitialValues({_key: _raw(_family(7))});
      await GamePersistence().save(_family(8));
      final prefs = await _prefs();
      expect(prefs.getString(_key), _raw(_family(8)));
      expect(prefs.getString(_prevKey), _raw(_family(7)));
    });

    test('unreadable main: loads the copy, sets the main aside', () async {
      SharedPreferences.setMockInitialValues({
        _key: _garbage,
        _prevKey: _raw(_family(5, capys: 3)),
      });
      final state = await GamePersistence().load();
      expect(state, isNotNull);
      expect(state!.grass, 5);
      expect(state.herdCount, 3);
      expect(await _setAside(), [_garbage]);
    });

    test('set-aside data survives the saves that follow', () async {
      SharedPreferences.setMockInitialValues({
        _key: _garbage,
        _prevKey: _raw(_family(5)),
      });
      final p = GamePersistence();
      await p.load();
      await p.save(_family(6));
      await p.save(_family(7));
      final prefs = await _prefs();
      expect(prefs.getString(_key), _raw(_family(7)));
      expect(prefs.getString(_prevKey), _raw(_family(6)));
      expect(await _setAside(), [_garbage]);
    });

    test('both unreadable: new game, both set aside and kept', () async {
      SharedPreferences.setMockInitialValues({
        _key: _garbage,
        _prevKey: _garbage2,
      });
      final p = GamePersistence();
      expect(await p.load(), isNull);
      await p.save(_family(1));
      await p.save(_family(2));
      expect(await _setAside(), [_garbage, _garbage2]);
      expect((await _prefs()).getString(_key), _raw(_family(2)));
    });

    test('later corruption is set aside next to the earlier one', () async {
      SharedPreferences.setMockInitialValues({
        _key: _garbage,
        _prevKey: _raw(_family(5)),
      });
      await GamePersistence().load();
      final prefs = await _prefs();
      await prefs.setString(_key, _garbage2);
      await GamePersistence().load();
      expect(await _setAside(), [_garbage, _garbage2]);
    });

    test('no main save: the copy is not raised', () async {
      SharedPreferences.setMockInitialValues({_prevKey: _raw(_family(5))});
      expect(await GamePersistence().load(), isNull);
      expect(await GamePersistence().hasSave(), isFalse);
    });

    test('clear drops main and copy, keeps set-aside data', () async {
      SharedPreferences.setMockInitialValues({
        _key: _garbage,
        _prevKey: _raw(_family(5)),
      });
      final p = GamePersistence();
      await p.load();
      await p.save(_family(6));
      await p.clear();
      final prefs = await _prefs();
      expect(prefs.getString(_key), isNull);
      expect(prefs.getString(_prevKey), isNull);
      expect(await _setAside(), [_garbage]);
      expect(await p.load(), isNull);
    });
  });

  group('controller on a damaged save (С4)', () {
    test('unreadable main: the family comes back from the copy', () async {
      SharedPreferences.setMockInitialValues({
        _key: _garbage,
        _prevKey: _raw(_family(9, capys: 3)),
      });
      final c = testController();
      await c.init();
      expect(c.state.herdCount, 3);
      expect(c.state.grass, 9);
      c.dispose();
    });

    test('both unreadable: new family, damaged data stays aside', () async {
      SharedPreferences.setMockInitialValues({
        _key: _garbage,
        _prevKey: _garbage2,
      });
      final c = testController();
      await c.init();
      expect(c.state.herdCount, BalanceV0.startingHerdSize);
      c.addProgress(1.0, fromTap: true);
      c.dispose();
      await pumpEventQueue();
      expect(await _setAside(), [_garbage, _garbage2]);
      final main = await GamePersistence().load();
      expect(main!.herdCount, BalanceV0.startingHerdSize + 1);
    });
  });

  group('one write at a time (Т8)', () {
    test(
      'a save started before clear does not bring the family back',
      () async {
        final slow = _SlowPrefs();
        final p = GamePersistence(prefs: slow);
        await p.save(_family(1));
        final late = p.save(_family(2)); // exit to menu, not awaited
        final wipe = p.clear(); // «Заново» right after
        await Future.wait([late, wipe]);
        expect(slow.values[_key], isNull);
        expect(slow.values[_prevKey], isNull);
        expect(await p.load(), isNull);
      },
    );

    test('load waits for the save in flight', () async {
      final p = GamePersistence(prefs: _SlowPrefs());
      await p.save(_family(3));
      final saving = p.save(_family(4)); // exit to menu, not awaited
      final loaded = await p.load(); // menu checks «Продолжить»
      await saving;
      expect(loaded?.grass, 4);
    });
  });
}
