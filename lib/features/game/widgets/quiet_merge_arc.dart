import 'package:flutter/material.dart';

/// Quiet dotted arc between a merge pair. No «сюда!» chip.
class QuietMergeArc extends StatelessWidget {
  const QuietMergeArc({super.key, required this.from, required this.to});

  /// Normalized meadow positions.
  final Offset from;
  final Offset to;

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
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 - 28);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    final paint = Paint()
      ..color = const Color(0xFFF8F3E6).withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      const dash = 5.0;
      const gap = 6.0;
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}
