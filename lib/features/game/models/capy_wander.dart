import 'dart:math' as math;
import 'dart:ui';

import 'balance.dart';
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

  /// Пень — center disc kept for callers; the body test uses the card rect.
  static const double stumpRadius = 0.078;

  /// Тёплый камень reads as a grassy nest — keep bodies off it.
  static const double nestRadius = 0.072;

  /// Temporary puddle sprite. Only when a center is passed in.
  static const double mudBodyRadius = 0.10;

  /// Berry sprite disc around [berryCenter] (body rect is the real test).
  static const double berryRadius = 0.09;

  /// Phone-like meadow used when a live size is not passed in.
  static const Size fallbackMeadow = Size(411, 480);

  /// Gap so a sprite does not visually touch a prop (idle bob included).
  static const double propPadPx = 8;

  static Offset get stumpCenter =>
      Offset(CozyPlaceKind.pen.center.$1, CozyPlaceKind.pen.center.$2);

  static Offset get nestCenter => Offset(
    CozyPlaceKind.warmStone.center.$1,
    CozyPlaceKind.warmStone.center.$2,
  );

  static Offset get berryCenter =>
      const Offset(BalanceV0.berryPosX, BalanceV0.berryPosY);

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

  static Size _meadow(Size? meadowSize) {
    final w = meadowSize?.width ?? fallbackMeadow.width;
    final h = meadowSize?.height ?? fallbackMeadow.height;
    if (w < 1 || h < 1) return fallbackMeadow;
    return Size(w, h);
  }

  /// Sprite box for a standing body. Anchor is the footprint center used by
  /// [MeadowDraggableCapybara] (badge hangs below the sprite).
  static Rect bodyRect(Offset anchor, Size meadow, {double capyWidth = 70}) {
    final fw = capyWidth + 8;
    final fh = capyWidth * 0.95 + 26;
    final spriteH = capyWidth * 0.95;
    final left = anchor.dx * meadow.width - fw / 2;
    final top = anchor.dy * meadow.height - fh / 2;
    return Rect.fromLTWH(
      left / meadow.width,
      top / meadow.height,
      capyWidth / meadow.width,
      spriteH / meadow.height,
    );
  }

  static Rect _rectPx({
    required double centerX,
    required double centerY,
    required double widthPx,
    required double heightPx,
    required double dxPx,
    required double dyPx,
    required Size meadow,
  }) {
    final left = centerX * meadow.width + dxPx;
    final top = centerY * meadow.height + dyPx;
    return Rect.fromLTWH(
      left / meadow.width,
      top / meadow.height,
      widthPx / meadow.width,
      heightPx / meadow.height,
    );
  }

  /// Visible props: stump card, nest card, berry sprite, optional puddle.
  static List<Rect> propRects({Offset? mudCenter, Size? meadowSize}) {
    final meadow = _meadow(meadowSize);
    final list = <Rect>[
      // Cozy card is 56×44, centered in the 72×64 marker.
      _rectPx(
        centerX: stumpCenter.dx,
        centerY: stumpCenter.dy,
        widthPx: 56,
        heightPx: 44,
        dxPx: -28,
        dyPx: -22,
        meadow: meadow,
      ),
      _rectPx(
        centerX: nestCenter.dx,
        centerY: nestCenter.dy,
        widthPx: 56,
        heightPx: 44,
        dxPx: -28,
        dyPx: -22,
        meadow: meadow,
      ),
      // Basket sprite centered in the 120×112 box (top inset 44).
      _rectPx(
        centerX: berryCenter.dx,
        centerY: berryCenter.dy,
        widthPx: 64,
        heightPx: 68,
        dxPx: -32,
        dyPx: -44 + (112 - 68) / 2,
        meadow: meadow,
      ),
    ];
    if (mudCenter != null) {
      // Mud sprite 110×78 centered in the 168×124 box (top inset 48).
      list.add(
        _rectPx(
          centerX: mudCenter.dx,
          centerY: mudCenter.dy,
          widthPx: 110,
          heightPx: 78,
          dxPx: -55,
          dyPx: -48 + (124 - 78) / 2,
          meadow: meadow,
        ),
      );
    }
    return list;
  }

  static Rect _pad(Rect prop, Size meadow) {
    return Rect.fromLTRB(
      prop.left - propPadPx / meadow.width,
      prop.top - propPadPx / meadow.height,
      prop.right + propPadPx / meadow.width,
      prop.bottom + propPadPx / meadow.height,
    );
  }

  /// True when the standing sprite would cover a prop (not merely the anchor).
  static bool hitsProp(
    Offset p, {
    Offset? mudCenter,
    Size? meadowSize,
    double capyWidth = 70,
  }) {
    final meadow = _meadow(meadowSize);
    final body = bodyRect(p, meadow, capyWidth: capyWidth);
    for (final prop in propRects(mudCenter: mudCenter, meadowSize: meadow)) {
      if (body.overlaps(_pad(prop, meadow))) return true;
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

  /// Push [p] until the body misses every prop, fanning with [salt] so two
  /// bodies leaving the same prop do not land on one point.
  static Offset clearProps(
    Offset p, {
    required int herdCount,
    Offset? mudCenter,
    Size? meadowSize,
    double capyWidth = 70,
    double salt = 0,
  }) {
    final meadow = _meadow(meadowSize);
    var o = clampToGrass(p, herdCount);
    for (var k = 0; k < 10; k++) {
      final body = bodyRect(o, meadow, capyWidth: capyWidth);
      Rect? hit;
      for (final prop in propRects(mudCenter: mudCenter, meadowSize: meadow)) {
        final padded = _pad(prop, meadow);
        if (body.overlaps(padded)) {
          hit = padded;
          break;
        }
      }
      if (hit == null) break;
      final overlapX =
          math.min(body.right, hit.right) - math.max(body.left, hit.left);
      final overlapY =
          math.min(body.bottom, hit.bottom) - math.max(body.top, hit.top);
      final fan = salt + (k.isEven ? 1 : -1) * (0.012 + k * 0.004);
      final Offset delta;
      if (overlapX <= overlapY) {
        final dir = body.center.dx >= hit.center.dx ? 1.0 : -1.0;
        delta = Offset(dir * (overlapX + 0.004), fan);
      } else {
        final dir = body.center.dy >= hit.center.dy ? 1.0 : -1.0;
        delta = Offset(fan, dir * (overlapY + 0.004));
      }
      final nudged = clampToGrass(o + delta, herdCount);
      if ((nudged - o).distance < 1e-4) {
        // Grass edge blocked the push — step the long way around the prop.
        final around = Offset(-delta.dy, delta.dx);
        final len = around.distance;
        if (len < 1e-6) break;
        o = clampToGrass(o + around / len * 0.04, herdCount);
      } else {
        o = nudged;
      }
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
    final discs = <(Offset, double)>[
      (stumpCenter, stumpRadius),
      (nestCenter, nestRadius),
      (berryCenter, berryRadius),
    ];
    if (mudCenter != null) discs.add((mudCenter, mudBodyRadius));
    for (final disc in discs) {
      final d = (t - disc.$1).distance - disc.$2;
      if (d < nearest) nearest = d;
    }
    return nearest;
  }

  static bool _targetClear(
    Offset t, {
    required Offset from,
    required int herdCount,
    required List<Offset> others,
    required Offset? mudCenter,
    required Size meadow,
    required double capyWidth,
    required double minDist,
  }) {
    return onGrass(t, herdCount) &&
        !hitsProp(
          t,
          mudCenter: mudCenter,
          meadowSize: meadow,
          capyWidth: capyWidth,
        ) &&
        !overlapsPeer(t, others) &&
        (t - from).distance >= minDist;
  }

  /// Pick a grass target whose body misses stump, nest, basket, puddle, peers.
  ///
  /// A sample that would cover a prop is nudged, then repicked. [spreadSalt]
  /// (0..1, stable per capy) fans bodies so they do not share one escape point.
  static Offset pickTarget({
    required Offset from,
    required double Function() random01,
    required int herdCount,
    List<Offset> others = const [],
    Offset? mudCenter,
    double minDist = 0.055,
    Size? meadowSize,
    double capyWidth = 70,
    double spreadSalt = 0,
  }) {
    final meadow = _meadow(meadowSize);
    Offset? best;
    var bestScore = -1e9;

    void consider(Offset t) {
      if (hitsProp(
        t,
        mudCenter: mudCenter,
        meadowSize: meadow,
        capyWidth: capyWidth,
      )) {
        return;
      }
      final score = _spreadScore(t, from, others, mudCenter: mudCenter);
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }

    for (var i = 0; i < 22; i++) {
      final raw = _sampleGrass(random01, herdCount);
      final salt = (spreadSalt - 0.5) * 0.06 + (i - 11) * 0.008;
      var t = raw;
      if (hitsProp(
        t,
        mudCenter: mudCenter,
        meadowSize: meadow,
        capyWidth: capyWidth,
      )) {
        t = clearProps(
          t,
          herdCount: herdCount,
          mudCenter: mudCenter,
          meadowSize: meadow,
          capyWidth: capyWidth,
          salt: salt,
        );
      }
      // Still covering a prop after the nudge — repick.
      if (hitsProp(
        t,
        mudCenter: mudCenter,
        meadowSize: meadow,
        capyWidth: capyWidth,
      )) {
        continue;
      }
      consider(t);
      if (_targetClear(
        t,
        from: from,
        herdCount: herdCount,
        others: others,
        mudCenter: mudCenter,
        meadow: meadow,
        capyWidth: capyWidth,
        minDist: minDist,
      )) {
        return t;
      }
    }

    var fallback =
        best ??
        clearProps(
          from,
          herdCount: herdCount,
          mudCenter: mudCenter,
          meadowSize: meadow,
          capyWidth: capyWidth,
          salt: (spreadSalt - 0.5) * 0.08,
        );
    consider(fallback);
    if (_targetClear(
      fallback,
      from: from,
      herdCount: herdCount,
      others: others,
      mudCenter: mudCenter,
      meadow: meadow,
      capyWidth: capyWidth,
      minDist: 0,
    )) {
      return fallback;
    }

    // Packed plate: orbit so bodies do not restack on one rim point.
    for (var i = 0; i < 16; i++) {
      final ang = spreadSalt * 6.28 + i * 0.85;
      final radius = 0.045 + (i % 5) * 0.02;
      final raw = clampToGrass(
        fallback +
            Offset(math.cos(ang) * radius, math.sin(ang) * radius * 0.75),
        herdCount,
      );
      final t = clearProps(
        raw,
        herdCount: herdCount,
        mudCenter: mudCenter,
        meadowSize: meadow,
        capyWidth: capyWidth,
        salt: (spreadSalt - 0.5) * 0.05 + (i - 8) * 0.01,
      );
      if (hitsProp(
        t,
        mudCenter: mudCenter,
        meadowSize: meadow,
        capyWidth: capyWidth,
      )) {
        continue;
      }
      consider(t);
      if (!overlapsPeer(t, others) && onGrass(t, herdCount)) return t;
    }
    return best ?? fallback;
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
