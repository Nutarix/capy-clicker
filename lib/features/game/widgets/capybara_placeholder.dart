import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Pixel-sprite capybara; size + warmer tint + badge grow with [level].
class CapybaraPlaceholder extends StatelessWidget {
  const CapybaraPlaceholder({
    super.key,
    this.level = 1,
    this.showLabel = true,
    this.compactLabel = false,
    this.sizeOverride,
    this.flash = false,
    this.twinSparkle = false,
    this.faceRight = true,
  });

  final int level;
  final bool showLabel;

  /// Smaller / quieter Lv badge (idle herd). Full badge when dragged / merged.
  final bool compactLabel;

  /// Optional absolute width; otherwise derived from [level].
  final double? sizeOverride;

  /// Golden merge flash ring.
  final bool flash;

  /// Soft twin-sparkle glow (merge skill window).
  final bool twinSparkle;

  /// When false, horizontal-flip the body sprite only (labels stay readable).
  final bool faceRight;

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
    if (!faceRight) {
      sprite = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: sprite,
      );
    }

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

    Widget body = Column(
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
          SizedBox(height: compactLabel ? 2 : 5),
          Opacity(
            opacity: compactLabel ? 0.55 : 1.0,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compactLabel ? 5 : 9,
                vertical: compactLabel ? 1 : 3,
              ),
              decoration: BoxDecoration(
                color: _badgeColor.withValues(alpha: compactLabel ? 0.7 : 0.92),
                borderRadius: BorderRadius.circular(compactLabel ? 7 : 10),
                border: Border.all(
                  color: _borderColor.withValues(alpha: compactLabel ? 0.35 : 0.55),
                  width: compactLabel ? 0.8 : 1.2,
                ),
                boxShadow: compactLabel
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Text(
                compactLabel ? '$level' : 'Lv.$level',
                style: TextStyle(
                  color: const Color(0xFF5C3D1E).withValues(
                    alpha: compactLabel ? 0.75 : 0.95,
                  ),
                  fontSize: compactLabel ? 9 : (level >= 5 ? 12 : 11),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
    if (twinSparkle) {
      body = TwinSparkleHalo(size: w, child: body);
    }
    return body;
  }
}

/// Soft opacity shimmer for twin-mark capys (procedural, no new frames).
class TwinSparkleHalo extends StatefulWidget {
  const TwinSparkleHalo({super.key, required this.child, required this.size});

  final Widget child;
  final double size;

  @override
  State<TwinSparkleHalo> createState() => _TwinSparkleHaloState();
}

class _TwinSparkleHaloState extends State<TwinSparkleHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final a = 0.35 + _ctrl.value * 0.45;
        final blur = 10.0 + _ctrl.value * 10.0;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.size * 0.22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7EC8E3).withValues(alpha: a),
                blurRadius: blur,
                spreadRadius: 2 + _ctrl.value * 3,
              ),
              BoxShadow(
                color: const Color(0xFFFFF8E1).withValues(alpha: a * 0.45),
                blurRadius: blur * 0.6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
