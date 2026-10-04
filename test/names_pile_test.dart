import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capy_naming.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';

import 'support/test_game.dart';

/// Spec 006, Т4 (spec 004, С1): a baby grown to level two in a pile gets a
/// name; nobody loses theirs; the transitional merge rule is gone.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Capybara get(GameController c, String id) =>
      c.state.herd.firstWhere((e) => e.id == id);

  void run(GameController c, double seconds) {
    for (var t = 0.0; t < seconds; t += 0.25) {
      c.debugAdvance(0.25);
    }
  }

  test('three babies grow up as peers: three names, three messages',
      () async {
    final c = testController();
    final got = <GameEvent>[];
    c.events.listen(got.add);
    await c.init();
    for (var i = 0; i < 2; i++) {
      c.addProgress(1.0, fromTap: false);
    }
    final ids = [for (final capy in c.state.herd) capy.id];
    expect(ids, hasLength(3));
    expect(c.joinPile(ids[1], ids[0]), isTrue);
    expect(c.joinPile(ids[2], ids[0]), isTrue);
    for (final id in ids) {
      expect(get(c, id).isNamed, isFalse, reason: 'babies stay unnamed');
    }
    got.clear();
    run(c, BalanceV0.pilePeerSeconds(1) + 1);
    final names = <String>{};
    for (final id in ids) {
      final capy = get(c, id);
      expect(capy.level, 2);
      expect(capy.isNamed, isTrue);
      names.add(capy.nameKey!);
    }
    expect(names, hasLength(3), reason: 'names are unique on the land');
    final named = got.whereType<CapyNamed>().toList();
    expect(named.map((e) => e.capyId).toSet(), ids.toSet());
    for (final e in named) {
      expect(
        e.text,
        'Малыш подрос — теперь это ${get(c, e.capyId).displayNameRu}',
      );
    }
    c.dispose();
  });

  test('a named capy keeps its name in a pile and when it grows', () async {
    SharedPreferences.setMockInitialValues(
      herdSave([
        for (final id in ['a', 'b', 'c']) testCapy(id, 2, pile: 'p'),
      ]),
    );
    final c = testController();
    await c.init();
    final before = {for (final capy in c.state.herd) capy.id: capy.nameKey};
    expect(before.values.every((k) => k != null), isTrue);
    run(c, BalanceV0.pilePeerSeconds(2) + 1);
    for (final id in before.keys) {
      final capy = get(c, id);
      expect(capy.level, 3);
      expect(capy.nameKey, before[id]);
    }
    c.dispose();
  });

  test('nobody disappears: every name stays taken after a pile', () async {
    SharedPreferences.setMockInitialValues(
      herdSave([testCapy('a', 2, x: 0.3), testCapy('b', 2, x: 0.7)]),
    );
    final c = testController();
    await c.init();
    final a = get(c, 'a');
    final b = get(c, 'b');
    expect(c.joinPile('a', 'b'), isTrue);
    final used = LandNames.of(c.state.herd);
    expect(used.isTaken(a), isTrue);
    expect(used.isTaken(b), isTrue);
    expect(c.state.herdCount, 2);
    c.dispose();
  });
}
