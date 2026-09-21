import 'capybara.dart';

/// Immutable snapshot of playable herd + progress.
class GameState {
  const GameState({
    required this.herdProgress,
    required this.herd,
    this.nextId = 1,
    this.savedAtMs,
  });

  /// Herd progress in range 0.0–1.0 (fills toward next spawn).
  final double herdProgress;

  /// Living capybaras on the meadow.
  final List<Capybara> herd;

  /// Monotonic id counter for new entities.
  final int nextId;

  /// Epoch ms when this snapshot was last persisted (for offline progress).
  final int? savedAtMs;

  int get herdCount => herd.length;

  GameState copyWith({
    double? herdProgress,
    List<Capybara>? herd,
    int? nextId,
    int? savedAtMs,
  }) {
    return GameState(
      herdProgress: herdProgress ?? this.herdProgress,
      herd: herd ?? this.herd,
      nextId: nextId ?? this.nextId,
      savedAtMs: savedAtMs ?? this.savedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'herdProgress': herdProgress,
    'nextId': nextId,
    'herd': herd.map((c) => c.toJson()).toList(),
    if (savedAtMs != null) 'savedAtMs': savedAtMs,
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
    );
  }

  static GameState initial() =>
      const GameState(herdProgress: 0, herd: [], nextId: 1);
}
