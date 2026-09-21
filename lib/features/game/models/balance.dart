/// Tunable balance constants for Phase 1–2 (v0).
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

  /// Soft herd size cap (Phase 2: roomier meadow).
  static const int maxHerdSize = 12;

  /// Starting herd: one level-1 capybara.
  static const int startingHerdSize = 1;
  static const int startingLevel = 1;

  /// Highest level we polish visually (scale + warmer tint + badge).
  static const int maxVisualLevel = 6;

  /// Visual scale multiplier per level: base * (1 + (level-1)*scalePerLevel).
  /// Raised in Phase 2 so Lv.1 vs Lv.6 reads clearly at a glance.
  static const double baseCapySize = 70;
  static const double scalePerLevel = 0.34;

  /// Camera zoom steps by herd count (Transform.scale).
  /// 1–2 close, 3–5 mid, 6–8 farther, 9–11 wide, 12+ widest.
  static const double zoomClose = 1.0;
  static const double zoomMid = 0.82;
  static const double zoomFar = 0.66;
  static const double zoomWide = 0.56;
  static const double zoomWidest = 0.50;

  static double zoomForHerdCount(int count) {
    if (count <= 2) return zoomClose;
    if (count <= 5) return zoomMid;
    if (count <= 8) return zoomFar;
    if (count <= 11) return zoomWide;
    return zoomWidest;
  }

  /// Pixel size for a given level (clamped visual growth past maxVisualLevel).
  static double capySizeForLevel(int level) {
    final lv = level.clamp(1, maxVisualLevel + 2);
    return baseCapySize * (1 + (lv - 1) * scalePerLevel);
  }

  /// Minimum normalized distance between spawn positions (0–1 meadow space).
  static const double minSpawnSeparation = 0.14;

  /// How often to debounce-persist to disk (ms).
  static const int persistDebounceMs = 400;

  // --- Offline progress (Phase 2) ---

  /// Soft cap on offline auto-progress (seconds of live auto rate).
  /// ~3 min ≈ 2.7 full bars at autoProgressPerSecond.
  static const int offlineCapSeconds = 180;

  /// Hard floor: ignore tiny gaps (app background flicker).
  static const int offlineMinSeconds = 8;

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

  // --- Meadow decor unlocks (visual only) ---

  /// Herd-size milestones that unlock static bush/rock decorations.
  static const int decorBush1At = 3;
  static const int decorRockAt = 6;
  static const int decorBush2At = 9;

  // --- Soft daily bonus (Phase 2–3) ---

  /// Once-per-local-calendar-day claimable progress gift (not an energy gate).
  static const double dailyBonusProgress = 0.25;

  /// Alternate flavor (docs): mud-boost equivalent duration if we ever switch reward.
  static const Duration dailyBonusMudBoostEquivalent = Duration(seconds: 30);

  // --- Juice / tips ---

  /// Brief merge flash duration on the new merged capy.
  static const Duration mergeFlashDuration = Duration(milliseconds: 520);

  /// SharedPreferences key: first-launch tip overlay dismissed.
  static const String tipsSeenKey = 'capy_clicker_tips_seen_v1';
}
