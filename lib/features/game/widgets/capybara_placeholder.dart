import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Soft round placeholder for a capybara; size + warmer tint grow with [level].
/// Structured so a sprite Image can replace the emoji later.
class CapybaraPlaceholder extends StatelessWidget {
  const CapybaraPlaceholder({
    super.key,
    this.level = 1,
    this.showLabel = true,
    this.sizeOverride,
    this.flash = false,
  });

  final int level;
  final bool showLabel;

  /// Optional absolute width; otherwise derived from [level].
  final double? sizeOverride;

  /// Golden merge flash ring.
  final bool flash;

  double get _width => sizeOverride ?? BalanceV0.capySizeForLevel(level);

  /// Base brown → warmer golden-brown for higher levels (up to Lv.6).
  Color get _bodyColor {
    final t = ((level - 1) / (BalanceV0.maxVisualLevel - 1)).clamp(0.0, 1.0);
    return Color.lerp(
      const Color(0xFFC49A5A), // soft sandy
      const Color(0xFFE8A040), // warm amber high-level
      t,
    )!;
  }

  Color get _borderColor {
    final t = ((level - 1) / (BalanceV0.maxVisualLevel - 1)).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFF8B6914), const Color(0xFFC87820), t)!;
  }

  @override
  Widget build(BuildContext context) {
    final w = _width;
    final h = w * 0.78;
    final fontSize = (w * 0.42).clamp(20.0, 64.0);
    final radius = w * 0.42; // rounder, almost pill

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: _bodyColor,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
              if (flash)
                BoxShadow(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.85),
                  blurRadius: 22,
                  spreadRadius: 6,
                ),
            ],
            border: Border.all(
              color: flash ? const Color(0xFFFFE082) : _borderColor,
              width: flash ? 3.5 : 2.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft top highlight for rounder look
              Positioned(
                top: h * 0.12,
                child: Container(
                  width: w * 0.55,
                  height: h * 0.22,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
              Text('🦫', style: TextStyle(fontSize: fontSize)),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _borderColor.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Text(
              'Lv.$level',
              style: TextStyle(
                color: const Color(0xFF5C3D1E).withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
