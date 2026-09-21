import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Rounded cream progress bar with green fill and herd / boost status.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Прогресс стада$countLabel$boostLabel',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.brown.shade800.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFF5E6C8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE8D4A8),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: boostActive
                      ? const [
                          Color(0xFFD4A017),
                          Color(0xFFB8860B),
                        ]
                      : const [
                          Color(0xFF7EC850),
                          Color(0xFF5AA832),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
