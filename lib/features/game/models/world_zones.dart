import 'dart:ui';

/// Forest playfield zones in normalized coords (0–1) relative to the portrait
/// meadow [SizedBox] (same space as [Capybara.position], mud, berries, flowers).
///
/// See `docs/WORLD_ZONES.md`. The forest asset has blocked tree trunks / canopy;
/// gameplay entities may only occupy the open grass clearing.
abstract final class WorldZones {
  /// Walkable meadow / clearing axis-aligned rect (normalized).
  ///
  /// Approximates the center–lower grass opening of `bg_forest.png`:
  /// inset from left/right tree trunks and below the top canopy / treeline.
  ///   left   ≈ inside left trunk/shrub edge
  ///   right  ≈ clear of the large right-side tree
  ///   top    ≈ below dense treeline / canopy
  ///   bottom ≈ above the very bottom edge (padding)
  static const double meadowLeft = 0.10;
  static const double meadowTop = 0.52;
  static const double meadowRight = 0.86;
  static const double meadowBottom = 0.92;

  /// Inclusive AABB of the walkable grass clearing.
  static Rect get meadowRect => const Rect.fromLTRB(
        meadowLeft,
        meadowTop,
        meadowRight,
        meadowBottom,
      );

  /// True if [normalized] lies inside the walkable meadow (inclusive edges).
  static bool isInMeadow(Offset normalized) {
    return normalized.dx >= meadowLeft &&
        normalized.dx <= meadowRight &&
        normalized.dy >= meadowTop &&
        normalized.dy <= meadowBottom;
  }

  /// Clamp [normalized] into the walkable meadow rect.
  ///
  /// Used for capybara spawn, drag-end, merge placement, and any future wander.
  static Offset clampToMeadow(Offset normalized) {
    return Offset(
      normalized.dx.clamp(meadowLeft, meadowRight),
      normalized.dy.clamp(meadowTop, meadowBottom),
    );
  }

  /// Random point uniformly inside the meadow (caller supplies [random01]).
  static Offset randomInMeadow(double Function() random01) {
    return Offset(
      meadowLeft + random01() * (meadowRight - meadowLeft),
      meadowTop + random01() * (meadowBottom - meadowTop),
    );
  }


  // --- Static decor positions (must all be inside meadowRect) ---

  /// Fixed flower tap targets (normalized). Kept on grass, clear of mud/berry.
  static const List<(double x, double y)> flowerPositions = [
    (0.16, 0.60),
    (0.68, 0.58),
    (0.34, 0.70),
    (0.80, 0.66),
    (0.50, 0.76),
  ];
}
