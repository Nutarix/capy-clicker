import 'package:flutter/material.dart';

/// Berry basket sprite — tap for a large progress burst.
class BerryBasket extends StatefulWidget {
  const BerryBasket({
    super.key,
    required this.onTap,
    this.showHint = false,
  });

  /// Called with global anchor for floating «+N%».
  final ValueChanged<Offset> onTap;

  /// Soft first-time affordance label.
  final bool showHint;

  @override
  State<BerryBasket> createState() => _BerryBasketState();
}

class _BerryBasketState extends State<BerryBasket>
    with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _pop;
  late final AnimationController _glow;
  final GlobalKey _key = GlobalKey();

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
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    _pop.dispose();
    _glow.dispose();
    super.dispose();
  }

  Offset _anchorGlobal() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _handleTap() {
    _pop.forward(from: 0).then((_) {
      if (mounted) widget.onTap(_anchorGlobal());
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _pop, _glow]),
        builder: (context, _) {
          final bobY = (_bob.value - 0.5) * 9;
          final scale =
              1.0 +
              (_pop.value < 0.5 ? _pop.value * 0.45 : (1 - _pop.value) * 0.45);
          final glow = 0.22 + _glow.value * 0.28;

          return Transform.translate(
            offset: Offset(0, bobY),
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                key: _key,
                width: 76,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Soft glow halo — clearer affordance.
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE03A5C).withValues(alpha: glow),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      child: Container(
                        width: 52,
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
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.showHint ? 'нажми!' : 'ягоды!',
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
