import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/capy_names.dart';
import 'package:capy_clicker/features/game/models/capy_naming.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';

/// Spec 004, Т2, С6: a free name on this land, then name with trait.
void main() {
  Capybara capy(String id, {int level = 2}) =>
      Capybara(id: id, level: level, position: const Offset(0.5, 0.5));

  test('same land and id → same name and trait (own stream)', () {
    final a = CapyNaming.assign(capy('c5'), used: LandNames(), landChapter: 0);
    final b = CapyNaming.assign(capy('c5'), used: LandNames(), landChapter: 0);
    expect(a.nameKey, isNotNull);
    expect(a.trait, isNotNull);
    expect(a.nameEpithet, isFalse);
    expect(b.nameKey, a.nameKey);
    expect(b.trait, a.trait);
  });

  test('a hundred capys on one land: a hundred different names', () {
    final used = LandNames();
    final keys = <String>{};
    final traits = <CapyTrait>{};
    for (var i = 0; i < 100; i++) {
      final named = CapyNaming.assign(capy('c$i'), used: used, landChapter: 0);
      expect(named.nameEpithet, isFalse, reason: 'plain names first');
      expect(keys.add(named.nameKey!), isTrue, reason: 'repeat at $i');
      traits.add(named.trait!);
      used.add(named);
    }
    expect(keys, hasLength(100));
    expect(traits, hasLength(CapyTrait.values.length));
  });

  test('all hundred taken → name with trait, never a repeat (С6)', () {
    final used = LandNames();
    for (final n in CapyNames.all) {
      used.add(
        Capybara(
          id: 'x${n.key}',
          level: 2,
          position: Offset.zero,
          nameKey: n.key,
          trait: CapyTrait.fidget,
        ),
      );
    }
    final seen = <String>{};
    for (var i = 0; i < 300; i++) {
      final named = CapyNaming.assign(capy('c$i'), used: used, landChapter: 3);
      expect(named.nameEpithet, isTrue);
      final shown = named.displayNameRu!;
      expect(shown, contains('-'));
      expect(shown, endsWith('-${named.trait!.epithetRu}'));
      expect(seen.add(shown), isTrue, reason: 'repeat $shown');
      used.add(named);
    }
  });

  test('pair taken → another name with the same trait', () {
    final used = LandNames();
    for (final n in CapyNames.all) {
      used.add(
        Capybara(
          id: 'x${n.key}',
          level: 2,
          position: Offset.zero,
          nameKey: n.key,
          trait: CapyTrait.cuddler,
        ),
      );
    }
    final first = CapyNaming.assign(
      capy('c1'),
      used: LandNames(),
      landChapter: 0,
    );
    final trait = first.trait!;
    // Every pair of this trait but one is taken.
    for (final n in CapyNames.all.skip(1)) {
      used.add(
        Capybara(
          id: 'y${n.key}',
          level: 2,
          position: Offset.zero,
          nameKey: n.key,
          nameEpithet: true,
          trait: trait,
        ),
      );
    }
    final named = CapyNaming.assign(capy('c1'), used: used, landChapter: 0);
    expect(named.trait, trait);
    expect(named.nameEpithet, isTrue);
    expect(named.nameKey, CapyNames.all.first.key);
  });

  test('freed name can be taken again', () {
    final used = LandNames();
    final a = CapyNaming.assign(capy('c1'), used: used, landChapter: 0);
    used.add(a);
    expect(used.isTaken(a), isTrue);
    final rebuilt = LandNames.of([capy('c9', level: 1)]);
    expect(rebuilt.isTaken(a), isFalse);
  });

  test('a baby and the already named are kept as is', () {
    final used = LandNames();
    final named = CapyNaming.assign(capy('c1'), used: used, landChapter: 0);
    expect(CapyNaming.assign(named, used: used, landChapter: 0), same(named));
  });
}
