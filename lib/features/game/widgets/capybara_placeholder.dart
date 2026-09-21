import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Pixel-sprite capybara; size + warmer tint + badge grow with [level].
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
    return t * 0.48;
  }

  Color get _badgeColor {
    final t = ((level - 1) / (BalanceV0.maxVisualLevel - 1)).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFFF5E6C8), const Color(0xFFFFC14A), t)!;
  }

  Color get _borderColor {
    final t = ((level - 1) / (BalanceV0.maxVisualLevel - 1)).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFF8B6914), const Color(0xFFC87820), t)!;
  }

  /// Soft glow ring strength for high levels (visual ladder clarity).
  double get _halo {
    if (level < 3) return 0;
    final t = ((level - 2) / (BalanceV0.maxVisualLevel - 2)).clamp(0.0, 1.0);
    return 0.12 + t * 0.28;
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
              if (_halo > 0)
                BoxShadow(
                  color: const Color(0xFFFFB74D).withValues(alpha: _halo),
                  blurRadius: 10 + level * 2.0,
                  spreadRadius: 1 + level * 0.4,
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
                : (level >= 4
                      ? Border.all(
                          color: _borderColor.withValues(alpha: 0.55),
                          width: 2,
                        )
                      : null),
          ),
          clipBehavior: Clip.none,
          child: sprite,
        ),
        if (showLabel) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _badgeColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _borderColor.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              'Lv.$level',
              style: TextStyle(
                color: const Color(0xFF5C3D1E).withValues(alpha: 0.95),
                fontSize: level >= 5 ? 12 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
