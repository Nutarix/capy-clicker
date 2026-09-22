import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/balance.dart';
import '../models/capybara.dart';
import '../models/game_state.dart';
import '../models/meadow_snapshot.dart';
import '../models/session_goals.dart';
import '../models/world_zones.dart';
import '../persistence/game_persistence.dart';

/// Owns [GameState], tick loop, spawn/merge, mud boost, berry basket,
/// grass currency, session goals, twin sparkle, offline, soft daily, persist.
class GameController extends ChangeNotifier {
  GameController({
    GamePersistence? persistence,
    Random? random,
    DateTime Function()? now,
  }) : _persistence = persistence ?? GamePersistence(),
       _random = random ?? Random(),
       _now = now ?? DateTime.now;

  final GamePersistence _persistence;
  final Random _random;
  final DateTime Function() _now;

  GameState _state = GameState.initial();
  Timer? _tickTimer;
  Timer? _persistTimer;
  bool _ready = false;
  DateTime _lastTick = DateTime.now();

  /// Active mud boost ends at this instant (null = inactive).
  DateTime? _mudBoostUntil;

  /// Capy currently playing wallow on the puddle (null = idle puddle).
  String? _wallowingCapyId;
  Timer? _wallowTimer;

  /// Berry basket visibility + next spawn clock.
  bool _berryVisible = false;
  Timer? _berryTimer;

  /// Id of the capy that just merged (for flash juice).
  String? _mergeFlashId;
  Timer? _mergeFlashTimer;

  /// Soft one-shot Sunny Glade unlock toast (RU), consumed by UI.
  String? _gladeUnlockToast;

  /// Progress granted on this launch from offline elapsed time (0 if none).
  double _offlineProgressGranted = 0;

  /// Elapsed seconds used for the offline grant (capped).
  int _offlineSecondsApplied = 0;

  /// Grass-spend auto boost (weaker than mud).
  DateTime? _grassBoostUntil;

  /// Fractional auto-grass accumulator (grants integers when ≥ 1).
  double _grassAcc = 0;

  /// Soft session-goal celebration toast (RU), consumed by UI.
  String? _goalCompleteToast;

  /// Extra grass granted with the last glade unlock (for UI float).
  int _lastGladeGrassReward = 0;

  /// Grass granted by the most recent flower/berry tap (for UI float).
  int lastTapGrass = 0;

  /// Seconds until next twin-sparkle reroll attempt.
  double _twinRerollIn = BalanceV0.twinRerollSeconds.toDouble();

  GameState get state => _state;
  bool get isReady => _ready;

  /// Live auto fill rate (fraction/sec), including boosts — for HUD «+X%/с».
  double get autoRatePerSecond {
    return BalanceV0.autoProgressPerSecond * _boostMultiplier;
  }

  double get _boostMultiplier {
    var mult = 1.0;
    if (isMudBoostActive) {
      mult = mult < BalanceV0.mudBoostMultiplier
          ? BalanceV0.mudBoostMultiplier
          : mult;
    }
    if (isGrassBoostActive) {
      mult = mult < BalanceV0.grassBoostMultiplier
          ? BalanceV0.grassBoostMultiplier
          : mult;
    }
    return mult;
  }
  double get cameraZoom => BalanceV0.cameraZoomForHerd(
        _meadowKeyForCount(_state.herdCount),
        _state.herd.map((c) => c.position),
      );

  bool get isMudBoostActive =>
      _mudBoostUntil != null && _now().isBefore(_mudBoostUntil!);

  double get mudBoostRemainingSeconds {
    if (!isMudBoostActive) return 0;
    return _mudBoostUntil!.difference(_now()).inMilliseconds / 1000.0;
  }

  bool get isGrassBoostActive =>
      _grassBoostUntil != null && _now().isBefore(_grassBoostUntil!);

  double get grassBoostRemainingSeconds {
    if (!isGrassBoostActive) return 0;
    return _grassBoostUntil!.difference(_now()).inMilliseconds / 1000.0;
  }

  /// Combined boost remaining for HUD (prefer mud label when both).
  double get activeBoostRemainingSeconds {
    if (isMudBoostActive) return mudBoostRemainingSeconds;
    if (isGrassBoostActive) return grassBoostRemainingSeconds;
    return 0;
  }

  bool get isAnyBoostActive => isMudBoostActive || isGrassBoostActive;

  String? get wallowingCapyId => _wallowingCapyId;
  bool get isBerryVisible => _berryVisible;
  String? get mergeFlashId => _mergeFlashId;

  /// Pending «Солнечные поляны» unlock line (e.g. «Открылась Ягодная поляна»).
  String? get gladeUnlockToast => _gladeUnlockToast;

  /// Grass granted with the last glade unlock (0 if none).
  int get lastGladeGrassReward => _lastGladeGrassReward;

  /// Pending session-goal celebration line.
  String? get goalCompleteToast => _goalCompleteToast;

  /// Current session goal, or null when the sequence is finished.
  SessionGoal? get currentSessionGoal =>
      SessionGoals.at(_state.sessionGoalIndex);

  /// 0–1 progress toward [currentSessionGoal] (1 if all done).
  double get sessionGoalProgress {
    final goal = currentSessionGoal;
    if (goal == null) return 1.0;
    return SessionGoals.progressToward(
      goal: goal,
      sunnyGladeAnnounced: _state.sunnyGladeAnnounced,
      herdCount: _state.herdCount,
      maxCapyLevel: _state.maxCapyLevel,
    );
  }

  /// Soft daily tip tied to the active goal.
  String get dailyGoalHintRu => SessionGoals.dailyHintRu(currentSessionGoal);

  /// Active named meadow (fixed Sunny Glade identity — Phase 2 forest map).
  SunnyGlade get currentGlade =>
      WorldZones.gladeById(_state.activeMeadowId);

  /// Meadow ids unlocked so far (forest map chips).
  List<String> get unlockedMeadowIds => _state.unlockedMeadowIds;

  /// Walkable / camera key for the **active named meadow** (fixed rect, not
  /// expanding with local herd). [herdCount] is ignored — kept for call-site compat.
  int _meadowKeyForCount(int herdCount) => currentGlade.minHerd;

  /// Clear unlock toast after the UI shows it (once).
  void acknowledgeGladeUnlock() {
    _gladeUnlockToast = null;
    _lastGladeGrassReward = 0;
  }

  void acknowledgeGoalComplete() {
    _goalCompleteToast = null;
  }

  /// Offline grant from this session's [init] (consume once for UI).
  double get offlineProgressGranted => _offlineProgressGranted;
  int get offlineSecondsApplied => _offlineSecondsApplied;

  bool get hasOfflineWelcome => _offlineProgressGranted > 0.001;

  /// Clear the one-shot offline welcome flag after UI shows it.
  void acknowledgeOfflineWelcome() {
    _offlineProgressGranted = 0;
    _offlineSecondsApplied = 0;
  }

  /// Local calendar day key `YYYY-MM-DD` for [instant].
  static String calendarDayKey(DateTime instant) {
    final y = instant.year.toString().padLeft(4, '0');
    final m = instant.month.toString().padLeft(2, '0');
    final d = instant.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get _todayKey => calendarDayKey(_now());

  /// Soft daily gift available (once per local calendar day, not claimed yet).
  bool get isDailyBonusAvailable =>
      _ready && _state.lastDailyClaimYmd != _todayKey;

  /// Claim today's soft daily: +[BalanceV0.dailyBonusProgress] progress.
  /// Returns false if already claimed today.
  bool claimDailyBonus() {
    if (!isDailyBonusAvailable) return false;
    final day = _todayKey;
    _setState(
      _state.copyWith(
        lastDailyClaimYmd: day,
        grass: _state.grass + 3,
      ),
    );
    addProgress(BalanceV0.dailyBonusProgress, fromTap: false);
    return true;
  }

  /// Load save (or bootstrap), grant capped offline progress, start ticker.
  Future<void> init() async {
    final loaded = await _persistence.load();
    if (loaded != null && loaded.totalHerdAcrossMeadows > 0) {
      _state = _clampHerdToMeadow(loaded.withActiveSynced());
      // Fill legacy empty unlocked meadows with cozy starters (no toast).
      _state = _fillEmptyUnlockedMeadows(_state);
      // Sync announced index quietly — no FOMO toast on relaunch.
      _state = _syncGladeAnnounced(_state, announce: false);
      _state = _sanitizeTwins(_state);
      _state = _advanceGoalsQuiet(_state);
      _applyOfflineProgress();
    } else {
      _state = _bootstrap();
      _state = _syncGladeAnnounced(_state, announce: false);
      await _persistence.save(_withSavedAt(_state));
    }
    _ready = true;
    _lastTick = _now();
    _twinRerollIn = BalanceV0.twinRerollSeconds.toDouble() * 0.4;
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 50), _onTick);
    _scheduleFirstBerry();
    notifyListeners();
  }

  void _applyOfflineProgress() {
    final savedMs = _state.savedAtMs;
    if (savedMs == null) return;
    final elapsed = _now().difference(
      DateTime.fromMillisecondsSinceEpoch(savedMs),
    );
    var seconds = elapsed.inSeconds;
    if (seconds < BalanceV0.offlineMinSeconds) return;
    if (seconds > BalanceV0.offlineCapSeconds) {
      seconds = BalanceV0.offlineCapSeconds;
    }
    final amount = BalanceV0.autoProgressPerSecond * seconds;
    _offlineProgressGranted = amount;
    _offlineSecondsApplied = seconds;
    // Apply without live-tick dt guards; may spawn under herd cap.
    addProgress(amount, fromTap: false);
  }

  GameState _bootstrap() {
    var state = GameState.initial();
    for (var i = 0; i < BalanceV0.startingHerdSize; i++) {
      state = _spawnCapybara(state, level: BalanceV0.startingLevel);
    }
    return state;
  }

  GameState _withSavedAt(GameState state) =>
      state.copyWith(savedAtMs: _now().millisecondsSinceEpoch);

  void _onTick(Timer _) {
    final now = _now();
    final dt = now.difference(_lastTick).inMilliseconds / 1000.0;
    _lastTick = now;
    if (dt <= 0 || dt > 1.0) return;

    var dirty = false;

    // Clear expired boosts.
    if (_mudBoostUntil != null && now.isAfter(_mudBoostUntil!)) {
      _mudBoostUntil = null;
      dirty = true;
    }
    if (_grassBoostUntil != null && now.isAfter(_grassBoostUntil!)) {
      _grassBoostUntil = null;
      dirty = true;
    }

    // Auto grass accrual.
    _grassAcc += BalanceV0.autoGrassPerSecond * dt;
    if (_grassAcc >= 1.0) {
      final granted = _grassAcc.floor();
      _grassAcc -= granted;
      _state = _state.copyWith(grass: _state.grass + granted);
      dirty = true;
    }

    // Twin sparkle reroll.
    _twinRerollIn -= dt;
    if (_twinRerollIn <= 0) {
      _twinRerollIn = BalanceV0.twinRerollSeconds.toDouble();
      final next = _maybeMarkTwins(_state);
      if (next != _state) {
        _state = next;
        dirty = true;
        _schedulePersist();
      }
    }

    if (dirty) notifyListeners();

    addProgress(
      BalanceV0.autoProgressPerSecond * _boostMultiplier * dt,
      fromTap: false,
    );
  }

  /// Add progress; may spawn while under herd cap. Overflow carries over.
  void addProgress(double amount, {required bool fromTap}) {
    if (amount <= 0) return;

    var progress = _state.herdProgress + amount;
    var herd = List<Capybara>.from(_state.herd);
    var nextId = _state.nextId;
    var state = _state;

    while (progress >= BalanceV0.spawnThreshold &&
        herd.length < BalanceV0.maxHerdSize) {
      progress -= BalanceV0.spawnThreshold;
      state = _spawnCapybara(
        state.copyWith(herd: herd, nextId: nextId, herdProgress: progress),
        level: BalanceV0.startingLevel,
      );
      herd = List<Capybara>.from(state.herd);
      nextId = state.nextId;
    }

    if (herd.length >= BalanceV0.maxHerdSize) {
      progress = progress.clamp(0.0, BalanceV0.spawnThreshold);
    }

    _setState(
      state.copyWith(herdProgress: progress, herd: herd, nextId: nextId),
    );
  }

  /// Returns progress fraction granted (for floating «+N%» feedback).
  double onFlowerTap() {
    final gain =
        BalanceV0.flowerTapGainMin +
        _random.nextDouble() *
            (BalanceV0.flowerTapGainMax - BalanceV0.flowerTapGainMin);
    final grass =
        BalanceV0.flowerTapGrassMin +
        _random.nextInt(
          BalanceV0.flowerTapGrassMax - BalanceV0.flowerTapGrassMin + 1,
        );
    lastTapGrass = grass;
    _state = _state.copyWith(grass: _state.grass + grass);
    addProgress(gain, fromTap: true);
    return gain;
  }

  /// Returns progress fraction granted, or null if basket not visible.
  double? onBerryTap() {
    if (!_berryVisible) return null;
    final gain =
        BalanceV0.berryTapGainMin +
        _random.nextDouble() *
            (BalanceV0.berryTapGainMax - BalanceV0.berryTapGainMin);
    final grass =
        BalanceV0.berryGrassMin +
        _random.nextInt(
          BalanceV0.berryGrassMax - BalanceV0.berryGrassMin + 1,
        );
    lastTapGrass = grass;
    _state = _state.copyWith(grass: _state.grass + grass);
    addProgress(gain, fromTap: true);
    _berryVisible = false;
    _scheduleBerryRespawn();
    notifyListeners();
    return gain;
  }


  /// Spend grass to spawn a Lv.1 capy if under soft herd cap.
  bool spendCallCapy() {
    if (_state.grass < BalanceV0.callCapyGrassCost) return false;
    if (_state.herdCount >= BalanceV0.maxHerdSize) return false;
    var next = _state.copyWith(
      grass: _state.grass - BalanceV0.callCapyGrassCost,
    );
    next = _spawnCapybara(next, level: BalanceV0.startingLevel);
    _setState(next);
    return true;
  }

  /// Spend grass for a short auto-progress boost (weaker than mud).
  bool spendGrassBoost() {
    if (_state.grass < BalanceV0.grassBoostCost) return false;
    _setState(
      _state.copyWith(grass: _state.grass - BalanceV0.grassBoostCost),
    );
    _grassBoostUntil = _now().add(BalanceV0.grassBoostDuration);
    notifyListeners();
    return true;
  }

  bool get canCallCapy =>
      _state.grass >= BalanceV0.callCapyGrassCost &&
      _state.herdCount < BalanceV0.maxHerdSize;

  bool get canGrassBoost => _state.grass >= BalanceV0.grassBoostCost;

  /// Drop a capybara onto the mud puddle → wallow anim + temporary boost.
  bool tryMudWallow(String capyId) {
    final capy = _find(capyId);
    if (capy == null) return false;

    // Snap capy onto puddle center while animating.
    updatePosition(
      capyId,
      WorldZones.clampToMeadow(
        const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY),
        herdCount: _meadowKeyForCount(_state.herdCount),
      ),
    );

    _wallowingCapyId = capyId;
    _wallowTimer?.cancel();
    _wallowTimer = Timer(BalanceV0.mudWallowAnimDuration, () {
      _wallowingCapyId = null;
      notifyListeners();
    });

    _mudBoostUntil = _now().add(BalanceV0.mudBoostDuration);
    notifyListeners();
    return true;
  }

  /// True if [normalized] is inside the mud puddle hit circle.
  bool isOverMud(Offset normalized) {
    final dx = normalized.dx - BalanceV0.mudCenterX;
    final dy = normalized.dy - BalanceV0.mudCenterY;
    return sqrt(dx * dx + dy * dy) <= BalanceV0.mudHitRadius;
  }

  /// Drag-merge: same level only → remove both, spawn level+1 at target pos.
  bool tryMerge(String draggedId, String targetId) {
    if (draggedId == targetId) return false;
    final dragged = _find(draggedId);
    final target = _find(targetId);
    if (dragged == null || target == null) return false;
    if (dragged.level != target.level) return false;

    final twinBonus = _isTwinPair(draggedId, targetId);
    final newLevel = dragged.level + 1;
    final remaining = _state.herd
        .where((c) => c.id != draggedId && c.id != targetId)
        .toList();

    final merged = Capybara(
      id: 'c${_state.nextId}',
      level: newLevel,
      position: WorldZones.clampToMeadow(
        target.position,
        herdCount: _meadowKeyForCount(remaining.length + 1),
      ),
    );

    var grass = _state.grass;
    if (twinBonus) {
      grass += BalanceV0.twinMergeBonusGrass;
    }

    _setState(
      _state.copyWith(
        herd: [...remaining, merged],
        nextId: _state.nextId + 1,
        grass: grass,
        clearTwin: twinBonus,
      ),
    );
    _triggerMergeFlash(merged.id);
    if (twinBonus) {
      _twinRerollIn = BalanceV0.twinPostMergeCooldownSeconds.toDouble();
    }
    return true;
  }

  void _triggerMergeFlash(String id) {
    _mergeFlashId = id;
    _mergeFlashTimer?.cancel();
    _mergeFlashTimer = Timer(BalanceV0.mergeFlashDuration, () {
      _mergeFlashId = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void updatePosition(String id, Offset normalized) {
    final clamped = WorldZones.clampToMeadow(
      normalized,
      herdCount: _meadowKeyForCount(_state.herdCount),
    );
    final herd = _state.herd.map((c) {
      if (c.id != id) return c;
      return c.copyWith(position: clamped);
    }).toList();
    _setState(_state.copyWith(herd: herd));
  }

  void _scheduleFirstBerry() {
    final span = BalanceV0.berryFirstSpawnMax - BalanceV0.berryFirstSpawnMin;
    final delay =
        BalanceV0.berryFirstSpawnMin +
        Duration(milliseconds: _random.nextInt(span.inMilliseconds + 1));
    _berryTimer?.cancel();
    _berryTimer = Timer(delay, _spawnBerry);
  }

  void _scheduleBerryRespawn() {
    final span = BalanceV0.berryRespawnMax - BalanceV0.berryRespawnMin;
    final delay =
        BalanceV0.berryRespawnMin +
        Duration(milliseconds: _random.nextInt(span.inMilliseconds + 1));
    _berryTimer?.cancel();
    _berryTimer = Timer(delay, _spawnBerry);
  }

  void _spawnBerry() {
    _berryVisible = true;
    notifyListeners();
  }

  Capybara? _find(String id) {
    for (final c in _state.herd) {
      if (c.id == id) return c;
    }
    return null;
  }

  GameState _spawnCapybara(GameState state, {required int level}) {
    final pos = _pickSpawnPosition(state.herd);
    final capy = Capybara(id: 'c${state.nextId}', level: level, position: pos);
    return state.copyWith(
      herd: [...state.herd, capy],
      nextId: state.nextId + 1,
    );
  }

  Offset _pickSpawnPosition(List<Capybara> existing) {
    // Meadow expands with herd after spawn; never below unlocked glade.
    final herdCount = _meadowKeyForCount(existing.length + 1);
    const attempts = 24;
    for (var i = 0; i < attempts; i++) {
      final candidate = WorldZones.clampToMeadow(
        WorldZones.randomInMeadow(_random.nextDouble, herdCount: herdCount),
        herdCount: herdCount,
      );
      // Keep away from mud puddle and berry spot.
      final mudDx = candidate.dx - BalanceV0.mudCenterX;
      final mudDy = candidate.dy - BalanceV0.mudCenterY;
      if (sqrt(mudDx * mudDx + mudDy * mudDy) < BalanceV0.mudHitRadius + 0.08) {
        continue;
      }
      final berryDx = candidate.dx - BalanceV0.berryPosX;
      final berryDy = candidate.dy - BalanceV0.berryPosY;
      if (sqrt(berryDx * berryDx + berryDy * berryDy) < 0.10) {
        continue;
      }
      final ok = existing.every(
        (c) =>
            (c.position - candidate).distance >= BalanceV0.minSpawnSeparation,
      );
      if (ok) return candidate;
    }
    final n = existing.length;
    final angle = n * 2.4;
    final rect = WorldZones.meadowRectForHerd(herdCount);
    final cx = (rect.left + rect.right) / 2;
    final cy = (rect.top + rect.bottom) / 2;
    return WorldZones.clampToMeadow(
      Offset(cx + 0.18 * cos(angle), cy + 0.12 * sin(angle)),
      herdCount: herdCount,
    );
  }


  /// Re-seat positions onto the active named meadow rect (trees stay blocked).
  GameState _clampHerdToMeadow(GameState state) {
    final key = WorldZones.gladeById(state.activeMeadowId).minHerd;
    final herd = [
      for (final c in state.herd)
        c.copyWith(
          position: WorldZones.clampToMeadow(c.position, herdCount: key),
        ),
    ];
    return state.copyWith(herd: herd);
  }

  /// Unlock named meadows when active herd reaches glade bands; seed starters.
  GameState _syncGladeAnnounced(GameState state, {required bool announce}) {
    final reached = WorldZones.gladeForHerd(state.herdCount);
    if (reached.index <= state.sunnyGladeAnnounced) return state;

    var nextId = state.nextId;
    final meadows = Map<String, MeadowSnapshot>.from(state.withActiveSynced().meadows);

    for (var i = state.sunnyGladeAnnounced + 1; i <= reached.index; i++) {
      final g = WorldZones.glades[i];
      final existing = meadows[g.id];
      if (existing == null || existing.herd.isEmpty) {
        final built = _buildStarterHerd(
          meadowId: g.id,
          startNextId: nextId,
          count: BalanceV0.meadowStarterHerdSize,
        );
        nextId = built.nextId;
        meadows[g.id] = MeadowSnapshot(herd: built.herd);
      }
    }

    if (announce && _ready && reached.unlockToastRu.isNotEmpty) {
      _gladeUnlockToast = reached.unlockToastRu;
      _lastGladeGrassReward = BalanceV0.gladeUnlockGrass;
      return state.copyWith(
        sunnyGladeAnnounced: reached.index,
        grass: state.grass + BalanceV0.gladeUnlockGrass,
        meadows: meadows,
        nextId: nextId,
      );
    }
    return state.copyWith(
      sunnyGladeAnnounced: reached.index,
      meadows: meadows,
      nextId: nextId,
    );
  }

  /// After legacy migrate: empty unlocked meadows get a small starter herd.
  GameState _fillEmptyUnlockedMeadows(GameState state) {
    var nextId = state.nextId;
    final meadows =
        Map<String, MeadowSnapshot>.from(state.withActiveSynced().meadows);
    var dirty = false;
    for (final g in WorldZones.glades) {
      if (g.index > state.sunnyGladeAnnounced) continue;
      if (g.id == state.activeMeadowId) continue;
      final existing = meadows[g.id];
      if (existing == null || existing.herd.isEmpty) {
        final built = _buildStarterHerd(
          meadowId: g.id,
          startNextId: nextId,
          count: BalanceV0.meadowStarterHerdSize,
        );
        nextId = built.nextId;
        meadows[g.id] = MeadowSnapshot(herd: built.herd);
        dirty = true;
      }
    }
    if (!dirty) return state;
    return state.copyWith(meadows: meadows, nextId: nextId);
  }

  ({List<Capybara> herd, int nextId}) _buildStarterHerd({
    required String meadowId,
    required int startNextId,
    required int count,
  }) {
    final key = WorldZones.gladeById(meadowId).minHerd;
    var nextId = startNextId;
    final herd = <Capybara>[];
    for (var i = 0; i < count; i++) {
      final raw = WorldZones.randomInMeadow(
        _random.nextDouble,
        herdCount: key,
      );
      final pos = WorldZones.clampToMeadow(raw, herdCount: key);
      herd.add(Capybara(id: 'c$nextId', level: BalanceV0.startingLevel, position: pos));
      nextId++;
    }
    return (herd: herd, nextId: nextId);
  }

  /// Herd size on a meadow (active uses live fields).
  int herdCountForMeadow(String meadowId) {
    if (meadowId == _state.activeMeadowId) return _state.herdCount;
    return _state.meadows[meadowId]?.herdCount ?? 0;
  }

  /// Forest map: switch playable meadow. Shared grass stays; herd restores.
  bool switchToMeadow(String meadowId) {
    if (!_ready) return false;
    if (meadowId == _state.activeMeadowId) return true;
    if (!_state.isMeadowUnlocked(meadowId)) return false;
    final synced = _state.withActiveSynced();
    final meadows = Map<String, MeadowSnapshot>.from(synced.meadows);
    final target = meadows[meadowId];
    if (target == null) return false;

    _wallowTimer?.cancel();
    _wallowingCapyId = null;

    final clearTwin = target.twinIdA == null || target.twinIdB == null;
    _setState(
      synced.copyWith(
        activeMeadowId: meadowId,
        herd: List<Capybara>.from(target.herd),
        herdProgress: target.herdProgress,
        meadows: meadows,
        twinIdA: target.twinIdA,
        twinIdB: target.twinIdB,
        clearTwin: clearTwin,
      ),
    );
    return true;
  }

  void _setState(GameState next) {
    // Reclamp to active Sunny Glade; soft-announce when a new glade opens.
    var state = _clampHerdToMeadow(next);
    if (state.grass < 0) {
      state = state.copyWith(grass: 0);
    }
    state = _sanitizeTwins(state);
    state = _syncGladeAnnounced(state, announce: true);
    state = _checkGoals(state, celebrate: true);
    _state = state;
    notifyListeners();
    _schedulePersist();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(
      const Duration(milliseconds: BalanceV0.persistDebounceMs),
      () => _persistence.save(_withSavedAt(_state)),
    );
  }


  bool _isTwinPair(String a, String b) {
    final tA = _state.twinIdA;
    final tB = _state.twinIdB;
    if (tA == null || tB == null) return false;
    return (a == tA && b == tB) || (a == tB && b == tA);
  }

  /// Drop twin marks if either id is missing / levels diverge.
  GameState _sanitizeTwins(GameState state) {
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

  /// Quietly catch up goal index on load (no celebration toast).
  GameState _advanceGoalsQuiet(GameState state) {
    var idx = state.sessionGoalIndex.clamp(0, SessionGoals.sequence.length);
    while (idx < SessionGoals.sequence.length) {
      final goal = SessionGoals.sequence[idx];
      if (!SessionGoals.isComplete(
        goal: goal,
        sunnyGladeAnnounced: state.sunnyGladeAnnounced,
        maxCapyLevel: state.maxCapyLevel,
      )) {
        break;
      }
      idx++;
    }
    if (idx == state.sessionGoalIndex) return state;
    return state.copyWith(sessionGoalIndex: idx);
  }

  /// Check / advance session goals; may set [_goalCompleteToast].
  GameState _checkGoals(GameState state, {required bool celebrate}) {
    var idx = state.sessionGoalIndex.clamp(0, SessionGoals.sequence.length);
    var grass = state.grass;
    String? toast;
    while (idx < SessionGoals.sequence.length) {
      final goal = SessionGoals.sequence[idx];
      if (!SessionGoals.isComplete(
        goal: goal,
        sunnyGladeAnnounced: state.sunnyGladeAnnounced,
        maxCapyLevel: state.maxCapyLevel,
      )) {
        break;
      }
      if (celebrate && _ready) {
        toast = goal.celebrationRu;
        grass += BalanceV0.goalCompleteGrass;
      }
      idx++;
    }
    if (toast != null) {
      _goalCompleteToast = toast;
    }
    if (idx == state.sessionGoalIndex && grass == state.grass) return state;
    return state.copyWith(sessionGoalIndex: idx, grass: grass);
  }

  /// Pick a random same-level pair for twin sparkle (or clear).
  GameState _maybeMarkTwins(GameState state) {
    if (state.herd.length < BalanceV0.twinMinHerd) {
      return state.copyWith(clearTwin: true);
    }
    final byLevel = <int, List<Capybara>>{};
    for (final c in state.herd) {
      byLevel.putIfAbsent(c.level, () => []).add(c);
    }
    final eligible =
        byLevel.entries.where((e) => e.value.length >= 2).toList();
    if (eligible.isEmpty) {
      return state.copyWith(clearTwin: true);
    }
    if (state.twinIdA != null && state.twinIdB != null) {
      final ids = {for (final c in state.herd) c.id};
      if (ids.contains(state.twinIdA) && ids.contains(state.twinIdB)) {
        final a = state.herd.firstWhere((c) => c.id == state.twinIdA);
        final b = state.herd.firstWhere((c) => c.id == state.twinIdB);
        if (a.level == b.level &&
            _random.nextDouble() < BalanceV0.twinLingerChance) {
          return state; // linger a bit longer
        }
      }
    }
    // Quiet gaps so sparkle stays a skill window, not a permanent glow.
    if (_random.nextDouble() > BalanceV0.twinMarkChance) {
      return state.copyWith(clearTwin: true);
    }
    final pick = eligible[_random.nextInt(eligible.length)].value;
    final shuffled = List<Capybara>.from(pick)..shuffle(_random);
    return state.copyWith(
      twinIdA: shuffled[0].id,
      twinIdB: shuffled[1].id,
    );
  }

  /// Force a twin mark (tests).
  @visibleForTesting
  void debugMarkTwins(String a, String b) {
    _setState(_state.copyWith(twinIdA: a, twinIdB: b));
  }

  /// Headless tick for progression sims (grass auto + twin reroll + auto bar).
  @visibleForTesting
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
    final now = _now();
    var dirty = false;
    if (_mudBoostUntil != null && now.isAfter(_mudBoostUntil!)) {
      _mudBoostUntil = null;
      dirty = true;
    }
    if (_grassBoostUntil != null && now.isAfter(_grassBoostUntil!)) {
      _grassBoostUntil = null;
      dirty = true;
    }
    _grassAcc += BalanceV0.autoGrassPerSecond * dt;
    if (_grassAcc >= 1.0) {
      final granted = _grassAcc.floor();
      _grassAcc -= granted;
      _state = _state.copyWith(grass: _state.grass + granted);
      dirty = true;
    }
    _twinRerollIn -= dt;
    if (_twinRerollIn <= 0) {
      _twinRerollIn = BalanceV0.twinRerollSeconds.toDouble();
      final next = _maybeMarkTwins(_state);
      if (next != _state) {
        _state = next;
        dirty = true;
        _schedulePersist();
      }
    }
    if (dirty) notifyListeners();
    addProgress(
      BalanceV0.autoProgressPerSecond * _boostMultiplier * dt,
      fromTap: false,
    );
  }

  /// Force berry visible (tests / sims).
  @visibleForTesting
  void debugShowBerry() {
    _berryVisible = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _persistTimer?.cancel();
    _wallowTimer?.cancel();
    _berryTimer?.cancel();
    _mergeFlashTimer?.cancel();
    unawaited(_persistence.save(_withSavedAt(_state)));
    super.dispose();
  }
}
