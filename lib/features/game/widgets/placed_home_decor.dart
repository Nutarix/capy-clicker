import 'package:flutter/material.dart';

import 'home_meadow_scene.dart';

/// Placed home decor on the live meadow. Empty places stay grass.
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
    return SizedBox(
      width: meadowSize.width,
      height: meadowSize.height,
      child: HomeMeadowScene(placedIds: placedIds),
    );
  }
}
