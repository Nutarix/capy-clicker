import 'dart:ui';

import 'balance.dart';
import 'capy_pose.dart';
import 'capy_wander.dart';
import 'capybara.dart';

/// One capy's seat in a pile on screen (spec 006, Т8).
class PileSeat {
  const PileSeat({
    required this.offset,
    required this.order,
    required this.faceRight,
    required this.breathPhase,
  });

  /// Shift of the capy's box center from the pile point, meadow pixels.
  final Offset offset;

  /// Paint order inside the pile: 0 first (behind).
  final int order;

  /// Lying sprite facing.
  final bool faceRight;

  /// 0–1 start of the breath, so a pile does not breathe in unison.
  final double breathPhase;
}

/// How a pile is stacked: the eldest behind, the young in front and on top.
///
/// Seats are in shares of the eldest's width, relative to the eldest's feet
/// at the pile point (y down). Approved by eye on
/// `store/art-pack-traits/preview-piles.png` (`tool/pile_preview_test.dart`).
abstract final class PileLayout {
  /// (dx, dy, faceRight) by pile size; index = rank by level, eldest first.
  static const Map<int, List<(double, double, bool)>> slots = {
    1: [(0, 0, true)],
    2: [(-0.16, 0, true), (0.30, 0.10, false)],
    3: [(0.0, 0.0, true), (-0.36, 0.12, true), (0.10, -0.33, false)],
    4: [
      (0.0, 0.0, true),
      (-0.38, 0.12, true),
      (0.36, 0.13, false),
      (0.02, -0.35, true),
    ],
  };

  /// Members by rank: higher level first, then id (stable).
  static List<Capybara> ranked(List<Capybara> members) =>
      List<Capybara>.of(members)..sort((a, b) {
        final byLevel = b.level.compareTo(a.level);
        return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
      });

  /// Feet of a capy box of width [w], from the box center (pixels).
  /// Same geometry as the meadow capy: footprint `w + 8` × `0.95w + 26`,
  /// sprite box `w` × `0.95w` at its top, feet on the walk foot line.
  static double feetFromCenter(double w) {
    final h = w * 0.95;
    final k = w / CapyPose.pixelsPerCapyWidth;
    final walkH = CapyWander.sheetPixelHeight * k;
    final footY = (h - walkH) / 2 + walkH - CapyPose.basePad * k;
    final footprintH = h + 26;
    return -footprintH / 2 + footY;
  }

  /// Seat of every member, by id.
  static Map<String, PileSeat> seats(List<Capybara> members) {
    final order = ranked(members);
    if (order.isEmpty) return const {};
    final eldestW = BalanceV0.capySizeForLevel(order.first.level);
    final table = slots[order.length.clamp(1, 4)]!;
    final ground = feetFromCenter(eldestW);
    final out = <String, PileSeat>{};
    for (var i = 0; i < order.length; i++) {
      final c = order[i];
      final (sx, sy, face) = table[i.clamp(0, table.length - 1)];
      final w = BalanceV0.capySizeForLevel(c.level);
      final dy = ground + sy * eldestW - feetFromCenter(w);
      out[c.id] = PileSeat(
        offset: Offset(sx * eldestW, dy),
        order: i,
        faceRight: face,
        breathPhase: CapyWander.phase01(c.id),
      );
    }
    return out;
  }

  /// Where the pile's caption hangs: below the lowest feet, from the pile
  /// point (pixels).
  static double captionTop(List<Capybara> members) {
    final order = ranked(members);
    if (order.isEmpty) return 0;
    final eldestW = BalanceV0.capySizeForLevel(order.first.level);
    final table = slots[order.length.clamp(1, 4)]!;
    var low = 0.0;
    for (var i = 0; i < order.length && i < table.length; i++) {
      if (table[i].$2 > low) low = table[i].$2;
    }
    return feetFromCenter(eldestW) + low * eldestW + 4;
  }
}
