import 'dart:ui';

/// One circle of **«Солнечные поляны»** (Sunny Glades): herd band → walkable
/// rect + baseline camera zoom + cozy Russian name.
///
/// Trees / canopy outside [rect] stay blocked. See `docs/WORLD_ZONES.md`.
class SunnyGlade {
  const SunnyGlade({
    required this.id,
    required this.index,
    required this.minHerd,
    required this.maxHerd,
    required this.nameRu,
    required this.nameEn,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.baseZoom,
    required this.unlockToastRu,
  });

  /// Stable machine id (`warm_edge`, `berry_glade`, …).
  final String id;

  /// 0 = starter … 3 = Great Meadow.
  final int index;

  /// Inclusive herd-count band.
  final int minHerd;
  final int maxHerd;

  /// Display name (RU) — used in UI toast / chip.
  final String nameRu;
  final String nameEn;

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Baseline camera scale (fit zoom may step further back to admire the grove).
  final double baseZoom;

  /// Soft one-shot toast when this glade first opens (empty for starter).
  final String unlockToastRu;

  Rect get rect => Rect.fromLTRB(left, top, right, bottom);

  double get width => right - left;
  double get height => bottom - top;
}

/// Forest playfield zones in normalized coords (0–1) relative to the portrait
/// meadow [SizedBox] (same space as [Capybara.position], mud, berries, flowers).
///
/// Walkable grass expands through **«Солнечные поляны»** as the herd grows;
/// canopy and trunks outside the active glade stay blocked.
abstract final class WorldZones {
  /// Four Sunny Glade circles (herd → rect + base zoom).
  ///
  /// | # | Name | Herd | Rect (L,T,R,B) | Zoom |
  /// |---|------|------|----------------|------|
  /// | 0 | Тёплая опушка | 0–4 | 0.10, 0.52, 0.86, 0.92 | 1.00 |
  /// | 1 | Ягодная поляна | 5–7 | 0.06, 0.50, 0.90, 0.93 | 0.82 |
  /// | 2 | Солнечный прогал | 8–10 | 0.05, 0.40, 0.91, 0.945 | 0.66 |
  /// | 3 | Большой луг | 11–12 | 0.03, 0.34, 0.94, 0.96 | 0.50 |
  static const List<SunnyGlade> glades = [
    SunnyGlade(
      id: 'warm_edge',
      index: 0,
      minHerd: 0,
      maxHerd: 4,
      nameRu: 'Тёплая опушка',
      nameEn: 'Warm Forest Edge',
      left: 0.10,
      top: 0.52,
      right: 0.86,
      bottom: 0.92,
      baseZoom: 1.0,
      unlockToastRu: '',
    ),
    SunnyGlade(
      id: 'berry_glade',
      index: 1,
      minHerd: 5,
      maxHerd: 7,
      nameRu: 'Ягодная поляна',
      nameEn: 'Berry Glade',
      // Wider sides — berry bushes along the tree line.
      left: 0.06,
      top: 0.50,
      right: 0.90,
      bottom: 0.93,
      baseZoom: 0.82,
      unlockToastRu: 'Открылась Ягодная поляна',
    ),
    SunnyGlade(
      id: 'sunny_clearing',
      index: 2,
      minHerd: 8,
      maxHerd: 10,
      nameRu: 'Солнечный прогал',
      nameEn: 'Sunny Clearing',
      // Deeper into the forest (taller meadow), still under canopy wall.
      left: 0.05,
      top: 0.40,
      right: 0.91,
      bottom: 0.945,
      baseZoom: 0.66,
      unlockToastRu: 'Открылся Солнечный прогал',
    ),
    SunnyGlade(
      id: 'great_meadow',
      index: 3,
      minHerd: 11,
      maxHerd: 12,
      nameRu: 'Большой луг',
      nameEn: 'Great Meadow',
      // Most of the lower ~2/3; dense canopy stays a soft wall above.
      left: 0.03,
      top: 0.34,
      right: 0.94,
      bottom: 0.96,
      baseZoom: 0.50,
      unlockToastRu: 'Открылся Большой луг',
    ),
  ];

  /// Starter meadow id (Тёплая опушка) — default [GameState.activeMeadowId].
  static const String starterMeadowId = 'warm_edge';

  /// Lookup by stable machine id (`warm_edge`, `mist_edge`, …). Throws if unknown.
  static SunnyGlade gladeById(String id) {
    for (final g in allMeadows) {
      if (g.id == id) return g;
    }
    throw ArgumentError.value(id, 'id', 'Unknown meadow id');
  }

  /// Index of [id] in biome-1 [glades], or -1 (misty meadows are not indexed here).
  static int indexOfMeadowId(String id) {
    for (final g in glades) {
      if (g.id == id) return g.index;
    }
    return -1;
  }

  /// @nodoc Legacy alias used by older call sites / docs tables.
  static List<SunnyGlade> get tiers => glades;

  /// Smallest (starter) meadow edges — Тёплая опушка.
  static const double meadowLeft = 0.10;
  static const double meadowTop = 0.52;
  static const double meadowRight = 0.86;
  static const double meadowBottom = 0.92;

  /// Inclusive AABB of the starter glade (Тёплая опушка).
  static Rect get meadowRect => const Rect.fromLTRB(
        meadowLeft,
        meadowTop,
        meadowRight,
        meadowBottom,
      );

  /// Active Sunny Glade for [herdCount] (clamped into Большой луг above soft-cap).
  static SunnyGlade gladeForHerd(int herdCount) {
    final n = herdCount < 0 ? 0 : herdCount;
    for (final g in glades) {
      if (n <= g.maxHerd) return g;
    }
    return glades.last;
  }

  /// @nodoc Alias for [gladeForHerd].
  static SunnyGlade tierForHerd(int herdCount) => gladeForHerd(herdCount);

  static int gladeIndexForHerd(int herdCount) => gladeForHerd(herdCount).index;

  /// Walkable rect for the current herd size.
  static Rect meadowRectForHerd(int herdCount) => gladeForHerd(herdCount).rect;

  /// True if [normalized] lies inside the walkable meadow for [herdCount]
  /// (inclusive edges). Defaults to the starter glade when [herdCount] is null
  /// (static decor / mud / berry must stay valid in every glade).
  static bool isInMeadow(Offset normalized, {int? herdCount}) {
    final r = herdCount == null ? meadowRect : meadowRectForHerd(herdCount);
    return normalized.dx >= r.left &&
        normalized.dx <= r.right &&
        normalized.dy >= r.top &&
        normalized.dy <= r.bottom;
  }

  /// Clamp [normalized] into the walkable meadow for [herdCount].
  static Offset clampToMeadow(Offset normalized, {int herdCount = 0}) {
    final r = meadowRectForHerd(herdCount);
    return Offset(
      normalized.dx.clamp(r.left, r.right),
      normalized.dy.clamp(r.top, r.bottom),
    );
  }

  /// Random point uniformly inside the meadow for [herdCount].
  static Offset randomInMeadow(
    double Function() random01, {
    int herdCount = 0,
  }) {
    final r = meadowRectForHerd(herdCount);
    return Offset(
      r.left + random01() * (r.right - r.left),
      r.top + random01() * (r.bottom - r.top),
    );
  }

  // --- Static decor (must stay inside Тёплая опушка / starter rect) ---

  /// Fixed flower tap targets (normalized). Inside the smallest glade so they
  /// remain valid as Sunny Glades expand — no regen needed.
  static const List<(double x, double y)> flowerPositions = [
    (0.16, 0.60),
    (0.68, 0.58),
    (0.34, 0.70),
    (0.80, 0.66),
    (0.50, 0.76),
  ];

  // --- Prestige v0: second forest biome «Туманный бор» ---

  /// Biome id for the starter Sunny Glades forest.
  static const String sunnyBiomeId = 'sunny_glades';
  static const String sunnyBiomeNameRu = 'Солнечные поляны';

  /// Biome id for misty forest stub.
  static const String mistyBiomeId = 'misty_grove';
  static const String mistyBiomeNameRu = 'Туманный бор';

  /// Starter meadow of Туманный бор (fresh small clearing).
  static const String mistEdgeMeadowId = 'mist_edge';

  /// Single stub meadow for biome 2 (fixed cozy rect, mid zoom).
  static const SunnyGlade mistEdge = SunnyGlade(
    id: mistEdgeMeadowId,
    index: 0,
    minHerd: 0,
    maxHerd: 4,
    nameRu: 'Туманная опушка',
    nameEn: 'Misty Edge',
    left: 0.10,
    top: 0.52,
    right: 0.86,
    bottom: 0.92,
    baseZoom: 1.0,
    unlockToastRu: 'Открылся Туманный бор',
  );

  /// All playable meadow definitions (biome 1 glades + biome 2 stub).
  static List<SunnyGlade> get allMeadows => [...glades, mistEdge];

  /// Meadows belonging to [biomeId].
  static List<SunnyGlade> meadowsForBiome(String biomeId) {
    if (biomeId == mistyBiomeId) return const [mistEdge];
    return glades;
  }

  /// Biome id for a meadow machine id.
  static String biomeIdForMeadow(String meadowId) {
    if (meadowId == mistEdgeMeadowId) return mistyBiomeId;
    return sunnyBiomeId;
  }

  static String biomeNameRuForMeadow(String meadowId) {
    return biomeIdForMeadow(meadowId) == mistyBiomeId
        ? mistyBiomeNameRu
        : sunnyBiomeNameRu;
  }

  /// True if [id] is the misty stub meadow.
  static bool isMistyMeadow(String id) => id == mistEdgeMeadowId;

  /// Portrait meadow background asset for [meadowId].
  ///
  /// Mist biome (`mist_edge`) uses `bg_misty_woods.png`. Unknown ids fall back
  /// to legacy `bg_forest.png` only.
  static String backgroundAssetForMeadow(String meadowId) {
    switch (meadowId) {
      case 'warm_edge':
        return 'assets/images/bg_warm_edge.png';
      case 'berry_glade':
        return 'assets/images/bg_berry_glade.png';
      case 'sunny_clearing':
        return 'assets/images/bg_sunny_clearing.png';
      case 'great_meadow':
        return 'assets/images/bg_great_meadow.png';
      case mistEdgeMeadowId:
        return 'assets/images/bg_misty_woods.png';
      default:
        return fallbackBackgroundAsset;
    }
  }

  /// Legacy single-forest plate — fallback only.
  static const String fallbackBackgroundAsset = 'assets/images/bg_forest.png';
}
