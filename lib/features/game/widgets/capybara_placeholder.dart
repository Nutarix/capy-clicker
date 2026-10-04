import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/balance.dart';
import '../models/capy_pose.dart';
import '../models/capy_walk.dart';
import '../models/capy_wander.dart';
import '../models/multipliers/capy_role.dart';

/// Pixel-sprite capybara; size + warmer tint + badge grow with [level].
///
/// Uses per-type walk sheets (`assets/images/walk/`) — role sheets are the
/// role look (not only a badge). [walkFrame] cycles 0..3 while walking.
class CapybaraPlaceholder extends StatelessWidget {
  const CapybaraPlaceholder({
    super.key,
    this.level = 1,
    this.role,
    this.walkFrame = 0,
    this.showLabel = true,
    this.compactLabel = false,
    this.sizeOverride,
    this.flash = false,
    this.twinSparkle = false,
    this.faceRight = true,
    this.name,
    this.pose,
  });

  final int level;

  /// Optional Семья role — selects nanny/gatherer/guard walk sheet.
  final CapyRole? role;

  /// Walk-cycle frame 0..3 (idle uses 0).
  final int walkFrame;

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

  /// Shown next to the level («Пуговка · Lv.2») while touched or dragged
  /// (spec 004, Т6). The chip may be wider than the capy; it never moves
  /// the sprite.
  final String? name;

  /// Sleepyhead / dreamer pose frame instead of the walk frame (Т9).
  final CapyPoseFrame? pose;

  double get _width => sizeOverride ?? BalanceV0.capySizeForLevel(level);

  CapyWalkSheet get walkSheet => CapyWalk.sheetFor(level: level, role: role);

  String get _assetPath => CapyWalk.assetPath(walkSheet, walkFrame);

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

  /// Blurred tint of the walk sheet, so the glow is the body not a rectangle.
  Widget _spriteGlow(
    double w,
    double h,
    Color color,
    double alpha,
    double blur,
  ) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Opacity(
        opacity: alpha.clamp(0.0, 1.0),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
          child: _rawSprite(w, h),
        ),
      ),
    );
  }

  Widget _rawSprite(double w, double h) {
    final p = pose;
    if (p != null) return _poseSprite(w, h, p, bubble: false);
    return Image.asset(
      _assetPath,
      width: w,
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
    );
  }

  /// The pose canvas at the walk scale, feet on the walk's foot line, so a
  /// capy sits down or lies down where it stood. May reach past the box.
  Widget _poseSprite(
    double w,
    double h,
    CapyPoseFrame p, {
    required bool bubble,
  }) {
    final k = w / CapyPose.pixelsPerCapyWidth;
    final walkH = CapyWander.sheetPixelHeight * k;
    // Walk frames: contain-fit, centered; feet 3 px above the frame bottom.
    final footY = (h - walkH) / 2 + walkH - CapyPose.basePad * k;
    final pw = CapyPose.canvasW * k;
    final ph = CapyPose.canvasH * k;
    final left = (w - pw) / 2;
    final top = footY - (CapyPose.canvasH - CapyPose.basePad) * k;
    Widget body = Image.asset(
      p.asset,
      width: pw,
      height: ph,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
    );
    if (!faceRight) {
      body = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: body,
      );
    }
    final children = <Widget>[
      Positioned(left: left, top: top, width: pw, height: ph, child: body),
    ];
    final b = p.bubbleAsset;
    if (bubble && b != null) {
      final size =
          CapyPose.bubbleCanvas * k * CapyPose.bubbleDrawScale * p.bubbleScale;
      final ax = faceRight
          ? p.bubbleAnchor.dx
          : CapyPose.canvasW - p.bubbleAnchor.dx;
      final x = left + ax * k;
      final y = top + p.bubbleAnchor.dy * k;
      children.add(
        Positioned(
          left: x - size / 2,
          top: y - size,
          width: size,
          height: size,
          child: Opacity(
            opacity: p.bubbleOpacity.clamp(0.0, 1.0),
            child: Image.asset(
              b,
              key: const ValueKey('capy-sleep-bubble'),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              gaplessPlayback: true,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: w,
      height: h,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _width;
    final h = w * 0.95;

    final p = pose;
    Widget sprite = p != null
        ? _poseSprite(w, h, p, bubble: true)
        : _walkSprite(w, h);

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
    return _withGlowAndBadge(w, h, sprite);
  }

  Widget _walkSprite(double w, double h) {
    Widget sprite = Image.asset(
      _assetPath,
      width: w,
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to legacy static sprites if a walk frame is missing.
        final fallback = level >= 3
            ? 'assets/images/capy_lv3.png'
            : 'assets/images/capy_lv1.png';
        return Image.asset(
          fallback,
          width: w,
          height: h,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        );
      },
    );
    if (!faceRight) {
      sprite = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: sprite,
      );
    }
    return sprite;
  }

  Widget _withGlowAndBadge(double w, double h, Widget sprite) {
    // Glow follows the opaque pixels. A frame BoxShadow read as a gray card
    // around the transparent corners of the walk sheet.
    Widget framed = sprite;
    if (_halo > 0 || flash) {
      framed = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (_halo > 0) _spriteGlow(w, h, const Color(0xFFFFB74D), _halo, 7),
          if (flash) _spriteGlow(w, h, const Color(0xFFFFD54F), 0.9, 9),
          sprite,
        ],
      );
    }

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: w, height: h, child: framed),
        if (showLabel) ...[
          SizedBox(height: compactLabel ? 2 : 5),
          Opacity(
            // Under a name chip the level badge only keeps the place.
            opacity: name != null ? 0.0 : (compactLabel ? 0.55 : 1.0),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compactLabel ? 5 : 9,
                vertical: compactLabel ? 1 : 3,
              ),
              decoration: BoxDecoration(
                color: _badgeColor.withValues(alpha: compactLabel ? 0.7 : 0.92),
                borderRadius: BorderRadius.circular(compactLabel ? 7 : 10),
                border: Border.all(
                  color: _borderColor.withValues(
                    alpha: compactLabel ? 0.35 : 0.55,
                  ),
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
                  color: const Color(0xFF5C3D1E)
                      .withValues(alpha: compactLabel ? 0.75 : 0.95),
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
    final shown = name;
    if (showLabel && shown != null) {
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          // Over the level badge, wider than the capy if it must be.
          Positioned(
            left: -90,
            right: -90,
            bottom: 0,
            child: Center(child: _nameChip(shown)),
          ),
        ],
      );
    }
    if (twinSparkle) {
      body = TwinSparkleHalo(size: w, child: body);
    }
    return body;
  }

  Widget _nameChip(String shown) {
    return Container(
      key: const ValueKey('capy-name-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: _badgeColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _borderColor.withValues(alpha: 0.6),
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
        '$shown · Lv.$level',
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: const Color(0xFF5C3D1E).withValues(alpha: 0.95),
          fontSize: level >= 5 ? 12 : 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
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
        // No frame shadow. A slight breathe keeps the twin mark without a card.
        return Opacity(opacity: 0.88 + _ctrl.value * 0.12, child: child);
      },
      child: widget.child,
    );
  }
}
