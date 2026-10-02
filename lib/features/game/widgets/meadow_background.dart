import 'package:flutter/material.dart';

import '../models/world_zones.dart';

/// Full-bleed forest meadow background with gameplay layered on top.
///
/// The plate widget instance is cached until [meadowId] changes. Flower taps
/// rebuild this parent, but returning the same child instance means the
/// [Image] element is not updated and cannot flash a decode/placeholder frame.
/// A [RepaintBoundary] keeps that layer off the tap invalidation.
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
          _MeadowPlate(key: ValueKey<String>(meadowId), meadowId: meadowId),
          const RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x14000000)],
                  stops: [0.55, 1.0],
                ),
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
  Widget? _cached;
  String? _cachedId;

  Widget _buildPlate(String meadowId) {
    final asset = WorldZones.backgroundAssetForMeadow(meadowId);
    return RepaintBoundary(
      child: ColoredBox(
        color: MeadowBackground.cream,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync || frame != null) return child;
            // Cream, never a gray/empty engine clear, while the first decode lands.
            return const ColoredBox(color: MeadowBackground.cream);
          },
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
                    Color(0xFFFFF8EC),
                    Color(0xFFC8E8F0),
                    Color(0xFFB5E0A8),
                    Color(0xFF8FCB6E),
                    Color(0xFF5FA848),
                  ],
                  stops: [0.0, 0.18, 0.40, 0.70, 1.0],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cached == null || _cachedId != widget.meadowId) {
      _cachedId = widget.meadowId;
      _cached = _buildPlate(widget.meadowId);
    }
    // Same instance → Element.updateChild skips the image. Taps do not rebuild it.
    return _cached!;
  }
}
