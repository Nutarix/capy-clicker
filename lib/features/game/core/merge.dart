import 'dart:async';

import '../models/balance.dart';
import '../models/capybara.dart';
import '../models/game_state.dart';
import '../models/world_zones.dart';
import 'game_core.dart';

/// Merge: two of a level become one of the next. Flash on the newcomer,
/// twin-sparkle pairs that pay extra grass when merged.
class GameMerge extends GamePart {
  GameMerge(super.core);

  /// Id of the capy that just merged (for flash juice).
  String? mergeFlashId;
  Timer? _mergeFlashTimer;

  /// Seconds until next twin-sparkle reroll attempt.
  double twinRerollIn = BalanceV0.twinRerollSeconds.toDouble();

  /// Drag-merge: same level only → remove both, spawn level+1 at target pos.
  bool tryMerge(String draggedId, String targetId) {
    if (draggedId == targetId) return false;
    final dragged = core.herd.find(draggedId);
    final target = core.herd.find(targetId);
    if (dragged == null || target == null) return false;
    if (dragged.level != target.level) return false;

    final twinBonus = _isTwinPair(draggedId, targetId);
    final newLevel = dragged.level + 1;
    final remaining = state.herd
        .where((c) => c.id != draggedId && c.id != targetId)
        .toList();

    final merged = Capybara(
      id: 'c${state.nextId}',
      level: newLevel,
      position: WorldZones.clampToMeadow(
        target.position,
        herdCount: core.meadows.meadowKey,
      ),
      role: target.role ?? dragged.role,
    );

    var grass = state.grass;
    if (twinBonus) {
      grass += BalanceV0.twinMergeBonusGrass;
    }

    core.commit(
      state.copyWith(
        herd: [...remaining, merged],
        nextId: state.nextId + 1,
        grass: grass,
        clearTwin: twinBonus,
      ),
    );
    _triggerMergeFlash(merged.id);
    if (twinBonus) {
      twinRerollIn = BalanceV0.twinPostMergeCooldownSeconds.toDouble();
    }
    return true;
  }

  void _triggerMergeFlash(String id) {
    mergeFlashId = id;
    _mergeFlashTimer?.cancel();
    _mergeFlashTimer = Timer(BalanceV0.mergeFlashDuration, () {
      mergeFlashId = null;
      core.notify();
    });
    core.notify();
  }

  /// Twin reroll on the game clock. True when the marks changed.
  bool advanceTwins(double dt) {
    twinRerollIn -= dt;
    if (twinRerollIn > 0) return false;
    twinRerollIn = BalanceV0.twinRerollSeconds.toDouble();
    final next = _maybeMarkTwins(state);
    if (next == state) return false;
    core.state = next;
    core.save.schedule();
    return true;
  }

  bool _isTwinPair(String a, String b) {
    final tA = state.twinIdA;
    final tB = state.twinIdB;
    if (tA == null || tB == null) return false;
    return (a == tA && b == tB) || (a == tB && b == tA);
  }

  /// Drop twin marks if either id is missing / levels diverge.
  GameState sanitizeTwins(GameState state) {
    final a = state.twinIdA;
    final b = state.twinIdB;
    if (a == null && b == null) return state;
    final ids = {for (final c in state.herd) c.id};
    if (a == null || b == null || !ids.contains(a) || !ids.contains(b)) {
      return state.copyWith(clearTwin: true);
    }
    final ca = state.herd.firstWhere((c) => c.id == a);
    final cb = state.herd.firstWhere((c) => c.id == b);
    if (ca.level != cb.level) return state.copyWith(clearTwin: true);
    return state;
  }

  /// Pick a random same-level pair for twin sparkle (or clear).
  GameState _maybeMarkTwins(GameState state) {
    final random = core.random;
    if (state.herd.length < BalanceV0.twinMinHerd) {
      return state.copyWith(clearTwin: true);
    }
    final byLevel = <int, List<Capybara>>{};
    for (final c in state.herd) {
      byLevel.putIfAbsent(c.level, () => []).add(c);
    }
    final eligible = byLevel.entries.where((e) => e.value.length >= 2).toList();
    if (eligible.isEmpty) {
      return state.copyWith(clearTwin: true);
    }
    if (state.twinIdA != null && state.twinIdB != null) {
      final ids = {for (final c in state.herd) c.id};
      if (ids.contains(state.twinIdA) && ids.contains(state.twinIdB)) {
        final a = state.herd.firstWhere((c) => c.id == state.twinIdA);
        final b = state.herd.firstWhere((c) => c.id == state.twinIdB);
        if (a.level == b.level &&
            random.nextDouble() < BalanceV0.twinLingerChance) {
          return state; // linger a bit longer
        }
      }
    }
    // Quiet gaps so sparkle stays a skill window, not a permanent glow.
    final markChance =
        (BalanceV0.twinMarkChance + core.rates.twinMarkChanceBonus).clamp(
          0.0,
          0.95,
        );
    if (random.nextDouble() > markChance) {
      return state.copyWith(clearTwin: true);
    }
    final pick = eligible[random.nextInt(eligible.length)].value;
    final shuffled = List<Capybara>.from(pick)..shuffle(random);
    return state.copyWith(twinIdA: shuffled[0].id, twinIdB: shuffled[1].id);
  }

  /// Force a twin mark (tests).
  void debugMarkTwins(String a, String b) {
    core.commit(state.copyWith(twinIdA: a, twinIdB: b));
  }

  void dispose() {
    _mergeFlashTimer?.cancel();
  }
}
