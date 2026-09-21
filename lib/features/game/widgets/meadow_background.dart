import 'package:flutter/material.dart';

/// Full-bleed forest meadow background with gameplay layered on top.
class MeadowBackground extends StatelessWidget {
  const MeadowBackground({super.key, required this.child});

  final Widget child;

  static const _asset = 'assets/images/bg_forest.png';
  static const _fallbackSky = Color(0xFFC8E8F0);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _fallbackSky,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFC8E8F0),
                    Color(0xFFB5E0A8),
                    Color(0xFF8FCB6E),
                    Color(0xFF5FA848),
                  ],
                  stops: [0.0, 0.28, 0.62, 1.0],
                ),
              ),
            ),
          ),
          // Soft bottom vignette so entities stay readable on bright meadow.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x14000000),
                ],
                stops: [0.55, 1.0],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
