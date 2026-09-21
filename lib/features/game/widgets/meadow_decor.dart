import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Static bush/rock decorations unlocked by herd-size milestones.
class MeadowDecorLayer extends StatelessWidget {
  const MeadowDecorLayer({
    super.key,
    required this.herdCount,
    required this.meadowSize,
  });

  final int herdCount;
  final Size meadowSize;

  @override
  Widget build(BuildContext context) {
    final w = meadowSize.width;
    final h = meadowSize.height;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (herdCount >= BalanceV0.decorBush1At)
          Positioned(
            left: 0.08 * w,
            top: 0.34 * h,
            child: const _BushSprite(scale: 1.0),
          ),
        if (herdCount >= BalanceV0.decorRockAt)
          Positioned(
            left: 0.86 * w - 36,
            top: 0.62 * h,
            child: const _RockSprite(),
          ),
        if (herdCount >= BalanceV0.decorBush2At)
          Positioned(
            left: 0.62 * w,
            top: 0.30 * h,
            child: const _BushSprite(scale: 0.85, tint: Color(0xFF6BA85A)),
          ),
      ],
    );
  }
}

class _BushSprite extends StatelessWidget {
  const _BushSprite({this.scale = 1.0, this.tint = const Color(0xFF4F8F3E)});

  final double scale;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 54,
        height: 42,
        child: CustomPaint(painter: _BushPainter(tint)),
      ),
    );
  }
}

class _BushPainter extends CustomPainter {
  _BushPainter(this.tint);

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.88),
        width: size.width * 0.7,
        height: 8,
      ),
      shadow,
    );

    final dark = Color.lerp(tint, const Color(0xFF2E5A24), 0.35)!;
    final light = Color.lerp(tint, const Color(0xFFB8E8A0), 0.35)!;

    void blob(Offset c, double rx, double ry, Color c_) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
        Paint()..color = c_,
      );
    }

    blob(Offset(size.width * 0.32, size.height * 0.58), 14, 12, dark);
    blob(Offset(size.width * 0.68, size.height * 0.58), 14, 12, dark);
    blob(Offset(size.width * 0.50, size.height * 0.42), 16, 14, tint);
    blob(Offset(size.width * 0.42, size.height * 0.36), 8, 6, light);
    blob(Offset(size.width * 0.58, size.height * 0.40), 6, 5, light);
  }

  @override
  bool shouldRepaint(covariant _BushPainter oldDelegate) =>
      oldDelegate.tint != tint;
}

class _RockSprite extends StatelessWidget {
  const _RockSprite();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 30,
      child: CustomPaint(painter: _RockPainter()),
    );
  }
}

class _RockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.9),
        width: size.width * 0.75,
        height: 7,
      ),
      shadow,
    );

    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.72)
      ..lineTo(size.width * 0.28, size.height * 0.28)
      ..lineTo(size.width * 0.62, size.height * 0.18)
      ..lineTo(size.width * 0.88, size.height * 0.48)
      ..lineTo(size.width * 0.78, size.height * 0.82)
      ..lineTo(size.width * 0.22, size.height * 0.86)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFF8A8678));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF6E6A5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Soft highlight facet
    final hi = Path()
      ..moveTo(size.width * 0.30, size.height * 0.36)
      ..lineTo(size.width * 0.55, size.height * 0.26)
      ..lineTo(size.width * 0.48, size.height * 0.48)
      ..close();
    canvas.drawPath(hi, Paint()..color = const Color(0x55D8D4C8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
