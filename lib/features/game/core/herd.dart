import 'dart:math';
import 'dart:ui';

import '../models/balance.dart';
import '../models/capy_wander.dart';
import '../models/capybara.dart';
import '../models/game_state.dart';
import '../models/world_zones.dart';
import 'game_core.dart';

/// The family on the active meadow: the progress bar and who it brings,
/// where newcomers sit, positions, starter families, camera.
class GameHerd extends GamePart {
  GameHerd(super.core);

  Capybara? find(String id) {
    for (final c in state.herd) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Add progress; may spawn while under herd cap. Overflow carries over.
  void addProgress(double amount, {required bool fromTap}) {
    if (amount <= 0) return;

    final cap = core.rates;
    var progress = state.herdProgress + amount;
    // Lists are never changed in place: no copy, so an unchanged family
    // keeps its list (screen parts compare it by identity).
    var herd = state.herd;
    var nextId = state.nextId;
    var next = state;
    var spawned = false;

    while (progress >= BalanceV0.spawnThreshold &&
        herd.length < cap.effectiveMaxHerdSize) {
      spawned = true;
      progress -= BalanceV0.spawnThreshold;
      next = spawnCapybara(
        next.copyWith(herd: herd, nextId: nextId, herdProgress: progress),
        level: BalanceV0.startingLevel,
      );
      herd = List<Capybara>.from(next.herd);
      nextId = next.nextId;
    }

    if (herd.length >= cap.effectiveMaxHerdSize) {
      progress = progress.clamp(0.0, BalanceV0.spawnThreshold);
    }

    // Only the bar moved: skip the check chain (spec 002, Т3).
    if (!spawned && core.checked) {
      core.commitProgress(progress);
      return;
    }
    core.commit(
      next.copyWith(herdProgress: progress, herd: herd, nextId: nextId),
    );
  }

  GameState bootstrap() {
    var state = GameState.initial();
    for (var i = 0; i < BalanceV0.startingHerdSize; i++) {
      state = spawnCapybara(state, level: BalanceV0.startingLevel);
    }
    return state;
  }

  GameState spawnCapybara(GameState state, {required int level}) {
    final pos = _pickSpawnPosition(state.herd);
    final capy = Capybara(id: 'c${state.nextId}', level: level, position: pos);
    return state.copyWith(
      herd: [...state.herd, capy],
      nextId: state.nextId + 1,
    );
  }

  Offset _pickSpawnPosition(List<Capybara> existing) {
    // Meadow expands with herd after spawn; never below unlocked glade.
    final herdCount = core.meadows.meadowKey;
    final others = [for (final c in existing) c.position];
    final rect = WorldZones.meadowRectForHerd(herdCount);
    final from = others.isEmpty
        ? Offset((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2)
        : others.last;
    // Placement uses its own stream so a longer search does not reshuffle
    // taps, twins, and the cozy-session balance sims.
    final placeRng = Random(0x51EED + existing.length * 97 + herdCount);
    final puddle = core.puddle;
    return CapyWander.pickTarget(
      from: from,
      random01: placeRng.nextDouble,
      herdCount: herdCount,
      others: others,
      mudCenter: puddle.present ? puddle.center : null,
      meadowSize: CapyWander.fallbackMeadow,
      minDist: BalanceV0.minSpawnSeparation * 0.5,
      spreadSalt: (existing.length * 0.173) % 1.0,
    );
  }

  void updatePosition(String id, Offset normalized) {
    final clamped = WorldZones.clampToMeadow(
      normalized,
      herdCount: core.meadows.meadowKey,
    );
    final herd = state.herd.map((c) {
      if (c.id != id) return c;
      return c.copyWith(position: clamped);
    }).toList();
    core.commit(state.copyWith(herd: herd));
  }

  /// Re-seat positions onto the active named meadow rect (trees stay blocked).
  /// Nobody moved: the same list and the same capys come back.
  GameState clampHerdToMeadow(GameState state) {
    final key = WorldZones.gladeById(state.activeMeadowId).minHerd;
    List<Capybara>? moved;
    for (var i = 0; i < state.herd.length; i++) {
      final c = state.herd[i];
      final p = WorldZones.clampToMeadow(c.position, herdCount: key);
      if (moved == null && p == c.position) continue;
      moved ??= state.herd.sublist(0, i);
      moved.add(p == c.position ? c : c.copyWith(position: p));
    }
    return state.copyWith(herd: moved ?? state.herd);
  }

  ({List<Capybara> herd, int nextId}) buildStarterHerd({
    required String meadowId,
    required int startNextId,
    required int count,
  }) {
    final key = WorldZones.gladeById(meadowId).minHerd;
    var nextId = startNextId;
    final herd = <Capybara>[];
    final rect = WorldZones.meadowRectForHerd(key);
    for (var i = 0; i < count; i++) {
      final from = herd.isEmpty
          ? Offset((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2)
          : herd.last.position;
      final placeRng = Random(0x57A27 + nextId * 13 + i);
      final pos = CapyWander.pickTarget(
        from: from,
        random01: placeRng.nextDouble,
        herdCount: key,
        others: [for (final c in herd) c.position],
        meadowSize: CapyWander.fallbackMeadow,
        minDist: BalanceV0.minSpawnSeparation * 0.5,
        spreadSalt: (i * 0.173) % 1.0,
      );
      herd.add(
        Capybara(id: 'c$nextId', level: BalanceV0.startingLevel, position: pos),
      );
      nextId++;
    }
    return (herd: herd, nextId: nextId);
  }

  double get cameraZoom => BalanceV0.cameraZoomForHerd(
    core.meadows.meadowKey,
    state.herd.map((c) => c.position),
  );
}
