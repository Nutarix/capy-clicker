import 'dart:math' as math;
import 'dart:ui';

import 'world_zones.dart';

/// Tunable balance constants for Phase 1–2 (v0).
/// See docs/BALANCE_V0.md for rationale.
/// Walkable meadow bounds: `world_zones.dart` / docs/WORLD_ZONES.md.
abstract final class BalanceV0 {
  /// Auto grass-eat fill rate: fraction of herd progress per second.
  /// Playtest v1.1: 0.020 → 0.015 so first glade lands ~2–4 min cozy (not ~1 min).
  static const double autoProgressPerSecond = 0.015;

  /// Progress gained when tapping a flower (fraction 0–1).
  /// Playtest v1.1: slightly softer taps so spend-fork / auto stay relevant.
  static const double flowerTapGainMin = 0.025;
  static const double flowerTapGainMax = 0.045;

  /// Midpoint used as default tap burst when random is not needed.
  static const double flowerTapGain = 0.035;

  /// Progress required to spawn one new level-1 capybara.
  static const double spawnThreshold = 1.0;

  /// Soft herd size cap (Phase 2: roomier meadow).
  static const int maxHerdSize = 12;

  /// Starting herd: one level-1 capybara.
  static const int startingHerdSize = 1;
  static const int startingLevel = 1;

  /// Starter herd size when a **new** meadow unlocks on the forest map
  /// (Phase 2). First meadow still uses [startingHerdSize].
  static const int meadowStarterHerdSize = 2;

  /// Highest level we polish visually (scale + warmer tint + badge).
  static const int maxVisualLevel = 6;

  /// Visual scale multiplier per level: base * (1 + (level-1)*scalePerLevel).
  /// Raised in Phase 2 so Lv.1 vs Lv.6 reads clearly at a glance.
  static const double baseCapySize = 70;
  static const double scalePerLevel = 0.34;

  /// Camera zoom baselines for «Солнечные поляны» (see [WorldZones.glades]).
  /// Fit zoom may step further back when the herd bbox no longer fits.
  /// 0–4 Тёплая опушка, 5–7 Ягодная поляна, 8–10 Солнечный прогал, 11–12 Большой луг.
  static const double zoomClose = 1.0;
  static const double zoomMid = 0.82;
  static const double zoomFar = 0.66;
  /// @Deprecated Prefer [zoomWidest] — 11–12 share one glade circle.
  static const double zoomWide = 0.50;
  static const double zoomWidest = 0.50;

  /// Normalized padding around the herd bounding box for fit-zoom.
  static const double zoomFitPadding = 0.08;

  /// Reference padded span that still looks cozy at [zoomClose].
  /// Larger herd bbox → camera steps back (scale down) proportionally.
  static const double zoomFitComfortSpan = 0.48;

  /// Baseline zoom from Sunny Glade circle (same bands as meadow expansion).
  static double zoomForHerdCount(int count) {
    return WorldZones.gladeForHerd(count).baseZoom;
  }

  /// Scale so the herd bbox (+ padding) still feels comfortable on screen.
  ///
  /// Larger spread → lower scale ("step back to admire the grove").
  /// Clamped to [zoomWidest, zoomClose]; combined with glade baseline via
  /// [cameraZoomForHerd].
  static double zoomToFitPositions(Iterable<Offset> positions) {
    final list = positions.toList();
    if (list.isEmpty) return zoomClose;

    var minX = list.first.dx;
    var maxX = list.first.dx;
    var minY = list.first.dy;
    var maxY = list.first.dy;
    for (final p in list) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final width =
        (maxX - minX + 2 * zoomFitPadding).clamp(0.05, 1.5);
    final height =
        (maxY - minY + 2 * zoomFitPadding).clamp(0.05, 1.5);
    final span = math.max(width, height);

    final fit = zoomFitComfortSpan / span;
    return fit.clamp(zoomWidest, zoomClose);
  }

  /// Combined camera target: tier baseline, pulled back if herd bbox needs it.
  static double cameraZoomForHerd(int count, Iterable<Offset> positions) {
    final tier = zoomForHerdCount(count);
    final fit = zoomToFitPositions(positions);
    return math.min(tier, fit);
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

  // --- Mud wallow / puddle (must stay inside WorldZones meadow) ---

  /// Normalized meadow position for the mud puddle (center + radius for hit).
  /// Must remain inside [WorldZones] walkable grass clearing (not on trees).
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

  /// Normalized meadow position for the berry basket (grass clearing only).
  /// Must remain inside [WorldZones] walkable meadow — never on tree trunks.
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

  // --- Soft magnetic merge (drag assist only) ---

  /// Normalized meadow distance within which a dragged capy gently attracts
  /// toward the nearest same-level neighbour and can complete a merge.
  /// Tuned local (~1/10 meadow) — does NOT magnet across the whole field.
  /// Compare: minSpawnSeparation = 0.14; mudHitRadius = 0.11.
  /// Playtest P1: slightly tighter than 0.10 to cut accidental mid-drag merges.
  static const double magnetRadius = 0.085;

  /// Mid-drag auto-complete when distance ≤ magnetRadius * this fraction.
  /// Drag-end still merges for any hit within the full [magnetRadius].
  /// Mid-drag auto-complete band (tighter → more release-to-snap).
  static const double magnetSnapFraction = 0.42;

  /// How strongly the drag feedback eases toward the magnet target (0–1).
  static const double magnetPullLerp = 0.28;


  // --- Grass currency (session loop fork) ---

  /// Integer grass from a flower tap (inclusive range).
  /// Showable v1: keep always-1 so Berry stays ~2–5′ (not <90s call-rush).
  static const int flowerTapGrassMin = 1;
  static const int flowerTapGrassMax = 1;

  /// Slow auto grass accrual (fractional units per second → integer grants).
  /// Showable v1: 0.07 → 0.110 (~9 с на 1🌿) — mid-session drip vs 🌿=0 despair.
  static const double autoGrassPerSecond = 0.110;

  /// Berry basket grass burst (inclusive).
  /// Showable v1: 5–8 → 7–10 — post-berry buffer for Дом/Наука.
  static const int berryGrassMin = 7;
  static const int berryGrassMax = 10;

  /// Grass reward when a Sunny Glade first unlocks.
  /// Showable v1: 6 → 10 — funds first permanent right after wow.
  static const int gladeUnlockGrass = 10;

  /// Bonus grass for merging a marked twin-sparkle pair.
  static const int twinMergeBonusGrass = 5;

  /// Soft celebration grass when a session goal completes.
  /// Showable v1: 4 → 6.
  static const int goalCompleteGrass = 6;

  /// Spend: call a new Lv.1 capy (if under soft herd cap).
  /// Showable v1: keep 12 (2.4× boost) — fork stays real; soft-cap still matters.
  static const int callCapyGrassCost = 12;

  /// Spend: short auto-progress boost (weaker than mud wallow).
  static const int grassBoostCost = 5;
  static const double grassBoostMultiplier = 1.5;
  static const Duration grassBoostDuration = Duration(seconds: 6);

  // --- Twin sparkle (merge skill window) ---

  /// How often we try to mark a same-level pair (seconds).
  /// Playtest v1.1: 18 → 36 — rare skill window (~30–60s feel), not permanent glow.
  static const int twinRerollSeconds = 36;

  /// After a successful twin-merge bonus, delay before next mark attempt.
  static const int twinPostMergeCooldownSeconds = 28;

  /// Chance to actually mark a pair on a reroll (else quiet gap).
  static const double twinMarkChance = 0.55;

  /// Chance an existing valid twin pair lingers across a reroll.
  static const double twinLingerChance = 0.35;

  /// Minimum herd size before twin marking can appear.
  static const int twinMinHerd = 2;

  // --- Уют meta (prestige v0) ---

  /// Permanent auto boost per Уют point (+3% to auto progress & auto grass).
  static const double uyutAutoBoostPerPoint = 0.03;

  /// First Уют grant when Great Glade + family Lv.4 chain completes.
  static const int firstMistyUyutGrant = 1;


  // --- Multipliers v0: family food ---

  /// Steady idle auto mult while Травка feed is active.
  static const double foodTravkaAutoMult = 1.25;
  static const Duration foodTravkaDuration = Duration(seconds: 12);

  /// Burst-ish Ягоды feed.
  static const double foodYagodyAutoMult = 1.55;
  static const Duration foodYagodyDuration = Duration(seconds: 5);
  static const double foodYagodyProgressBurst = 0.08;

  /// Орешки: twin/magnet luck + short auto.
  static const double foodOreshkiAutoMult = 1.35;
  static const Duration foodOreshkiDuration = Duration(seconds: 8);
  static const double foodOreshkiTwinChanceBonus = 0.25;
  static const double foodOreshkiMagnetBonus = 0.35;

  /// Chance flower tap grants a food item (base; research/decor add).
  static const double flowerFoodDropChance = 0.18;
  /// Relative weights travka : yagody : oreshki
  static const double foodDropTravkaWeight = 0.55;
  static const double foodDropYagodyWeight = 0.30;
  static const double foodDropOreshkiWeight = 0.15;

  /// Convert grass → Травка feed pack.
  static const int grassToTravkaCost = 4;
  /// Showable v1: 7 → 6 — food stays a light sink next to call/boost.
  static const int grassToYagodyCost = 6;
  static const int grassToOreshkiCost = 12;

  // --- Multipliers v0: cozy places ---

  static const double placeHitRadius = 0.10;

  static const double penMagnetBonus = 0.40;
  static const double penTwinChanceBonus = 0.20;
  static const Duration penBoostDuration = Duration(seconds: 8);
  static const Duration penCooldown = Duration(seconds: 20);

  static const double warmStoneGrassAutoMult = 1.45;
  static const Duration warmStoneDuration = Duration(seconds: 8);
  static const Duration warmStoneCooldown = Duration(seconds: 25);

  static const double tentSpawnMult = 1.30;
  static const double tentOfflineMult = 1.20;
  static const Duration tentDuration = Duration(seconds: 15);
  static const Duration tentCooldown = Duration(seconds: 40);

  // --- Multipliers v0: roles ---

  static const int roleSlotsStart = 1;
  static const double roleNanyaAutoBonus = 0.15;
  static const double roleSobiratelFindBonus = 0.20;
  static const int roleStorozhSoftCapBonus = 1;
  static const double roleStorozhBerryFactor = 0.90;

  // --- Multipliers v0: research effects ---

  static const double researchFlowerBonus = 0.08;
  static const Duration researchMudExtra = Duration(seconds: 4);
  static const double researchBerryRespawnFactor = 0.85;
  static const double researchFoodDropBonus = 0.10;

  // --- Juice / tips ---


  /// Brief merge flash duration on the new merged capy.
  static const Duration mergeFlashDuration = Duration(milliseconds: 520);

  /// SharedPreferences key: first-launch tip overlay dismissed.
  static const String tipsSeenKey = 'capy_clicker_tips_seen_v1_2';
}
