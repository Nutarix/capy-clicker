/// Tunable balance constants for Phase 1 (v0).
/// See docs/BALANCE_V0.md for rationale.
abstract final class BalanceV0 {
  /// Auto grass-eat fill rate: fraction of herd progress per second.
  static const double autoProgressPerSecond = 0.015;

  /// Progress gained when tapping a flower (fraction 0–1).
  static const double flowerTapGainMin = 0.03;
  static const double flowerTapGainMax = 0.06;

  /// Midpoint used as default tap burst when random is not needed.
  static const double flowerTapGain = 0.045;

  /// Progress required to spawn one new level-1 capybara.
  static const double spawnThreshold = 1.0;

  /// Early-game herd size soft cap.
  static const int maxHerdSize = 8;

  /// Starting herd: one level-1 capybara.
  static const int startingHerdSize = 1;
  static const int startingLevel = 1;

  /// Visual scale multiplier per level: base * (1 + (level-1)*scalePerLevel).
  static const double baseCapySize = 72;
  static const double scalePerLevel = 0.28;

  /// Camera zoom steps by herd count (Transform.scale).
  /// 1–2 close, 3–5 mid, 6+ farther.
  static const double zoomClose = 1.0;
  static const double zoomMid = 0.82;
  static const double zoomFar = 0.66;

  static double zoomForHerdCount(int count) {
    if (count <= 2) return zoomClose;
    if (count <= 5) return zoomMid;
    return zoomFar;
  }

  /// Minimum normalized distance between spawn positions (0–1 meadow space).
  static const double minSpawnSeparation = 0.14;

  /// How often to debounce-persist to disk (ms).
  static const int persistDebounceMs = 400;

  // --- Mud wallow / puddle ---

  /// Normalized meadow rect for the mud puddle (center + radius for hit).
  static const double mudCenterX = 0.22;
  static const double mudCenterY = 0.78;
  static const double mudHitRadius = 0.11;

  /// Auto-progress multiplier while wallow boost is active.
  static const double mudBoostMultiplier = 2.0;

  /// Duration of the mud boost after a successful wallow.
  static const Duration mudBoostDuration = Duration(seconds: 10);

  /// How long the cute wallow animation plays on the puddle.
  static const Duration mudWallowAnimDuration = Duration(milliseconds: 1400);

  // --- Berry basket ---

  /// Large progress burst when collecting the berry basket.
  static const double berryTapGainMin = 0.18;
  static const double berryTapGainMax = 0.25;

  /// Delay after collect before the basket reappears.
  static const Duration berryRespawnMin = Duration(seconds: 22);
  static const Duration berryRespawnMax = Duration(seconds: 38);

  /// First appearance delay from session start (so it feels "rare").
  static const Duration berryFirstSpawnMin = Duration(seconds: 8);
  static const Duration berryFirstSpawnMax = Duration(seconds: 16);

  /// Normalized meadow position for the berry basket.
  static const double berryPosX = 0.78;
  static const double berryPosY = 0.72;
}
