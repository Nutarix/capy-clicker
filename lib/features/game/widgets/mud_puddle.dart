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
          width: 96,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Puddle body
              Transform.translate(
                offset: Offset(0, bounce * 0.15),
                child: Container(
                  width: 88 + splash * 10,
                  height: 48 + splash * 6,
                  decoration: BoxDecoration(
                    color: widget.boostActive
                        ? const Color(0xFF8B5A2B)
                        : const Color(0xFF6B4423),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: const Color(0xFF4A2F14),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5C3A1A).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              // Highlight oval
              Positioned(
                top: 18,
                child: Container(
                  width: 36,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              // Splash particles during wallow
              if (widget.isWallowing) ...[
                for (var i = 0; i < 6; i++)
                  _MudParticle(
                    angle: i * math.pi / 3,
                    progress: splash,
                  ),
              ],
              // Label
              Positioned(
                bottom: -2,
                child: Text(
                  widget.boostActive ? 'грязь ×2!' : 'лужа',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.brown.shade900.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MudParticle extends StatelessWidget {
  const _MudParticle({required this.angle, required this.progress});

  final double angle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final dist = 18 + progress * 28;
    final dx = math.cos(angle) * dist;
    final dy = math.sin(angle) * dist - progress * 12;
    final size = 6.0 + (1 - progress) * 4;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: (1 - progress).clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF8B5A2B),
            shape: BoxShape.circle,
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
          child: Transform.rotate(
            angle: _rotate.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
