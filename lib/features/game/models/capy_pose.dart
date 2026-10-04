import 'dart:ui';

import 'capy_walk.dart';

/// Sleepyhead and dreamer poses (spec 004, Т9): art, timing, chances.
///
/// Frames come from `tool/slice_traits_pack.py`: every pose on one canvas
/// of [canvasW]×[canvasH] pixels, at the walk scale of its look (256 canvas
/// pixels = one capy width), feet [basePad] above the bottom edge, centered.
enum CapyPoseKind { sleep, dream }

/// What a posing capy shows at one moment.
class CapyPoseFrame {
  const CapyPoseFrame({
    required this.asset,
    this.bubbleAsset,
    this.bubbleScale = 1,
    this.bubbleOpacity = 1,
    this.bubbleAnchor = Offset.zero,
  });

  final String asset;

  /// Sleep bubble over the nose, or null.
  final String? bubbleAsset;
  final double bubbleScale;
  final double bubbleOpacity;

  /// Bubble bottom-center, canvas pixels (facing right).
  final Offset bubbleAnchor;
}

abstract final class CapyPose {
  static const double canvasW = 320;
  static const double canvasH = 288;
  static const double basePad = 3;

  /// Walk sheets are 256 pixels wide for one capy width.
  static const double pixelsPerCapyWidth = 256;

  static const double bubbleCanvas = 128;

  /// Bubbles are drawn at this share of the canvas scale.
  static const double bubbleDrawScale = 0.55;

  /// Chance that a wander turn becomes a nap (sleepyhead) or a gaze up
  /// (dreamer) instead of a walk.
  static const double napChance = 0.35;
  static const double gazeChance = 0.3;

  static String sleepAsset(CapyWalkSheet sheet, int frame) =>
      'assets/images/traits/sleep_${sheet.name}_${frame % 2}.png';

  static String dreamAsset(CapyWalkSheet sheet, int frame) =>
      'assets/images/traits/dream_${sheet.name}_${frame % 2}.png';

  static String bubbleAsset(int size) =>
      'assets/images/traits/bubble_${size.clamp(0, 2)}.png';

  static List<String> get allAssetPaths => [
    for (final sheet in CapyWalkSheet.values) ...[
      sleepAsset(sheet, 0),
      sleepAsset(sheet, 1),
      dreamAsset(sheet, 0),
      dreamAsset(sheet, 1),
    ],
    for (var i = 0; i < 3; i++) bubbleAsset(i),
  ];

  /// Nose tip of the sleeping look, canvas pixels (set by eye from the art).
  static Offset sleepNose(CapyWalkSheet sheet) => switch (sheet) {
    CapyWalkSheet.base => const Offset(292, 226),
    CapyWalkSheet.lv3 => const Offset(298, 232),
    CapyWalkSheet.nanny => const Offset(265, 205),
    CapyWalkSheet.gatherer => const Offset(285, 190),
    CapyWalkSheet.guard => const Offset(252, 122),
  };

  /// Nap 7–11 s, gaze 4–7 s.
  static Duration length(CapyPoseKind kind, double random01) {
    final ms = switch (kind) {
      CapyPoseKind.sleep => 7000 + random01 * 4000,
      CapyPoseKind.dream => 4000 + random01 * 3000,
    };
    return Duration(milliseconds: ms.round());
  }

  /// Breathing: inhale, then exhale, 2.4 s a breath.
  static const double breathSeconds = 2.4;

  /// The bubble: small, medium, large, then it pops; 3.2 s a round.
  static const double bubbleSeconds = 3.2;

  /// Dreamer: eyes half-closed for a moment every [blinkEvery] seconds.
  static const double blinkEvery = 1.9;
  static const double blinkFor = 0.35;

  static CapyPoseFrame frameAt(
    CapyPoseKind kind,
    CapyWalkSheet sheet,
    double seconds,
  ) {
    switch (kind) {
      case CapyPoseKind.sleep:
        final breath = (seconds % breathSeconds) / breathSeconds;
        final asset = sleepAsset(sheet, breath < 0.5 ? 0 : 1);
        final bubble = bubbleAt(seconds);
        final nose = sleepNose(sheet);
        return CapyPoseFrame(
          asset: asset,
          bubbleAsset: bubble == null ? null : bubbleAsset(bubble.size),
          bubbleScale: bubble?.scale ?? 1,
          bubbleOpacity: bubble?.opacity ?? 1,
          bubbleAnchor: Offset(nose.dx + 10, nose.dy - 6),
        );
      case CapyPoseKind.dream:
        // Look up first; the first half-close comes after a beat.
        final t = seconds % blinkEvery;
        final blink = seconds > blinkFor && t > blinkEvery - blinkFor;
        return CapyPoseFrame(asset: dreamAsset(sheet, blink ? 1 : 0));
    }
  }

  /// Bubble size 0..2 with scale and opacity, or null between rounds.
  static ({int size, double scale, double opacity})? bubbleAt(double seconds) {
    final t = seconds % bubbleSeconds;
    if (t < 0.9) return (size: 0, scale: 1, opacity: 1);
    if (t < 1.8) return (size: 1, scale: 1, opacity: 1);
    if (t < 2.7) return (size: 2, scale: 1, opacity: 1);
    if (t < 3.0) {
      // Pop: a little wider and gone.
      final k = (t - 2.7) / 0.3;
      return (size: 2, scale: 1 + 0.35 * k, opacity: 1 - k);
    }
    return null;
  }
}
