import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

/// Centers the game in a 9:16 phone frame on web/desktop with dark letterboxing.
/// On mobile phones the child fills the screen (SystemChrome portrait lock applies).
class PortraitPhoneFrame extends StatelessWidget {
  const PortraitPhoneFrame({super.key, required this.child});

  final Widget child;

  static const _letterbox = Color(0xFF121212);
  static const _frameBorder = Color(0xFF2A2A2A);

  static bool get useFrame {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!useFrame) return child;

    final size = MediaQuery.sizeOf(context);
    // Playtest P2: use more of the window (was 0.90 height-only → huge bars).
    final maxW = size.width * 0.97;
    final maxH = size.height * 0.97;
    // Largest 9:16 rect that fits in the available box.
    final byHeight = maxH * 9 / 16;
    final byWidth = maxW;
    final frameW = math.min(byWidth, byHeight);
    final frameH = frameW * 16 / 9;

    return ColoredBox(
      color: _letterbox,
      child: Center(
        child: SizedBox(
          width: frameW,
          height: frameH,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _frameBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.5),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
