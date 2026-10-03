import 'dart:ui';

import '../models/balance.dart';
import '../models/capybara.dart';
import '../models/family_land.dart';
import '../models/game_state.dart';
import '../models/meadow_snapshot.dart';
import '../models/world_zones.dart';
import 'game_core.dart';

/// The rocket and the family's lands: send the youngest on, visit old lands.
class GameLands extends GamePart {
  GameLands(super.core);

  /// Newest chapter (not a visit back to an older land).
  bool get playingNewestLand {
    for (final land in state.otherLands) {
      if (land.chapter > state.landChapter) return false;
    }
    return true;
  }

  /// Roadmap step 8, after prestige v0 is lived: mist unlocked, visited,
  /// at least one spark, and someone stays home. Does not replace Туманный бор.
  bool get rocketUnlocked =>
      playingNewestLand &&
      state.mistyBiomeUnlocked &&
      state.visitedMist &&
      state.uyut >= 1 &&
      state.totalHerdAcrossMeadows >= 2;

  bool get hasLandsGallery =>
      state.landChapter > 0 || state.otherLands.isNotEmpty;

  /// Arrival meadow: the newest land, before its own glades open.
  bool get onFreshNewLand =>
      playingNewestLand &&
      state.landChapter > 0 &&
      state.sunnyGladeAnnounced == 0 &&
      !state.mistyBiomeUnlocked;

  /// Send the youngest capy on. Grass and sparks stay. Old land is archived.
  bool launchToNewLand() {
    if (!core.ready || !rocketUnlocked) return false;
    final synced = state.withActiveSynced();
    if (synced.totalHerdAcrossMeadows < 2) return false;
    Capybara? traveler;
    String? fromMeadow;
    for (final entry in synced.meadows.entries) {
      for (final capy in entry.value.herd) {
        if (traveler == null || capy.level < traveler.level) {
          traveler = capy;
          fromMeadow = entry.key;
        }
      }
    }
    if (traveler == null || fromMeadow == null) return false;

    final meadows = Map<String, MeadowSnapshot>.from(synced.meadows);
    final snap = meadows[fromMeadow]!;
    final leftBehind = [
      for (final capy in snap.herd)
        if (capy.id != traveler.id) capy,
    ];
    meadows[fromMeadow] = snap.copyWith(herd: leftBehind);
    final travelerLeftActive = fromMeadow == synced.activeMeadowId;
    final archive = FamilyLand.fromState(
      synced.copyWith(
        meadows: meadows,
        herd: travelerLeftActive ? leftBehind : synced.herd,
        clearTwin:
            travelerLeftActive &&
            (synced.twinIdA == traveler.id || synced.twinIdB == traveler.id),
      ),
    );

    final grass = synced.grass;
    final uyut = synced.uyut;
    var nextId = synced.nextId;
    final arrived = traveler.copyWith(
      position: const Offset(0.30, 0.72),
      clearRole: true,
    );
    final companion = Capybara(
      id: 'c$nextId',
      level: BalanceV0.startingLevel,
      position: const Offset(0.68, 0.74),
    );
    nextId += 1;
    final freshHerd = [arrived, companion];
    core.commit(
      GameState(
        herdProgress: 0,
        herd: freshHerd,
        nextId: nextId,
        savedAtMs: synced.savedAtMs,
        lastDailyClaimYmd: synced.lastDailyClaimYmd,
        sunnyGladeAnnounced: 0,
        grass: grass,
        sessionGoalIndex: 0,
        activeMeadowId: WorldZones.starterMeadowId,
        meadows: {WorldZones.starterMeadowId: MeadowSnapshot(herd: freshHerd)},
        uyut: uyut,
        mistyBiomeUnlocked: false,
        food: synced.food,
        ownedDecor: synced.ownedDecor,
        placedDecor: const {},
        researched: synced.researched,
        roleSlots: synced.roleSlots,
        tentUnlocked: synced.tentUnlocked,
        visitedMist: false,
        landChapter: synced.landChapter + 1,
        otherLands: [...synced.otherLands, archive],
      ),
    );
    return state.grass == grass && state.uyut == uyut && state.landChapter > 0;
  }

  /// Swap the live land with an archived one. Nothing is deleted.
  bool visitLand(int chapter) {
    if (!core.ready) return false;
    if (chapter == state.landChapter) return true;
    final others = List<FamilyLand>.from(state.otherLands);
    final index = others.indexWhere((land) => land.chapter == chapter);
    if (index < 0) return false;
    final target = others[index];
    others[index] = FamilyLand.fromState(state);
    final grass = state.grass;
    final uyut = state.uyut;
    core.commit(target.toGameState(globals: state, otherLands: others));
    return state.landChapter == chapter &&
        state.grass == grass &&
        state.uyut == uyut;
  }
}
