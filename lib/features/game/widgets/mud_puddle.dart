import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Soft mud puddle zone. Accepts dragged capybaras and plays a cute wallow.
class MudPuddle extends StatefulWidget {
  const MudPuddle({
    super.key,
    required this.isWallowing,
    required this.boostActive,
  });

  final bool isWallowing;
  final bool boostActive;

  @override
  State<MudPuddle> createState() => _MudPuddleState();
}

class _MudPuddleState extends State<MudPuddle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: BalanceV0.mudWallowAnimDuration,
    );
  }

  @override
  void didUpdateWidget(covariant MudPuddle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWallowing && !oldWidget.isWallowing) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final splash = widget.isWallowing ? Curves.easeOut.transform(t) : 0.0;
        final bounce = widget.isWallowing
            ? math.sin(t * math.pi * 3) * (1 - t) * 10
            : 0.0;
        return SizedBox(
          width: 110,
          height: 86,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Soft ground shadow
              Positioned(
                bottom: 10,
                child: Container(
                  width: 92,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
              // Puddle body (layered ovals for readability)
              Transform.translate(
                offset: Offset(0, bounce * 0.15),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96 + splash * 12,
                      height: 52 + splash * 8,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: widget.boostActive
                              ? const [Color(0xFFA06A35), Color(0xFF6B3E18)]
                              : const [Color(0xFF8B5A2B), Color(0xFF4A2F14)],
                        ),
                        borderRadius: BorderRadius.circular(48),
                        border: Border.all(
                          color: const Color(0xFF3A220E),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5C3A1A)
                                .withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    // Inner wet sheen
                    Positioned(
                      top: 14,
                      child: Container(
                        width: 44,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    // Mud bubbles
                    Positioned(left: 22, bottom: 16, child: _bubble(7)),
                    Positioned(right: 26, bottom: 20, child: _bubble(5)),
                  ],
                ),
              ),
              // Splash particles during wallow
              if (widget.isWallowing) ...[
                for (var i = 0; i < 8; i++)
                  _MudParticle(angle: i * math.pi / 4, progress: splash),
              ],
              // Label chip
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.boostActive ? 'грязь ×2!' : 'лужа',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.brown.shade900.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bubble(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFC49A5A).withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
    );
  }
}

class _MudParticle extends StatelessWidget {
  const _MudParticle({required this.angle, required this.progress});

  final double angle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final dist = 20 + progress * 32;
    final dx = math.cos(angle) * dist;
    final dy = math.sin(angle) * dist - progress * 14;
    final size = 7.0 + (1 - progress) * 5;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: (1 - progress).clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5A2B),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF5C3A1A), width: 1),
          ),
        ),
      ),
    );
  }
}

/// Overlay bounce/rotate for a capybara sitting on the puddle.
class WallowOverlay extends StatefulWidget {
  const WallowOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<WallowOverlay> createState() => _WallowOverlayState();
}

class _WallowOverlayState extends State<WallowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotate;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: BalanceV0.mudWallowAnimDuration,
    )..forward();
    _rotate = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.18), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: -0.18), weight: 50),
      TweenSequenceItem(tween: Tween(begin: -0.18, end: 0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _bounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -14), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -14, end: 4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounce.value),
          child: Transform.rotate(angle: _rotate.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
