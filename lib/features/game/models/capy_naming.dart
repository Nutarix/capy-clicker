import 'dart:math';

import 'capy_names.dart';
import 'capybara.dart';

/// Names and traits already worn on one land (all its meadows).
class LandNames {
  LandNames();

  /// Everyone on a land; babies and the unnamed are skipped.
  LandNames.of(Iterable<Capybara> capys) {
    for (final c in capys) {
      add(c);
    }
  }

  /// Game name keys in plain form («Шишка»).
  final Set<String> _plain = {};

  /// `key|trait` of names with a trait («Шишка-соня»).
  final Set<String> _pairs = {};

  static String _pair(String key, CapyTrait trait) => '$key|${trait.id}';

  void add(Capybara c) {
    final key = c.nameKey;
    if (key == null) return;
    final trait = c.trait;
    if (c.nameEpithet && trait != null) {
      _pairs.add(_pair(key, trait));
    } else {
      _plain.add(key);
    }
  }

  bool isTaken(Capybara c) {
    final key = c.nameKey;
    if (key == null) return false;
    final trait = c.trait;
    if (c.nameEpithet && trait != null) {
      return _pairs.contains(_pair(key, trait));
    }
    return _plain.contains(key);
  }

  bool _plainFree(String key) => !_plain.contains(key);

  bool _pairFree(String key, CapyTrait trait) =>
      !_pairs.contains(_pair(key, trait));
}

/// Picks a name and a trait (spec 004, Т2, `docs/NAMES.md`).
///
/// Its own [Random] per capy, seeded from the land chapter and the capy id:
/// the game's random stream is never touched (Т3), and the same capy on the
/// same land always gets the same pick.
abstract final class CapyNaming {
  /// Stable seed: no `String.hashCode` (not fixed across runs).
  static int seedFor(int landChapter, String capyId) {
    var h = 0x4E414D45 ^ (landChapter * 0x2F1B);
    for (final unit in capyId.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return h;
  }

  /// [capy] with a name and a trait. Already named → returned as is.
  ///
  /// 1. A name nobody on this land wears.
  /// 2. All hundred taken: name with the capy's trait («Шишка-соня»).
  /// 3. That pair taken too: another name with the same trait.
  /// 4. Every pair of that trait taken: another trait with a free pair.
  ///
  /// Does not add the result to [used]: the caller does, once it is placed.
  static Capybara assign(
    Capybara capy, {
    required LandNames used,
    required int landChapter,
  }) {
    if (capy.isNamed) return capy;
    final rng = Random(seedFor(landChapter, capy.id));
    final trait = CapyTrait.values[rng.nextInt(CapyTrait.values.length)];

    final plain = [
      for (final n in CapyNames.all)
        if (used._plainFree(n.key)) n,
    ];
    if (plain.isNotEmpty) {
      final name = plain[rng.nextInt(plain.length)];
      return capy.copyWith(nameKey: name.key, trait: trait);
    }

    final start = trait.index;
    for (var k = 0; k < CapyTrait.values.length; k++) {
      final t = CapyTrait.values[(start + k) % CapyTrait.values.length];
      final free = [
        for (final n in CapyNames.all)
          if (used._pairFree(n.key, t)) n,
      ];
      if (free.isEmpty) continue;
      final name = free[rng.nextInt(free.length)];
      return capy.copyWith(nameKey: name.key, nameEpithet: true, trait: t);
    }

    // Six hundred on one land: a repeat rather than no name.
    final name = CapyNames.all[rng.nextInt(CapyNames.all.length)];
    return capy.copyWith(nameKey: name.key, trait: trait);
  }
}
