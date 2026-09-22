import 'package:flutter/material.dart';

import '../models/multipliers/home_decor.dart';

/// Soft meadow sprites for [HomeDecor] items the player has placed.
/// Glowing props pulse; others get a tiny idle sway.
class PlacedHomeDecorLayer extends StatelessWidget {
  const PlacedHomeDecorLayer({
    super.key,
    required this.placedIds,
    required this.meadowSize,
  });

  final Set<String> placedIds;
  final Size meadowSize;

  @override
  Widget build(BuildContext context) {
    final w = meadowSize.width;
    final h = meadowSize.height;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final decor in HomeDecor.values)
          if (placedIds.contains(decor.id))
            Positioned(
              left: decor.meadowSlot.$1 * w - 22,
              top: decor.meadowSlot.$2 * h - 22,
              child: _PlacedDecorSprite(decor: decor),
            ),
      ],
    );
  }
}

class _PlacedDecorSprite extends StatefulWidget {
  const _PlacedDecorSprite({required this.decor});

  final HomeDecor decor;

  @override
  State<_PlacedDecorSprite> createState() => _PlacedDecorSpriteState();
}

class _PlacedDecorSpriteState extends State<_PlacedDecorSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  bool get _glows => switch (widget.decor) {
        HomeDecor.fonarik || HomeDecor.girlyanda || HomeDecor.lampa => true,
        _ => false,
      };

  @override
  void initState() {
    super.initState();
    final phase = widget.decor.index / HomeDecor.values.length;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _glows ? 1500 : 2400),
    );
    _ctrl.value = phase;
    _ctrl.repeat(reverse: true);
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
      builder: (context, _) {
        final t = _ctrl.value;
        final glow = _glows ? (0.22 + t * 0.38) : 0.0;
        final sway = _glows ? 0.0 : (t - 0.5) * 0.08;
        final bob = _glows ? 0.0 : (t - 0.5) * 2.5;
        final opacity = _glows ? (0.82 + t * 0.18) : 1.0;

        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: sway,
            child: Opacity(
              opacity: opacity,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_glows)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFE082)
                                  .withValues(alpha: glow),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    Image.asset(
                      widget.decor.assetPath,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension HomeDecorMeadowSlot on HomeDecor {
  /// Fixed normalized slots inside the starter glade (always visible).
  (double x, double y) get meadowSlot => switch (this) {
        HomeDecor.fonarik => (0.14, 0.56),
        HomeDecor.kovrik => (0.48, 0.90),
        HomeDecor.vazon => (0.72, 0.58),
        HomeDecor.girlyanda => (0.58, 0.54),
        HomeDecor.skvorechnik => (0.30, 0.56),
        HomeDecor.podushka => (0.40, 0.86),
        HomeDecor.lampa => (0.84, 0.60),
        HomeDecor.kormushka => (0.20, 0.88),
      };
}
