import 'package:flutter/material.dart';

import '../../../theme/cozy_theme.dart';
import '../models/multipliers/home_decor.dart';

/// One fixed place in the cozy meadow picture (15 → 16 → 17).
class HomeSlot {
  const HomeSlot({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  /// Center, 0–1 of the scene.
  final double x;
  final double y;

  /// Size as a fraction of the scene width / height.
  final double w;
  final double h;
}

/// Fixed places. Empty slots stay grass. Order is the picture, not a list.
abstract final class HomeMeadowLayout {
  static const slots = <HomeDecor, HomeSlot>{
    HomeDecor.girlyanda: HomeSlot(x: 0.50, y: 0.18, w: 0.78, h: 0.16),
    HomeDecor.fonarik: HomeSlot(x: 0.12, y: 0.52, w: 0.16, h: 0.20),
    HomeDecor.vazon: HomeSlot(x: 0.30, y: 0.56, w: 0.15, h: 0.18),
    HomeDecor.skvorechnik: HomeSlot(x: 0.86, y: 0.50, w: 0.16, h: 0.16),
    HomeDecor.lampa: HomeSlot(x: 0.64, y: 0.64, w: 0.14, h: 0.16),
    HomeDecor.kovrik: HomeSlot(x: 0.48, y: 0.76, w: 0.40, h: 0.18),
    HomeDecor.podushka: HomeSlot(x: 0.48, y: 0.72, w: 0.16, h: 0.12),
    HomeDecor.kormushka: HomeSlot(x: 0.16, y: 0.82, w: 0.24, h: 0.13),
  };

  static HomeSlot slotOf(HomeDecor decor) => slots[decor]!;
}

/// The home picture: placed sprites, and the next buys sitting in their places.
class HomeMeadowScene extends StatelessWidget {
  const HomeMeadowScene({
    super.key,
    required this.placedIds,
    this.offerIds = const {},
    this.buyDecor,
    this.canBuy,
    this.labelPlaced = false,
  });

  final Set<String> placedIds;

  /// Unowned items whose buy button sits in the slot (research already open).
  final Set<String> offerIds;
  final void Function(HomeDecor decor)? buyDecor;
  final bool Function(HomeDecor decor)? canBuy;
  final bool labelPlaced;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final decor in HomeDecor.values)
              if (placedIds.contains(decor.id))
                _at(
                  HomeMeadowLayout.slotOf(decor),
                  w,
                  h,
                  Column(
                    children: [
                      Expanded(
                        child: Image.asset(
                          decor.assetPath,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                      if (labelPlaced)
                        Text(
                          decor.labelRu,
                          maxLines: 1,
                          style: CozyTheme.hudChipStyle(fontSize: 10),
                        ),
                    ],
                  ),
                )
              else if (offerIds.contains(decor.id) && buyDecor != null)
                _at(
                  HomeMeadowLayout.slotOf(decor),
                  w,
                  h,
                  _BuyPill(
                    decor: decor,
                    enabled: canBuy?.call(decor) ?? false,
                    onTap: () => buyDecor!(decor),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _at(HomeSlot slot, double w, double h, Widget child) {
    final width = slot.w * w;
    final height = slot.h * h;
    return Positioned(
      left: slot.x * w - width / 2,
      top: slot.y * h - height / 2,
      width: width,
      height: height,
      child: child,
    );
  }
}

class _BuyPill extends StatelessWidget {
  const _BuyPill({
    required this.decor,
    required this.enabled,
    required this.onTap,
  });

  final HomeDecor decor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spark = decor.uyutCost > 0;
    return Align(
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EC)
                  .withValues(alpha: enabled ? 0.94 : 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8A6A45), width: 1.4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      decor.assetPath,
                      width: 22,
                      height: 22,
                      filterQuality: FilterQuality.none,
                    ),
                    Text(
                      decor.labelRu,
                      maxLines: 1,
                      softWrap: false,
                      style: CozyTheme.hudChipStyle(fontSize: 11),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/ui/icon_grass.png',
                          width: 12,
                          height: 12,
                          filterQuality: FilterQuality.none,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${decor.grassCost}',
                          style: CozyTheme.hudChipStyle(fontSize: 11),
                        ),
                        if (spark) ...[
                          const SizedBox(width: 4),
                          Image.asset(
                            'assets/images/ui/icon_spark.png',
                            width: 12,
                            height: 12,
                            filterQuality: FilterQuality.none,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${decor.uyutCost}',
                            style: CozyTheme.hudChipStyle(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
