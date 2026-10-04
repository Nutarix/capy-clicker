import '../models/capy_names.dart';
import '../models/capy_naming.dart';
import '../models/capybara.dart';
import '../models/family_land.dart';
import '../models/game_state.dart';
import '../models/meadow_snapshot.dart';
import 'game_core.dart';

/// Names and traits (spec 004): the name at level two, the quiet naming of
/// an old save, the player's own name.
///
/// Picks run on [CapyNaming]'s own seed, never on the game's random stream:
/// the rest of the game draws the same numbers as before (Т3).
class GameNames extends GamePart {
  GameNames(super.core);

  /// Level from which a capy has a name.
  static const int namedFromLevel = 2;

  /// Names worn on the live land, all meadows. [except] are not counted
  /// (the two capys a merge removes).
  LandNames usedOnLand(GameState state, {Set<String> except = const {}}) {
    final used = LandNames();
    for (final snap in state.withActiveSynced().meadows.values) {
      for (final c in snap.herd) {
        if (!except.contains(c.id)) used.add(c);
      }
    }
    return used;
  }

  /// A merge made [merged] from [dragged] onto [target] (transitional rule
  /// until spec 006). Queues «Малыш подрос…» when a new name was given.
  Capybara nameMerged(
    Capybara merged, {
    required Capybara dragged,
    required Capybara target,
  }) {
    final keep = CapyNaming.mergeKeeps(dragged: dragged, target: target);
    if (keep != null) return CapyNaming.inherit(merged, from: keep);
    if (!core.namesEnabled || merged.level < namedFromLevel) return merged;
    final named = CapyNaming.assign(
      merged,
      used: usedOnLand(state, except: {dragged.id, target.id}),
      landChapter: state.landChapter,
    );
    core.messages.capyNamed(
      'Малыш подрос — теперь это ${named.listNameRu}',
      named.id,
    );
    return named;
  }

  /// Old save: every capy of level two and up gets a name, quietly. Each
  /// land on its own: the live one (all meadows), then every archived one.
  GameState migrate(GameState state) {
    if (!core.namesEnabled) return state;
    final synced = state.withActiveSynced();
    final meadows = _nameMeadows(synced.meadows, synced.landChapter);
    var next = state;
    if (meadows != null) {
      final active = meadows[synced.activeMeadowId]!;
      next = synced.copyWith(meadows: meadows, herd: active.herd);
    }
    List<FamilyLand>? lands;
    for (var i = 0; i < next.otherLands.length; i++) {
      final land = next.otherLands[i];
      final named = _nameLand(land);
      if (identical(named, land)) continue;
      lands ??= List<FamilyLand>.of(next.otherLands);
      lands[i] = named;
    }
    if (lands != null) next = next.copyWith(otherLands: lands);
    return next;
  }

  /// Named copies of [meadows], or null when nobody needed a name.
  Map<String, MeadowSnapshot>? _nameMeadows(
    Map<String, MeadowSnapshot> meadows,
    int chapter, {
    Map<String, Capybara>? named,
  }) {
    final used = LandNames();
    for (final snap in meadows.values) {
      for (final c in snap.herd) {
        used.add(c);
      }
    }
    final given = named ?? <String, Capybara>{};
    Map<String, MeadowSnapshot>? out;
    for (final entry in meadows.entries) {
      List<Capybara>? herd;
      final list = entry.value.herd;
      for (var i = 0; i < list.length; i++) {
        final c = list[i];
        if (c.isNamed || c.level < namedFromLevel) continue;
        var n = given[c.id];
        if (n == null) {
          n = CapyNaming.assign(c, used: used, landChapter: chapter);
          used.add(n);
          given[c.id] = n;
        }
        herd ??= List<Capybara>.of(list);
        herd[i] = n;
      }
      if (herd == null) continue;
      out ??= Map<String, MeadowSnapshot>.of(meadows);
      out[entry.key] = entry.value.copyWith(herd: herd);
    }
    return out;
  }

  /// An archived land: its meadows, and its active herd copy (same capys,
  /// same names).
  FamilyLand _nameLand(FamilyLand land) {
    final given = <String, Capybara>{};
    final meadows = Map<String, MeadowSnapshot>.of(land.meadows);
    if (!meadows.containsKey(land.activeMeadowId)) {
      meadows[land.activeMeadowId] = MeadowSnapshot(
        herd: land.herd,
        herdProgress: land.herdProgress,
        twinIdA: land.twinIdA,
        twinIdB: land.twinIdB,
      );
    }
    final named = _nameMeadows(meadows, land.chapter, named: given);
    final herdNeeds = land.herd.any(
      (c) => !c.isNamed && c.level >= namedFromLevel,
    );
    if (named == null && !herdNeeds) return land;
    final herd = [for (final c in land.herd) given[c.id] ?? c];
    return FamilyLand(
      chapter: land.chapter,
      meadows: named == null
          ? land.meadows
          : {
              for (final e in named.entries)
                if (land.meadows.containsKey(e.key)) e.key: e.value,
            },
      activeMeadowId: land.activeMeadowId,
      sunnyGladeAnnounced: land.sunnyGladeAnnounced,
      mistyBiomeUnlocked: land.mistyBiomeUnlocked,
      sessionGoalIndex: land.sessionGoalIndex,
      placedDecor: land.placedDecor,
      visitedMist: land.visitedMist,
      herdProgress: land.herdProgress,
      herd: herd,
      twinIdA: land.twinIdA,
      twinIdB: land.twinIdB,
    );
  }

  /// The player's own name for a named capy on any meadow of this land.
  /// Trimmed, at most [CapyNames.maxCustomLength] characters, never empty.
  bool rename(String capyId, String text) {
    final clean = cleanCustomName(text);
    if (clean == null) return false;
    final synced = state.withActiveSynced();
    final meadows = Map<String, MeadowSnapshot>.of(synced.meadows);
    for (final entry in synced.meadows.entries) {
      final list = entry.value.herd;
      final i = list.indexWhere((c) => c.id == capyId);
      if (i < 0) continue;
      final capy = list[i];
      if (!capy.isNamed) return false;
      final herd = List<Capybara>.of(list);
      herd[i] = capy.copyWith(customName: clean);
      meadows[entry.key] = entry.value.copyWith(herd: herd);
      final active = meadows[synced.activeMeadowId]!;
      core.commit(synced.copyWith(meadows: meadows, herd: active.herd));
      return true;
    }
    return false;
  }

  /// Trim, cut to [CapyNames.maxCustomLength] characters; empty → null.
  static String? cleanCustomName(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final runes = trimmed.runes.toList();
    if (runes.length <= CapyNames.maxCustomLength) return trimmed;
    return String.fromCharCodes(runes.take(CapyNames.maxCustomLength))
        .trimRight();
  }
}
