import 'capybara.dart';
import 'meadow_snapshot.dart';
import 'multipliers/family_food.dart';
import 'multipliers/home_decor.dart';
import 'world_zones.dart';

/// Immutable snapshot of playable herd + progress + session loop + forest map.
///
/// **Shared globally:** grass wallet, session goals, daily claim, nextId,
/// unlock index ([sunnyGladeAnnounced]), meta [uyut], [mistyBiomeUnlocked],
/// food inventory, owned decor, research, role slot count.
/// **Per meadow:** herd (incl. roles), local progress bar, twin marks ([meadows]).
class GameState {
  const GameState({
    required this.herdProgress,
    required this.herd,
    this.nextId = 1,
    this.savedAtMs,
    this.lastDailyClaimYmd,
    this.sunnyGladeAnnounced = 0,
    this.grass = 0,
    this.sessionGoalIndex = 0,
    this.twinIdA,
    this.twinIdB,
    this.activeMeadowId = WorldZones.starterMeadowId,
    this.meadows = const {},
    this.uyut = 0,
    this.mistyBiomeUnlocked = false,
    this.food = const FoodInventory(),
    this.ownedDecor = const {},
    this.placedDecor = const {},
    this.researched = const {},
    this.roleSlots = 1,
    this.tentUnlocked = false,
  });

  /// Herd progress in range 0.0–1.0 (fills toward next spawn) — **active** meadow.
  final double herdProgress;

  /// Living capybaras on the **active** meadow.
  final List<Capybara> herd;

  /// Monotonic id counter for new entities (global).
  final int nextId;

  /// Epoch ms when this snapshot was last persisted (for offline progress).
  final int? savedAtMs;

  /// Local calendar day of last soft daily claim as `YYYY-MM-DD`, or null.
  final String? lastDailyClaimYmd;

  /// Highest unlocked «Солнечные поляны» meadow index (0–3).
  final int sunnyGladeAnnounced;

  /// Spendable grass currency (integer) — **shared** across meadows.
  final int grass;

  /// Index into [SessionGoals.sequence]; equals length when all complete.
  final int sessionGoalIndex;

  /// Ids of the currently marked twin-sparkle pair (same level), if any.
  final String? twinIdA;
  final String? twinIdB;

  /// Which meadow is currently playable (`warm_edge`, `berry_glade`, …).
  final String activeMeadowId;

  /// All unlocked meadows → herd snapshots. Always includes [activeMeadowId]
  /// after [withActiveSynced] / normal [copyWith] paths.
  final Map<String, MeadowSnapshot> meadows;

  /// Meta-валюта «Уют» / искры уюта — permanent, never wiped.
  final int uyut;

  /// Prestige v0: second forest biome «Туманный бор» unlocked.
  final bool mistyBiomeUnlocked;

  /// Family food inventory (Травка / Ягоды / Орешки).
  final FoodInventory food;

  /// Owned home decor ids.
  final Set<String> ownedDecor;

  /// Placed decor ids (subset of owned; for meadow pins).
  final Set<String> placedDecor;

  /// Unlocked research node ids.
  final Set<String> researched;

  /// How many role assignments the family may hold at once.
  final int roleSlots;

  /// Whether Тент placeable is unlocked (research).
  final bool tentUnlocked;

  int get herdCount => herd.length;

  /// Sum of herds across every stored meadow (menu «Продолжить»).
  int get totalHerdAcrossMeadows {
    if (meadows.isEmpty) return herd.length;
    var n = 0;
    for (final m in meadows.values) {
      n += m.herd.length;
    }
    return n;
  }

  int get maxCapyLevel {
    if (herd.isEmpty) return 0;
    var m = 0;
    for (final c in herd) {
      if (c.level > m) m = c.level;
    }
    return m;
  }

  /// Family power = Σ levels on the **active** meadow.
  ///
  /// Drives Sunny Glade unlock thresholds (Ягодная ≥5, Солнечный ≥10,
  /// Большой ≥16). Soft-cap still limits body count; merge raises power.
  int get familyPower {
    var p = 0;
    for (final c in herd) {
      p += c.level;
    }
    return p;
  }

  bool isTwinMarked(String id) => id == twinIdA || id == twinIdB;

  bool ownsDecor(HomeDecor d) => ownedDecor.contains(d.id);

  bool hasResearch(String id) => researched.contains(id);

  int get assignedRoleCount {
    var n = 0;
    for (final c in herd) {
      if (c.role != null) n++;
    }
    // Count roles on other meadows too (global slot pool).
    for (final e in meadows.entries) {
      if (e.key == activeMeadowId) continue;
      for (final c in e.value.herd) {
        if (c.role != null) n++;
      }
    }
    return n;
  }

  bool isMeadowUnlocked(String meadowId) {
    if (WorldZones.isMistyMeadow(meadowId)) return mistyBiomeUnlocked;
    final idx = WorldZones.indexOfMeadowId(meadowId);
    if (idx < 0) return false;
    return idx <= sunnyGladeAnnounced;
  }

  List<String> get unlockedMeadowIds {
    final ids = [
      for (final g in WorldZones.glades)
        if (g.index <= sunnyGladeAnnounced) g.id,
    ];
    if (mistyBiomeUnlocked) {
      ids.add(WorldZones.mistEdgeMeadowId);
    }
    return ids;
  }

  /// Snapshot of the active meadow fields.
  MeadowSnapshot get activeSnapshot => MeadowSnapshot(
        herd: herd,
        herdProgress: herdProgress,
        twinIdA: twinIdA,
        twinIdB: twinIdB,
      );

  /// Ensures [meadows] contains the active herd fields (call before persist).
  GameState withActiveSynced() {
    final map = Map<String, MeadowSnapshot>.from(meadows);
    map[activeMeadowId] = activeSnapshot;
    return copyWith(meadows: map);
  }

  GameState copyWith({
    double? herdProgress,
    List<Capybara>? herd,
    int? nextId,
    int? savedAtMs,
    String? lastDailyClaimYmd,
    bool clearLastDailyClaimYmd = false,
    int? sunnyGladeAnnounced,
    int? grass,
    int? sessionGoalIndex,
    String? twinIdA,
    String? twinIdB,
    bool clearTwin = false,
    String? activeMeadowId,
    Map<String, MeadowSnapshot>? meadows,
    int? uyut,
    bool? mistyBiomeUnlocked,
    FoodInventory? food,
    Set<String>? ownedDecor,
    Set<String>? placedDecor,
    Set<String>? researched,
    int? roleSlots,
    bool? tentUnlocked,
  }) {
    final nextActive = activeMeadowId ?? this.activeMeadowId;
    final nextHerd = herd ?? this.herd;
    final nextProgress = herdProgress ?? this.herdProgress;
    final nextTwinA = clearTwin ? null : (twinIdA ?? this.twinIdA);
    final nextTwinB = clearTwin ? null : (twinIdB ?? this.twinIdB);

    var nextMeadows = meadows ?? this.meadows;
    if (herd != null ||
        herdProgress != null ||
        twinIdA != null ||
        twinIdB != null ||
        clearTwin ||
        activeMeadowId != null ||
        meadows != null) {
      nextMeadows = Map<String, MeadowSnapshot>.from(nextMeadows);
      nextMeadows[nextActive] = MeadowSnapshot(
        herd: nextHerd,
        herdProgress: nextProgress,
        twinIdA: nextTwinA,
        twinIdB: nextTwinB,
      );
    }

    return GameState(
      herdProgress: nextProgress,
      herd: nextHerd,
      nextId: nextId ?? this.nextId,
      savedAtMs: savedAtMs ?? this.savedAtMs,
      lastDailyClaimYmd: clearLastDailyClaimYmd
          ? null
          : (lastDailyClaimYmd ?? this.lastDailyClaimYmd),
      sunnyGladeAnnounced: sunnyGladeAnnounced ?? this.sunnyGladeAnnounced,
      grass: grass ?? this.grass,
      sessionGoalIndex: sessionGoalIndex ?? this.sessionGoalIndex,
      twinIdA: nextTwinA,
      twinIdB: nextTwinB,
      activeMeadowId: nextActive,
      meadows: nextMeadows,
      uyut: uyut ?? this.uyut,
      mistyBiomeUnlocked: mistyBiomeUnlocked ?? this.mistyBiomeUnlocked,
      food: food ?? this.food,
      ownedDecor: ownedDecor ?? this.ownedDecor,
      placedDecor: placedDecor ?? this.placedDecor,
      researched: researched ?? this.researched,
      roleSlots: roleSlots ?? this.roleSlots,
      tentUnlocked: tentUnlocked ?? this.tentUnlocked,
    );
  }

  Map<String, dynamic> toJson() {
    final synced = withActiveSynced();
    return {
      'herdProgress': synced.herdProgress,
      'nextId': synced.nextId,
      'herd': synced.herd.map((c) => c.toJson()).toList(),
      if (synced.savedAtMs != null) 'savedAtMs': synced.savedAtMs,
      if (synced.lastDailyClaimYmd != null)
        'lastDailyClaimYmd': synced.lastDailyClaimYmd,
      'sunnyGladeAnnounced': synced.sunnyGladeAnnounced,
      'grass': synced.grass,
      'sessionGoalIndex': synced.sessionGoalIndex,
      if (synced.twinIdA != null) 'twinIdA': synced.twinIdA,
      if (synced.twinIdB != null) 'twinIdB': synced.twinIdB,
      'activeMeadowId': synced.activeMeadowId,
      'meadows': {
        for (final e in synced.meadows.entries) e.key: e.value.toJson(),
      },
      'uyut': synced.uyut,
      'mistyBiomeUnlocked': synced.mistyBiomeUnlocked,
      'food': synced.food.toJson(),
      'ownedDecor': synced.ownedDecor.toList(),
      'placedDecor': synced.placedDecor.toList(),
      'researched': synced.researched.toList(),
      'roleSlots': synced.roleSlots,
      'tentUnlocked': synced.tentUnlocked,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    final rawMeadows = json['meadows'];
    if (rawMeadows is Map && rawMeadows.isNotEmpty) {
      return _fromMultiMeadowJson(json, rawMeadows);
    }
    return _fromLegacySingleHerdJson(json);
  }

  static FoodInventory _parseFood(Map<String, dynamic> json) {
    final raw = json['food'];
    if (raw is Map) {
      return FoodInventory.fromJson(Map<String, dynamic>.from(raw));
    }
    return const FoodInventory();
  }

  static Set<String> _parseStringSet(dynamic raw) {
    if (raw is! List) return {};
    return {for (final e in raw) e.toString()};
  }

  static GameState _fromMultiMeadowJson(
    Map<String, dynamic> json,
    Map rawMeadows,
  ) {
    final meadows = <String, MeadowSnapshot>{};
    for (final e in rawMeadows.entries) {
      final key = e.key.toString();
      final value = e.value;
      if (value is Map) {
        meadows[key] =
            MeadowSnapshot.fromJson(Map<String, dynamic>.from(value));
      }
    }
    final activeId = (json['activeMeadowId'] as String?) ??
        WorldZones.starterMeadowId;
    final active = meadows[activeId] ??
        MeadowSnapshot(
          herdProgress: (json['herdProgress'] as num?)?.toDouble() ?? 0,
          herd: _parseHerdList(json['herd']),
          twinIdA: json['twinIdA'] as String?,
          twinIdB: json['twinIdB'] as String?,
        );
    meadows.putIfAbsent(activeId, () => active);

    final researched = _parseStringSet(json['researched']);
    final tentFromResearch = researched.contains('unlock_tent');

    return GameState(
      herdProgress: active.herdProgress,
      herd: active.herd,
      nextId: json['nextId'] as int? ?? 1,
      savedAtMs: (json['savedAtMs'] as num?)?.toInt(),
      lastDailyClaimYmd: json['lastDailyClaimYmd'] as String?,
      sunnyGladeAnnounced: (json['sunnyGladeAnnounced'] as num?)?.toInt() ?? 0,
      grass: (json['grass'] as num?)?.toInt() ?? 0,
      sessionGoalIndex: (json['sessionGoalIndex'] as num?)?.toInt() ?? 0,
      twinIdA: active.twinIdA,
      twinIdB: active.twinIdB,
      activeMeadowId: activeId,
      meadows: meadows,
      uyut: (json['uyut'] as num?)?.toInt() ?? 0,
      mistyBiomeUnlocked: json['mistyBiomeUnlocked'] as bool? ?? false,
      food: _parseFood(json),
      ownedDecor: _parseStringSet(json['ownedDecor']),
      placedDecor: _parseStringSet(json['placedDecor']),
      researched: researched,
      roleSlots: (json['roleSlots'] as num?)?.toInt() ??
          (researched.contains('role_slot_2') ? 2 : 1),
      tentUnlocked: json['tentUnlocked'] as bool? ?? tentFromResearch,
    );
  }

  static GameState _fromLegacySingleHerdJson(Map<String, dynamic> json) {
    final herd = _parseHerdList(json['herd']);
    final progress = (json['herdProgress'] as num?)?.toDouble() ?? 0;
    final announced = (json['sunnyGladeAnnounced'] as num?)?.toInt() ?? 0;
    final twinA = json['twinIdA'] as String?;
    final twinB = json['twinIdB'] as String?;
    const activeId = WorldZones.starterMeadowId;

    final meadows = <String, MeadowSnapshot>{
      activeId: MeadowSnapshot(
        herd: herd,
        herdProgress: progress,
        twinIdA: twinA,
        twinIdB: twinB,
      ),
    };
    for (final g in WorldZones.glades) {
      if (g.index == 0) continue;
      if (g.index <= announced) {
        meadows.putIfAbsent(g.id, () => MeadowSnapshot.empty);
      }
    }

    final researched = _parseStringSet(json['researched']);

    return GameState(
      herdProgress: progress,
      herd: herd,
      nextId: json['nextId'] as int? ?? 1,
      savedAtMs: (json['savedAtMs'] as num?)?.toInt(),
      lastDailyClaimYmd: json['lastDailyClaimYmd'] as String?,
      sunnyGladeAnnounced: announced,
      grass: (json['grass'] as num?)?.toInt() ?? 0,
      sessionGoalIndex: (json['sessionGoalIndex'] as num?)?.toInt() ?? 0,
      twinIdA: twinA,
      twinIdB: twinB,
      activeMeadowId: activeId,
      meadows: meadows,
      uyut: (json['uyut'] as num?)?.toInt() ?? 0,
      mistyBiomeUnlocked: json['mistyBiomeUnlocked'] as bool? ?? false,
      food: _parseFood(json),
      ownedDecor: _parseStringSet(json['ownedDecor']),
      placedDecor: _parseStringSet(json['placedDecor']),
      researched: researched,
      roleSlots: (json['roleSlots'] as num?)?.toInt() ??
          (researched.contains('role_slot_2') ? 2 : 1),
      tentUnlocked: json['tentUnlocked'] as bool? ??
          researched.contains('unlock_tent'),
    );
  }

  static List<Capybara> _parseHerdList(dynamic raw) {
    final list = raw as List<dynamic>? ?? const [];
    return list
        .map((e) => Capybara.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static GameState initial() => GameState(
        herdProgress: 0,
        herd: const [],
        nextId: 1,
        activeMeadowId: WorldZones.starterMeadowId,
        meadows: {
          WorldZones.starterMeadowId: MeadowSnapshot.empty,
        },
      );
}
