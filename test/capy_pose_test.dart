import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/capy_pose.dart';
import 'package:capy_clicker/features/game/models/capy_walk.dart';

/// Spec 004, Т9: sleepyhead and dreamer art and timing.
void main() {
  test('every pose frame is on disk and in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/images/traits/'));
    expect(CapyPose.allAssetPaths, hasLength(5 * 4 + 3));
    for (final path in CapyPose.allAssetPaths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  Future<(int, int, Uint8List)> decode(String path) async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (image.width, image.height, data!.buffer.asUint8List());
  }

  testWidgets('one canvas, feet on the base line, head to the right', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final sheet in CapyWalkSheet.values) {
        for (final path in [
          CapyPose.sleepAsset(sheet, 0),
          CapyPose.sleepAsset(sheet, 1),
          CapyPose.dreamAsset(sheet, 0),
          CapyPose.dreamAsset(sheet, 1),
        ]) {
          final (w, h, px) = await decode(path);
          expect(w, CapyPose.canvasW, reason: path);
          expect(h, CapyPose.canvasH, reason: path);
          int alpha(int x, int y) => px[(y * w + x) * 4 + 3];
          // Feet: opaque on the base line, nothing below it.
          final base = h - CapyPose.basePad.toInt() - 1;
          expect(
            [for (var x = 0; x < w; x++) alpha(x, base)].any((a) => a > 128),
            isTrue,
            reason: '$path feet',
          );
          for (var y = base + 1; y < h; y++) {
            for (var x = 0; x < w; x++) {
              expect(alpha(x, y), 0, reason: '$path below feet');
            }
          }
          // Corners clear: no cream left around the figure.
          expect(alpha(0, 0), 0);
          expect(alpha(w - 1, 0), 0);
          if (path.contains('dream')) {
            // Looking up: the top of the head is right of center, as all
            // sprites face right (the guard sheet was drawn facing left).
            var top = -1;
            var sumX = 0;
            var n = 0;
            for (var y = 0; y < h && top < 0; y++) {
              for (var x = 0; x < w; x++) {
                if (alpha(x, y) > 128) {
                  top = y;
                  sumX += x;
                  n++;
                }
              }
            }
            expect(sumX / n, greaterThan(w / 2), reason: '$path faces right');
          }
        }
      }
    });
  });

  test('sleep: breath frames alternate; bubble grows then pops', () {
    final a = CapyPose.frameAt(CapyPoseKind.sleep, CapyWalkSheet.base, 0.1);
    final b = CapyPose.frameAt(CapyPoseKind.sleep, CapyWalkSheet.base, 1.5);
    expect(a.asset, CapyPose.sleepAsset(CapyWalkSheet.base, 0));
    expect(b.asset, CapyPose.sleepAsset(CapyWalkSheet.base, 1));
    expect(CapyPose.bubbleAt(0.2)!.size, 0);
    expect(CapyPose.bubbleAt(1.0)!.size, 1);
    expect(CapyPose.bubbleAt(2.0)!.size, 2);
    final pop = CapyPose.bubbleAt(2.95)!;
    expect(pop.opacity, lessThan(0.3));
    expect(pop.scale, greaterThan(1.2));
    expect(CapyPose.bubbleAt(3.1), isNull);
    expect(a.bubbleAsset, CapyPose.bubbleAsset(0));
  });

  test('dream: eyes open, half-closed now and then', () {
    final frames = {
      for (var t = 0.0; t < 6; t += 0.05)
        CapyPose.frameAt(CapyPoseKind.dream, CapyWalkSheet.lv3, t).asset,
    };
    expect(frames, {
      CapyPose.dreamAsset(CapyWalkSheet.lv3, 0),
      CapyPose.dreamAsset(CapyWalkSheet.lv3, 1),
    });
    expect(
      CapyPose.frameAt(CapyPoseKind.dream, CapyWalkSheet.lv3, 0).asset,
      CapyPose.dreamAsset(CapyWalkSheet.lv3, 0),
    );
  });

  test('nap and gaze lengths', () {
    expect(CapyPose.length(CapyPoseKind.sleep, 0), const Duration(seconds: 7));
    expect(CapyPose.length(CapyPoseKind.sleep, 1), const Duration(seconds: 11));
    expect(CapyPose.length(CapyPoseKind.dream, 0), const Duration(seconds: 4));
  });
}
