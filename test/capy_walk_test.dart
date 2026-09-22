import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/capy_walk.dart';
import 'package:capy_clicker/features/game/models/multipliers/capy_role.dart';

void main() {
  group('CapyWalk.sheetFor', () {
    test('base vs lv3 by level when no role', () {
      expect(CapyWalk.sheetFor(level: 1), CapyWalkSheet.base);
      expect(CapyWalk.sheetFor(level: 2), CapyWalkSheet.base);
      expect(CapyWalk.sheetFor(level: 3), CapyWalkSheet.lv3);
      expect(CapyWalk.sheetFor(level: 6), CapyWalkSheet.lv3);
    });

    test('role wins over level — unique sheets', () {
      expect(
        CapyWalk.sheetFor(level: 1, role: CapyRole.nanya),
        CapyWalkSheet.nanny,
      );
      expect(
        CapyWalk.sheetFor(level: 5, role: CapyRole.nanya),
        CapyWalkSheet.nanny,
      );
      expect(
        CapyWalk.sheetFor(level: 2, role: CapyRole.sobiratel),
        CapyWalkSheet.gatherer,
      );
      expect(
        CapyWalk.sheetFor(level: 4, role: CapyRole.storozh),
        CapyWalkSheet.guard,
      );
    });

    test('each role/level type maps to a distinct sheet', () {
      final sheets = {
        CapyWalk.sheetFor(level: 1),
        CapyWalk.sheetFor(level: 3),
        CapyWalk.sheetFor(level: 1, role: CapyRole.nanya),
        CapyWalk.sheetFor(level: 1, role: CapyRole.sobiratel),
        CapyWalk.sheetFor(level: 1, role: CapyRole.storozh),
      };
      expect(sheets.length, 5);
    });
  });

  group('CapyWalk FPS + frames', () {
    test('role-specific FPS bands', () {
      expect(CapyWalk.fps(CapyWalkSheet.base), inInclusiveRange(8.0, 10.0));
      expect(CapyWalk.fps(CapyWalkSheet.lv3), inInclusiveRange(6.0, 7.0));
      expect(CapyWalk.fps(CapyWalkSheet.nanny), closeTo(7.0, 0.01));
      expect(
        CapyWalk.fps(CapyWalkSheet.gatherer),
        inInclusiveRange(10.0, 11.0),
      );
      expect(CapyWalk.fps(CapyWalkSheet.guard), closeTo(8.0, 0.01));
      // gatherer busier than nanny; lv3 slower than base
      expect(
        CapyWalk.fps(CapyWalkSheet.gatherer),
        greaterThan(CapyWalk.fps(CapyWalkSheet.nanny)),
      );
      expect(
        CapyWalk.fps(CapyWalkSheet.lv3),
        lessThan(CapyWalk.fps(CapyWalkSheet.base)),
      );
    });

    test('frameFromLoop01 covers 0..3', () {
      expect(CapyWalk.frameFromLoop01(0), 0);
      expect(CapyWalk.frameFromLoop01(0.24), 0);
      expect(CapyWalk.frameFromLoop01(0.25), 1);
      expect(CapyWalk.frameFromLoop01(0.5), 2);
      expect(CapyWalk.frameFromLoop01(0.75), 3);
      expect(CapyWalk.frameFromLoop01(1.0), 0);
    });

    test('asset paths follow walk/{sheet}_{frame}.png', () {
      expect(
        CapyWalk.assetPath(CapyWalkSheet.base, 0),
        'assets/images/walk/base_0.png',
      );
      expect(
        CapyWalk.assetPath(CapyWalkSheet.guard, 3),
        'assets/images/walk/guard_3.png',
      );
      expect(CapyWalk.allAssetPaths.length, CapyWalkSheet.values.length * 4);
    });
  });

  group('CapyWalk idle uniqueness', () {
    test('idle amplitudes differ by sheet', () {
      const t = 1.0; // max of reverse controller
      final amps = {
        for (final s in CapyWalkSheet.values)
          s: CapyWalk.idleBobY(s, t).abs(),
      };
      expect(amps[CapyWalkSheet.nanny]! < amps[CapyWalkSheet.base]!, isTrue);
      expect(amps[CapyWalkSheet.guard]! < amps[CapyWalkSheet.nanny]!, isTrue);
      expect(amps[CapyWalkSheet.lv3]! > amps[CapyWalkSheet.base]!, isTrue);
      expect(CapyWalk.idleSwayX(CapyWalkSheet.nanny, t).abs(), greaterThan(0));
      expect(CapyWalk.idleSwayX(CapyWalkSheet.base, t), 0);
      // Guard upright pulse stronger squash than nanny.
      expect(
        (1.0 - CapyWalk.idleSquashY(CapyWalkSheet.guard, 1.0)),
        greaterThan(1.0 - CapyWalk.idleSquashY(CapyWalkSheet.nanny, 1.0)),
      );
    });
  });

  group('walk assets on disk', () {
    test('every CapyWalk asset file exists', () {
      for (final path in CapyWalk.allAssetPaths) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: path);
        expect(f.lengthSync(), greaterThan(1000), reason: '$path too small');
      }
    });
  });
}
