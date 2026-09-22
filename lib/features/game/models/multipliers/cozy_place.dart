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
  (double x, double y) get center => switch (this) {
        CozyPlaceKind.pen => (0.58, 0.84),
        CozyPlaceKind.warmStone => (0.42, 0.60),
        CozyPlaceKind.tent => (0.70, 0.52),
      };

  static CozyPlaceKind? tryParse(String? raw) {
    if (raw == null) return null;
    for (final k in CozyPlaceKind.values) {
      if (k.id == raw) return k;
    }
    return null;
  }
}
