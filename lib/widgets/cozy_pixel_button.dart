import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cozy_theme.dart';

/// Soft-pixel CTA style matching `store/art-pack-zones/ui-btn-kit-strip.png`
/// (sage fill / cream outline / muted disabled) — programmatic bevel, no 9-slice.
enum CozyPixelButtonVariant {
  /// Filled sage with light/dark bevel edge.
  primary,

  /// Cream pill with warm outline.
  secondary,
}

/// Cozy pill button — Pixelify (primary) / Nunito (secondary) labels.
class CozyPixelButton extends StatelessWidget {
  const CozyPixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CozyPixelButtonVariant.primary,
    this.expand = false,
    this.compact = false,
    this.leading,
    this.fontSize,
    this.maxWidth,
  });

  final String label;
  final VoidCallback? onPressed;
  final CozyPixelButtonVariant variant;
  final bool expand;
  final bool compact;
  final Widget? leading;
  final double? fontSize;
  final double? maxWidth;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final isPrimary = variant == CozyPixelButtonVariant.primary;

    final Color fill;
    final Color edge;
    final Color textColor;
    if (!enabled) {
      fill = const Color(0xFFD5C8B0);
      edge = const Color(0xFFB0A08A);
      textColor = const Color(0xFF8A7A65);
    } else if (isPrimary) {
      fill = CozyTheme.softSage;
      edge = CozyTheme.softSageEdge;
      textColor = CozyTheme.cream;
    } else {
      fill = CozyTheme.cream.withValues(alpha: 0.92);
      edge = const Color(0xFFE2CFA8);
      textColor = CozyTheme.warmBrown;
    }

    final radius = compact ? 14.0 : 22.0;
    final hPad = compact ? 12.0 : 22.0;
    final vPad = compact ? 8.0 : 12.0;
    final fs = fontSize ?? (compact ? 12.0 : (isPrimary ? 16.0 : 13.0));

    final labelStyle = isPrimary && !compact
        ? CozyTheme.menuPrimaryCtaStyle(fontSize: fs).copyWith(
            color: textColor,
          )
        : (isPrimary
            ? CozyTheme.primaryButtonStyle(fontSize: fs).copyWith(
                color: textColor,
              )
            : CozyTheme.secondaryButtonStyle(fontSize: fs).copyWith(
                color: textColor,
              ));

    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            color: (enabled && isPrimary) ? null : fill,
            gradient: enabled && isPrimary
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF8FBE78),
                      Color(0xFF7AAD68),
                      Color(0xFF6A9A58),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  )
                : null,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: edge, width: isPrimary ? 2 : 1.5),
            boxShadow: enabled && isPrimary
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: compact ? 6 : 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Widget result = child;
    if (expand) {
      result = SizedBox(width: double.infinity, child: result);
    }
    if (maxWidth != null) {
      result = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: result,
      );
    }
    return result;
  }
}

/// Circular cozy pixel frame for mute / close / pause icons.
class CozyPixelIconButton extends StatelessWidget {
  const CozyPixelIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 36,
    this.iconSize = 20,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          customBorder: const CircleBorder(),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? CozyTheme.cream.withValues(alpha: 0.95)
                  : const Color(0xFFD5C8B0),
              border: Border.all(
                color: enabled
                    ? const Color(0xFFE2CFA8)
                    : const Color(0xFFB0A08A),
                width: 1.5,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: enabled
                  ? CozyTheme.warmBrown
                  : const Color(0xFF8A7A65),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
