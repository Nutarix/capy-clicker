import 'dart:ui';

import 'balance.dart';
import 'capybara.dart';

/// Soft magnet while a capy is dragged (spec 006): pulls toward the nearest
/// capy or pile within [BalanceV0.magnetRadius], any level. A snap assist on
/// the gesture, not map-wide.
abstract final class PileMagnet {
  /// Nearest capy within [radius] of [dragNormalized] that [draggedId] could
  /// sit with: not itself, not its own pile ([draggedPileId]). A full pile
  /// counts only with [includeFull] (on release: a soft refusal there).
  static PileMagnetHit? nearest({
    required String draggedId,
    String? draggedPileId,
    required Offset dragNormalized,
    required Iterable<Capybara> herd,
    double radius = BalanceV0.magnetRadius,
    bool includeFull = false,
  }) {
    final sizes = <String, int>{};
    for (final c in herd) {
      final p = c.pileId;
      if (p != null) sizes[p] = (sizes[p] ?? 0) + 1;
    }
    Capybara? best;
    var bestDist = double.infinity;
    for (final other in herd) {
      if (other.id == draggedId) continue;
      final p = other.pileId;
      if (p != null && p == draggedPileId) continue;
      final full = p != null && sizes[p]! >= BalanceV0.pileMaxSize;
      if (full && !includeFull) continue;
      final dist = (other.position - dragNormalized).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = other;
      }
    }
    if (best == null || bestDist > radius) return null;
    final p = best.pileId;
    return PileMagnetHit(
      target: best,
      distance: bestDist,
      full: p != null && sizes[p]! >= BalanceV0.pileMaxSize,
    );
  }

  /// Soft pull: lerp [drag] toward [toward] by [t] (0 = none, 1 = snap).
  static Offset lerpToward(Offset drag, Offset toward, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return Offset.lerp(drag, toward, clamped)!;
  }

  /// True when [distance] is close enough to seat during the drag.
  ///
  /// Mid-drag uses [BalanceV0.magnetSnapFraction] of the radius so the assist
  /// only finishes once the finger is clearly committed; release uses the
  /// full radius via [nearest].
  static bool withinSnapDistance(
    double distance, {
    double radius = BalanceV0.magnetRadius,
    double snapFraction = BalanceV0.magnetSnapFraction,
  }) {
    return distance <= radius * snapFraction;
  }
}

/// Result of a magnet query.
final class PileMagnetHit {
  const PileMagnetHit({
    required this.target,
    required this.distance,
    this.full = false,
  });

  final Capybara target;
  final double distance;

  /// The target sits in a pile of [BalanceV0.pileMaxSize].
  final bool full;
}
