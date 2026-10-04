import 'dart:async';
import 'dart:math';

import '../models/balance.dart';
import '../models/game_state.dart';
import '../models/world_zones.dart';
import '../persistence/game_persistence.dart';
import 'boosts.dart';
import 'clock.dart';
import 'family_roles.dart';
import 'finds.dart';
import 'goals.dart';
import 'herd.dart';
import 'lands.dart';
import 'meadows.dart';
import 'merge.dart';
import 'messages.dart';
import 'names.dart';
import 'puddle.dart';
import 'rates.dart';
import 'save.dart';
import 'shop.dart';

/// One slice of the game rules. Reads [GameState] and commits it via [core].
abstract class GamePart {
  GamePart(this.core);

  final GameCore core;

  GameState get state => core.state;
}

/// Shared heart of [GameController]: the state, the clock and the seed, and
/// the check chain every change runs through. Parts hang off it.
class GameCore {
  GameCore({
    required this.persistence,
    required this.random,
    required this.lootRandom,
    required this.now,
    required this.autoTick,
    required this._onNotify,
    this.namesEnabled = true,
  });

  final GamePersistence persistence;
  final Random random;

  /// Separate stream so food/loot drops do not desync core progression RNG.
  final Random lootRandom;
  final DateTime Function() now;

  /// False: no periodic tick — tests drive the game clock via debugAdvance.
  final bool autoTick;

  final void Function() _onNotify;

  /// False: no names or traits are given (spec 004, Т12 test: the same
  /// session with and without names draws the same numbers).
  final bool namesEnabled;

  late final GameClock clock = GameClock(this);
  late final GameSave save = GameSave(this);
  late final GameRates rates = GameRates(this);
  late final GameBoosts boosts = GameBoosts(this);
  late final GamePuddle puddle = GamePuddle(this);
  late final GameFinds finds = GameFinds(this);
  late final GameHerd herd = GameHerd(this);
  late final GameMerge merge = GameMerge(this);
  late final GameMeadows meadows = GameMeadows(this);
  late final GameShop shop = GameShop(this);
  late final FamilyRoles roles = FamilyRoles(this);
  late final GameGoals goals = GameGoals(this);
  late final GameMessages messages = GameMessages(this);
  late final GameLands lands = GameLands(this);
  late final GameNames names = GameNames(this);

  /// Save loaded and the game running (toasts and rewards only when true).
  bool ready = false;

  /// Screen closed. A late [init] must not start timers or write the save.
  bool disposed = false;

  GameState _state = GameState.initial();

  /// [_state] came out of [commit], and since then only the bar moved.
  bool _checked = false;

  GameState get state => _state;

  /// Direct write, past the check chain (load, auto grass, twins, taps).
  /// The next change runs the full chain again.
  set state(GameState next) {
    _state = next;
    _checked = false;
  }

  /// True while the state is a fixed point of the [commit] chain: running
  /// the chain again would change nothing (see [commitProgress]).
  bool get checked => _checked;

  /// Change notice to listeners, then the one-shot messages it brought.
  void notify() {
    _onNotify();
    messages.flush();
  }

  /// Every rule change lands here: reclamp to the active glade, keep the
  /// research flags in sync, open glades and goals, notify, save soon.
  void commit(GameState next) {
    // Reclamp to active Sunny Glade; soft-announce when a new glade opens.
    var state = herd.clampHerdToMeadow(next);
    if (state.grass < 0) {
      state = state.copyWith(grass: 0);
    }
    if (state.uyut < 0) {
      state = state.copyWith(uyut: 0);
    }
    if (state.activeMeadowId == WorldZones.mistEdgeMeadowId &&
        !state.visitedMist) {
      state = state.copyWith(visitedMist: true);
    }
    // Keep roleSlots in sync with research.
    if (state.hasResearch('role_slot_2') && state.roleSlots < 2) {
      state = state.copyWith(roleSlots: 2);
    }
    if (state.hasResearch('unlock_tent') && !state.tentUnlocked) {
      state = state.copyWith(tentUnlocked: true);
    }
    state = merge.sanitizeTwins(state);
    state = meadows.syncGladeAnnounced(state, announce: true);
    state = meadows.maybeUnlockMistyBiome(state, announce: true);
    state = goals.checkGoals(state, celebrate: true);
    _state = state;
    _checked = true;
    notify();
    save.schedule();
  }

  /// Fast path of [commit] when only the bar moved on a [checked] state.
  ///
  /// Every link of the chain reads fields other than `herdProgress`, and a
  /// checked state is its fixed point: the full chain would return the same
  /// value. No randomness, no toasts — the result is identical.
  void commitProgress(double progress) {
    _state = _state.copyWith(herdProgress: progress);
    notify();
    save.schedule();
  }

  /// Load save (or bootstrap), grant capped offline progress, start ticker.
  Future<void> init() async {
    messages.resetDaily();
    final loaded = await persistence.load();
    // Left before the save loaded: keep it as is, no ticker on a dead screen.
    if (disposed) return;
    if (loaded != null && loaded.totalHerdAcrossMeadows > 0) {
      state = herd.clampHerdToMeadow(loaded.withActiveSynced());
      // Old save: level two and up get names and traits, quietly (С5).
      state = names.migrate(state);
      // Fill legacy empty unlocked meadows with cozy starters (no toast).
      state = meadows.fillEmptyUnlockedMeadows(state);
      // Sync announced index quietly — no FOMO toast on relaunch.
      state = meadows.syncGladeAnnounced(state, announce: false);
      state = merge.sanitizeTwins(state);
      state = meadows.maybeUnlockMistyBiome(state, announce: false);
      state = meadows.fillEmptyUnlockedMeadows(state);
      state = goals.advanceGoalsQuiet(state);
      final savedMs = state.savedAtMs;
      if (savedMs != null) {
        clock.applyOfflineProgress(
          DateTime.fromMillisecondsSinceEpoch(savedMs),
        );
      }
    } else {
      state = herd.bootstrap();
      state = meadows.syncGladeAnnounced(state, announce: false);
      await persistence.save(save.withSavedAt(state));
      if (disposed) return;
    }
    ready = true;
    clock.lastTick = now();
    merge.twinRerollIn = BalanceV0.twinRerollSeconds.toDouble() * 0.4;
    if (clock.suspendedAt != null) {
      // Hidden while loading: away from now on; the clock waits for «shown».
      clock.suspendedAt = now();
    } else {
      clock.startTicker();
    }
    finds.scheduleFirstBerry();
    puddle.beginPresence();
    notify();
  }

  void dispose() {
    clock.dispose();
    save.dispose();
    puddle.dispose();
    finds.dispose();
    merge.dispose();
    messages.dispose();
    disposed = true;
    // Before load finished [state] is the empty placeholder — never write it.
    if (ready) {
      unawaited(persistence.save(save.withSavedAt(state)));
    }
  }
}
