import 'capybara.dart';
import 'game_state.dart';
import 'meadow_snapshot.dart';
import 'world_zones.dart';

/// One visitable land. Grass, sparks, food, and research stay on [GameState].
///
/// Labels in the UI are only «Прежняя земля» and «Новая земля» — no planet names.
class FamilyLand {
  const FamilyLand({
    required this.chapter,
    required this.meadows,
    required this.activeMeadowId,
    required this.sunnyGladeAnnounced,
    required this.mistyBiomeUnlocked,
    required this.sessionGoalIndex,
    required this.placedDecor,
    required this.visitedMist,
    required this.herdProgress,
    required this.herd,
    this.twinIdA,
    this.twinIdB,
  });

  final int chapter;
  final Map<String, MeadowSnapshot> meadows;
  final String activeMeadowId;
  final int sunnyGladeAnnounced;
  final bool mistyBiomeUnlocked;
  final int sessionGoalIndex;
  final Set<String> placedDecor;
  final bool visitedMist;
  final double herdProgress;
  final List<Capybara> herd;
  final String? twinIdA;
  final String? twinIdB;

  int get familyCount {
    var n = 0;
    for (final m in meadows.values) {
      n += m.herd.length;
    }
    return n;
  }

  factory FamilyLand.fromState(GameState state) {
    final synced = state.withActiveSynced();
    return FamilyLand(
      chapter: synced.landChapter,
      meadows: Map<String, MeadowSnapshot>.from(synced.meadows),
      activeMeadowId: synced.activeMeadowId,
      sunnyGladeAnnounced: synced.sunnyGladeAnnounced,
      mistyBiomeUnlocked: synced.mistyBiomeUnlocked,
      sessionGoalIndex: synced.sessionGoalIndex,
      placedDecor: Set<String>.from(synced.placedDecor),
      visitedMist: synced.visitedMist,
      herdProgress: synced.herdProgress,
      herd: List<Capybara>.from(synced.herd),
      twinIdA: synced.twinIdA,
      twinIdB: synced.twinIdB,
    );
  }

  /// Restore this land's family. Shared wallet comes from [globals].
  GameState toGameState({
    required GameState globals,
    required List<FamilyLand> otherLands,
  }) {
    final active =
        meadows[activeMeadowId] ??
        MeadowSnapshot(
          herd: herd,
          herdProgress: herdProgress,
          twinIdA: twinIdA,
          twinIdB: twinIdB,
        );
    final map = Map<String, MeadowSnapshot>.from(meadows);
    map.putIfAbsent(activeMeadowId, () => active);
    return GameState(
      herdProgress: active.herdProgress,
      herd: List<Capybara>.from(active.herd),
      nextId: globals.nextId,
      savedAtMs: globals.savedAtMs,
      lastDailyClaimYmd: globals.lastDailyClaimYmd,
      sunnyGladeAnnounced: sunnyGladeAnnounced,
      grass: globals.grass,
      sessionGoalIndex: sessionGoalIndex,
      twinIdA: active.twinIdA,
      twinIdB: active.twinIdB,
      activeMeadowId: activeMeadowId,
      meadows: map,
      uyut: globals.uyut,
      mistyBiomeUnlocked: mistyBiomeUnlocked,
      food: globals.food,
      ownedDecor: globals.ownedDecor,
      placedDecor: placedDecor,
      researched: globals.researched,
      roleSlots: globals.roleSlots,
      tentUnlocked: globals.tentUnlocked,
      visitedMist: visitedMist,
      landChapter: chapter,
      otherLands: otherLands,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapter': chapter,
    'activeMeadowId': activeMeadowId,
    'sunnyGladeAnnounced': sunnyGladeAnnounced,
    'mistyBiomeUnlocked': mistyBiomeUnlocked,
    'sessionGoalIndex': sessionGoalIndex,
    'placedDecor': placedDecor.toList(),
    'visitedMist': visitedMist,
    'herdProgress': herdProgress,
    'herd': herd.map((c) => c.toJson()).toList(),
    if (twinIdA != null) 'twinIdA': twinIdA,
    if (twinIdB != null) 'twinIdB': twinIdB,
    'meadows': {for (final e in meadows.entries) e.key: e.value.toJson()},
  };

  factory FamilyLand.fromJson(Map<String, dynamic> json) {
    final rawMeadows = json['meadows'];
    final meadows = <String, MeadowSnapshot>{};
    if (rawMeadows is Map) {
      for (final e in rawMeadows.entries) {
        final value = e.value;
        if (value is Map) {
          meadows[e.key.toString()] = MeadowSnapshot.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }
    final activeId =
        (json['activeMeadowId'] as String?) ?? WorldZones.starterMeadowId;
    final herd = GameState.parseHerdList(json['herd']);
    return FamilyLand(
      chapter: (json['chapter'] as num?)?.toInt() ?? 0,
      meadows: meadows,
      activeMeadowId: activeId,
      sunnyGladeAnnounced: (json['sunnyGladeAnnounced'] as num?)?.toInt() ?? 0,
      mistyBiomeUnlocked: json['mistyBiomeUnlocked'] as bool? ?? false,
      sessionGoalIndex: (json['sessionGoalIndex'] as num?)?.toInt() ?? 0,
      placedDecor: {
        for (final e in (json['placedDecor'] as List? ?? const []))
          e.toString(),
      },
      visitedMist: json['visitedMist'] as bool? ?? false,
      herdProgress: (json['herdProgress'] as num?)?.toDouble() ?? 0,
      herd: herd,
      twinIdA: json['twinIdA'] as String?,
      twinIdB: json['twinIdB'] as String?,
    );
  }

  static List<FamilyLand> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) FamilyLand.fromJson(Map<String, dynamic>.from(e)),
    ];
  }
}
