import 'dart:math';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

/// Still instant for controller tests: no real clock, no midnight.
final DateTime testNow = DateTime(2026, 9, 21, 12);

/// Controller for unit tests: seeded randomness, still clock, no live tick.
///
/// Drive the game clock with [GameController.debugAdvance]. Tests of the live
/// tick build their own controller under fake time (see game_tick_test.dart).
GameController testController({
  GamePersistence? persistence,
  Random? random,
  int seed = 1,
  DateTime Function()? now,
  bool debugNames = true,
}) {
  return GameController(
    persistence: persistence ?? GamePersistence(),
    random: random ?? Random(seed),
    now: now ?? () => testNow,
    autoTick: false,
    debugNames: debugNames,
  );
}
