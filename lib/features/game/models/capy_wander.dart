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

  /// Logical pixels of grass between opaque sprite edges.
  ///
  /// Half a sprite plus a few pixels still lets bodies touch: the drawn
  /// sheet fills its width, so centers ~140px apart on a phone overlap.
  static const double peerGrassPx = 22;

  /// Walk-sheet pixel size. BoxFit.contain in the level box, width-limited.
  static const double sheetPixelWidth = 256;
  static const double sheetPixelHeight = 188;

  /// Latest displayed anchor per capy so a walk does not cut through a peer
  /// that has not persisted its destination yet.
  static final Map<String, Offset> livePositions = {};

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
  static const double propPadPx = 6;

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

  /// Opaque sprite box. Anchor is the footprint center used by
  /// [MeadowDraggableCapybara] (badge hangs below the sprite).
  ///
  /// The sheet is wider than the widget box, so [BoxFit.contain] letterboxes
  /// vertically. Peer and prop tests use the drawn pixels, not the empty
  /// padding inside the box.
  static double opaqueSpriteHeight(double capyWidth) =>
      capyWidth * (sheetPixelHeight / sheetPixelWidth);

  static Rect bodyRect(Offset anchor, Size meadow, {double capyWidth = 70}) {
    final boxH = capyWidth * 0.95;
    final drawnH = opaqueSpriteHeight(capyWidth);
    final footprintH = boxH + 26;
    final footprintW = capyWidth + 8;
    final boxTop = anchor.dy * meadow.height - footprintH / 2;
    final spriteTop = boxTop + (boxH - drawnH) / 2;
    final left = anchor.dx * meadow.width - footprintW / 2;
    return Rect.fromLTWH(
      left / meadow.width,
      spriteTop / meadow.height,
      capyWidth / meadow.width,
      drawnH / meadow.height,
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
      // Full 72×64 marker, not only the inner 56×44 card. The drawn
      // stump/nest reads larger than the card, and bodies were standing on it.
      _rectPx(
        centerX: stumpCenter.dx,
        centerY: stumpCenter.dy,
        widthPx: 64,
        heightPx: 52,
        dxPx: -32,
        dyPx: -26,
        meadow: meadow,
      ),
      _rectPx(
        centerX: nestCenter.dx,
        centerY: nestCenter.dy,
        widthPx: 64,
        heightPx: 52,
        dxPx: -32,
        dyPx: -26,
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
      // Mud sheet is wide, so BoxFit.contain in the 110×78 box draws ~110×55.
      // The rect is that drawn oval, centered in the 168×124 marker.
      list.add(
        _rectPx(
          centerX: mudCenter.dx,
          centerY: mudCenter.dy,
          widthPx: 110,
          heightPx: 56,
          dxPx: -55,
          dyPx: -48 + (124 - 56) / 2,
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

  /// Half-width / half-height of one standing sprite, plus half the grass strip.
  ///
  /// Two radii sum to a full sprite plus [peerGrassPx] of meadow between the
  /// drawn edges. The old +5px air left centers close enough that the sheets
  /// still touched.
  static ({double rx, double ry}) personalRadii(
    Size? meadowSize, {
    double capyWidth = 70,
  }) {
    final meadow = _meadow(meadowSize);
    final body = bodyRect(const Offset(0.5, 0.5), meadow, capyWidth: capyWidth);
    return (
      rx: body.width / 2 + (peerGrassPx / 2) / meadow.width,
      ry: body.height / 2 + (peerGrassPx / 2) / meadow.height,
    );
  }

  /// Center separation that keeps grass between two drawn bodies.
  static ({double minX, double minY}) pairSeparation(
    Size? meadowSize, {
    double capyWidth = 70,
    double otherWidth = 70,
  }) {
    final meadow = _meadow(meadowSize);
    final a = personalRadii(meadow, capyWidth: capyWidth);
    final b = personalRadii(meadow, capyWidth: otherWidth);
    return (
      minX: math.max(a.rx + b.rx, peerGap),
      minY: math.max(a.ry + b.ry, peerGap * 0.85),
    );
  }

  /// Longer personal axis — a circle that covers the sprite.
  static double personalRadius(Size? meadowSize, {double capyWidth = 70}) {
    final r = personalRadii(meadowSize, capyWidth: capyWidth);
    return math.max(r.rx, r.ry);
  }

  static bool overlapsPeer(
    Offset p,
    List<Offset> others, {
    double gap = peerGap,
    Size? meadowSize,
    double capyWidth = 70,
    List<double>? peerWidths,
  }) {
    final meadow = _meadow(meadowSize);
    for (var i = 0; i < others.length; i++) {
      final otherW = (peerWidths != null && i < peerWidths.length)
          ? peerWidths[i]
          : capyWidth;
      final sep = pairSeparation(
        meadow,
        capyWidth: capyWidth,
        otherWidth: otherW,
      );
      // Floor with the caller's gap so a legacy center distance still counts.
      final minX = math.max(sep.minX, gap);
      final minY = math.max(sep.minY, gap * 0.85);
      final o = others[i];
      // Inflated body boxes, not a circle. A circle of the long axis pushed
      // the herd into one row and the fallback then stacked the extras.
      if ((p.dx - o.dx).abs() < minX && (p.dy - o.dy).abs() < minY) {
        return true;
      }
    }
    return false;
  }

  /// Push [p] out of every peer ellipse, then back onto grass.
  static Offset nudgeOffPeers(
    Offset p, {
    required List<Offset> others,
    required int herdCount,
    Size? meadowSize,
    double capyWidth = 70,
    double salt = 0,
    List<double>? peerWidths,
  }) {
    if (others.isEmpty) return clampToGrass(p, herdCount);
    final meadow = _meadow(meadowSize);
    var o = clampToGrass(p, herdCount);
    for (var k = 0; k < 24; k++) {
      if (!overlapsPeer(
        o,
        others,
        meadowSize: meadow,
        capyWidth: capyWidth,
        peerWidths: peerWidths,
      )) {
        return o;
      }
      var push = Offset.zero;
      for (var i = 0; i < others.length; i++) {
        final other = others[i];
        final otherW = (peerWidths != null && i < peerWidths.length)
            ? peerWidths[i]
            : capyWidth;
        final sep = pairSeparation(
          meadow,
          capyWidth: capyWidth,
          otherWidth: otherW,
        );
        final dx = o.dx - other.dx;
        final dy = o.dy - other.dy;
        final adx = dx.abs();
        final ady = dy.abs();
        if (adx >= sep.minX || ady >= sep.minY) continue;
        final penX = sep.minX - adx;
        final penY = sep.minY - ady;
        if (adx < 1e-6 && ady < 1e-6) {
          final ang = salt * math.pi * 2 + k * 0.85;
          push += Offset(math.cos(ang) * sep.minX, math.sin(ang) * sep.minY);
          continue;
        }
        // Leave along the cheaper axis so a row can sit beside a column.
        if (penX <= penY) {
          final dir = adx < 1e-6
              ? (math.cos(salt * math.pi * 2 + k) >= 0 ? 1.0 : -1.0)
              : dx.sign;
          push += Offset(dir * penX * 1.08, 0);
        } else {
          final dir = ady < 1e-6
              ? (math.sin(salt * math.pi * 2 + k) >= 0 ? 1.0 : -1.0)
              : dy.sign;
          push += Offset(0, dir * penY * 1.08);
        }
      }
      if (push.distance < 1e-5) {
        final ang = salt * math.pi * 2 + k;
        final sep = pairSeparation(meadow, capyWidth: capyWidth);
        push = Offset(math.cos(ang) * sep.minX, math.sin(ang) * sep.minY);
      }
      final next = clampToGrass(o + push, herdCount);
      if ((next - o).distance < 1e-4) {
        final ang = salt * math.pi * 2 + k * 1.3;
        o = clampToGrass(
          o + Offset(math.cos(ang) * 0.045, math.sin(ang) * 0.035),
          herdCount,
        );
      } else {
        o = next;
      }
    }
    return o;
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

  /// Pick a grass target whose body misses stump, nest, basket, puddle, peers.
  ///
  /// Each capy keeps a [personalRadius]. A sample that would cover a prop or
  /// another body is nudged, then repicked. [spreadSalt] (0..1, stable per
  /// capy) fans bodies so they do not share one escape point.
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
    List<double>? peerWidths,
  }) {
    final meadow = _meadow(meadowSize);
    Offset? bestClear;
    var bestClearScore = -1e9;
    Offset? bestLoose;
    var bestLooseDist = -1.0;

    bool propHit(Offset t) => hitsProp(
      t,
      mudCenter: mudCenter,
      meadowSize: meadow,
      capyWidth: capyWidth,
    );

    bool peerHit(Offset t) => overlapsPeer(
      t,
      others,
      meadowSize: meadow,
      capyWidth: capyWidth,
      peerWidths: peerWidths,
    );

    /// Rescue a sample off props and off other bodies. May still fail.
    Offset rescue(Offset raw, double salt) {
      var t = clampToGrass(raw, herdCount);
      if (propHit(t)) {
        t = clearProps(
          t,
          herdCount: herdCount,
          mudCenter: mudCenter,
          meadowSize: meadow,
          capyWidth: capyWidth,
          salt: salt,
        );
      }
      if (peerHit(t)) {
        t = nudgeOffPeers(
          t,
          others: others,
          herdCount: herdCount,
          meadowSize: meadow,
          capyWidth: capyWidth,
          salt: salt,
          peerWidths: peerWidths,
        );
      }
      if (propHit(t)) {
        t = clearProps(
          t,
          herdCount: herdCount,
          mudCenter: mudCenter,
          meadowSize: meadow,
          capyWidth: capyWidth,
          salt: salt + 0.2,
        );
      }
      // Prop push can land back on a peer — one more nudge, then stop.
      if (peerHit(t) && !propHit(t)) {
        t = nudgeOffPeers(
          t,
          others: others,
          herdCount: herdCount,
          meadowSize: meadow,
          capyWidth: capyWidth,
          salt: salt + 0.35,
          peerWidths: peerWidths,
        );
      }
      return clampToGrass(t, herdCount);
    }

    void consider(Offset t) {
      if (!onGrass(t, herdCount) || propHit(t)) return;
      final spread = _spreadScore(t, from, others, mudCenter: mudCenter);
      // Stable per-capy fan so two bodies do not pick the same grass point.
      final ang = math.atan2(t.dy - from.dy, t.dx - from.dx);
      final fan = math.cos(ang - spreadSalt * math.pi * 2) * 0.035;
      final hop = (t - from).distance;
      final hopBias = hop >= minDist * 0.5 ? 0.02 : 0.0;
      final score = spread + fan + hopBias;
      if (!peerHit(t)) {
        if (score > bestClearScore) {
          bestClearScore = score;
          bestClear = t;
        }
      }
    }

    /// Off-prop grass, even if a body ellipse overlaps. Used when the plate
    /// cannot give everyone a full personal radius — still pick the farthest
    /// point so bodies do not restack on one coordinate.
    void considerSpread(Offset raw) {
      final t = clampToGrass(raw, herdCount);
      if (!onGrass(t, herdCount) || propHit(t)) return;
      var nearest = (t - from).distance;
      for (final o in others) {
        final d = (t - o).distance;
        if (d < nearest) nearest = d;
      }
      final ang = math.atan2(t.dy - from.dy, t.dx - from.dx);
      final fan = math.cos(ang - spreadSalt * math.pi * 2) * 0.008;
      final score = nearest + fan;
      if (score > bestLooseDist) {
        bestLooseDist = score;
        bestLoose = t;
      }
    }

    for (var i = 0; i < 24; i++) {
      final salt = (spreadSalt - 0.5) * 0.06 + (i - 12) * 0.008;
      final raw = _sampleGrass(random01, herdCount);
      // Raw grass first. Rescue can shove a free pocket back onto a peer.
      consider(clampToGrass(raw, herdCount));
      consider(rescue(raw, salt));
      considerSpread(raw);
    }

    // Grid the plate so a crowded meadow still gets a free personal radius.
    final plate = grassPlate(herdCount);
    const cols = 11;
    const rows = 8;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final fx = cols == 1 ? 0.5 : x / (cols - 1);
        final fy = rows == 1 ? 0.5 : y / (rows - 1);
        final jitter = (spreadSalt - 0.5) * 0.02;
        final raw = Offset(
          plate.left + (fx + jitter) * (plate.right - plate.left),
          plate.top + fy * (plate.bottom - plate.top),
        );
        consider(clampToGrass(raw, herdCount));
        consider(rescue(raw, spreadSalt + x * 0.05 + y * 0.07));
        considerSpread(raw);
      }
    }

    // A clear pocket wins even when it is a short hop. Falling through to
    // the loose point is what stacked bodies that already had room.
    if (bestClear != null) return bestClear!;

    final loose = bestLoose;
    if (loose != null && !propHit(loose) && onGrass(loose, herdCount)) {
      final nudged = nudgeOffPeers(
        loose,
        others: others,
        herdCount: herdCount,
        meadowSize: meadow,
        capyWidth: capyWidth,
        salt: spreadSalt,
        peerWidths: peerWidths,
      );
      if (!propHit(nudged) && onGrass(nudged, herdCount) && !peerHit(nudged)) {
        return nudged;
      }
      // Farthest off-prop grass. Still not the same coordinate as a peer.
      return loose;
    }

    final fallback = rescue(from, (spreadSalt - 0.5) * 0.08);
    if (!propHit(fallback) && !peerHit(fallback)) return fallback;
    if (!propHit(fallback)) return fallback;
    // Last push off the prop we started on — never stay on stump/nest/basket.
    final pushed = clearProps(
      from,
      herdCount: herdCount,
      mudCenter: mudCenter,
      meadowSize: meadow,
      capyWidth: capyWidth,
      salt: spreadSalt,
    );
    if (!propHit(pushed)) return pushed;
    return bestLoose ?? pushed;
  }


  /// Stop a straight walk before the body enters a prop or another capy.
  ///
  /// If [from] is already inside someone, keep going until the path is clear
  /// so a stacked body can walk out instead of staying put.
  static Offset clipTravel({
    required Offset from,
    required Offset to,
    required List<Offset> others,
    required int herdCount,
    Offset? mudCenter,
    Size? meadowSize,
    double capyWidth = 70,
    List<double>? peerWidths,
  }) {
    bool bad(Offset p) =>
        !onGrass(p, herdCount) ||
        hitsProp(
          p,
          mudCenter: mudCenter,
          meadowSize: meadowSize,
          capyWidth: capyWidth,
        ) ||
        overlapsPeer(
          p,
          others,
          meadowSize: meadowSize,
          capyWidth: capyWidth,
          peerWidths: peerWidths,
        );

    var escaping = bad(from);
    var safe = from;
    const steps = 8;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final p = Offset(
        from.dx + (to.dx - from.dx) * t,
        from.dy + (to.dy - from.dy) * t,
      );
      if (!onGrass(p, herdCount)) return safe;
      final blocked = bad(p);
      if (escaping) {
        safe = p;
        if (!blocked) escaping = false;
        continue;
      }
      if (blocked) return safe;
      safe = p;
    }
    return to;
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
