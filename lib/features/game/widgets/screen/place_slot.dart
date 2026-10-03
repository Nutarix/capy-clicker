import 'package:flutter/widgets.dart';

import '../../controllers/game_controller.dart';
import '../../models/multipliers/multipliers.dart';
import '../game_selector.dart';
import '../uyut/cozy_place_marker.dart';

/// One cozy place marker. Rebuilds when it turns on or off, its cooldown
/// starts or ends, or the seconds on it change — not every tick.
class PlaceSlot extends StatelessWidget {
  const PlaceSlot({
    super.key,
    required this.controller,
    required this.kind,
    required this.onTap,
  });

  final GameController controller;
  final CozyPlaceKind kind;
  final VoidCallback onTap;

  /// The marker shows `ceil()` seconds above 0.4 s; below it, nothing.
  (bool, bool, int) _view() {
    final cooling = controller.isPlaceOnCooldown(kind);
    final left = controller.placeCooldownRemaining(kind);
    return (
      controller.activePlaceBoost == kind,
      cooling,
      cooling && left > 0.4 ? left.ceil() : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameSelector<(bool, bool, int)>(
      listenable: controller,
      select: _view,
      builder: (context, view) => CozyPlaceMarker(
        kind: kind,
        active: view.$1,
        onCooldown: view.$2,
        cooldownSeconds: controller.placeCooldownRemaining(kind),
        onTap: onTap,
      ),
    );
  }
}
