import 'package:flutter/material.dart';

import '../models/world_zones.dart';

/// Full-bleed forest meadow background with gameplay layered on top.
///
/// The **plate** ([_MeadowPlate]) is isolated: it only rebuilds / crossfades
/// when [meadowId] changes. Flower taps and other [setState]s on the parent
/// must not rebuild or crossfade the image (playtest: gray flash after tap).
class MeadowBackground extends StatelessWidget {
  const MeadowBackground({
    super.key,
    required this.child,
    this.meadowId = WorldZones.starterMeadowId,
  });

  final Widget child;

  /// Active meadow machine id (`warm_edge`, `berry_glade`, `mist_edge`, …).
  final String meadowId;

  static const fallbackSky = Color(0xFFC8E8F0);
  static const cream = Color(0xFFFFF8EC);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MeadowBackground.cream,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Plate lives in its own Element — parent setState does not rebuild it
          // unless [meadowId] changes (ValueKey).
          _MeadowPlate(key: ValueKey<String>(meadowId), meadowId: meadowId),
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

class _MeadowPlate extends StatefulWidget {
  const _MeadowPlate({super.key, required this.meadowId});

  final String meadowId;

  @override
  State<_MeadowPlate> createState() => _MeadowPlateState();
}

class _MeadowPlateState extends State<_MeadowPlate> {
  static const _crossfade = Duration(milliseconds: 400);
  late String _asset;
  String? _prevAsset;

  @override
  void initState() {
    super.initState();
    _asset = WorldZones.backgroundAssetForMeadow(widget.meadowId);
  }

  @override
  void didUpdateWidget(covariant _MeadowPlate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meadowId != widget.meadowId) {
      _prevAsset = _asset;
      _asset = WorldZones.backgroundAssetForMeadow(widget.meadowId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only swap when meadowId (hence asset) actually changes.
    return ColoredBox(
      color: MeadowBackground.fallbackSky,
      child: AnimatedSwitcher(
        duration: _prevAsset == null ? Duration.zero : _crossfade,
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: Image.asset(
          _asset,
          key: ValueKey<String>(_asset),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => Image.asset(
            WorldZones.fallbackBackgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
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
    );
  }
}
