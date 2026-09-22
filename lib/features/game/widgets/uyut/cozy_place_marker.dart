import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/multipliers/cozy_place.dart';
import 'multiplier_icon.dart';

/// Placeable marker on the meadow (пень / камень / тент).
/// Soft pulse when ready; stronger glow when boost active; dim on cooldown.
class CozyPlaceMarker extends StatefulWidget {
  const CozyPlaceMarker({
    super.key,
    required this.kind,
    required this.active,
    required this.onCooldown,
    required this.cooldownSeconds,
    required this.onTap,
  });

  final CozyPlaceKind kind;
  final bool active;
  final bool onCooldown;
  final double cooldownSeconds;
  final VoidCallback onTap;

  @override
  State<CozyPlaceMarker> createState() => _CozyPlaceMarkerState();
}

class _CozyPlaceMarkerState extends State<CozyPlaceMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dim = widget.onCooldown && !widget.active;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final readyPulse = (!dim && !widget.active)
              ? (0.55 + _pulse.value * 0.35)
              : 1.0;
          final activeGlow = widget.active ? (0.55 + _pulse.value * 0.40) : 0.0;
          final scale = widget.active
              ? (1.0 + _pulse.value * 0.04)
              : (dim ? 0.96 : 1.0 + _pulse.value * 0.015);

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 72,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.active || !dim)
                    Container(
                      width: 58,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.active
                                    ? const Color(0xFFE0A020)
                                    : const Color(0xFFFFE08A))
                                .withValues(
                              alpha: widget.active
                                  ? activeGlow
                                  : 0.18 + _pulse.value * 0.22,
                            ),
                            blurRadius: widget.active ? 18 : 12,
                            spreadRadius: widget.active ? 3 : 1,
                          ),
                        ],
                      ),
                    ),
                  Opacity(
                    opacity: dim ? 0.5 : readyPulse.clamp(0.55, 1.0),
                    child: Container(
                      width: 56,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.active
                            ? const Color(0xFFFFE08A).withValues(alpha: 0.92)
                            : const Color(0xFFF8EDD8)
                                .withValues(alpha: dim ? 0.45 : 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.active
                              ? const Color(0xFFE0A020)
                              : const Color(0xFFE2CFA8),
                          width: widget.active ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: MultiplierIcon(
                          assetPath: widget.kind.assetPath,
                          size: 30,
                          opacity: dim ? 0.55 : 1,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onCooldown && widget.cooldownSeconds > 0.4)
                    Positioned(
                      bottom: 0,
                      child: Text(
                        '${widget.cooldownSeconds.ceil()}с',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.brown.shade700.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
