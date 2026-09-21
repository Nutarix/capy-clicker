import 'package:flutter/material.dart';

/// Cute placeholder berry basket — tap for a large progress burst.
class BerryBasket extends StatefulWidget {
  const BerryBasket({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<BerryBasket> createState() => _BerryBasketState();
}

class _BerryBasketState extends State<BerryBasket>
    with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _bob.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pop.forward(from: 0).then((_) {
      if (mounted) widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _pop]),
        builder: (context, _) {
          final bobY = (_bob.value - 0.5) * 7;
          final scale =
              1.0 +
              (_pop.value < 0.5 ? _pop.value * 0.45 : (1 - _pop.value) * 0.45);

          return Transform.translate(
            offset: Offset(0, bobY),
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 64,
                height: 74,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Soft glow
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 50,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE03A5C)
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    // Basket body
                    Positioned(
                      bottom: 10,
                      child: Container(
                        width: 52,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFE0C070),
                              Color(0xFFC4A35A),
                              Color(0xFFA07830),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                            topLeft: Radius.circular(5),
                            topRight: Radius.circular(5),
                          ),
                          border: Border.all(
                            color: const Color(0xFF8B6914),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        // Weave lines
                        child: CustomPaint(painter: _BasketWeavePainter()),
                      ),
                    ),
                    // Basket handle
                    Positioned(
                      top: 6,
                      child: Container(
                        width: 30,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF8B6914),
                            width: 2.8,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    // Berries heap
                    const Positioned(
                      top: 24,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Berry(color: Color(0xFFE03A5C), size: 12),
                          SizedBox(width: 1),
                          _Berry(color: Color(0xFF9B2D8A), size: 13),
                          SizedBox(width: 1),
                          _Berry(color: Color(0xFFE03A5C), size: 11),
                        ],
                      ),
                    ),
                    const Positioned(
                      top: 18,
                      child: _Berry(color: Color(0xFFD4507A), size: 10),
                    ),
                    // Label chip
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ягоды!',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.brown.shade900.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Berry extends StatelessWidget {
  const _Berry({required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _BasketWeavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x668B6914)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
