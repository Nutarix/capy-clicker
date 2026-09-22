import 'multipliers/capy_role.dart';
import 'capy_wander.dart';

/// Walk-cycle sheet + FPS / idle flavour per capy type (Семья).
///
/// Each type has its own 4-frame sheet under `assets/images/walk/`.
/// Role sheets are the role look while walking — not only a badge overlay.
enum CapyWalkSheet {
  base,
  lv3,
  nanny,
  gatherer,
  guard,
}

abstract final class CapyWalk {
  static const int frameCount = 4;

  /// Pick sheet: role wins; else lv3 body for level ≥ 3; else base.
  static CapyWalkSheet sheetFor({required int level, CapyRole? role}) {
    if (role != null) {
      return switch (role) {
        CapyRole.nanya => CapyWalkSheet.nanny,
        CapyRole.sobiratel => CapyWalkSheet.gatherer,
        CapyRole.storozh => CapyWalkSheet.guard,
      };
    }
    return level >= 3 ? CapyWalkSheet.lv3 : CapyWalkSheet.base;
  }

  static String assetPath(CapyWalkSheet sheet, int frame) {
    final i = frame % frameCount;
    if (i < 0) {
      return 'assets/images/walk/${sheet.name}_0.png';
    }
    return 'assets/images/walk/${sheet.name}_$i.png';
  }

  /// All registered walk frame paths (for asset / pubspec tests).
  static List<String> get allAssetPaths {
    final out = <String>[];
    for (final sheet in CapyWalkSheet.values) {
      for (var i = 0; i < frameCount; i++) {
        out.add(assetPath(sheet, i));
      }
    }
    return out;
  }

  /// Role-specific walk FPS (paws cycle).
  static double fps(CapyWalkSheet sheet) => switch (sheet) {
        CapyWalkSheet.base => 9.0,
        CapyWalkSheet.lv3 => 6.5,
        CapyWalkSheet.nanny => 7.0,
        CapyWalkSheet.gatherer => 10.5,
        CapyWalkSheet.guard => 8.0,
      };

  /// Duration of one full 4-frame loop.
  static Duration loopDuration(CapyWalkSheet sheet) {
    final ms = (1000.0 * frameCount / fps(sheet)).round();
    return Duration(milliseconds: ms);
  }

  /// Frame index from a 0..1 loop controller value.
  static int frameFromLoop01(double loop01) {
    final t = loop01.clamp(0.0, 1.0);
    // value==1.0 (repeat seam) → frame 0
    if (t >= 1.0) return 0;
    return (t * frameCount).floor().clamp(0, frameCount - 1);
  }

  /// Unique idle period per sheet (phase jitter from [id]).
  static Duration idlePeriod(CapyWalkSheet sheet, String id) {
    final baseMs = switch (sheet) {
      CapyWalkSheet.nanny => 2200, // gentler
      CapyWalkSheet.gatherer => 1200, // busier ready bob
      CapyWalkSheet.guard => 1600,
      CapyWalkSheet.base => 1500,
      CapyWalkSheet.lv3 => 2100, // heavier
    };
    final ms = (baseMs + CapyWander.phase01(id) * 800).round();
    return Duration(milliseconds: ms);
  }

  /// Vertical idle bob — amplitude differs by type.
  static double idleBobY(CapyWalkSheet sheet, double controller01) {
    final amp = switch (sheet) {
      CapyWalkSheet.nanny => 3.0, // softer sway
      CapyWalkSheet.gatherer => 2.4, // tiny ready bob
      CapyWalkSheet.guard => 1.4, // upright — small Y
      CapyWalkSheet.base => 5.0,
      CapyWalkSheet.lv3 => 6.2, // heavier
    };
    return (controller01 - 0.5) * amp;
  }

  /// Soft horizontal sway (nanny) / tiny ready shift (gatherer).
  static double idleSwayX(CapyWalkSheet sheet, double controller01) {
    return switch (sheet) {
      CapyWalkSheet.nanny => (controller01 - 0.5) * 2.8,
      CapyWalkSheet.gatherer => (controller01 - 0.5) * 1.2,
      _ => 0.0,
    };
  }

  /// Squash / upright pulse — guard is snappier on scaleY.
  static double idleSquashY(CapyWalkSheet sheet, double controller01) {
    final amount = switch (sheet) {
      CapyWalkSheet.nanny => 0.022,
      CapyWalkSheet.gatherer => 0.032,
      CapyWalkSheet.guard => 0.058, // alerter upright pulse
      CapyWalkSheet.base => 0.04,
      CapyWalkSheet.lv3 => 0.052,
    };
    return 1.0 - (controller01 - 0.5).abs() * amount;
  }
}
