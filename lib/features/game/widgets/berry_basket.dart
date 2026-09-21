import 'package:flutter/material.dart';

/// Cute placeholder berry basket — tap for a large progress burst.
class BerryBasket extends StatefulWidget {
  const BerryBasket({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<BerryBasket> createState() => _BerryBasketState();
}

class _BerryBasketState extends State<BerryBasket>
    with SingleTickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 200),
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
          final bobY = (_bob.value - 0.5) * 6;
          final scale = 1.0 + (_pop.value < 0.5
              ? _pop.value * 0.4
              : (1 - _pop.value) * 0.4);

          return Transform.translate(
            offset: Offset(0, bobY),
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 56,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Basket body
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 48,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC4A35A),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          border: Border.all(
                            color: const Color(0xFF8B6914),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Basket handle
                    Positioned(
                      top: 8,
                      child: Container(
                        width: 28,
                        height: 18,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF8B6914),
                            width: 2.5,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    // Berries
                    const Positioned(
                      top: 22,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Berry(color: Color(0xFFE03A5C)),
                          SizedBox(width: 2),
                          _Berry(color: Color(0xFF9B2D8A)),
                          SizedBox(width: 2),
                          _Berry(color: Color(0xFFE03A5C)),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Text(
                        'ягоды!',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.brown.shade900.withValues(alpha: 0.65),
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
  const _Berry({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 1),
      ),
    );
  }
}
