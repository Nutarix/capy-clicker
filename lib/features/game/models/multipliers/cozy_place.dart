/// Placeable cozy spots beyond the mud wallow.
enum CozyPlaceKind {
  /// Short merge-magnet / twin chance boost.
  pen,

  /// Short auto-grass boost (different from mud).
  warmStone,

  /// Offline-leaning / spawn-rate while active (research unlock).
  tent,
}

extension CozyPlaceKindX on CozyPlaceKind {
  String get id => name;

  /// Soft-pixel icon (chroma-keyed).
  String get assetPath => switch (this) {
    CozyPlaceKind.pen => 'assets/images/place_pen.png',
    CozyPlaceKind.warmStone => 'assets/images/place_warm_stone.png',
    CozyPlaceKind.tent => 'assets/images/place_tent.png',
  };

  String get emoji => switch (this) {
    CozyPlaceKind.pen => '🪵',
    CozyPlaceKind.warmStone => '🪨',
    CozyPlaceKind.tent => '⛺',
  };

  String get labelRu => switch (this) {
    CozyPlaceKind.pen => 'Пень',
    CozyPlaceKind.warmStone => 'Тёплый камень',
    CozyPlaceKind.tent => 'Тент',
  };

  String get effectRu => switch (this) {
    CozyPlaceKind.pen => 'магнит слияния / близнецы',
    CozyPlaceKind.warmStone => 'авто-трава',
    CozyPlaceKind.tent => 'спавн / оффлайн-наклон',
  };

  /// Normalized meadow center.
  ///
  /// Clear of the low wood ring (~0.48, 0.84), the berry basket (~0.78, 0.80),
  /// and the early-meadow bodies. Sprites only — no plate behind them.
  (double x, double y) get center => switch (this) {
    CozyPlaceKind.pen => (0.16, 0.84),
    CozyPlaceKind.warmStone => (0.30, 0.58),
    CozyPlaceKind.tent => (0.84, 0.54),
  };

  static CozyPlaceKind? tryParse(String? raw) {
    if (raw == null) return null;
    for (final k in CozyPlaceKind.values) {
      if (k.id == raw) return k;
    }
    return null;
  }
}
