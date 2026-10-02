import 'package:flutter/material.dart';

import '../models/balance.dart';
import '../../../widgets/cozy_pixel_button.dart';

/// Soft once-per-day claim sheet: «Утренний уют».
/// Not an energy gate — dismissible, claimable until taken that calendar day.
class MorningCozySheet extends StatelessWidget {
  const MorningCozySheet({
    super.key,
    required this.onClaim,
    this.dailyGoalHint,
  });

  final VoidCallback onClaim;

  /// Soft daily tip, e.g. «Сегодня: доберись до Ягодной поляны».
  final String? dailyGoalHint;

  /// Shows the sheet; returns true if the player claimed.
  static Future<bool> show(
    BuildContext context, {
    required VoidCallback onClaim,
    String? dailyGoalHint,
  }) async {
    var claimed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return MorningCozySheet(
          dailyGoalHint: dailyGoalHint,
          onClaim: () {
            claimed = true;
            onClaim();
            Navigator.of(ctx).pop();
          },
        );
      },
    );
    return claimed;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.brown.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Image.asset(
                  'assets/images/ui/icon_spark.png',
                  width: 54,
                  height: 54,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Утренний уют',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5C3D1E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Нежный подарок на сегодня',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: Colors.brown.shade800.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '+${(BalanceV0.dailyBonusProgress * 100).round()}% к прогрессу семьи',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.brown.shade800.withValues(alpha: 0.85),
                  ),
                ),
                if (dailyGoalHint != null && dailyGoalHint!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    dailyGoalHint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.brown.shade800.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                CozyPixelButton(
                  label: 'Забрать уют',
                  expand: true,
                  onPressed: onClaim,
                ),
                const SizedBox(height: 8),
                CozyPixelButton(
                  label: 'Позже',
                  variant: CozyPixelButtonVariant.secondary,
                  compact: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
