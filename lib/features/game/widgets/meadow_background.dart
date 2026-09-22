import 'package:flutter/material.dart';

import '../models/world_zones.dart';

/// Full-bleed forest meadow background with gameplay layered on top.
///
/// Picks a unique portrait plate from [meadowId] (Sunny Glades + mist biome).
/// Crossfades ~400 ms when the plate changes. Legacy [bg_forest] is fallback
/// only (unknown id / load error).
class MeadowBackground extends StatefulWidget {
  const MeadowBackground({
    super.key,
    required this.child,
    this.meadowId = WorldZones.starterMeadowId,
  });

  final Widget child;

  /// Active meadow machine id (`warm_edge`, `berry_glade`, `mist_edge`, …).
  final String meadowId;

  static const _fallbackSky = Color(0xFFC8E8F0);
  static const _crossfade = Duration(milliseconds: 400);

  @override
  State<MeadowBackground> createState() => _MeadowBackgroundState();
}

class _MeadowBackgroundState extends State<MeadowBackground> {
  late String _asset;

  @override
  void initState() {
    super.initState();
    _asset = WorldZones.backgroundAssetForMeadow(widget.meadowId);
  }

  @override
  void didUpdateWidget(covariant MeadowBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meadowId != widget.meadowId) {
      setState(() {
        _asset = WorldZones.backgroundAssetForMeadow(widget.meadowId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MeadowBackground._fallbackSky,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: MeadowBackground._crossfade,
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: Image.asset(
              _asset,
              key: ValueKey<String>(_asset),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Image.asset(
                WorldZones.fallbackBackgroundAsset,
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
          widget.child,
        ],
      ),
    );
  }
}
