import 'capybara.dart';

/// Immutable snapshot of playable herd + progress.
class GameState {
  const GameState({
    required this.herdProgress,
    required this.herd,
    this.nextId = 1,
    this.savedAtMs,
    this.lastDailyClaimYmd,
    this.sunnyGladeAnnounced = 0,
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

  int get herdCount => herd.length;

  GameState copyWith({
    double? herdProgress,
    List<Capybara>? herd,
    int? nextId,
    int? savedAtMs,
    String? lastDailyClaimYmd,
    bool clearLastDailyClaimYmd = false,
    int? sunnyGladeAnnounced,
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
    );
  }

  Map<String, dynamic> toJson() => {
    'herdProgress': herdProgress,
    'nextId': nextId,
    'herd': herd.map((c) => c.toJson()).toList(),
    if (savedAtMs != null) 'savedAtMs': savedAtMs,
    if (lastDailyClaimYmd != null) 'lastDailyClaimYmd': lastDailyClaimYmd,
    'sunnyGladeAnnounced': sunnyGladeAnnounced,
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
    );
  }

  static GameState initial() =>
      const GameState(herdProgress: 0, herd: [], nextId: 1);
}
