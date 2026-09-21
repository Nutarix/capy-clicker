import 'package:flutter/material.dart';

/// Berry basket sprite — tap for a large progress burst.
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
                width: 72,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 50,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE03A5C).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    Image.asset(
                      'assets/images/berry_basket.png',
                      width: 64,
                      height: 68,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
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
                            color: Colors.brown.shade900.withValues(alpha: 0.72),
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
