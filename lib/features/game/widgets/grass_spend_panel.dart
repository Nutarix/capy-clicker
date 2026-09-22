import 'package:flutter/material.dart';

import '../../../theme/cozy_theme.dart';
import '../../../widgets/cozy_pixel_button.dart';
import '../models/balance.dart';

/// Cozy spend row: grass chip + Call Capy / Boost pills.
class GrassSpendPanel extends StatelessWidget {
  const GrassSpendPanel({
    super.key,
    required this.grass,
    required this.canCallCapy,
    required this.canBoost,
    required this.onCallCapy,
    required this.onBoost,
    this.boostActive = false,
    this.onUyutHub,
    this.foodHint,
  });

  final int grass;
  final bool canCallCapy;
  final bool canBoost;
  final VoidCallback onCallCapy;
  final VoidCallback onBoost;
  final bool boostActive;
  final VoidCallback? onUyutHub;
  final String? foodHint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8EDD8).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2CFA8).withValues(alpha: 0.9),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            _GrassChip(grass: grass),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _SpendPill(
                    label: 'Позвать капи',
                    cost: BalanceV0.callCapyGrassCost,
                    enabled: canCallCapy,
                    onTap: onCallCapy,
                  ),
                  _SpendPill(
                    label: boostActive ? 'Ускорение…' : 'Ускорение',
                    cost: BalanceV0.grassBoostCost,
                    enabled: canBoost,
                    onTap: onBoost,
                  ),
                  if (onUyutHub != null)
                    _SpendPill(
                      label: foodHint ?? 'Еда',
                      cost: 0,
                      enabled: true,
                      onTap: onUyutHub!,
                      hideCost: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrassChip extends StatelessWidget {
  const _GrassChip({required this.grass});

  final int grass;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5D8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA8C878)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌿', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              '$grass',
              style: CozyTheme.hudChipStyle(fontSize: 13).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendPill extends StatelessWidget {
  const _SpendPill({
    required this.label,
    required this.cost,
    required this.enabled,
    required this.onTap,
    this.hideCost = false,
  });

  final String label;
  final int cost;
  final bool enabled;
  final VoidCallback onTap;
  final bool hideCost;

  @override
  Widget build(BuildContext context) {
    return CozyPixelButton(
      label: hideCost ? label : '$label · $cost🌿',
      variant: CozyPixelButtonVariant.secondary,
      compact: true,
      fontSize: 11,
      onPressed: enabled ? onTap : null,
    );
  }
}
