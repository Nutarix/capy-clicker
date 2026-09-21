import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Soft cream track + leafy green fill, matching cozy key-art vibe.
class CreamProgressBar extends StatelessWidget {
  const CreamProgressBar({
    super.key,
    required this.value,
    this.herdCount,
    this.boostActive = false,
    this.boostSeconds = 0,
  });

  /// Progress in range 0.0–1.0.
  final double value;

  /// Optional herd size shown beside the label.
  final int? herdCount;

  final bool boostActive;
  final double boostSeconds;

  @override
  Widget build(BuildContext context) {
    final countLabel = herdCount == null
        ? ''
        : ' · ${herdCount!}/${BalanceV0.maxHerdSize}';
    final boostLabel = boostActive
        ? ' · грязь ×${BalanceV0.mudBoostMultiplier.toStringAsFixed(0)} '
              '(${boostSeconds.ceil()}с)'
        : '';
    final t = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Прогресс стада$countLabel$boostLabel',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF5C3D1E).withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF8EDD8),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.55),
                blurRadius: 0,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
            border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Soft empty track tint
                const ColoredBox(color: Color(0xFFF3E4C4)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: boostActive
                            ? const [
                                Color(0xFFF0D060),
                                Color(0xFFD4A017),
                                Color(0xFFB8860B),
                              ]
                            : const [
                                Color(0xFFA8E070),
                                Color(0xFF7EC850),
                                Color(0xFF4F9A30),
                              ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.42,
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
