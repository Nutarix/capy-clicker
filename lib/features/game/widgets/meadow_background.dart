import 'package:flutter/material.dart';

/// Soft meadow: sky→grass gradient with layered hills (dir-v-early vibe).
class MeadowBackground extends StatelessWidget {
  const MeadowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFC8E8F0), // soft sky
            Color(0xFFB5E0A8), // horizon haze
            Color(0xFF8FCB6E), // mid grass
            Color(0xFF5FA848), // deep meadow
          ],
          stops: [0.0, 0.28, 0.62, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _MeadowPainter(),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _MeadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Far soft hills (cooler green)
    _drawHill(
      canvas,
      size,
      peaks: const [
        (0.0, 0.52),
        (0.2, 0.40),
        (0.45, 0.48),
        (0.7, 0.38),
        (1.0, 0.46),
      ],
      color: const Color(0x5590C070),
    );

    // Mid hills
    _drawHill(
      canvas,
      size,
      peaks: const [
        (0.0, 0.68),
        (0.18, 0.55),
        (0.4, 0.64),
        (0.62, 0.52),
        (0.85, 0.60),
        (1.0, 0.58),
      ],
      color: const Color(0x6680B858),
    );

    // Near rolling meadow
    _drawHill(
      canvas,
      size,
      peaks: const [
        (0.0, 0.78),
        (0.25, 0.66),
        (0.5, 0.76),
        (0.78, 0.68),
        (1.0, 0.74),
      ],
      color: const Color(0x774A8A3A),
    );

    // Soft sun glow (top-right)
    final sunPaint = Paint()
      ..shader =
          const RadialGradient(colors: [Color(0x55FFF8C8), Color(0x00FFF8C8)])
              .createShader(
                Rect.fromCircle(
                  center: Offset(size.width * 0.82, size.height * 0.12),
                  radius: size.width * 0.35,
                ),
              );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.12),
      size.width * 0.35,
      sunPaint,
    );

    // Tiny meadow dots (grass tufts)
    final tuft = Paint()..color = const Color(0x334A7A30);
    for (var i = 0; i < 18; i++) {
      final x = (i * 0.057 + 0.04) * size.width;
      final y = (0.58 + (i % 5) * 0.07) * size.height;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 6, height: 3),
        tuft,
      );
    }
  }

  void _drawHill(
    Canvas canvas,
    Size size, {
    required List<(double, double)> peaks,
    required Color color,
  }) {
    final path = Path()..moveTo(0, size.height * peaks.first.$2);
    for (var i = 0; i < peaks.length - 1; i++) {
      final a = peaks[i];
      final b = peaks[i + 1];
      final cx = ((a.$1 + b.$1) / 2) * size.width;
      final cy = ((a.$2 + b.$2) / 2 - 0.04) * size.height;
      path.quadraticBezierTo(cx, cy, b.$1 * size.width, b.$2 * size.height);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
