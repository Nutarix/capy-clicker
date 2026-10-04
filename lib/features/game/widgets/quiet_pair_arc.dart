import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/balance.dart';
import '../models/capybara.dart';

/// Quiet dotted arc between the «хотят посидеть рядом» pair (spec 006):
/// the two marked capys, close but not together yet. No «сюда!» chip.
class QuietPairArc extends StatelessWidget {
  const QuietPairArc({super.key, required this.from, required this.to});

  /// Normalized meadow positions.
  final Offset from;
  final Offset to;

  /// The marked pair [twinA]/[twinB] when both stand on [herd], a grass gap
  /// apart and not too far (sprite pixels), and not in one pile.
  static (Offset, Offset)? pairFor(
    List<Capybara> herd,
    Size meadow, {
    required String? twinA,
    required String? twinB,
  }) {
    if (twinA == null || twinB == null) return null;
    Capybara? a;
    Capybara? b;
    for (final c in herd) {
      if (c.id == twinA) a = c;
      if (c.id == twinB) b = c;
    }
    if (a == null || b == null) return null;
    if (a.pileId != null && a.pileId == b.pileId) return null;
    final minPx = BalanceV0.baseCapySize * 0.95;
    final maxPx = BalanceV0.baseCapySize * 4.0;
    final dx = (a.position.dx - b.position.dx) * meadow.width;
    final dy = (a.position.dy - b.position.dy) * meadow.height;
    final dist2 = dx * dx + dy * dy;
    if (dist2 < minPx * minPx || dist2 > maxPx * maxPx) return null;
    return (a.position, b.position);
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
