import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

import 'support/test_game.dart';

/// Spec 004, С3: the player's own name — at once, free, kept.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<(GameController, Capybara)> grown(GamePersistence p) async {
    final c = testController(persistence: p);
    await c.init();
    for (var i = 0; i < 10 && c.state.herd.length < 3; i++) {
      c.addProgress(1.0, fromTap: false);
    }
    // Three babies in a pile grow up together (spec 006).
    final ids = [for (final x in c.state.herd) x.id];
    c.joinPile(ids[1], ids[0]);
    c.joinPile(ids[2], ids[0]);
    c.debugAdvance(BalanceV0.pilePeerSeconds(1) + 1);
    return (c, c.state.herd.firstWhere((x) => x.level == 2));
  }

  test('rename: trimmed, shown as is, kept after a restart', () async {
    final p = GamePersistence();
    final (c, capy) = await grown(p);
    expect(c.renameCapy(capy.id, '  Пух  '), isTrue);
    final renamed = c.state.herd.firstWhere((x) => x.id == capy.id);
    expect(renamed.displayNameRu, 'Пух');
    expect(renamed.customName, 'Пух');
    expect(renamed.nameKey, capy.nameKey, reason: 'game name stays');
    expect(renamed.trait, capy.trait);
    await c.flushSave();
    c.dispose();

    final again = testController(persistence: p);
    await again.init();
    expect(
      again.state.herd.firstWhere((x) => x.id == capy.id).displayNameRu,
      'Пух',
    );
    again.dispose();
  });

  test('empty name is refused, the old one stays', () async {
    final (c, capy) = await grown(GamePersistence());
    expect(c.renameCapy(capy.id, 'Пух'), isTrue);
    expect(c.renameCapy(capy.id, ''), isFalse);
    expect(c.renameCapy(capy.id, '    '), isFalse);
    expect(
      c.state.herd.firstWhere((x) => x.id == capy.id).displayNameRu,
      'Пух',
    );
    c.dispose();
  });

  test('at most 16 characters; costs nothing', () async {
    final (c, capy) = await grown(GamePersistence());
    final grass = c.state.grass;
    final uyut = c.state.uyut;
    expect(c.renameCapy(capy.id, 'Очень-очень-длинное имя'), isTrue);
    final name = c.state.herd.firstWhere((x) => x.id == capy.id).displayNameRu!;
    expect(name.length, lessThanOrEqualTo(16));
    expect(name, 'Очень-очень-длин');
    expect(c.state.grass, grass);
    expect(c.state.uyut, uyut);
    c.dispose();
  });

  test('a baby has no name to change', () async {
    final (c, _) = await grown(GamePersistence());
    final baby = c.state.herd.firstWhere((x) => x.level == 1);
    expect(c.renameCapy(baby.id, 'Пух'), isFalse);
    expect(c.renameCapy('nobody', 'Пух'), isFalse);
    c.dispose();
  });

  test('a capy on another meadow can be renamed', () async {
    final (c, capy) = await grown(GamePersistence());
    // Grow until a second meadow opens, then go there.
    growFamily(c, () => c.state.sunnyGladeAnnounced >= 1);
    expect(c.state.sunnyGladeAnnounced, greaterThanOrEqualTo(1));
    final home = c.state.activeMeadowId;
    final named = c.state.herd.firstWhere((x) => x.isNamed);
    expect(c.switchToMeadow(c.unlockedMeadowIds[1]), isTrue);
    expect(c.renameCapy(named.id, 'Соседушка'), isTrue);
    final there = c.state.meadows[home]!.herd.firstWhere(
      (x) => x.id == named.id,
    );
    expect(there.displayNameRu, 'Соседушка');
    expect(capy.isNamed, isTrue);
    c.dispose();
  });
}
