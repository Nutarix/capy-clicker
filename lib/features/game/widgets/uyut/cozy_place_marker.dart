import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/multipliers/cozy_place.dart';
import 'multiplier_icon.dart';

/// Placeable marker on the meadow (пень / камень / тент).
class CozyPlaceMarker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final dim = onCooldown && !active;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: SizedBox(
        width: 72,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFFE08A).withValues(alpha: 0.85)
                    : const Color(0xFFF8EDD8).withValues(alpha: dim ? 0.45 : 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active
                      ? const Color(0xFFE0A020)
                      : const Color(0xFFE2CFA8),
                  width: active ? 2 : 1,
                ),
              ),
              child: Center(
                child: MultiplierIcon(
                  assetPath: kind.assetPath,
                  size: 30,
                  opacity: dim ? 0.55 : 1,
                ),
              ),
            ),
            if (onCooldown && cooldownSeconds > 0.4)
              Positioned(
                bottom: 0,
                child: Text(
                  '${cooldownSeconds.ceil()}с',
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
  }
}
