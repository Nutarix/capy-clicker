import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Soft brown rounded placeholder for a capybara; scale grows with [level].
/// Structured so a sprite Image can replace the emoji later.
class CapybaraPlaceholder extends StatelessWidget {
  const CapybaraPlaceholder({
    super.key,
    this.level = 1,
    this.showLabel = true,
    this.sizeOverride,
  });

  final int level;
  final bool showLabel;

  /// Optional absolute width; otherwise derived from [level].
  final double? sizeOverride;

  double get _width =>
      sizeOverride ??
      BalanceV0.baseCapySize * (1 + (level - 1) * BalanceV0.scalePerLevel);

  @override
  Widget build(BuildContext context) {
    final w = _width;
    final h = w * 0.72;
    final fontSize = (w * 0.38).clamp(18.0, 56.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFF8B6914),
              const Color(0xFF5C4010),
              ((level - 1) / 6).clamp(0.0, 1.0),
            ),
            borderRadius: BorderRadius.circular(w * 0.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF6B4E10),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '🦫',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            'Lv.$level',
            style: TextStyle(
              color: Colors.brown.shade900.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
