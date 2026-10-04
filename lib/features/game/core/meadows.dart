import '../models/balance.dart';
import '../models/capybara.dart';
import '../models/game_state.dart';
import '../models/meadow_snapshot.dart';
import '../models/world_zones.dart';
import 'game_core.dart';

/// Meadows of this land: glade circles opening with family power, the misty
/// grove, starter families of new meadows, the forest-map switch.
class GameMeadows extends GamePart {
  GameMeadows(super.core);

  /// Active named meadow (fixed Sunny Glade identity — Phase 2 forest map).
  SunnyGlade get currentGlade => WorldZones.gladeById(state.activeMeadowId);

  /// Walkable / camera key for the **active named meadow** (fixed rect, not
  /// expanding with local herd).
  int get meadowKey => currentGlade.minHerd;

  /// Meadow ids unlocked so far (forest map chips).
  List<String> get unlockedMeadowIds => state.unlockedMeadowIds;

  /// Herd size on a meadow (active uses live fields).
  int herdCountForMeadow(String meadowId) {
    if (meadowId == state.activeMeadowId) return state.herdCount;
    return state.meadows[meadowId]?.herdCount ?? 0;
  }

  /// Unlock named meadows when active herd reaches glade bands; seed starters.
  GameState syncGladeAnnounced(GameState state, {required bool announce}) {
    final reached = WorldZones.gladeForFamilyPower(state.familyPower);
    if (reached.index <= state.sunnyGladeAnnounced) return state;

    var nextId = state.nextId;
    final meadows = Map<String, MeadowSnapshot>.from(
      state.withActiveSynced().meadows,
    );

    for (var i = state.sunnyGladeAnnounced + 1; i <= reached.index; i++) {
      final g = WorldZones.glades[i];
      final existing = meadows[g.id];
      if (existing == null || existing.herd.isEmpty) {
        final built = core.herd.buildStarterHerd(
          meadowId: g.id,
          startNextId: nextId,
          count: BalanceV0.meadowStarterHerdSize,
        );
        nextId = built.nextId;
        meadows[g.id] = MeadowSnapshot(herd: built.herd);
      }
    }

    if (announce && core.ready && reached.unlockToastRu.isNotEmpty) {
      core.messages.announceGlade(reached.unlockToastRu);
      return state.copyWith(
        sunnyGladeAnnounced: reached.index,
        grass: state.grass + BalanceV0.gladeUnlockGrass,
        meadows: meadows,
        nextId: nextId,
      );
    }
    return state.copyWith(
      sunnyGladeAnnounced: reached.index,
      meadows: meadows,
      nextId: nextId,
    );
  }

  /// After legacy migrate: empty unlocked meadows get a small starter herd.
  GameState fillEmptyUnlockedMeadows(GameState state) {
    var nextId = state.nextId;
    final meadows = Map<String, MeadowSnapshot>.from(
      state.withActiveSynced().meadows,
    );
    var dirty = false;
    final toFill = <SunnyGlade>[
      for (final g in WorldZones.glades)
        if (g.index <= state.sunnyGladeAnnounced) g,
      if (state.mistyBiomeUnlocked) WorldZones.mistEdge,
    ];
    for (final g in toFill) {
      if (g.id == state.activeMeadowId) continue;
      final existing = meadows[g.id];
      if (existing == null || existing.herd.isEmpty) {
        final built = core.herd.buildStarterHerd(
          meadowId: g.id,
          startNextId: nextId,
          count: BalanceV0.meadowStarterHerdSize,
        );
        nextId = built.nextId;
        meadows[g.id] = MeadowSnapshot(herd: built.herd);
        dirty = true;
      }
    }
    if (!dirty) return state;
    return state.copyWith(meadows: meadows, nextId: nextId);
  }

  /// Prestige v0: Great Glade + Капи Lv.[BalanceV0.goalCapyLevel] → first
  /// Уют + Туманный бор stub.
  GameState maybeUnlockMistyBiome(GameState state, {required bool announce}) {
    if (state.mistyBiomeUnlocked) return state;
    if (state.sunnyGladeAnnounced < 3) return state;

    var maxLv = state.maxCapyLevel;
    for (final snap in state.meadows.values) {
      for (final c in snap.herd) {
        if (c.level > maxLv) maxLv = c.level;
      }
    }
    if (maxLv < BalanceV0.goalCapyLevel) return state;

    var nextId = state.nextId;
    final meadows = Map<String, MeadowSnapshot>.from(
      state.withActiveSynced().meadows,
    );
    final existing = meadows[WorldZones.mistEdgeMeadowId];
    if (existing == null || existing.herd.isEmpty) {
      final built = core.herd.buildStarterHerd(
        meadowId: WorldZones.mistEdgeMeadowId,
        startNextId: nextId,
        count: BalanceV0.meadowStarterHerdSize,
      );
      nextId = built.nextId;
      meadows[WorldZones.mistEdgeMeadowId] = MeadowSnapshot(herd: built.herd);
    }

    final loud = announce && core.ready;
    if (loud) {
      core.messages.announceGlade(WorldZones.mistEdge.unlockToastRu);
    }

    return state.copyWith(
      mistyBiomeUnlocked: true,
      uyut: state.uyut + BalanceV0.firstMistyUyutGrant,
      grass: state.grass + (loud ? BalanceV0.gladeUnlockGrass : 0),
      meadows: meadows,
      nextId: nextId,
    );
  }

  /// Forest map: switch playable meadow. Shared grass stays; herd restores.
  bool switchToMeadow(String meadowId) {
    if (!core.ready) return false;
    if (meadowId == state.activeMeadowId) return true;
    if (!state.isMeadowUnlocked(meadowId)) return false;
    final synced = state.withActiveSynced();
    final meadows = Map<String, MeadowSnapshot>.from(synced.meadows);
    final target = meadows[meadowId];
    if (target == null) return false;

    core.puddle.onMeadowSwitch(target.herd);

    final clearTwin = target.twinIdA == null || target.twinIdB == null;
    core.commit(
      synced.copyWith(
        activeMeadowId: meadowId,
        herd: List<Capybara>.from(target.herd),
        herdProgress: target.herdProgress,
        meadows: meadows,
        twinIdA: target.twinIdA,
        twinIdB: target.twinIdB,
        clearTwin: clearTwin,
      ),
    );
    return true;
  }
}
