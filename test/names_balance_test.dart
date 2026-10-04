import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/fingerprint.dart';

/// Spec 004, Т12: names and traits do not touch the numbers.
///
/// One long session — grow, merge at every level, taps, berry, mud, glades,
/// the misty grove, the rocket, a visit back, save and load — played twice
/// on the same seed: with names and with naming switched off. Every probe
/// of the game (state and every public number) is the same once the name
/// fields are taken out. The balance sims check the same through their
/// fingerprints (`tool/fingerprint_names_diff.py`).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<List<String>> play({required bool names}) async {
    SharedPreferences.setMockInitialValues({});
    var clock = DateTime.utc(2026, 9, 22, 7);
    final persistence = GamePersistence();
    var c = GameController(
      persistence: persistence,
      random: Random(404),
      now: () => clock,
      autoTick: false,
      debugNames: names,
    );
    await c.init();
    final probes = <String>[];
    var namedSeen = 0;
    void mark(String step) {
      namedSeen += c.state.herd.where((x) => x.isNamed).length;
      probes.add(jsonEncode({'step': step, ..._strip(probe(c))}));
    }

    void adv(double seconds) {
      var left = seconds;
      while (left > 1e-9) {
        final dt = left < 0.25 ? left : 0.25;
        clock = clock.add(Duration(microseconds: (dt * 1e6).round()));
        c.debugAdvance(dt);
        left -= dt;
      }
    }

    bool mergeLowest() {
      final byLevel = <int, List<Capybara>>{};
      for (final x in c.state.herd) {
        byLevel.putIfAbsent(x.level, () => []).add(x);
      }
      for (final lv in byLevel.keys.toList()..sort()) {
        final list = byLevel[lv]!;
        if (list.length >= 2) return c.tryMerge(list[1].id, list[0].id);
      }
      return false;
    }

    void grow(bool Function() done, {int rounds = 900}) {
      for (var i = 0; i < rounds && !done(); i++) {
        if (c.state.herdCount < c.effectiveMaxHerdSize) {
          c.addProgress(1.0, fromTap: false);
        } else {
          mergeLowest();
        }
        if (i % 7 == 0) c.onFlowerTap();
        if (i % 23 == 0) {
          c.debugShowBerry();
          c.onBerryTap();
        }
        if (i % 31 == 0 && c.state.herd.isNotEmpty) {
          c.debugPlaceMud(const Offset(0.48, 0.84), seconds: 4);
          c.tryMudWallow(c.state.herd.last.id);
        }
        adv(0.5);
        if (i % 40 == 0) mark('grow $i');
      }
    }

    mark('init');
    grow(() => c.state.sunnyGladeAnnounced >= 3 && c.state.maxCapyLevel >= 4);
    mark('great meadow');
    grow(() => c.state.mistyBiomeUnlocked, rounds: 400);
    mark('misty');
    expect(c.switchToMeadow(WorldZones.mistEdgeMeadowId), isTrue);
    adv(3);
    mark('in the mist');
    expect(c.rocketUnlocked, isTrue);
    expect(c.launchToNewLand(), isTrue);
    mark('new land');
    grow(() => c.state.sunnyGladeAnnounced >= 1, rounds: 300);
    mark('new land grown');
    expect(c.visitLand(0), isTrue);
    mark('visit back');
    await c.flushSave();
    c.dispose();
    clock = clock.add(const Duration(minutes: 3));
    c = GameController(
      persistence: persistence,
      random: Random(405),
      now: () => clock,
      autoTick: false,
      debugNames: names,
    );
    await c.init();
    mark('loaded');
    grow(() => false, rounds: 120);
    mark('end');
    if (names) {
      expect(namedSeen, greaterThan(20), reason: 'names were given');
    } else {
      expect(namedSeen, 0);
    }
    c.dispose();
    return probes;
  }

  test('same session with and without names: same numbers', () async {
    final withNames = await play(names: true);
    final without = await play(names: false);
    expect(withNames.length, without.length);
    for (var i = 0; i < withNames.length; i++) {
      expect(withNames[i], without[i], reason: 'probe $i');
    }
  });
}

/// Name, epithet, own name and trait out of every capy.
Map<String, Object?> _strip(Map<String, Object?> probe) =>
    _walk(probe) as Map<String, Object?>;

Object? _walk(Object? v) {
  if (v is Map) {
    final capy = v.containsKey('id') && v.containsKey('level');
    return <String, Object?>{
      for (final e in v.entries)
        if (!capy ||
            !const {'name', 'epithet', 'customName', 'trait'}.contains(e.key))
          e.key as String: _walk(e.value),
    };
  }
  if (v is List) return [for (final e in v) _walk(e)];
  return v;
}
