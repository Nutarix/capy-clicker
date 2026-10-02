import 'package:flutter/material.dart';

import '../../../theme/cozy_theme.dart';
import '../../../widgets/cozy_pixel_button.dart';
import '../models/balance.dart';

/// One even row: Позвать, Ускорение, Еда, Лес.
///
/// Costs stay in behavior ([BalanceV0]) and in semantics. The short label
/// hides the number, matching the meadow frames.
class GrassSpendPanel extends StatelessWidget {
  const GrassSpendPanel({
    super.key,
    required this.grass,
    required this.canCallCapy,
    this.callBlockedReason,
    required this.canBoost,
    required this.onCallCapy,
    required this.onBoost,
    this.boostActive = false,
    this.onUyutHub,
    this.onForest,
    this.foodHint,
  });

  final int grass;
  final bool canCallCapy;

  /// Shown instead of «Позвать» while the call is gray.
  /// «Не хватает травы» or «Семья полная».
  final String? callBlockedReason;

  final bool canBoost;
  final VoidCallback onCallCapy;
  final VoidCallback onBoost;
  final bool boostActive;
  final VoidCallback? onUyutHub;
  final VoidCallback? onForest;

  /// Kept for callers. The meadow button is just «Еда».
  final String? foodHint;

  @override
  Widget build(BuildContext context) {
    assert(grass >= 0);
    final callLabel = callBlockedReason ?? 'Позвать';
    return Row(
      children: [
        Expanded(
          child: _SpendPill(
            label: callLabel,
            semantics: callBlockedReason == null
                ? 'Позвать, ${BalanceV0.callCapyGrassCost} травы'
                : callLabel,
            enabled: canCallCapy,
            onTap: onCallCapy,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _SpendPill(
            label: 'Ускорение',
            semantics: 'Ускорение, ${BalanceV0.grassBoostCost} травы',
            enabled: canBoost && !boostActive,
            onTap: onBoost,
          ),
        ),
        if (onUyutHub != null) ...[
          const SizedBox(width: 6),
          Expanded(
            child: _SpendPill(
              label: 'Еда',
              semantics: 'Еда',
              enabled: true,
              onTap: onUyutHub!,
            ),
          ),
        ],
        if (onForest != null) ...[
          const SizedBox(width: 6),
          Expanded(
            child: _SpendPill(
              label: 'Лес',
              semantics: 'Лес',
              enabled: true,
              onTap: onForest!,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpendPill extends StatelessWidget {
  const _SpendPill({
    required this.label,
    required this.semantics,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String semantics;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: CozyPixelButton(
        label: label,
        variant: CozyPixelButtonVariant.secondary,
        compact: true,
        expand: true,
        fontSize: 12,
        onPressed: enabled ? onTap : null,
      ),
    );
  }
}

/// Grass count for the thin top bar. [grass] is accepted so callers compile.
class MeadowGrassReadout extends StatelessWidget {
  const MeadowGrassReadout({super.key, required this.grass, this.uyut = 0});

  final int grass;
  final int uyut;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/ui/icon_grass.png',
          width: 22,
          height: 22,
          filterQuality: FilterQuality.none,
        ),
        const SizedBox(width: 4),
        Text(
          '$grass',
          style: CozyTheme.hudChipStyle(fontSize: 16)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        if (uyut > 0) ...[
          const SizedBox(width: 10),
          Image.asset(
            'assets/images/ui/icon_spark.png',
            width: 18,
            height: 18,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 2),
          Text('$uyut', style: CozyTheme.hudChipStyle(fontSize: 14)),
        ],
      ],
    );
  }
}
