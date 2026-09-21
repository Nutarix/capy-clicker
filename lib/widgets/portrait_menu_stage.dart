import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'portrait_phone_frame.dart';

/// Centers menu UI in a full-height **9:16** column on web/desktop.
///
/// Side gutters keep the forest backdrop (soft blur + green wash) — no phone
/// bezel, border, or dark letterbox. On mobile phones the child fills the
/// screen (system portrait lock applies).
class PortraitMenuStage extends StatelessWidget {
  const PortraitMenuStage({super.key, required this.child});

  final Widget child;

  /// Soft forest-tint wash over blurred gutters (not opaque letterbox).
  static const _gutterWash = Color(0x4022451C);

  @override
  Widget build(BuildContext context) {
    if (!PortraitPhoneFrame.useFrame) return child;

    final size = MediaQuery.sizeOf(context);
    // Full-height 9:16 — use as much vertical space as possible.
    final frameH = size.height;
    final frameW = math.min(size.width, frameH * 9 / 16);
    final gutter = (size.width - frameW) / 2;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (gutter > 0.5) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: gutter,
            child: const _ForestGutter(),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: gutter,
            child: const _ForestGutter(),
          ),
        ],
        Center(
          child: SizedBox(
            width: frameW,
            height: frameH,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _ForestGutter extends StatelessWidget {
  const _ForestGutter();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: const ColoredBox(color: PortraitMenuStage._gutterWash),
      ),
    );
  }
}
