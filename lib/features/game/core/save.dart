import 'dart:async';

import '../models/balance.dart';
import '../models/game_state.dart';
import 'game_core.dart';

/// Writes: every [BalanceV0.persistIntervalMs] during play, now on demand.
class GameSave extends GamePart {
  GameSave(super.core);

  Timer? _persistTimer;

  GameState withSavedAt(GameState state) =>
      state.copyWith(savedAtMs: core.now().millisecondsSinceEpoch);

  /// Write soon. Ticks change the state every 50 ms, so the pending write is
  /// never pushed back — otherwise live play would never be saved.
  void schedule() {
    if (_persistTimer?.isActive ?? false) return;
    _persistTimer = Timer(
      const Duration(milliseconds: BalanceV0.persistIntervalMs),
      () => core.persistence.save(withSavedAt(core.state)),
    );
  }

  /// Write now instead of on the next [BalanceV0.persistIntervalMs].
  /// Nothing before load finished or after dispose.
  Future<void> flush() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (!core.ready || core.disposed) return;
    await core.persistence.save(withSavedAt(core.state));
  }

  void dispose() {
    _persistTimer?.cancel();
  }
}
