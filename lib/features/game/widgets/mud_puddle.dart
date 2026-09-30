import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/balance.dart';
import 'meadow_hint_chip.dart';

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
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _idleGlow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: BalanceV0.mudWallowAnimDuration,
    );
    _idleGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
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
    _idleGlow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl, _idleGlow]),
      builder: (context, _) {
        final t = _ctrl.value;
        final splash = widget.isWallowing ? Curves.easeOut.transform(t) : 0.0;
        final bounce = widget.isWallowing
            ? math.sin(t * math.pi * 2) * (1 - t) * 16
            : 0.0;
        final idle = widget.boostActive
            ? 0.55
            : (0.22 + _idleGlow.value * 0.28);
        return SizedBox(
          width: 168,
          height: 124,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 118,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5A2B).withValues(alpha: idle),
                      blurRadius: widget.isWallowing ? 28 : 16,
                      spreadRadius: widget.isWallowing ? 4 : 1,
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 18,
                child: Container(
                  width: 100,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, bounce * 0.2),
                child: Transform.scale(
                  scale: 1.0 + splash * 0.22,
                  child: ColorFiltered(
                    colorFilter: widget.boostActive
                        ? const ColorFilter.mode(
                            Color(0xFFFFE0B0),
                            BlendMode.modulate,
                          )
                        : const ColorFilter.mode(
                            Colors.white,
                            BlendMode.modulate,
                          ),
                    child: Image.asset(
                      'assets/images/mud.png',
                      width: 110,
                      height: 78,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              if (widget.isWallowing) ...[
                for (var i = 0; i < 12; i++)
                  _MudParticle(
                    angle: i * math.pi / 6,
                    progress: splash,
                    big: i.isEven,
                  ),
                Opacity(
                  opacity: (1 - splash).clamp(0.0, 1.0),
                  child: const Text('💦', style: TextStyle(fontSize: 28)),
                ),
              ],
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: MeadowHintChip(
                    text: widget.boostActive
                        ? 'грязь ×2!'
                        : (widget.isWallowing ? 'плеск!' : 'сюда!'),
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
  const _MudParticle({
    required this.angle,
    required this.progress,
    required this.big,
  });

  final double angle;
  final double progress;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final dist = 18 + progress * (big ? 64 : 48);
    final dx = math.cos(angle) * dist;
    final dy = math.sin(angle) * dist * 0.72 - progress * 22;
    final size = (big ? 11.0 : 7.0) + (1 - progress) * 6;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: (1 - progress).clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: big ? const Color(0xFF8B5A2B) : const Color(0xFFD7A15A),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF5C3A1A), width: 1),
          ),
        ),
      ),
    );
  }
}

/// Obvious ~1s mud bath: hop, spin, sink, then pop back. Splash sits outside
/// the transform so it reads even when the capy is small.
class WallowOverlay extends StatefulWidget {
  const WallowOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<WallowOverlay> createState() => _WallowOverlayState();
}

class _WallowOverlayState extends State<WallowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: BalanceV0.mudWallowAnimDuration,
    )..forward();
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
        final t = _ctrl.value;
        // 0–0.35 hop up, 0.35–0.7 spin+sink, 0.7–1 pop back.
        final hop = t < 0.35
            ? -40 * math.sin(t / 0.35 * math.pi)
            : (t < 0.75 ? 26 * math.sin((t - 0.35) / 0.4 * math.pi) : 0.0);
        final rot = math.sin(t * math.pi * 3) * 0.7;
        final squash = t < 0.35
            ? 1.0 + 0.18 * math.sin(t / 0.35 * math.pi)
            : (t < 0.75 ? 0.78 : 0.78 + 0.22 * ((t - 0.75) / 0.25));
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < 8; i++)
              _MudParticle(
                angle: i * math.pi / 4 + 0.2,
                progress: Curves.easeOut.transform(t),
                big: i.isEven,
              ),
            Transform.translate(
              offset: Offset(math.sin(t * math.pi * 4) * 10, hop),
              child: Transform.rotate(
                angle: rot,
                child: Transform.scale(
                  scale: squash.clamp(0.7, 1.3),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
