import 'dart:async';

import '../models/balance.dart';
import 'game_core.dart';

/// The game clock: live tick, one shared step for tick and tests, auto
/// grass, offline grant, pause in background.
class GameClock extends GamePart {
  GameClock(super.core);

  Timer? _tickTimer;
  DateTime lastTick = DateTime.now();

  /// When the app went to background; null while on screen.
  DateTime? suspendedAt;

  /// Fractional auto-grass accumulator (grants integers when ≥ 1).
  double _grassAcc = 0;

  bool get isSuspended => suspendedAt != null;

  void startTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
    if (core.autoTick) {
      _tickTimer = Timer.periodic(const Duration(milliseconds: 50), _onTick);
    }
  }

  /// App hidden (swiped away, tab hidden, window minimized): stop the game
  /// clock and write the save with this moment as «left at».
  Future<void> suspend() async {
    if (core.disposed || suspendedAt != null) return;
    _tickTimer?.cancel();
    _tickTimer = null;
    suspendedAt = core.now();
    await core.save.flush();
  }

  /// App back on screen: offline grant by the cold-start rules, then the
  /// live clock resumes from now (no catch-up jump).
  void resumeFromBackground() {
    final since = suspendedAt;
    if (since == null || core.disposed) return;
    suspendedAt = null;
    // Shown again before load finished: init starts the clock itself.
    if (!core.ready) return;
    // As on a relaunch: glades / goals the grant reaches open quietly, with
    // no toasts or celebration grass (those check ready).
    core.ready = false;
    applyOfflineProgress(since);
    core.ready = true;
    lastTick = core.now();
    startTicker();
    core.notify();
  }

  /// Capped auto progress for the time away since [since] (cold start uses
  /// the save's `savedAtMs`, a return from background — the hide moment).
  void applyOfflineProgress(DateTime since) {
    final elapsed = core.now().difference(since);
    var seconds = elapsed.inSeconds;
    if (seconds < BalanceV0.offlineMinSeconds) return;
    if (seconds > BalanceV0.offlineCapSeconds) {
      seconds = BalanceV0.offlineCapSeconds;
    }
    final rates = core.rates;
    var offlineMult =
        rates.uyutMultiplier *
        rates.decorAutoMultiplier *
        rates.roleAutoMultiplier;
    // Tent is session-only; offline leans on research tent unlock + decor.
    if (state.tentUnlocked) {
      offlineMult *= BalanceV0.tentOfflineMult;
    }
    final amount = BalanceV0.autoProgressPerSecond * offlineMult * seconds;
    core.messages.offlineGranted(amount, seconds);
    // Apply without live-tick dt guards; may spawn under herd cap.
    core.herd.addProgress(amount, fromTap: false);
  }

  void _onTick(Timer _) {
    final now = core.now();
    final dt = now.difference(lastTick).inMilliseconds / 1000.0;
    lastTick = now;
    if (dt <= 0 || dt > 1.0) return;
    advance(dt, now);
  }

  /// One step of the game clock: mud, boosts, auto grass, twins, auto bar.
  /// Shared by the live tick and [debugAdvance], so tests run the real thing.
  void advance(double dt, DateTime now) {
    var dirty = false;
    final puddle = core.puddle;
    final messages = core.messages;
    final mudBefore = puddle.present;
    final mudCenterBefore = puddle.center;
    final toastBefore = messages.puddleToast;
    puddle.advance(dt);
    if (puddle.present != mudBefore ||
        puddle.center != mudCenterBefore ||
        messages.puddleToast != toastBefore) {
      dirty = true;
    }

    // Clear expired boosts.
    if (core.boosts.expire(now)) dirty = true;

    // Auto grass accrual (decor + Уют + warm stone).
    _grassAcc +=
        BalanceV0.autoGrassPerSecond * core.rates.grassAutoMultiplier * dt;
    if (_grassAcc >= 1.0) {
      final granted = _grassAcc.floor();
      _grassAcc -= granted;
      core.state = state.copyWith(grass: state.grass + granted);
      dirty = true;
    }

    // Twin sparkle reroll.
    if (core.merge.advanceTwins(dt)) dirty = true;

    if (dirty) core.notify();

    core.herd.addProgress(core.rates.autoRatePerSecond * dt, fromTap: false);
  }

  /// Headless tick for progression sims: the live tick body, any [dt].
  void debugAdvance(double dt) {
    if (dt <= 0) return;
    if (dt > 1.0) {
      // Split long steps so spawn/boost logic stays stable.
      var left = dt;
      while (left > 0) {
        final step = left > 1.0 ? 1.0 : left;
        debugAdvance(step);
        left -= step;
      }
      return;
    }
    advance(dt, core.now());
  }

  void dispose() {
    _tickTimer?.cancel();
  }
}
