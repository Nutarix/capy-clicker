import 'capybara.dart';

/// Immutable snapshot of playable herd + progress + session loop.
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
  });

  /// Herd progress in range 0.0–1.0 (fills toward next spawn).
  final double herdProgress;

  /// Living capybaras on the meadow.
  final List<Capybara> herd;

  /// Monotonic id counter for new entities.
  final int nextId;

  /// Epoch ms when this snapshot was last persisted (for offline progress).
  final int? savedAtMs;

  /// Local calendar day of last soft daily claim as `YYYY-MM-DD`, or null.
  final String? lastDailyClaimYmd;

  /// Highest «Солнечные поляны» glade index already soft-announced (0–3).
  /// Starter (Тёплая опушка) is 0 — no toast. Prevents re-toasting on relaunch.
  final int sunnyGladeAnnounced;

  /// Spendable grass currency (integer).
  final int grass;

  /// Index into [SessionGoals.sequence]; equals length when all complete.
  final int sessionGoalIndex;

  /// Ids of the currently marked twin-sparkle pair (same level), if any.
  final String? twinIdA;
  final String? twinIdB;

  int get herdCount => herd.length;

  int get maxCapyLevel {
    if (herd.isEmpty) return 0;
    var m = 0;
    for (final c in herd) {
      if (c.level > m) m = c.level;
    }
    return m;
  }

  bool isTwinMarked(String id) => id == twinIdA || id == twinIdB;

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
  }) {
    return GameState(
      herdProgress: herdProgress ?? this.herdProgress,
      herd: herd ?? this.herd,
      nextId: nextId ?? this.nextId,
      savedAtMs: savedAtMs ?? this.savedAtMs,
      lastDailyClaimYmd: clearLastDailyClaimYmd
          ? null
          : (lastDailyClaimYmd ?? this.lastDailyClaimYmd),
      sunnyGladeAnnounced: sunnyGladeAnnounced ?? this.sunnyGladeAnnounced,
      grass: grass ?? this.grass,
      sessionGoalIndex: sessionGoalIndex ?? this.sessionGoalIndex,
      twinIdA: clearTwin ? null : (twinIdA ?? this.twinIdA),
      twinIdB: clearTwin ? null : (twinIdB ?? this.twinIdB),
    );
  }

  Map<String, dynamic> toJson() => {
    'herdProgress': herdProgress,
    'nextId': nextId,
    'herd': herd.map((c) => c.toJson()).toList(),
    if (savedAtMs != null) 'savedAtMs': savedAtMs,
    if (lastDailyClaimYmd != null) 'lastDailyClaimYmd': lastDailyClaimYmd,
    'sunnyGladeAnnounced': sunnyGladeAnnounced,
    'grass': grass,
    'sessionGoalIndex': sessionGoalIndex,
    if (twinIdA != null) 'twinIdA': twinIdA,
    if (twinIdB != null) 'twinIdB': twinIdB,
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final rawHerd = json['herd'] as List<dynamic>? ?? const [];
    return GameState(
      herdProgress: (json['herdProgress'] as num?)?.toDouble() ?? 0,
      nextId: json['nextId'] as int? ?? 1,
      herd: rawHerd
          .map((e) => Capybara.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      savedAtMs: (json['savedAtMs'] as num?)?.toInt(),
      lastDailyClaimYmd: json['lastDailyClaimYmd'] as String?,
      sunnyGladeAnnounced: (json['sunnyGladeAnnounced'] as num?)?.toInt() ?? 0,
      grass: (json['grass'] as num?)?.toInt() ?? 0,
      sessionGoalIndex: (json['sessionGoalIndex'] as num?)?.toInt() ?? 0,
      twinIdA: json['twinIdA'] as String?,
      twinIdB: json['twinIdB'] as String?,
    );
  }

  static GameState initial() =>
      const GameState(herdProgress: 0, herd: [], nextId: 1);
}
