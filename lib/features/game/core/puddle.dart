import 'dart:async';
import 'dart:math';
import 'dart:ui';

import '../models/balance.dart';
import '../models/capy_wander.dart';
import '../models/capybara.dart';
import '../models/meadow_occupancy.dart';
import '../models/world_zones.dart';
import 'game_core.dart';

/// Temporary mud puddle: comes, stays a while, dries, comes back elsewhere.
/// Drop a capy on it → wallow + mud boost. Position is session-only.
class GamePuddle extends GamePart {
  GamePuddle(super.core);

  bool present = false;
  bool _cooling = false;
  Offset center = const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY);
  double _secondsLeft = 0;

  /// Capy currently playing wallow on the puddle (null = idle puddle).
  String? wallowingCapyId;
  Timer? _wallowTimer;

  /// Puddle anchor whose painted disc does not cover a resting body.
  ///
  /// The widget still steps anyone off if the live meadow size differs from
  /// the fallback used here. Gameplay hit circle stays [BalanceV0.mudHitRadius].
  Offset pickCenter(int herdCount, {List<Capybara>? herd}) {
    final family = herd ?? state.herd;
    final bodies = [for (final c in family) c.position];
    final widths = [
      for (final c in family) BalanceV0.capySizeForLevel(c.level),
    ];
    Offset? fallback;
    final meadow = CapyWander.fallbackMeadow;
    for (var i = 0; i < 24; i++) {
      final p = BalanceV0.randomMudCenter(
        core.random.nextDouble,
        herdCount: herdCount,
      );
      fallback ??= p;
      if (MeadowOccupancy.puddleClears(
        p,
        meadow,
        herdCount: herdCount,
        capyAnchors: bodies,
        capyWidths: widths,
        tentUnlocked: state.tentUnlocked,
      )) {
        return p;
      }
    }
    return fallback ??
        BalanceV0.randomMudCenter(core.random.nextDouble, herdCount: herdCount);
  }

  void beginPresence() {
    present = true;
    _cooling = false;
    center = pickCenter(core.meadows.meadowKey);
    var extra = 0.0;
    if (state.hasResearch('longer_mud')) {
      extra = BalanceV0.researchMudExtra.inSeconds.toDouble();
    }
    final span =
        BalanceV0.mudVisibleMaxSeconds - BalanceV0.mudVisibleMinSeconds;
    _secondsLeft =
        BalanceV0.mudVisibleMinSeconds +
        core.random.nextDouble() * span +
        extra;
    core.messages.puddleAppeared();
  }

  void _beginCooldown() {
    present = false;
    _cooling = true;
    // Drop the point so nothing about the last spot is kept.
    center = Offset.zero;
    final span =
        BalanceV0.mudCooldownMaxSeconds - BalanceV0.mudCooldownMinSeconds;
    _secondsLeft =
        BalanceV0.mudCooldownMinSeconds + core.random.nextDouble() * span;
  }

  /// Advance the spawn / despawn clock by [dt] seconds. Caller notifies.
  void advance(double dt) {
    if (!present && !_cooling) {
      beginPresence();
      return;
    }
    _secondsLeft -= dt;
    if (_secondsLeft > 0) return;
    if (present) {
      _beginCooldown();
    } else {
      beginPresence();
    }
  }

  /// Tests: plant a puddle with a known center and lifetime.
  void debugPlace(Offset at, {double seconds = 3}) {
    present = true;
    _cooling = false;
    center = at;
    _secondsLeft = seconds;
    core.messages.acknowledgePuddle();
    core.notify();
  }

  /// Drop a capybara onto the mud puddle → wallow anim + temporary boost.
  bool tryWallow(String capyId) {
    if (!present) return false;
    final capy = core.herd.find(capyId);
    if (capy == null) return false;

    // Snap capy onto the live puddle (it may not be the old fixed corner).
    core.herd.updatePosition(
      capyId,
      WorldZones.clampToMeadow(center, herdCount: core.meadows.meadowKey),
    );

    wallowingCapyId = capyId;
    _wallowTimer?.cancel();
    _wallowTimer = Timer(BalanceV0.mudWallowAnimDuration, () {
      wallowingCapyId = null;
      core.notify();
    });

    core.boosts.startMud();
    core.notify();
    return true;
  }

  /// True if [normalized] is inside the mud puddle hit circle.
  bool isOverMud(Offset normalized) {
    if (!present) return false;
    final dx = normalized.dx - center.dx;
    final dy = normalized.dy - center.dy;
    return sqrt(dx * dx + dy * dy) <= BalanceV0.mudHitRadius;
  }

  /// Meadow switch: the wallow stops, a live puddle moves clear of [herd].
  void onMeadowSwitch(List<Capybara> herd) {
    _wallowTimer?.cancel();
    wallowingCapyId = null;
    if (present) {
      center = pickCenter(core.meadows.meadowKey, herd: herd);
    }
  }

  void dispose() {
    _wallowTimer?.cancel();
  }
}
