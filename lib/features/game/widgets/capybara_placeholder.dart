import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Pixel-sprite capybara; size + warmer tint grow with [level].
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

  /// lv1 sprite for levels 1–2, lv3 sprite for levels 3+.
  String get _assetPath =>
      level >= 3 ? 'assets/images/capy_lv3.png' : 'assets/images/capy_lv1.png';

  /// Warm amber ColorFilter strength for higher levels (up to Lv.6).
  double get _warmth {
    final t = ((level - 1) / (BalanceV0.maxVisualLevel - 1)).clamp(0.0, 1.0);
    return t * 0.35;
  }

  Color get _borderColor {
    final t = ((level - 1) / (BalanceV0.maxVisualLevel - 1)).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFF8B6914), const Color(0xFFC87820), t)!;
  }

  @override
  Widget build(BuildContext context) {
    final w = _width;
    final h = w * 0.95;

    Widget sprite = Image.asset(
      _assetPath,
      width: w,
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );

    // Optional warmer tint for higher levels (cheap ColorFiltered blend).
    if (_warmth > 0.01) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Color.lerp(Colors.white, const Color(0xFFFFAA3C), _warmth)!,
          BlendMode.modulate,
        ),
        child: sprite,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(w * 0.18),
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
            border: flash
                ? Border.all(color: const Color(0xFFFFE082), width: 3.5)
                : null,
          ),
          clipBehavior: Clip.none,
          child: sprite,
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
