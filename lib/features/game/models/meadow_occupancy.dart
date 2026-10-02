import 'dart:ui';

import 'balance.dart';
import 'capy_wander.dart';
import 'multipliers/cozy_place.dart';
import 'world_zones.dart';

/// One clearance rule for meadow props.
///
/// Flowers, the puddle ring, stump, warm stone, tent, berry basket, and capy
/// bodies keep [CapyWander.peerGrassPx] of grass between their sprites. A
/// taken spot is replaced by another point on the walkable grass. The puddle
/// itself stays in the low band chosen by [BalanceV0.randomMudCenter].
abstract final class MeadowOccupancy {
  /// Matches [FlowerDot.spriteSize].
  static const double flowerSprite = 40;

  /// Matches the stump / nest / tent card in [CapyWander.propRects].
  static const double placeSpriteW = 64;
  static const double placeSpriteH = 52;

  static const double basketSpriteW = 64;
  static const double basketSpriteH = 68;

  /// Basket art is centered in the 120×112 box, 12px below the anchor.
  static const double basketCenterDy = 12;

  static Rect flowerRect(Offset center, Size meadow) => CapyWander.spriteRect(
    center,
    meadow,
    widthPx: flowerSprite,
    heightPx: flowerSprite,
  );

  static Rect placeRect(Offset center, Size meadow) => CapyWander.spriteRect(
    center,
    meadow,
    widthPx: placeSpriteW,
    heightPx: placeSpriteH,
  );

  static Rect basketRect(Size meadow) => CapyWander.spriteRect(
    CapyWander.berryCenter,
    meadow,
    widthPx: basketSpriteW,
    heightPx: basketSpriteH,
    centerDyPx: basketCenterDy,
  );

  static Rect puddleRect(Offset center, Size meadow) =>
      CapyWander.mudRingRect(center, meadow);

  static Rect capyRect(Offset center, Size meadow, double widthPx) =>
      CapyWander.bodyRect(center, meadow, capyWidth: widthPx);

  /// Edge gap in pixels. Positive when the boxes are apart on one axis.
  /// Negative when they overlap (the smaller overlap depth).
  static double edgeGapPx(Rect a, Rect b, Size meadow) {
    final gapX = _axisGap(a.left, a.right, b.left, b.right) * meadow.width;
    final gapY = _axisGap(a.top, a.bottom, b.top, b.bottom) * meadow.height;
    return gapX > gapY ? gapX : gapY;
  }

  static double _axisGap(double a0, double a1, double b0, double b1) {
    if (a1 <= b0) return b0 - a1;
    if (b1 <= a0) return a0 - b1;
    final overlap = (a1 < b1 ? a1 : b1) - (a0 > b0 ? a0 : b0);
    return -overlap;
  }

  static bool separated(Rect a, Rect b, Size meadow) =>
      edgeGapPx(a, b, meadow) >= CapyWander.peerGrassPx - 0.5;

  static bool intersects(Rect a, Rect b) => a.overlaps(b);

  /// Preferred anchors shifted onto open grass.
  static MeadowProps layout({
    required Size meadow,
    required int herdCount,
    Offset? mud,
    required List<Offset> capyAnchors,
    required List<double> capyWidths,
    required bool tentUnlocked,
  }) {
    final blocked = <Rect>[
      basketRect(meadow),
      for (var i = 0; i < capyAnchors.length; i++)
        capyRect(capyAnchors[i], meadow, capyWidths[i]),
      if (mud != null) puddleRect(mud, meadow),
    ];
    final places = <CozyPlaceKind, Offset>{};
    for (final kind in CozyPlaceKind.values) {
      if (kind == CozyPlaceKind.tent && !tentUnlocked) continue;
      final preferred = Offset(kind.center.$1, kind.center.$2);
      final spot = _settle(
        preferred: preferred,
        footprint: (p) => placeRect(p, meadow),
        blocked: blocked,
        meadow: meadow,
        herdCount: herdCount,
      );
      places[kind] = spot;
      blocked.add(placeRect(spot, meadow));
    }
    final flowers = <Offset>[];
    for (final (x, y) in WorldZones.flowerPositions) {
      final preferred = Offset(x, y);
      final spot = _settle(
        preferred: preferred,
        footprint: (p) => flowerRect(p, meadow),
        blocked: blocked,
        meadow: meadow,
        herdCount: herdCount,
      );
      flowers.add(spot);
      blocked.add(flowerRect(spot, meadow));
    }
    return MeadowProps(flowers: flowers, places: places);
  }

  /// True when a low-grass puddle candidate clears basket, places, flowers,
  /// and the bodies already standing there.
  static bool puddleClears(
    Offset candidate,
    Size meadow, {
    required int herdCount,
    required List<Offset> capyAnchors,
    required List<double> capyWidths,
    required bool tentUnlocked,
  }) {
    if (!WorldZones.isInMeadow(candidate, herdCount: herdCount)) return false;
    final ring = puddleRect(candidate, meadow);
    final blocked = <Rect>[
      basketRect(meadow),
      for (final kind in CozyPlaceKind.values)
        if (kind != CozyPlaceKind.tent || tentUnlocked)
          placeRect(Offset(kind.center.$1, kind.center.$2), meadow),
      for (final (x, y) in WorldZones.flowerPositions)
        flowerRect(Offset(x, y), meadow),
      for (var i = 0; i < capyAnchors.length; i++)
        capyRect(capyAnchors[i], meadow, capyWidths[i]),
    ];
    for (final other in blocked) {
      if (!separated(ring, other, meadow)) return false;
    }
    return true;
  }

  static Offset _settle({
    required Offset preferred,
    required Rect Function(Offset) footprint,
    required List<Rect> blocked,
    required Size meadow,
    required int herdCount,
  }) {
    if (_ok(preferred, footprint, blocked, meadow, herdCount)) {
      return preferred;
    }
    final plate = CapyWander.grassPlate(herdCount);
    Offset? clear;
    var clearDist = double.infinity;
    Offset? loose;
    var looseGap = double.negativeInfinity;
    const step = 0.04;
    for (var y = plate.top; y <= plate.bottom + 0.001; y += step) {
      for (var x = plate.left; x <= plate.right + 0.001; x += step) {
        final p = Offset(x, y);
        if (!CapyWander.onGrass(p, herdCount)) continue;
        final rect = footprint(p);
        final gap = _minGap(rect, blocked, meadow);
        final dist = (p - preferred).distance;
        if (gap >= CapyWander.peerGrassPx - 0.5 && dist < clearDist) {
          clear = p;
          clearDist = dist;
        }
        if (gap > looseGap) {
          loose = p;
          looseGap = gap;
        }
      }
    }
    return clear ?? loose ?? preferred;
  }

  static bool _ok(
    Offset p,
    Rect Function(Offset) footprint,
    List<Rect> blocked,
    Size meadow,
    int herdCount,
  ) {
    if (!CapyWander.onGrass(p, herdCount)) return false;
    return _minGap(footprint(p), blocked, meadow) >=
        CapyWander.peerGrassPx - 0.5;
  }

  static double _minGap(Rect rect, List<Rect> blocked, Size meadow) {
    var gap = double.infinity;
    for (final other in blocked) {
      final g = edgeGapPx(rect, other, meadow);
      if (g < gap) gap = g;
    }
    return gap;
  }
}

class MeadowProps {
  const MeadowProps({required this.flowers, required this.places});

  final List<Offset> flowers;
  final Map<CozyPlaceKind, Offset> places;
}
