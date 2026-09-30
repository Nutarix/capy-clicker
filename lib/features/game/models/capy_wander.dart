import 'dart:math' as math;
import 'dart:ui';

import 'multipliers/cozy_place.dart';
import 'world_zones.dart';

/// Pure helpers for meadow idle bob + wander (no Flutter ticker dependency).
///
/// Walk position uses ease lerp + bounce; paw frames via [CapyWalk] sheets.
abstract final class CapyWander {
  /// Stable 0..1 phase from [id] (idle bob offset / period jitter).
  static double phase01(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 1000) / 1000.0;
  }

  /// Soft idle bob loop length (~1.5–2.5 s).
  static Duration idlePeriod(String id) {
    final ms = (1500 + phase01(id) * 1000).round();
    return Duration(milliseconds: ms);
  }

  /// Pause before the next wander hop.
  static Duration pauseBetweenWalks(double Function() random01) {
    final ms = (1800 + random01() * 3200).round(); // ~1.8–5 s
    return Duration(milliseconds: ms);
  }

  /// Initial delay so the herd does not all start walking together.
  static Duration initialDelay(String id, double Function() random01) {
    final ms = (400 + phase01(id) * 2200 + random01() * 1500).round();
    return Duration(milliseconds: ms);
  }

  /// How far apart body centers should stay (normalized meadow space).
  static const double peerGap = 0.09;

  /// Пень — bodies must not stand on the stump.
  static const double stumpRadius = 0.078;

  /// Тёплый камень reads as a grassy nest — keep bodies off it.
  static const double nestRadius = 0.072;

  /// Temporary puddle sprite (stump-top). Only when a center is passed in.
  static const double mudBodyRadius = 0.10;

  static Offset get stumpCenter =>
      Offset(CozyPlaceKind.pen.center.$1, CozyPlaceKind.pen.center.$2);

  static Offset get nestCenter => Offset(
    CozyPlaceKind.warmStone.center.$1,
    CozyPlaceKind.warmStone.center.$2,
  );

  /// Grass of the meadow plate: walkable glade, inset so a body stays on grass.
  static Rect grassPlate(int herdCount) {
    final r = WorldZones.meadowRectForHerd(herdCount);
    const edge = 0.03;
    var left = r.left + edge;
    var top = r.top + edge;
    var right = r.right - edge;
    var bottom = r.bottom - edge;
    if (right - left < 0.08) {
      left = r.left;
      right = r.right;
    }
    if (bottom - top < 0.08) {
      top = r.top;
      bottom = r.bottom;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Offset clampToGrass(Offset p, int herdCount) {
    final r = grassPlate(herdCount);
    return Offset(p.dx.clamp(r.left, r.right), p.dy.clamp(r.top, r.bottom));
  }

  static bool onGrass(Offset p, int herdCount) {
    final r = grassPlate(herdCount);
    return p.dx >= r.left &&
        p.dx <= r.right &&
        p.dy >= r.top &&
        p.dy <= r.bottom;
  }

  /// Stump, nest, and (optional) live puddle discs.
  static List<(Offset center, double radius)> props({Offset? mudCenter}) {
    final list = <(Offset, double)>[
      (stumpCenter, stumpRadius),
      (nestCenter, nestRadius),
    ];
    if (mudCenter != null) {
      list.add((mudCenter, mudBodyRadius));
    }
    return list;
  }

  static bool hitsProp(Offset p, {Offset? mudCenter}) {
    for (final obs in props(mudCenter: mudCenter)) {
      if ((p - obs.$1).distance < obs.$2) return true;
    }
    return false;
  }

  static bool overlapsPeer(
    Offset p,
    List<Offset> others, {
    double gap = peerGap,
  }) {
    for (final o in others) {
      if ((p - o).distance < gap) return true;
    }
    return false;
  }

  /// Push [p] off stump / nest / puddle, then seat it on the grass plate.
  static Offset clearProps(
    Offset p, {
    required int herdCount,
    Offset? mudCenter,
  }) {
    var o = clampToGrass(p, herdCount);
    for (var k = 0; k < 6; k++) {
      var moved = false;
      for (final obs in props(mudCenter: mudCenter)) {
        final delta = o - obs.$1;
        final d = delta.distance;
        if (d < obs.$2) {
          final away = d < 1e-4
              ? const Offset(0.09, 0.04)
              : delta / d * (obs.$2 - d + 0.012);
          o = clampToGrass(o + away, herdCount);
          moved = true;
        }
      }
      if (!moved) break;
    }
    return clampToGrass(o, herdCount);
  }

  static Offset _sampleGrass(double Function() random01, int herdCount) {
    final r = grassPlate(herdCount);
    return Offset(
      r.left + random01() * (r.right - r.left),
      r.top + random01() * (r.bottom - r.top),
    );
  }

  /// Spread score: prefer points far from peers and props, and not a tiny hop.
  static double _spreadScore(
    Offset t,
    Offset from,
    List<Offset> others, {
    Offset? mudCenter,
  }) {
    var nearest = (t - from).distance;
    for (final o in others) {
      final d = (t - o).distance;
      if (d < nearest) nearest = d;
    }
    for (final obs in props(mudCenter: mudCenter)) {
      final d = (t - obs.$1).distance - obs.$2;
      if (d < nearest) nearest = d;
    }
    return nearest;
  }

  /// Pick a grass target that does not sit on the stump, nest, puddle, or peers.
  static Offset pickTarget({
    required Offset from,
    required double Function() random01,
    required int herdCount,
    List<Offset> others = const [],
    Offset? mudCenter,
    double minDist = 0.055,
  }) {
    Offset? best;
    var bestScore = -1e9;
    for (var i = 0; i < 18; i++) {
      final t = _sampleGrass(random01, herdCount);
      final score = _spreadScore(t, from, others, mudCenter: mudCenter);
      final clear =
          !hitsProp(t, mudCenter: mudCenter) &&
          !overlapsPeer(t, others) &&
          (t - from).distance >= minDist &&
          onGrass(t, herdCount);
      if (clear) return t;
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    final seeded = clearProps(
      best ?? from,
      herdCount: herdCount,
      mudCenter: mudCenter,
    );
    if (!hitsProp(seeded, mudCenter: mudCenter) &&
        !overlapsPeer(seeded, others)) {
      return seeded;
    }
    // Packed plate: still refuse the stump / nest / puddle, then the least-crowded grass.
    var fallback = seeded;
    var fallbackScore = _spreadScore(
      fallback,
      from,
      others,
      mudCenter: mudCenter,
    );
    for (var i = 0; i < 12; i++) {
      final t = clearProps(
        _sampleGrass(random01, herdCount),
        herdCount: herdCount,
        mudCenter: mudCenter,
      );
      if (hitsProp(t, mudCenter: mudCenter)) continue;
      final score = _spreadScore(t, from, others, mudCenter: mudCenter);
      if (!overlapsPeer(t, others)) return t;
      if (score > fallbackScore) {
        fallbackScore = score;
        fallback = t;
      }
    }
    return fallback;
  }

  /// Walk duration scales gently with normalized distance.
  static Duration walkDuration(Offset from, Offset to) {
    final d = (to - from).distance;
    final ms = (850 + d * 4500).clamp(650, 2600).round();
    return Duration(milliseconds: ms);
  }

  /// Smoothstep ease (same family as Curves.easeInOut without Material).
  static double easeInOut(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
  }

  static Offset lerp(Offset a, Offset b, double t) {
    final e = easeInOut(t);
    return Offset(a.dx + (b.dx - a.dx) * e, a.dy + (b.dy - a.dy) * e);
  }

  /// Face right when moving rightward (or standing still).
  static bool faceRight(Offset from, Offset to) => to.dx >= from.dx - 1e-6;

  /// Vertical bob pixels while idle (soft squash feel via translate).
  static double idleBobY(double controller01) => (controller01 - 0.5) * 5.0;

  /// Extra bounce while walking (two soft hops).
  static double walkBounceY(double walk01) {
    final t = walk01.clamp(0.0, 1.0);
    final hops = math.sin(t * 2 * math.pi);
    final envelope = (1.0 - (t - 0.5).abs() * 1.6).clamp(0.15, 1.0);
    return -hops.abs() * 3.2 * envelope;
  }

  /// Soft squash scaleY while idle bobbing (1 ± small).
  static double idleSquashY(double controller01) {
    return 1.0 - (controller01 - 0.5).abs() * 0.04;
  }
}
