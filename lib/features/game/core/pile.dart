import 'dart:async';
import 'dart:ui';

import '../models/balance.dart';
import '../models/capy_pile.dart';
import '../models/capy_wander.dart';
import '../models/capybara.dart';
import '../models/game_state.dart';
import '../models/world_zones.dart';
import 'game_core.dart';

/// The pile (spec 006): drop a capy on a capy and they sit together; in a
/// pile the young catch up with the eldest and three peers grow up. Flash on
/// a seat and on growth; the «хотят посидеть рядом» pair (former twins).
class GamePile extends GamePart {
  GamePile(super.core);

  /// Capy that just sat down or grew (flash juice).
  String? flashId;
  Timer? _flashTimer;

  /// Seconds until next pair reroll attempt.
  double twinRerollIn = BalanceV0.twinRerollSeconds.toDouble();

  /// Places taken on the active meadow (single = 1, pile = 1).
  int get placesUsed => CapyPiles.placesOf(state.herd);

  /// Members of [pileId] on the active meadow.
  List<Capybara> membersOf(String pileId) =>
      CapyPiles.membersOf(state.herd, pileId);

  // --- Seat ---

  /// [draggedId] sits down with [targetId] (on its own or in its pile).
  ///
  /// False: nothing to do (same capy, same pile, missing), or the target's
  /// pile is full — then the dragged capy stands beside it on the grass,
  /// quietly (С4).
  bool join(String draggedId, String targetId) {
    if (draggedId == targetId) return false;
    final dragged = core.herd.find(draggedId);
    final target = core.herd.find(targetId);
    if (dragged == null || target == null) return false;
    final targetPile = target.pileId;
    if (targetPile != null && dragged.pileId == targetPile) return false;
    final members = targetPile == null
        ? [target]
        : CapyPiles.membersOf(state.herd, targetPile);

    if (members.length >= BalanceV0.pileMaxSize) {
      final beside = besidePile(target.position, members);
      final herd = CapyPiles.sanitize([
        for (final c in state.herd)
          if (c.id == draggedId)
            c.copyWith(position: beside, clearPile: true)
          else
            c,
      ]);
      core.commit(state.copyWith(herd: herd));
      return false;
    }

    var nextId = state.nextId;
    final pileId = targetPile ?? 'p${nextId++}';
    final herd = CapyPiles.sanitize([
      for (final c in state.herd)
        if (c.id == draggedId)
          c.copyWith(pileId: pileId, position: target.position)
        else if (c.id == targetId && targetPile == null)
          c.copyWith(pileId: pileId)
        else
          c,
    ]);

    // «Хотят посидеть рядом»: the pair in one pile pays like a twin merge.
    final pair = _pairTogether(herd);
    core.commit(
      state.copyWith(
        herd: herd,
        nextId: nextId,
        grass: state.grass + (pair ? BalanceV0.pairBonusGrass : 0),
        clearTwin: pair,
      ),
    );
    if (pair) {
      twinRerollIn = BalanceV0.pairPostBonusCooldownSeconds.toDouble();
    }
    // A pile in the puddle: one shared bath, the boost as from one (С8).
    if (core.puddle.isWallowing(targetId)) core.puddle.joinBath(draggedId);
    _flash(draggedId);
    return true;
  }

  /// Grass next to a pile at [at] (normalized), toward the meadow middle.
  Offset besidePile(Offset at, List<Capybara> members) {
    var widest = 0.0;
    for (final m in members) {
      final w = BalanceV0.capySizeForLevel(m.level);
      if (w > widest) widest = w;
    }
    final key = core.meadows.meadowKey;
    final rect = WorldZones.meadowRectForHerd(key);
    final dx = widest * 1.25 / CapyWander.fallbackMeadow.width;
    final toRight = at.dx < (rect.left + rect.right) / 2;
    final p = Offset(at.dx + (toRight ? dx : -dx), at.dy + 0.02);
    return WorldZones.clampToMeadow(p, herdCount: key);
  }

  bool _pairTogether(List<Capybara> herd) {
    final a = state.twinIdA;
    final b = state.twinIdB;
    if (a == null || b == null) return false;
    String? pa;
    String? pb;
    for (final c in herd) {
      if (c.id == a) pa = c.pileId;
      if (c.id == b) pb = c.pileId;
    }
    return pa != null && pa == pb;
  }

  void _flash(String id) {
    flashId = id;
    _flashTimer?.cancel();
    _flashTimer = Timer(BalanceV0.pileFlashDuration, () {
      flashId = null;
      core.notify();
    });
    core.notify();
  }

  /// Chain link: piles of one dissolve (same state when nothing to do).
  GameState sanitize(GameState state) {
    final herd = CapyPiles.sanitize(state.herd);
    if (identical(herd, state.herd)) return state;
    return state.copyWith(herd: herd);
  }

  // --- Growth ---

  /// [dt] seconds of the game clock for the piles of the active meadow.
  void advance(double dt) {
    final herd = state.herd;
    final r = CapyPiles.grow(herd, dt);
    if (identical(r.herd, herd)) return;
    if (r.grown.isEmpty) {
      // Only growth moved: nothing on screen, no chain link reads it.
      core.commitQuiet(state.copyWith(herd: r.herd));
      return;
    }
    _landGrowth(r.herd, r.grown);
  }

  /// Time away (С9): the seconds the auto progress got, by the same rules,
  /// in one-second steps (one level at a time stays true).
  void advanceOffline(int seconds) {
    var herd = state.herd;
    if (CapyPiles.groups(herd).isEmpty) return;
    final grown = <String>[];
    for (var i = 0; i < seconds; i++) {
      final r = CapyPiles.grow(herd, 1.0);
      herd = r.herd;
      grown.addAll(r.grown);
    }
    if (identical(herd, state.herd)) return;
    if (grown.isEmpty) {
      core.commit(state.copyWith(herd: herd));
      return;
    }
    _landGrowth(herd, grown);
  }

  /// Level-ups land: names at level two, flash, «подрос» sound event.
  void _landGrowth(List<Capybara> herd, List<String> grown) {
    var next = state.copyWith(herd: herd);
    final named = core.names.nameGrown(next, grown.toSet());
    if (named != null) next = named;
    core.commit(next);
    final last = grown.last;
    final capy = core.herd.find(last);
    core.messages.capyGrew(last, capy?.level ?? 0);
    _flash(last);
  }

  // --- The pair «хотят посидеть рядом» (former twins) ---

  /// Pair reroll on the game clock. True when the marks changed.
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

  /// Drop pair marks if either id is missing or the two already sit together.
  GameState sanitizeTwins(GameState state) {
    final a = state.twinIdA;
    final b = state.twinIdB;
    if (a == null && b == null) return state;
    if (a == null || b == null) return state.copyWith(clearTwin: true);
    Capybara? ca;
    Capybara? cb;
    for (final c in state.herd) {
      if (c.id == a) ca = c;
      if (c.id == b) cb = c;
    }
    if (ca == null || cb == null) return state.copyWith(clearTwin: true);
    if (ca.pileId != null && ca.pileId == cb.pileId) {
      return state.copyWith(clearTwin: true);
    }
    return state;
  }

  static bool _apart(Capybara a, Capybara b) =>
      a.pileId == null || a.pileId != b.pileId;

  /// Pick a random same-level pair that does not sit together yet (or clear).
  GameState _maybeMarkTwins(GameState state) {
    final random = core.random;
    if (state.herd.length < BalanceV0.twinMinHerd) {
      return state.copyWith(clearTwin: true);
    }
    final byLevel = <int, List<Capybara>>{};
    for (final c in state.herd) {
      byLevel.putIfAbsent(c.level, () => []).add(c);
    }
    bool hasPair(List<Capybara> list) {
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          if (_apart(list[i], list[j])) return true;
        }
      }
      return false;
    }

    final eligible = byLevel.entries.where((e) => hasPair(e.value)).toList();
    if (eligible.isEmpty) {
      return state.copyWith(clearTwin: true);
    }
    if (state.twinIdA != null && state.twinIdB != null) {
      Capybara? a;
      Capybara? b;
      for (final c in state.herd) {
        if (c.id == state.twinIdA) a = c;
        if (c.id == state.twinIdB) b = c;
      }
      if (a != null &&
          b != null &&
          a.level == b.level &&
          _apart(a, b) &&
          random.nextDouble() < BalanceV0.twinLingerChance) {
        return state; // linger a bit longer
      }
    }
    // Quiet gaps so the pair stays a skill window, not a permanent glow.
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
    final first = shuffled[0];
    final second = shuffled.skip(1).firstWhere((c) => _apart(first, c),
        orElse: () => shuffled[1]);
    if (!_apart(first, second)) {
      // Rare: the first pick sits with every peer; pair two who don't.
      for (var i = 0; i < shuffled.length; i++) {
        for (var j = i + 1; j < shuffled.length; j++) {
          if (_apart(shuffled[i], shuffled[j])) {
            return state.copyWith(
              twinIdA: shuffled[i].id,
              twinIdB: shuffled[j].id,
            );
          }
        }
      }
    }
    return state.copyWith(twinIdA: first.id, twinIdB: second.id);
  }

  /// Force a pair mark (tests).
  void debugMarkTwins(String a, String b) {
    core.commit(state.copyWith(twinIdA: a, twinIdB: b));
  }

  void dispose() {
    _flashTimer?.cancel();
  }
}
