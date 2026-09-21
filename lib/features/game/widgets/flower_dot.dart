import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tappable flower with enlarged hitbox, scale punch + petal burst.
class FlowerDot extends StatefulWidget {
  const FlowerDot({super.key, required this.color, required this.onTap});

  final Color color;

  /// Called with the global anchor of the flower (for floating «+N%»).
  final ValueChanged<Offset> onTap;

  /// Playtest P1: larger standardized hitbox (was 48).
  static const double hitSize = 68;
  static const double spriteSize = 40;

  @override
  State<FlowerDot> createState() => _FlowerDotState();
}

class _FlowerDotState extends State<FlowerDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _burst = false;
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.55), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 1.55, end: 0.90), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _burst = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _anchorGlobal() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _handleTap() {
    setState(() => _burst = true);
    _controller.forward(from: 0);
    widget.onTap(_anchorGlobal());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        key: _key,
        width: FlowerDot.hitSize,
        height: FlowerDot.hitSize,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Soft invisible hit pad (helps fat-finger taps).
                Container(
                  width: FlowerDot.hitSize,
                  height: FlowerDot.hitSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.06),
                  ),
                ),
                if (_burst)
                  for (var i = 0; i < 6; i++)
                    _PetalParticle(
                      color: widget.color,
                      angle: i * math.pi / 3,
                      progress: Curves.easeOut.transform(_controller.value),
                    ),
                ScaleTransition(
                  scale: _scale,
                  child: Image.asset(
                    'assets/images/flower.png',
                    width: FlowerDot.spriteSize,
                    height: FlowerDot.spriteSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PetalParticle extends StatelessWidget {
  const _PetalParticle({
    required this.color,
    required this.angle,
    required this.progress,
  });

  final Color color;
  final double angle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final dist = 8 + progress * 26;
    final dx = math.cos(angle) * dist;
    final dy = math.sin(angle) * dist - progress * 6;
    final size = 5.0 + (1 - progress) * 3;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: (1 - progress * 0.95).clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white54, width: 0.8),
          ),
        ),
      ),
    );
  }
}
