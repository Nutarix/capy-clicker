import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/balance.dart';
import '../models/capybara.dart';

/// Quiet dotted arc between a merge pair. No «сюда!» chip.
class QuietMergeArc extends StatelessWidget {
  const QuietMergeArc({super.key, required this.from, required this.to});

  /// Normalized meadow positions.
  final Offset from;
  final Offset to;

  /// Dotted arc for a same-level pair that is close, but not stacked.
  ///
  /// Magnet snap stays at [GameController.effectiveMagnetRadius]. The arc
  /// uses sprite pixels so a grass gap still reads, and a pile does not.
  static (Offset, Offset)? pairFor(List<Capybara> herd, Size meadow) {
    (Offset, Offset)? best;
    var bestDist = double.infinity;
    final minPx = BalanceV0.baseCapySize * 0.95;
    final maxPx = BalanceV0.baseCapySize * 2.6;
    final min2 = minPx * minPx;
    final max2 = maxPx * maxPx;
    for (var i = 0; i < herd.length; i++) {
      for (var j = i + 1; j < herd.length; j++) {
        final a = herd[i];
        final b = herd[j];
        if (a.level != b.level) continue;
        final dx = (a.position.dx - b.position.dx) * meadow.width;
        final dy = (a.position.dy - b.position.dy) * meadow.height;
        final dist2 = dx * dx + dy * dy;
        if (dist2 < min2 || dist2 > max2) continue;
        if (dist2 < bestDist) {
          bestDist = dist2;
          best = (a.position, b.position);
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ArcPainter(from: from, to: to),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(from.dx * size.width, from.dy * size.height);
    final b = Offset(to.dx * size.width, to.dy * size.height);
    final delta = b - a;
    final len = delta.distance;
    if (len < 8) return;
    final dir = delta / len;
    // Start outside the bodies so the dots sit in the grass between them.
    final inset = math.min(46.0, len * 0.32);
    final start = a + dir * inset;
    final end = b - dir * inset;
    final bow = math.max(26.0, len * 0.22);
    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2 - bow);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    final under = Paint()
      ..color = const Color(0xFF5C3D1E).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    final paint = Paint()
      ..color = const Color(0xFFFFF8EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      const dash = 5.0;
      const gap = 5.0;
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        final bit = metric.extractPath(dist, next);
        canvas.drawPath(bit, under);
        canvas.drawPath(bit, paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}
