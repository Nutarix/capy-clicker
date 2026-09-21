import 'dart:ui';

import 'balance.dart';
import 'capybara.dart';

/// Soft magnetic merge assist — only while the player is dragging a capy.
///
/// Not full auto-merge: eligibility is local ([BalanceV0.magnetRadius]) and
/// same-level only. Feels like a snap assist on the gesture, not map-wide AI.
abstract final class MergeMagnet {
  /// Nearest same-level herd mate within [radius] of [dragNormalized].
  ///
  /// Returns null when nothing is eligible (wrong level, self, or too far).
  static MergeMagnetHit? nearestEligible({
    required String draggedId,
    required int draggedLevel,
    required Offset dragNormalized,
    required Iterable<Capybara> herd,
    double radius = BalanceV0.magnetRadius,
  }) {
    Capybara? best;
    var bestDist = double.infinity;

    for (final other in herd) {
      if (other.id == draggedId) continue;
      if (other.level != draggedLevel) continue;
      final dist = (other.position - dragNormalized).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = other;
      }
    }

    if (best == null || bestDist > radius) return null;
    return MergeMagnetHit(target: best, distance: bestDist);
  }

  /// Soft pull: lerp [drag] toward [toward] by [t] (0 = none, 1 = snap).
  static Offset lerpToward(Offset drag, Offset toward, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return Offset.lerp(drag, toward, clamped)!;
  }

  /// True when [distance] is close enough to complete the soft merge.
  ///
  /// Mid-drag uses [BalanceV0.magnetSnapFraction] of the radius so the assist
  /// only finishes once the finger is clearly committed; drag-end uses the
  /// full [BalanceV0.magnetRadius] via [nearestEligible].
  static bool withinSnapDistance(
    double distance, {
    double radius = BalanceV0.magnetRadius,
    double snapFraction = BalanceV0.magnetSnapFraction,
  }) {
    return distance <= radius * snapFraction;
  }
}

/// Result of a magnet eligibility query.
final class MergeMagnetHit {
  const MergeMagnetHit({required this.target, required this.distance});

  final Capybara target;
  final double distance;
}
