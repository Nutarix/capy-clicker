import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/capy_names.dart';
import 'package:capy_clicker/features/game/models/capy_naming.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';

import 'support/test_game.dart';

/// Spec 004, С1 and the transitional merge rule.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Grow until [n] babies stand on the meadow.
  void babies(GameController c, int n) {
    for (var i = 0; i < 50 && c.state.herd.length < n; i++) {
      c.addProgress(1.0, fromTap: false);
    }
    expect(c.state.herd.length, greaterThanOrEqualTo(n));
  }

  List<Capybara> atLevel(GameController c, int level) => [
    for (final capy in c.state.herd)
      if (capy.level == level) capy,
  ];

  test('two babies → level 2 with a name, a trait and one message', () async {
    final c = testController();
    final got = <GameEvent>[];
    c.events.listen(got.add);
    await c.init();
    babies(c, 2);
    for (final capy in c.state.herd) {
      expect(capy.isNamed, isFalse, reason: 'babies stay unnamed');
    }
    got.clear();
    final pair = atLevel(c, 1);
    expect(c.tryMerge(pair[0].id, pair[1].id), isTrue);
    final grown = atLevel(c, 2).single;
    expect(grown.isNamed, isTrue);
    expect(grown.trait, isNotNull);
    final named = got.whereType<CapyNamed>().toList();
    expect(named, hasLength(1));
    expect(named.single.capyId, grown.id);
    expect(
      named.single.text,
      'Малыш подрос — теперь это ${grown.displayNameRu}',
    );
    // Saved with the capy.
    final again = Capybara.fromJson(grown.toJson());
    expect(again.nameKey, grown.nameKey);
    expect(again.trait, grown.trait);
    c.dispose();
  });

  test('two named → the target keeps its name, no message', () async {
    final c = testController();
    final got = <GameEvent>[];
    c.events.listen(got.add);
    await c.init();
    babies(c, 4);
    var ones = atLevel(c, 1);
    c.tryMerge(ones[0].id, ones[1].id);
    ones = atLevel(c, 1);
    c.tryMerge(ones[0].id, ones[1].id);
    final twos = atLevel(c, 2);
    expect(twos, hasLength(2));
    final dragged = twos[0];
    final target = twos[1];
    expect(dragged.nameKey, isNot(target.nameKey));
    got.clear();
    expect(c.tryMerge(dragged.id, target.id), isTrue);
    final three = atLevel(c, 3).single;
    expect(three.nameKey, target.nameKey);
    expect(three.trait, target.trait);
    expect(three.displayNameRu, target.displayNameRu);
    expect(got.whereType<CapyNamed>(), isEmpty);
    c.dispose();
  });

  test('rule: target name, else dragged name, else a new one', () {
    final named = Capybara(
      id: 'a',
      level: 2,
      position: Offset.zero,
      nameKey: 'button',
      customName: 'Пух',
      trait: CapyTrait.dreamer,
    );
    final other = Capybara(
      id: 'b',
      level: 2,
      position: Offset.zero,
      nameKey: 'pip',
      trait: CapyTrait.fidget,
    );
    final baby = Capybara(id: 'c', level: 2, position: Offset.zero);
    expect(CapyNaming.mergeKeeps(dragged: other, target: named), same(named));
    expect(CapyNaming.mergeKeeps(dragged: named, target: other), same(other));
    expect(CapyNaming.mergeKeeps(dragged: named, target: baby), same(named));
    expect(CapyNaming.mergeKeeps(dragged: baby, target: other), same(other));
    expect(CapyNaming.mergeKeeps(dragged: baby, target: baby), isNull);
    final merged = CapyNaming.inherit(
      Capybara(id: 'n', level: 3, position: Offset.zero),
      from: named,
    );
    expect(merged.nameKey, 'button');
    expect(merged.customName, 'Пух');
    expect(merged.trait, CapyTrait.dreamer);
    expect(merged.id, 'n');
  });

  test('freed name: the dragged one\'s name may be given again', () async {
    final c = testController();
    await c.init();
    babies(c, 4);
    var ones = atLevel(c, 1);
    c.tryMerge(ones[0].id, ones[1].id);
    ones = atLevel(c, 1);
    c.tryMerge(ones[0].id, ones[1].id);
    final twos = atLevel(c, 2);
    c.tryMerge(twos[0].id, twos[1].id);
    final used = LandNames.of([
      for (final m in c.state.withActiveSynced().meadows.values) ...m.herd,
    ]);
    expect(used.isTaken(twos[0]), isFalse);
    expect(used.isTaken(twos[1]), isTrue);
    c.dispose();
  });
}
