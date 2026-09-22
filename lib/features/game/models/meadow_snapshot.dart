import 'capybara.dart';

/// Per-meadow herd + local progress (twins). Grass is global — see [GameState].
class MeadowSnapshot {
  const MeadowSnapshot({
    required this.herd,
    this.herdProgress = 0,
    this.twinIdA,
    this.twinIdB,
  });

  final List<Capybara> herd;
  final double herdProgress;
  final String? twinIdA;
  final String? twinIdB;

  int get herdCount => herd.length;

  MeadowSnapshot copyWith({
    List<Capybara>? herd,
    double? herdProgress,
    String? twinIdA,
    String? twinIdB,
    bool clearTwin = false,
  }) {
    return MeadowSnapshot(
      herd: herd ?? this.herd,
      herdProgress: herdProgress ?? this.herdProgress,
      twinIdA: clearTwin ? null : (twinIdA ?? this.twinIdA),
      twinIdB: clearTwin ? null : (twinIdB ?? this.twinIdB),
    );
  }

  Map<String, dynamic> toJson() => {
        'herdProgress': herdProgress,
        'herd': herd.map((c) => c.toJson()).toList(),
        if (twinIdA != null) 'twinIdA': twinIdA,
        if (twinIdB != null) 'twinIdB': twinIdB,
      };

  factory MeadowSnapshot.fromJson(Map<String, dynamic> json) {
    final rawHerd = json['herd'] as List<dynamic>? ?? const [];
    return MeadowSnapshot(
      herdProgress: (json['herdProgress'] as num?)?.toDouble() ?? 0,
      herd: rawHerd
          .map((e) => Capybara.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      twinIdA: json['twinIdA'] as String?,
      twinIdB: json['twinIdB'] as String?,
    );
  }

  static const empty = MeadowSnapshot(herd: []);
}
