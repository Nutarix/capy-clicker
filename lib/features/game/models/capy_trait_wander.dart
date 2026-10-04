import 'dart:math' as math;
import 'dart:ui';

import 'balance.dart';
import 'capy_wander.dart';

/// Where a capy of a trait likes to walk (spec 004, Т8). Meadow widget only:
/// the game core never calls these, so no rule or number moves.
///
/// Each target obeys the same ground rules as a plain wander target (on the
/// grass, off every prop, a grass strip from every body); the walk itself is
/// still cut by [CapyWander.clipTravel]. Null → the plain target.
abstract final class CapyTraitWander {
  /// Chance a wander turn follows the trait (when its thing is there).
  static const double sweetToothChance = 0.7;
  static const double splasherChance = 0.65;
  static const double cuddlerChance = 0.75;

  /// Fidget: walks take this share of the usual time, pauses this share.
  static const double fidgetWalkScale = 0.75;
  static const double fidgetPauseScale = 0.6;

  static bool _clear(
    Offset t, {
    required int herdCount,
    required List<Offset> others,
    Offset? mudCenter,
    Size? meadowSize,
    double capyWidth = 70,
    List<double>? peerWidths,
  }) {
    return CapyWander.onGrass(t, herdCount) &&
        !CapyWander.hitsProp(
          t,
          mudCenter: mudCenter,
          meadowSize: meadowSize,
          capyWidth: capyWidth,
        ) &&
        !CapyWander.overlapsPeer(
          t,
          others,
          meadowSize: meadowSize,
          capyWidth: capyWidth,
          peerWidths: peerWidths,
        );
  }

  /// The clear point of a ring around [center] closest to it: [tries] random
  /// angles, radii from [inner] to [outer] (normalized meadow units).
  static Offset? _ring({
    required Offset center,
    required double inner,
    required double outer,
    required double Function() random01,
    required bool Function(Offset) ok,
    int tries = 18,
  }) {
    Offset? best;
    var bestD = double.infinity;
    for (var i = 0; i < tries; i++) {
      final ang = random01() * math.pi * 2;
      final r = inner + random01() * (outer - inner);
      // Meadows are taller than wide: keep the ring round on screen.
      final t = center + Offset(math.cos(ang) * r, math.sin(ang) * r * 0.75);
      if (!ok(t)) continue;
      final d = (t - center).distance;
      if (d < bestD) {
        bestD = d;
        best = t;
      }
    }
    return best;
  }

  /// Sweet tooth: a spot by the berry basket (call while it is shown).
  static Offset? sweetToothTarget({
    required Offset from,
    required double Function() random01,
    required int herdCount,
    required List<Offset> others,
    Offset? mudCenter,
    Size? meadowSize,
    double capyWidth = 70,
    List<double>? peerWidths,
  }) {
    return _ring(
      center: CapyWander.berryCenter,
      inner: 0.11,
      outer: 0.22,
      random01: random01,
      ok: (t) => _clear(
        t,
        herdCount: herdCount,
        others: others,
        mudCenter: mudCenter,
        meadowSize: meadowSize,
        capyWidth: capyWidth,
        peerWidths: peerWidths,
      ),
    );
  }

  /// Splasher: the puddle edge. Outside the wallow circle with room to
  /// spare: the bath stays the player's to give.
  static Offset? splasherTarget({
    required Offset from,
    required double Function() random01,
    required int herdCount,
    required Offset mudCenter,
    required List<Offset> others,
    Size? meadowSize,
    double capyWidth = 70,
    List<double>? peerWidths,
  }) {
    const keepOut = BalanceV0.mudHitRadius + 0.02;
    return _ring(
      center: mudCenter,
      inner: keepOut / 0.75,
      outer: keepOut / 0.75 + 0.1,
      random01: random01,
      ok: (t) =>
          (t - mudCenter).distance > keepOut &&
          _clear(
            t,
            herdCount: herdCount,
            others: others,
            mudCenter: mudCenter,
            meadowSize: meadowSize,
            capyWidth: capyWidth,
            peerWidths: peerWidths,
          ),
    );
  }

  /// Cuddler's buddy among [herdIds]: stable for the pair (rendezvous
  /// hash), so it keeps to the same one while that one is around.
  static String? buddyFor(String id, List<String> herdIds) {
    String? best;
    var bestScore = -1;
    for (final other in herdIds) {
      if (other == id) continue;
      final score = _hash('$id>$other');
      if (score > bestScore) {
        bestScore = score;
        best = other;
      }
    }
    return best;
  }

  static int _hash(String s) {
    var h = 0x811C9DC5;
    for (final unit in s.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  /// Cuddler: right next to [buddy] — a body and a strip of grass away,
  /// on the side closest to [from].
  static Offset? cuddlerTarget({
    required Offset from,
    required Offset buddy,
    required int herdCount,
    required List<Offset> others,
    Offset? mudCenter,
    Size? meadowSize,
    double capyWidth = 70,
    double buddyWidth = 70,
    List<double>? peerWidths,
  }) {
    final sep = CapyWander.pairSeparation(
      meadowSize,
      capyWidth: capyWidth,
      otherWidth: buddyWidth,
    );
    final dx = sep.minX + 0.006;
    final dy = sep.minY + 0.006;
    final spots = [
      Offset(buddy.dx - dx, buddy.dy),
      Offset(buddy.dx + dx, buddy.dy),
      Offset(buddy.dx - dx, buddy.dy + dy * 0.5),
      Offset(buddy.dx + dx, buddy.dy + dy * 0.5),
      Offset(buddy.dx - dx, buddy.dy - dy * 0.5),
      Offset(buddy.dx + dx, buddy.dy - dy * 0.5),
      Offset(buddy.dx, buddy.dy + dy),
      Offset(buddy.dx, buddy.dy - dy),
    ]..sort((a, b) => (a - from).distance.compareTo((b - from).distance));
    for (final t in spots) {
      if (_clear(
        t,
        herdCount: herdCount,
        others: others,
        mudCenter: mudCenter,
        meadowSize: meadowSize,
        capyWidth: capyWidth,
        peerWidths: peerWidths,
      )) {
        return t;
      }
    }
    return null;
  }

  /// Fidget: two plain picks, the farther one.
  static Offset fidgetTarget({
    required Offset from,
    required Offset Function() pick,
  }) {
    final a = pick();
    final b = pick();
    return (b - from).distance > (a - from).distance ? b : a;
  }

  static Duration walkDuration(Offset from, Offset to, {required bool fidget}) {
    final d = CapyWander.walkDuration(from, to);
    if (!fidget) return d;
    return Duration(milliseconds: (d.inMilliseconds * fidgetWalkScale).round());
  }

  static Duration pause(Duration plain, {required bool fidget}) {
    if (!fidget) return plain;
    return Duration(
      milliseconds: (plain.inMilliseconds * fidgetPauseScale).round(),
    );
  }
}
