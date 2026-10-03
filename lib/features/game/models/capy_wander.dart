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
  /// 30px still reads as a strip after idle bob. When seven bodies do not
  /// fit, placement steps down through [peerGrassSteps] and then takes the
  /// widest strip the plate still has, out to the glade edge.
  static const double peerGrassPx = 30;

  /// Widest strip first. The tail is the smallest gap we still prefer
  /// over two sprites touching.
  static const List<double> peerGrassSteps = [30, 20, 14, 10];

  /// Walk-sheet pixel size. BoxFit.contain in the level box, width-limited.
  static const double sheetPixelWidth = 256;
  static const double sheetPixelHeight = 188;

  /// Пень — center disc kept for callers; the body test uses the card rect.
  static const double stumpRadius = 0.078;

  /// Тёплый камень reads as a grassy nest — keep bodies off it.
  static const double nestRadius = 0.072;

  /// Painted wood-ring disc (mud.png), not the small gameplay hit circle.
  ///
  /// Half-extent used only by the spread score. The hard test is the sprite
  /// rect in [propRects] — the log slice is much wider than [BalanceV0.mudHitRadius]
  /// on a phone, and a circle of 0.10 let bodies stand on the rings.
  static const double mudBodyRadius = 0.16;

  /// Mud marker in [game_screen]: placed at anchor − (dx, dy), size 168×124.
  static const double mudMarkerW = 168;
  static const double mudMarkerH = 124;
  static const double mudAnchorX = 84;
  static const double mudAnchorY = 48;

  /// `Image.asset` box. The 642×319 sheet is wider, so BoxFit.contain draws
  /// [mudDrawnW]×[mudDrawnH] centered in that box (the brown log disc).
  static const double mudSheetBoxW = 110;
  static const double mudSheetBoxH = 78;
  static const double mudPngW = 642;
  static const double mudPngH = 319;
  static const double mudDrawnW = mudSheetBoxW;
  static const double mudDrawnH = mudSheetBoxW * mudPngH / mudPngW;

  /// «сюда!» sits this far below the marker, clear of the painted disc.
  static const double mudChipGapBelow = 10;
  static const double mudChipW = 112;
  static const double mudChipH = 28;

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

  /// Grass of the meadow plate: the active glade, out to its edges.
  ///
  /// A fixed inset left the rim empty and stacked the seventh body on a
  /// neighbor. Anchors may sit on the glade edge so sprites keep a grass
  /// strip; stump, nest, basket, puddle, and hint chips stay forbidden.
  static Rect grassPlate(int herdCount) =>
      WorldZones.meadowRectForHerd(herdCount);

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
      // Painted log disc, not the gameplay hit circle. The sheet is centered
      // in the marker, whose anchor sits [mudAnchorY] below the marker top.
      final discTop = (mudMarkerH - mudDrawnH) / 2 - mudAnchorY;
      list.add(
        _rectPx(
          centerX: mudCenter.dx,
          centerY: mudCenter.dy,
          widthPx: mudDrawnW,
          heightPx: mudDrawnH,
          dxPx: -mudDrawnW / 2,
          dyPx: discTop,
          meadow: meadow,
        ),
      );
      // Hint chip hangs under the disc. It must not sit on the wood, and a
      // body must not cover «сюда!».
      final chipTop = mudMarkerH + mudChipGapBelow - mudChipH - mudAnchorY;
      list.add(
        _rectPx(
          centerX: mudCenter.dx,
          centerY: mudCenter.dy,
          widthPx: mudChipW,
          heightPx: mudChipH,
          dxPx: -mudChipW / 2,
          dyPx: chipTop,
          meadow: meadow,
        ),
      );
    }
    return list;
  }

  /// Painted wood ring (disc plus the thin oval), centered like [MudPuddle].
  static Rect mudRingRect(Offset center, Size meadow) {
    final discTop = (mudMarkerH - mudDrawnH) / 2 - mudAnchorY;
    final discCenterDy = discTop + mudDrawnH / 2;
    final ringW = mudDrawnW + 18;
    final ringH = mudDrawnH + 14;
    return _rectPx(
      centerX: center.dx,
      centerY: center.dy,
      widthPx: ringW,
      heightPx: ringH,
      dxPx: -ringW / 2,
      dyPx: discCenterDy - ringH / 2,
      meadow: meadow,
    );
  }

  /// Sprite box centered on [center], with an optional pixel shift of that center.
  static Rect spriteRect(
    Offset center,
    Size meadow, {
    required double widthPx,
    required double heightPx,
    double centerDyPx = 0,
  }) {
    return _rectPx(
      centerX: center.dx,
      centerY: center.dy,
      widthPx: widthPx,
      heightPx: heightPx,
      dxPx: -widthPx / 2,
      dyPx: centerDyPx - heightPx / 2,
      meadow: meadow,
    );
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
    double? grassPx,
  }) {
    final meadow = _meadow(meadowSize);
    final grass = grassPx ?? peerGrassPx;
    final body = bodyRect(const Offset(0.5, 0.5), meadow, capyWidth: capyWidth);
    return (
      rx: body.width / 2 + (grass / 2) / meadow.width,
      ry: body.height / 2 + (grass / 2) / meadow.height,
    );
  }

  /// Signed grass between two body rects, in logical pixels.
  ///
  /// Positive on the axis that separates them. Negative when the rects
  /// overlap on both axes (the less-overlapping axis, so zero is a touch).
  static double axisGapPx(Rect a, Rect b, Size meadow) {
    final gapX = math.max(a.left - b.right, b.left - a.right) * meadow.width;
    final gapY = math.max(a.top - b.bottom, b.top - a.bottom) * meadow.height;
    return math.max(gapX, gapY);
  }

  /// Smallest [axisGapPx] from [p] to [others]. Empty herd → a wide gap.
  static double minPeerGapPx(
    Offset p,
    List<Offset> others, {
    Size? meadowSize,
    double capyWidth = 70,
    List<double>? peerWidths,
  }) {
    if (others.isEmpty) return 100000;
    final meadow = _meadow(meadowSize);
    final me = bodyRect(p, meadow, capyWidth: capyWidth);
    var best = 100000.0;
    for (var i = 0; i < others.length; i++) {
      final w = (peerWidths != null && i < peerWidths.length)
          ? peerWidths[i]
          : capyWidth;
      final gap = axisGapPx(
        me,
        bodyRect(others[i], meadow, capyWidth: w),
        meadow,
      );
      if (gap < best) best = gap;
    }
    return best;
  }

  /// True when stepping to [to] would close grass against any one peer.
  ///
  /// Checked per body, not on the herd minimum. A capy still stacked on
  /// someone must not slide into a third body while that first gap stays
  /// the worst. A full strip may narrow down to [peerGrassPx]. Below that,
  /// a step is allowed only when it opens space with the peer it approaches.
  static bool peerGapShrinks(
    Offset from,
    Offset to,
    List<Offset> others, {
    Size? meadowSize,
    double capyWidth = 70,
    List<double>? peerWidths,
  }) {
    if (others.isEmpty) return false;
    final meadow = _meadow(meadowSize);
    final fromRect = bodyRect(from, meadow, capyWidth: capyWidth);
    final toRect = bodyRect(to, meadow, capyWidth: capyWidth);
    for (var i = 0; i < others.length; i++) {
      final w = (peerWidths != null && i < peerWidths.length)
          ? peerWidths[i]
          : capyWidth;
      final peer = bodyRect(others[i], meadow, capyWidth: w);
      final next = axisGapPx(toRect, peer, meadow);
      if (next >= peerGrassPx - 0.5) continue;
      final now = axisGapPx(fromRect, peer, meadow);
      if (next < now - 0.5) return true;
    }
    return false;
  }

  /// Center separation that keeps grass between two drawn bodies.
  static ({double minX, double minY}) pairSeparation(
    Size? meadowSize, {
    double capyWidth = 70,
    double otherWidth = 70,
    double? grassPx,
  }) {
    final meadow = _meadow(meadowSize);
    final a = personalRadii(meadow, capyWidth: capyWidth, grassPx: grassPx);
    final b = personalRadii(meadow, capyWidth: otherWidth, grassPx: grassPx);
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
    double? grassPx,
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
        grassPx: grassPx,
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
    double? grassPx,
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
        grassPx: grassPx,
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
          grassPx: grassPx,
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
        final sep = pairSeparation(
          meadow,
          capyWidth: capyWidth,
          grassPx: grassPx,
        );
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
  ///
  /// The full [peerGrassPx] strip wins when the plate has room. Otherwise
  /// the same search repeats down [peerGrassSteps]. If even the smallest
  /// strip does not fit, the widest remaining gap is used and a tie prefers
  /// the glade edge over stacking in the middle.
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

    bool propHit(Offset t) => hitsProp(
      t,
      mudCenter: mudCenter,
      meadowSize: meadow,
      capyWidth: capyWidth,
    );

    final fromOnPlate = onGrass(from, herdCount) && !propHit(from);
    final fromGap = fromOnPlate
        ? minPeerGapPx(
            from,
            others,
            meadowSize: meadow,
            capyWidth: capyWidth,
            peerWidths: peerWidths,
          )
        : -100000.0;

    /// Highest-spread point whose grass strip is at least [grass] and, when
    /// we already stand tighter than a full strip, not worse than [from].
    Offset? hunt(double grass) {
      Offset? bestClear;
      var bestClearScore = -1e9;
      final keep = (!fromOnPlate || fromGap >= peerGrassPx)
          ? grass
          : math.max(grass, fromGap);

      bool peerHit(Offset t) => overlapsPeer(
        t,
        others,
        meadowSize: meadow,
        capyWidth: capyWidth,
        peerWidths: peerWidths,
        grassPx: grass,
      );

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
            grassPx: grass,
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
        if (peerHit(t) && !propHit(t)) {
          t = nudgeOffPeers(
            t,
            others: others,
            herdCount: herdCount,
            meadowSize: meadow,
            capyWidth: capyWidth,
            salt: salt + 0.35,
            peerWidths: peerWidths,
            grassPx: grass,
          );
        }
        return clampToGrass(t, herdCount);
      }

      void consider(Offset t) {
        if (!onGrass(t, herdCount) || propHit(t) || peerHit(t)) return;
        if (minPeerGapPx(
                  t,
                  others,
                  meadowSize: meadow,
                  capyWidth: capyWidth,
                  peerWidths: peerWidths,
                ) +
                0.4 <
            keep) {
          return;
        }
        final spread = _spreadScore(t, from, others, mudCenter: mudCenter);
        final ang = math.atan2(t.dy - from.dy, t.dx - from.dx);
        final fan = math.cos(ang - spreadSalt * math.pi * 2) * 0.035;
        final hop = (t - from).distance;
        final hopBias = hop >= minDist * 0.5 ? 0.02 : 0.0;
        final score = spread + fan + hopBias;
        if (score > bestClearScore) {
          bestClearScore = score;
          bestClear = t;
        }
      }

      for (var i = 0; i < 24; i++) {
        final salt = (spreadSalt - 0.5) * 0.06 + (i - 12) * 0.008;
        final raw = _sampleGrass(random01, herdCount);
        consider(clampToGrass(raw, herdCount));
        consider(rescue(raw, salt));
      }

      final plate = grassPlate(herdCount);
      const cols = 13;
      const rows = 9;
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
          consider(rescue(raw, spreadSalt + x * 0.04 + y * 0.05));
        }
      }
      return bestClear;
    }

    for (final grass in peerGrassSteps) {
      final found = hunt(grass);
      if (found != null) return found;
    }

    // No full strip. Take the widest gap and, on a tie, the plate edge.
    final plate = grassPlate(herdCount);
    Offset? widest;
    var widestScore = -1e12;

    void considerWide(Offset raw) {
      final t = clampToGrass(raw, herdCount);
      if (!onGrass(t, herdCount) || propHit(t)) return;
      final gap = others.isEmpty
          ? peerGrassPx
          : minPeerGapPx(
              t,
              others,
              meadowSize: meadow,
              capyWidth: capyWidth,
              peerWidths: peerWidths,
            );
      if (fromOnPlate && fromGap < peerGrassPx && gap < fromGap - 0.5) {
        return;
      }
      final cx = (plate.left + plate.right) / 2;
      final cy = (plate.top + plate.bottom) / 2;
      final ex = plate.width <= 1e-6
          ? 0.0
          : ((t.dx - cx).abs() / (plate.width / 2)).clamp(0.0, 1.0);
      final ey = plate.height <= 1e-6
          ? 0.0
          : ((t.dy - cy).abs() / (plate.height / 2)).clamp(0.0, 1.0);
      final edge = math.max(ex, ey) * 4.0;
      final ang = math.atan2(t.dy - from.dy, t.dx - from.dx);
      final fan = math.cos(ang - spreadSalt * math.pi * 2) * 0.35;
      final score = gap + edge + fan;
      if (score > widestScore) {
        widestScore = score;
        widest = t;
      }
    }

    for (var i = 0; i < 16; i++) {
      considerWide(_sampleGrass(random01, herdCount));
    }
    const cols = 17;
    const rows = 12;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final fx = cols == 1 ? 0.5 : x / (cols - 1);
        final fy = rows == 1 ? 0.5 : y / (rows - 1);
        considerWide(
          Offset(plate.left + fx * plate.width, plate.top + fy * plate.height),
        );
      }
    }
    final wide = widest;
    if (wide != null) return wide;
    if (fromOnPlate) return from;

    final pushed = clearProps(
      from,
      herdCount: herdCount,
      mudCenter: mudCenter,
      meadowSize: meadow,
      capyWidth: capyWidth,
      salt: spreadSalt,
    );
    if (!propHit(pushed)) return pushed;
    return pushed;
  }

  /// Stop a straight walk before the body enters a prop or another capy.
  ///
  /// A step that would shrink the grass strip is cut. A body that is already
  /// tighter than [peerGrassPx] may keep walking while the strip opens.
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
        peerGapShrinks(
          from,
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
