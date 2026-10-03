import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/balance.dart';
import '../models/capy_wander.dart';
import '../models/meadow_occupancy.dart';
import '../models/capybara.dart';
import '../models/family_land.dart';
import '../models/game_state.dart';
import '../models/meadow_snapshot.dart';
import '../models/multipliers/multipliers.dart';
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
    this.autoTick = true,
  }) : _persistence = persistence ?? GamePersistence(),
       _random = random ?? Random(),
       // Separate stream so food/loot drops do not desync core progression RNG.
       _lootRandom = Random(0xC4A7F00D),
       _now = now ?? DateTime.now;

  final GamePersistence _persistence;
  final Random _random;
  final Random _lootRandom;
  final DateTime Function() _now;

  /// False: no periodic tick — tests drive the game clock via [debugAdvance].
  final bool autoTick;

  GameState _state = GameState.initial();
  Timer? _tickTimer;
  Timer? _persistTimer;
  bool _ready = false;

  /// Screen closed. A late [init] must not start timers or write the save.
  bool _disposed = false;
  DateTime _lastTick = DateTime.now();

  /// Active mud boost ends at this instant (null = inactive).
  DateTime? _mudBoostUntil;

  /// Capy currently playing wallow on the puddle (null = idle puddle).
  String? _wallowingCapyId;
  Timer? _wallowTimer;

  /// Temporary puddle. Position is session-only — never written to the save.
  bool _mudPresent = false;
  bool _mudCooling = false;
  Offset _mudCenter = const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY);
  double _mudSecondsLeft = 0;
  String? _puddleToast;

  /// Berry basket visibility + next spawn clock.
  bool _berryVisible = false;
  Timer? _berryTimer;

  /// Id of the capy that just merged (for flash juice).
  String? _mergeFlashId;
  Timer? _mergeFlashTimer;

  /// Soft one-shot Sunny Glade unlock toast (RU), consumed by UI.
  String? _gladeUnlockToast;
  String? _lastRoleToast;

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

  /// Active family-food temporary boost.
  FamilyFood? _foodBoostKind;
  DateTime? _foodBoostUntil;

  /// Active cozy-place temporary boost.
  CozyPlaceKind? _placeBoostKind;
  DateTime? _placeBoostUntil;

  /// Per-place cooldown ends-at.
  final Map<CozyPlaceKind, DateTime> _placeCooldownUntil = {};

  /// Selected food for next feed (UI picker).
  FamilyFood _selectedFood = FamilyFood.travka;

  GameState get state => _state;
  bool get isReady => _ready;

  /// Live auto fill rate (fraction/sec) — full stack for HUD «+X%/с».
  /// Order: base → temp (mud/grass/food/places) → roles → decor → research → Уют.
  double get autoRatePerSecond {
    return BalanceV0.autoProgressPerSecond *
        _tempLayerMultiplier *
        _roleAutoMultiplier *
        _decorAutoMultiplier *
        _researchAutoMultiplier *
        _uyutMultiplier;
  }

  /// Permanent Уют multiplier (1 + uyut * 3%).
  double get _uyutMultiplier =>
      1.0 + _state.uyut * BalanceV0.uyutAutoBoostPerPoint;

  /// Temporary layer: mud/grass take max; food & places multiply on top.
  double get _tempLayerMultiplier {
    var mudGrass = 1.0;
    if (isMudBoostActive) {
      mudGrass = mudGrass < BalanceV0.mudBoostMultiplier
          ? BalanceV0.mudBoostMultiplier
          : mudGrass;
    }
    if (isGrassBoostActive) {
      mudGrass = mudGrass < BalanceV0.grassBoostMultiplier
          ? BalanceV0.grassBoostMultiplier
          : mudGrass;
    }
    return mudGrass * _foodAutoMultiplier * _placeAutoMultiplier;
  }

  double get _foodAutoMultiplier {
    if (!isFoodBoostActive || _foodBoostKind == null) return 1.0;
    return switch (_foodBoostKind!) {
      FamilyFood.travka => BalanceV0.foodTravkaAutoMult,
      FamilyFood.yagody => BalanceV0.foodYagodyAutoMult,
      FamilyFood.oreshki => BalanceV0.foodOreshkiAutoMult,
    };
  }

  double get _placeAutoMultiplier {
    if (!isPlaceBoostActive || _placeBoostKind == null) return 1.0;
    return switch (_placeBoostKind!) {
      CozyPlaceKind.warmStone => BalanceV0.warmStoneGrassAutoMult,
      CozyPlaceKind.tent => BalanceV0.tentSpawnMult,
      CozyPlaceKind.pen => 1.0, // magnet/twin only
    };
  }

  double get _roleAutoMultiplier {
    var bonus = 0.0;
    for (final c in _state.herd) {
      if (c.role == CapyRole.nanya) bonus += BalanceV0.roleNanyaAutoBonus;
    }
    return 1.0 + bonus;
  }

  double get _decorAutoMultiplier {
    var bonus = 0.0;
    for (final id in _state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) bonus += d.autoBonus;
    }
    return 1.0 + bonus;
  }

  /// Research does not add a flat auto % in v0 (effects are targeted).
  double get _researchAutoMultiplier => 1.0;

  double get _flowerFindMultiplier {
    var m = 1.0;
    if (_state.hasResearch('more_flowers')) {
      m += BalanceV0.researchFlowerBonus;
    }
    for (final id in _state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) m += d.flowerBonus;
    }
    for (final c in _state.herd) {
      if (c.role == CapyRole.sobiratel) {
        m += BalanceV0.roleSobiratelFindBonus;
      }
    }
    return m;
  }

  double get _grassAutoMultiplier {
    var m = _uyutMultiplier;
    for (final id in _state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) m *= (1.0 + d.grassAutoBonus);
    }
    if (isPlaceBoostActive && _placeBoostKind == CozyPlaceKind.warmStone) {
      m *= BalanceV0.warmStoneGrassAutoMult;
    }
    return m;
  }

  int get effectiveMaxHerdSize {
    var cap = BalanceV0.maxHerdSize;
    if (_state.hasResearch('soft_cap_plus')) cap += 1;
    for (final c in _state.herd) {
      if (c.role == CapyRole.storozh) {
        cap += BalanceV0.roleStorozhSoftCapBonus;
      }
    }
    return cap;
  }

  double get effectiveMagnetRadius {
    var r = BalanceV0.magnetRadius;
    if (isFoodBoostActive && _foodBoostKind == FamilyFood.oreshki) {
      r *= (1.0 + BalanceV0.foodOreshkiMagnetBonus);
    }
    if (isPlaceBoostActive && _placeBoostKind == CozyPlaceKind.pen) {
      r *= (1.0 + BalanceV0.penMagnetBonus);
    }
    return r;
  }

  double get _twinMarkChanceBonus {
    var b = 0.0;
    if (isFoodBoostActive && _foodBoostKind == FamilyFood.oreshki) {
      b += BalanceV0.foodOreshkiTwinChanceBonus;
    }
    if (isPlaceBoostActive && _placeBoostKind == CozyPlaceKind.pen) {
      b += BalanceV0.penTwinChanceBonus;
    }
    return b;
  }

  Duration get _mudBoostDuration {
    var d = BalanceV0.mudBoostDuration;
    if (_state.hasResearch('longer_mud')) {
      d += BalanceV0.researchMudExtra;
    }
    return d;
  }

  FamilyFood get selectedFood => _selectedFood;

  void selectFood(FamilyFood food) {
    _selectedFood = food;
    notifyListeners();
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

  bool get isFoodBoostActive =>
      _foodBoostUntil != null && _now().isBefore(_foodBoostUntil!);

  double get foodBoostRemainingSeconds {
    if (!isFoodBoostActive) return 0;
    return _foodBoostUntil!.difference(_now()).inMilliseconds / 1000.0;
  }

  FamilyFood? get activeFoodBoost => isFoodBoostActive ? _foodBoostKind : null;

  bool get isPlaceBoostActive =>
      _placeBoostUntil != null && _now().isBefore(_placeBoostUntil!);

  double get placeBoostRemainingSeconds {
    if (!isPlaceBoostActive) return 0;
    return _placeBoostUntil!.difference(_now()).inMilliseconds / 1000.0;
  }

  CozyPlaceKind? get activePlaceBoost =>
      isPlaceBoostActive ? _placeBoostKind : null;

  bool isPlaceOnCooldown(CozyPlaceKind kind) {
    final until = _placeCooldownUntil[kind];
    return until != null && _now().isBefore(until);
  }

  double placeCooldownRemaining(CozyPlaceKind kind) {
    final until = _placeCooldownUntil[kind];
    if (until == null || !_now().isBefore(until)) return 0;
    return until.difference(_now()).inMilliseconds / 1000.0;
  }

  bool get isAnyBoostActive =>
      isMudBoostActive ||
      isGrassBoostActive ||
      isFoodBoostActive ||
      isPlaceBoostActive;

  String? get wallowingCapyId => _wallowingCapyId;
  bool get isBerryVisible => _berryVisible;
  String? get mergeFlashId => _mergeFlashId;

  /// Pending «Солнечные поляны» unlock line (e.g. «Открылась Ягодная поляна»).
  String? get gladeUnlockToast => _gladeUnlockToast;

  /// One-shot toast after assigning a role («Няня: +15% авто»).
  String? get lastRoleToast => _lastRoleToast;

  void acknowledgeRoleToast() {
    _lastRoleToast = null;
  }

  /// Live RU summary of active role bonuses for Уют / HUD.
  String get activeRoleBonusesRu {
    var nanya = 0;
    var sobi = 0;
    var stor = 0;
    for (final c in _state.herd) {
      switch (c.role) {
        case CapyRole.nanya:
          nanya++;
        case CapyRole.sobiratel:
          sobi++;
        case CapyRole.storozh:
          stor++;
        case null:
          break;
      }
    }
    final parts = <String>[];
    if (nanya > 0) {
      final pct = (nanya * BalanceV0.roleNanyaAutoBonus * 100).round();
      parts.add('Няня +$pct% авто');
    }
    if (sobi > 0) {
      final pct = (sobi * BalanceV0.roleSobiratelFindBonus * 100).round();
      parts.add('Собиратель +$pct% находки');
    }
    if (stor > 0) {
      final extra = stor * BalanceV0.roleStorozhSoftCapBonus;
      parts.add('Сторож +$extra лимит семьи');
    }
    if (parts.isEmpty) return 'Роли пока не назначены';
    return parts.join(' · ');
  }

  /// Grass granted with the last glade unlock (0 if none).
  int get lastGladeGrassReward => _lastGladeGrassReward;

  /// Pending session-goal celebration line.
  String? get goalCompleteToast => _goalCompleteToast;

  /// Current session goal, or null when the sequence is finished.
  SessionGoal? get currentSessionGoal =>
      SessionGoals.at(_state.sessionGoalIndex);

  /// 0–1 progress toward [currentSessionGoal].
  double get sessionGoalProgress {
    final goal = currentSessionGoal;
    if (goal == null) return 1.0;
    return SessionGoals.progressToward(
      goal: goal,
      sunnyGladeAnnounced: _state.sunnyGladeAnnounced,
      herdCount: _state.herdCount,
      maxCapyLevel: _state.maxCapyLevel,
      mistyBiomeUnlocked: _state.mistyBiomeUnlocked,
      activeMeadowId: _state.activeMeadowId,
      uyut: _state.uyut,
      familyPower: _state.familyPower,
    );
  }

  /// Soft daily tip tied to the active goal.
  String get dailyGoalHintRu => SessionGoals.dailyHintRu(currentSessionGoal);

  /// Active named meadow (fixed Sunny Glade identity — Phase 2 forest map).
  SunnyGlade get currentGlade => WorldZones.gladeById(_state.activeMeadowId);

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

  /// Live puddle, or null while it is despawned. Not part of [GameState].
  bool get mudVisible => _mudPresent;
  Offset? get mudCenter => _mudPresent ? _mudCenter : null;

  /// One-shot «Лужа!» when a puddle appears. UI must acknowledge.
  String? get puddleToast => _puddleToast;

  void acknowledgePuddleToast() {
    _puddleToast = null;
  }

  /// Puddle anchor whose painted disc does not cover a resting body.
  ///
  /// The widget still steps anyone off if the live meadow size differs from
  /// the fallback used here. Gameplay hit circle stays [BalanceV0.mudHitRadius].
  Offset _pickMudCenter(int herdCount, {List<Capybara>? herd}) {
    final family = herd ?? _state.herd;
    final bodies = [for (final c in family) c.position];
    final widths = [
      for (final c in family) BalanceV0.capySizeForLevel(c.level),
    ];
    Offset? fallback;
    final meadow = CapyWander.fallbackMeadow;
    for (var i = 0; i < 24; i++) {
      final p = BalanceV0.randomMudCenter(
        _random.nextDouble,
        herdCount: herdCount,
      );
      fallback ??= p;
      if (MeadowOccupancy.puddleClears(
        p,
        meadow,
        herdCount: herdCount,
        capyAnchors: bodies,
        capyWidths: widths,
        tentUnlocked: _state.tentUnlocked,
      )) {
        return p;
      }
    }
    return fallback ??
        BalanceV0.randomMudCenter(_random.nextDouble, herdCount: herdCount);
  }

  void _beginMudPresence() {
    _mudPresent = true;
    _mudCooling = false;
    _mudCenter = _pickMudCenter(_meadowKeyForCount(_state.herdCount));
    var extra = 0.0;
    if (_state.hasResearch('longer_mud')) {
      extra = BalanceV0.researchMudExtra.inSeconds.toDouble();
    }
    final span =
        BalanceV0.mudVisibleMaxSeconds - BalanceV0.mudVisibleMinSeconds;
    _mudSecondsLeft =
        BalanceV0.mudVisibleMinSeconds + _random.nextDouble() * span + extra;
    _puddleToast = 'Лужа!';
  }

  void _beginMudCooldown() {
    _mudPresent = false;
    _mudCooling = true;
    // Drop the point so nothing about the last spot is kept.
    _mudCenter = Offset.zero;
    final span =
        BalanceV0.mudCooldownMaxSeconds - BalanceV0.mudCooldownMinSeconds;
    _mudSecondsLeft =
        BalanceV0.mudCooldownMinSeconds + _random.nextDouble() * span;
  }

  /// Advance the spawn / despawn clock by [dt] seconds. Caller notifies.
  void _advanceMud(double dt) {
    if (!_mudPresent && !_mudCooling) {
      _beginMudPresence();
      return;
    }
    _mudSecondsLeft -= dt;
    if (_mudSecondsLeft > 0) return;
    if (_mudPresent) {
      _beginMudCooldown();
    } else {
      _beginMudPresence();
    }
  }

  /// Tests: plant a puddle with a known center and lifetime.
  @visibleForTesting
  void debugPlaceMud(Offset center, {double seconds = 3}) {
    _mudPresent = true;
    _mudCooling = false;
    _mudCenter = center;
    _mudSecondsLeft = seconds;
    _puddleToast = null;
    notifyListeners();
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
    _setState(_state.copyWith(lastDailyClaimYmd: day, grass: _state.grass + 3));
    addProgress(BalanceV0.dailyBonusProgress, fromTap: false);
    return true;
  }

  /// Load save (or bootstrap), grant capped offline progress, start ticker.
  Future<void> init() async {
    final loaded = await _persistence.load();
    // Left before the save loaded: keep it as is, no ticker on a dead screen.
    if (_disposed) return;
    if (loaded != null && loaded.totalHerdAcrossMeadows > 0) {
      _state = _clampHerdToMeadow(loaded.withActiveSynced());
      // Fill legacy empty unlocked meadows with cozy starters (no toast).
      _state = _fillEmptyUnlockedMeadows(_state);
      // Sync announced index quietly — no FOMO toast on relaunch.
      _state = _syncGladeAnnounced(_state, announce: false);
      _state = _sanitizeTwins(_state);
      _state = _maybeUnlockMistyBiome(_state, announce: false);
      _state = _fillEmptyUnlockedMeadows(_state);
      _state = _advanceGoalsQuiet(_state);
      _applyOfflineProgress();
    } else {
      _state = _bootstrap();
      _state = _syncGladeAnnounced(_state, announce: false);
      await _persistence.save(_withSavedAt(_state));
      if (_disposed) return;
    }
    _ready = true;
    _lastTick = _now();
    _twinRerollIn = BalanceV0.twinRerollSeconds.toDouble() * 0.4;
    _tickTimer?.cancel();
    if (autoTick) {
      _tickTimer = Timer.periodic(const Duration(milliseconds: 50), _onTick);
    }
    _scheduleFirstBerry();
    _beginMudPresence();
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
    var offlineMult =
        _uyutMultiplier * _decorAutoMultiplier * _roleAutoMultiplier;
    // Tent is session-only; offline leans on research tent unlock + decor.
    if (_state.tentUnlocked) {
      offlineMult *= BalanceV0.tentOfflineMult;
    }
    final amount = BalanceV0.autoProgressPerSecond * offlineMult * seconds;
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
    _advanceClock(dt, now);
  }

  /// One step of the game clock: mud, boosts, auto grass, twins, auto bar.
  /// Shared by the live tick and [debugAdvance], so tests run the real thing.
  void _advanceClock(double dt, DateTime now) {
    var dirty = false;
    final mudBefore = _mudPresent;
    final mudCenterBefore = _mudCenter;
    final toastBefore = _puddleToast;
    _advanceMud(dt);
    if (_mudPresent != mudBefore ||
        _mudCenter != mudCenterBefore ||
        _puddleToast != toastBefore) {
      dirty = true;
    }

    // Clear expired boosts.
    if (_mudBoostUntil != null && now.isAfter(_mudBoostUntil!)) {
      _mudBoostUntil = null;
      dirty = true;
    }
    if (_grassBoostUntil != null && now.isAfter(_grassBoostUntil!)) {
      _grassBoostUntil = null;
      dirty = true;
    }
    if (_foodBoostUntil != null && now.isAfter(_foodBoostUntil!)) {
      _foodBoostUntil = null;
      _foodBoostKind = null;
      dirty = true;
    }
    if (_placeBoostUntil != null && now.isAfter(_placeBoostUntil!)) {
      _placeBoostUntil = null;
      _placeBoostKind = null;
      dirty = true;
    }

    // Auto grass accrual (decor + Уют + warm stone).
    _grassAcc += BalanceV0.autoGrassPerSecond * _grassAutoMultiplier * dt;
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

    addProgress(autoRatePerSecond * dt, fromTap: false);
  }

  /// Add progress; may spawn while under herd cap. Overflow carries over.
  void addProgress(double amount, {required bool fromTap}) {
    if (amount <= 0) return;

    var progress = _state.herdProgress + amount;
    var herd = List<Capybara>.from(_state.herd);
    var nextId = _state.nextId;
    var state = _state;

    while (progress >= BalanceV0.spawnThreshold &&
        herd.length < effectiveMaxHerdSize) {
      progress -= BalanceV0.spawnThreshold;
      state = _spawnCapybara(
        state.copyWith(herd: herd, nextId: nextId, herdProgress: progress),
        level: BalanceV0.startingLevel,
      );
      herd = List<Capybara>.from(state.herd);
      nextId = state.nextId;
    }

    if (herd.length >= effectiveMaxHerdSize) {
      progress = progress.clamp(0.0, BalanceV0.spawnThreshold);
    }

    _setState(
      state.copyWith(herdProgress: progress, herd: herd, nextId: nextId),
    );
  }

  /// Returns progress fraction granted (for floating «+N%» feedback).
  double onFlowerTap() {
    final base =
        BalanceV0.flowerTapGainMin +
        _random.nextDouble() *
            (BalanceV0.flowerTapGainMax - BalanceV0.flowerTapGainMin);
    final gain = base * _flowerFindMultiplier;
    final grass =
        BalanceV0.flowerTapGrassMin +
        _random.nextInt(
          BalanceV0.flowerTapGrassMax - BalanceV0.flowerTapGrassMin + 1,
        );
    lastTapGrass = grass;
    var food = _state.food;
    final dropped = _maybeDropFood();
    if (dropped != null) {
      food = food.add(dropped);
      lastDroppedFood = dropped;
    } else {
      lastDroppedFood = null;
    }
    _state = _state.copyWith(grass: _state.grass + grass, food: food);
    addProgress(gain, fromTap: true);
    return gain;
  }

  /// Last food granted by flower/buy (UI float); null if none.
  FamilyFood? lastDroppedFood;

  double get _foodDropChance {
    var c = BalanceV0.flowerFoodDropChance;
    if (_state.hasResearch('food_pouch')) {
      c += BalanceV0.researchFoodDropBonus;
    }
    for (final id in _state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) c += d.foodDropBonus;
    }
    for (final cap in _state.herd) {
      if (cap.role == CapyRole.sobiratel) {
        c += BalanceV0.roleSobiratelFindBonus * 0.5;
      }
    }
    return c.clamp(0.0, 0.85);
  }

  FamilyFood? _maybeDropFood() {
    if (_lootRandom.nextDouble() > _foodDropChance) return null;
    final wT = BalanceV0.foodDropTravkaWeight;
    final wY = BalanceV0.foodDropYagodyWeight;
    final wO = BalanceV0.foodDropOreshkiWeight;
    final roll = _lootRandom.nextDouble() * (wT + wY + wO);
    if (roll < wT) return FamilyFood.travka;
    if (roll < wT + wY) return FamilyFood.yagody;
    return FamilyFood.oreshki;
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
        _random.nextInt(BalanceV0.berryGrassMax - BalanceV0.berryGrassMin + 1);
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
    if (_state.herdCount >= effectiveMaxHerdSize) return false;
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
    _setState(_state.copyWith(grass: _state.grass - BalanceV0.grassBoostCost));
    _grassBoostUntil = _now().add(BalanceV0.grassBoostDuration);
    notifyListeners();
    return true;
  }

  bool get canCallCapy =>
      _state.grass >= BalanceV0.callCapyGrassCost &&
      _state.herdCount < effectiveMaxHerdSize;

  /// Why «Позвать капи» is gray. Null while the call is available.
  /// A full семья wins over low grass — leftover grass must not look like a bug.
  String? get callCapyBlockedReason {
    if (_state.herdCount >= effectiveMaxHerdSize) return 'Семья полная';
    if (_state.grass < BalanceV0.callCapyGrassCost) return 'Не хватает травы';
    return null;
  }

  bool get canGrassBoost => _state.grass >= BalanceV0.grassBoostCost;

  /// Drop a capybara onto the mud puddle → wallow anim + temporary boost.
  bool tryMudWallow(String capyId) {
    if (!_mudPresent) return false;
    final capy = _find(capyId);
    if (capy == null) return false;

    // Snap capy onto the live puddle (it may not be the old fixed corner).
    updatePosition(
      capyId,
      WorldZones.clampToMeadow(
        _mudCenter,
        herdCount: _meadowKeyForCount(_state.herdCount),
      ),
    );

    _wallowingCapyId = capyId;
    _wallowTimer?.cancel();
    _wallowTimer = Timer(BalanceV0.mudWallowAnimDuration, () {
      _wallowingCapyId = null;
      notifyListeners();
    });

    _mudBoostUntil = _now().add(_mudBoostDuration);
    notifyListeners();
    return true;
  }

  /// True if [normalized] is inside the mud puddle hit circle.
  bool isOverMud(Offset normalized) {
    if (!_mudPresent) return false;
    final dx = normalized.dx - _mudCenter.dx;
    final dy = normalized.dy - _mudCenter.dy;
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
      role: target.role ?? dragged.role,
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
    var delayMs =
        BalanceV0.berryRespawnMin.inMilliseconds +
        _random.nextInt(span.inMilliseconds + 1);
    delayMs = (delayMs * _berryRespawnFactor).round();
    final delay = Duration(milliseconds: delayMs.clamp(8000, 60000));
    _berryTimer?.cancel();
    _berryTimer = Timer(delay, _spawnBerry);
  }

  double get _berryRespawnFactor {
    var f = 1.0;
    if (_state.hasResearch('more_berries')) {
      f *= BalanceV0.researchBerryRespawnFactor;
    }
    for (final id in _state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) f *= d.berryRespawnFactor;
    }
    for (final c in _state.herd) {
      if (c.role == CapyRole.storozh) {
        f *= BalanceV0.roleStorozhBerryFactor;
      }
    }
    return f.clamp(0.5, 1.0);
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
    final others = [for (final c in existing) c.position];
    final rect = WorldZones.meadowRectForHerd(herdCount);
    final from = others.isEmpty
        ? Offset((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2)
        : others.last;
    // Placement uses its own stream so a longer search does not reshuffle
    // taps, twins, and the cozy-session balance sims.
    final placeRng = Random(0x51EED + existing.length * 97 + herdCount);
    return CapyWander.pickTarget(
      from: from,
      random01: placeRng.nextDouble,
      herdCount: herdCount,
      others: others,
      mudCenter: _mudPresent ? _mudCenter : null,
      meadowSize: CapyWander.fallbackMeadow,
      minDist: BalanceV0.minSpawnSeparation * 0.5,
      spreadSalt: (existing.length * 0.173) % 1.0,
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
    final reached = WorldZones.gladeForFamilyPower(state.familyPower);
    if (reached.index <= state.sunnyGladeAnnounced) return state;

    var nextId = state.nextId;
    final meadows = Map<String, MeadowSnapshot>.from(
      state.withActiveSynced().meadows,
    );

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
    final meadows = Map<String, MeadowSnapshot>.from(
      state.withActiveSynced().meadows,
    );
    var dirty = false;
    final toFill = <SunnyGlade>[
      for (final g in WorldZones.glades)
        if (g.index <= state.sunnyGladeAnnounced) g,
      if (state.mistyBiomeUnlocked) WorldZones.mistEdge,
    ];
    for (final g in toFill) {
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
    if (_mudPresent) {
      _mudCenter = _pickMudCenter(
        _meadowKeyForCount(target.herdCount),
        herd: target.herd,
      );
    }

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

  /// Prestige v0: Great Glade + Капи Lv.4 → first Уют + Туманный бор stub.
  GameState _maybeUnlockMistyBiome(GameState state, {required bool announce}) {
    if (state.mistyBiomeUnlocked) return state;
    if (state.sunnyGladeAnnounced < 3) return state;

    var maxLv = state.maxCapyLevel;
    for (final snap in state.meadows.values) {
      for (final c in snap.herd) {
        if (c.level > maxLv) maxLv = c.level;
      }
    }
    if (maxLv < 4) return state;

    var nextId = state.nextId;
    final meadows = Map<String, MeadowSnapshot>.from(
      state.withActiveSynced().meadows,
    );
    final existing = meadows[WorldZones.mistEdgeMeadowId];
    if (existing == null || existing.herd.isEmpty) {
      final built = _buildStarterHerd(
        meadowId: WorldZones.mistEdgeMeadowId,
        startNextId: nextId,
        count: BalanceV0.meadowStarterHerdSize,
      );
      nextId = built.nextId;
      meadows[WorldZones.mistEdgeMeadowId] = MeadowSnapshot(herd: built.herd);
    }

    if (announce && _ready) {
      _gladeUnlockToast = WorldZones.mistEdge.unlockToastRu;
      _lastGladeGrassReward = BalanceV0.gladeUnlockGrass;
    }

    return state.copyWith(
      mistyBiomeUnlocked: true,
      uyut: state.uyut + BalanceV0.firstMistyUyutGrant,
      grass:
          state.grass + (announce && _ready ? BalanceV0.gladeUnlockGrass : 0),
      meadows: meadows,
      nextId: nextId,
    );
  }

  void _setState(GameState next) {
    // Reclamp to active Sunny Glade; soft-announce when a new glade opens.
    var state = _clampHerdToMeadow(next);
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
    state = _sanitizeTwins(state);
    state = _syncGladeAnnounced(state, announce: true);
    state = _maybeUnlockMistyBiome(state, announce: true);
    state = _checkGoals(state, celebrate: true);
    _state = state;
    notifyListeners();
    _schedulePersist();
  }

  /// Write soon. Ticks change the state every 50 ms, so the pending write is
  /// never pushed back — otherwise live play would never be saved.
  void _schedulePersist() {
    if (_persistTimer?.isActive ?? false) return;
    _persistTimer = Timer(
      const Duration(milliseconds: BalanceV0.persistIntervalMs),
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
        mistyBiomeUnlocked: state.mistyBiomeUnlocked,
        activeMeadowId: state.activeMeadowId,
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
        mistyBiomeUnlocked: state.mistyBiomeUnlocked,
        activeMeadowId: state.activeMeadowId,
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
            _random.nextDouble() < BalanceV0.twinLingerChance) {
          return state; // linger a bit longer
        }
      }
    }
    // Quiet gaps so sparkle stays a skill window, not a permanent glow.
    final markChance = (BalanceV0.twinMarkChance + _twinMarkChanceBonus).clamp(
      0.0,
      0.95,
    );
    if (_random.nextDouble() > markChance) {
      return state.copyWith(clearTwin: true);
    }
    final pick = eligible[_random.nextInt(eligible.length)].value;
    final shuffled = List<Capybara>.from(pick)..shuffle(_random);
    return state.copyWith(twinIdA: shuffled[0].id, twinIdB: shuffled[1].id);
  }

  // --- Multipliers v0: food / places / roles / decor / research ---

  /// Convert grass into one food unit of [food].
  bool buyFood(FamilyFood food) {
    final cost = switch (food) {
      FamilyFood.travka => BalanceV0.grassToTravkaCost,
      FamilyFood.yagody => BalanceV0.grassToYagodyCost,
      FamilyFood.oreshki => BalanceV0.grassToOreshkiCost,
    };
    if (_state.grass < cost) return false;
    _setState(
      _state.copyWith(grass: _state.grass - cost, food: _state.food.add(food)),
    );
    lastDroppedFood = food;
    return true;
  }

  /// Feed selected / given food to the family (temporary boost).
  bool feedFamily([FamilyFood? food]) {
    final kind = food ?? _selectedFood;
    final nextInv = _state.food.trySpend(kind);
    if (nextInv == null) return false;
    _setState(_state.copyWith(food: nextInv));
    _foodBoostKind = kind;
    final dur = switch (kind) {
      FamilyFood.travka => BalanceV0.foodTravkaDuration,
      FamilyFood.yagody => BalanceV0.foodYagodyDuration,
      FamilyFood.oreshki => BalanceV0.foodOreshkiDuration,
    };
    _foodBoostUntil = _now().add(dur);
    if (kind == FamilyFood.yagody) {
      addProgress(BalanceV0.foodYagodyProgressBurst, fromTap: false);
    }
    notifyListeners();
    return true;
  }

  bool get canFeedSelected => _state.food.countOf(_selectedFood) > 0;

  /// True if [normalized] is inside a cozy place hit circle.
  CozyPlaceKind? placeAt(Offset normalized) {
    for (final kind in CozyPlaceKind.values) {
      if (kind == CozyPlaceKind.tent && !_state.tentUnlocked) continue;
      final (cx, cy) = kind.center;
      final dx = normalized.dx - cx;
      final dy = normalized.dy - cy;
      if (sqrt(dx * dx + dy * dy) <= BalanceV0.placeHitRadius) {
        return kind;
      }
    }
    return null;
  }

  bool isOverPlace(Offset normalized) => placeAt(normalized) != null;

  /// Drag capy onto place OR tap place → activate (with cooldown).
  bool tryActivatePlace(CozyPlaceKind kind, {String? capyId, Offset? standAt}) {
    if (kind == CozyPlaceKind.tent && !_state.tentUnlocked) return false;
    if (isPlaceOnCooldown(kind)) return false;

    if (capyId != null) {
      final at = standAt ?? Offset(kind.center.$1, kind.center.$2);
      updatePosition(
        capyId,
        WorldZones.clampToMeadow(
          at,
          herdCount: _meadowKeyForCount(_state.herdCount),
        ),
      );
    }

    final dur = switch (kind) {
      CozyPlaceKind.pen => BalanceV0.penBoostDuration,
      CozyPlaceKind.warmStone => BalanceV0.warmStoneDuration,
      CozyPlaceKind.tent => BalanceV0.tentDuration,
    };
    final cd = switch (kind) {
      CozyPlaceKind.pen => BalanceV0.penCooldown,
      CozyPlaceKind.warmStone => BalanceV0.warmStoneCooldown,
      CozyPlaceKind.tent => BalanceV0.tentCooldown,
    };
    _placeBoostKind = kind;
    _placeBoostUntil = _now().add(dur);
    _placeCooldownUntil[kind] = _now().add(cd);
    notifyListeners();
    return true;
  }

  /// Assign [role] to capy; respects role slot limit. Null clears.
  bool assignRole(String capyId, CapyRole? role) {
    final capy = _find(capyId);
    if (capy == null) return false;
    if (role != null) {
      // Count slots excluding this capy's current role.
      var used = 0;
      for (final c in _state.herd) {
        if (c.id == capyId) continue;
        if (c.role != null) used++;
      }
      for (final e in _state.meadows.entries) {
        if (e.key == _state.activeMeadowId) continue;
        for (final c in e.value.herd) {
          if (c.role != null) used++;
        }
      }
      if (capy.role == null && used >= _state.roleSlots) return false;
    }
    final herd = [
      for (final c in _state.herd)
        if (c.id == capyId)
          c.copyWith(role: role, clearRole: role == null)
        else
          c,
    ];
    _setState(_state.copyWith(herd: herd));
    if (role != null) {
      _lastRoleToast = role.assignToastRu;
    }
    return true;
  }

  /// Buy a decor item if affordable and research-unlocked.
  bool buyDecor(HomeDecor decor) {
    if (_state.ownsDecor(decor)) return false;
    final req = decor.requiresResearch;
    if (req != null && !_state.hasResearch(req)) return false;
    if (_state.grass < decor.grassCost) return false;
    if (_state.uyut < decor.uyutCost) return false;
    final owned = Set<String>.from(_state.ownedDecor)..add(decor.id);
    final placed = Set<String>.from(_state.placedDecor)..add(decor.id);
    _setState(
      _state.copyWith(
        grass: _state.grass - decor.grassCost,
        uyut: _state.uyut - decor.uyutCost,
        ownedDecor: owned,
        placedDecor: placed,
      ),
    );
    return true;
  }

  bool togglePlaceDecor(HomeDecor decor) {
    if (!_state.ownsDecor(decor)) return false;
    final placed = Set<String>.from(_state.placedDecor);
    if (placed.contains(decor.id)) {
      placed.remove(decor.id);
    } else {
      placed.add(decor.id);
    }
    _setState(_state.copyWith(placedDecor: placed));
    return true;
  }

  /// Unlock a research node if prereqs + cost met.
  bool unlockResearch(String nodeId) {
    final node = UyutResearch.byId(nodeId);
    if (node == null) return false;
    if (!UyutResearch.canUnlock(
      node: node,
      unlocked: _state.researched,
      grass: _state.grass,
      uyut: _state.uyut,
    )) {
      return false;
    }
    final researched = Set<String>.from(_state.researched)..add(node.id);
    var roleSlots = _state.roleSlots;
    var tent = _state.tentUnlocked;
    if (node.id == 'role_slot_2') roleSlots = 2;
    if (node.id == 'unlock_tent') tent = true;
    _setState(
      _state.copyWith(
        grass: _state.grass - node.grassCost,
        uyut: _state.uyut - node.uyutCost,
        researched: researched,
        roleSlots: roleSlots,
        tentUnlocked: tent,
      ),
    );
    return true;
  }

  /// Force a twin mark (tests).
  @visibleForTesting
  void debugMarkTwins(String a, String b) {
    _setState(_state.copyWith(twinIdA: a, twinIdB: b));
  }

  /// Headless tick for progression sims: the live tick body, any [dt].
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
    _advanceClock(dt, _now());
  }

  /// Newest chapter (not a visit back to an older land).
  bool get playingNewestLand {
    for (final land in _state.otherLands) {
      if (land.chapter > _state.landChapter) return false;
    }
    return true;
  }

  /// Roadmap step 8, after prestige v0 is lived: mist unlocked, visited,
  /// at least one spark, and someone stays home. Does not replace Туманный бор.
  bool get rocketUnlocked =>
      playingNewestLand &&
      _state.mistyBiomeUnlocked &&
      _state.visitedMist &&
      _state.uyut >= 1 &&
      _state.totalHerdAcrossMeadows >= 2;

  bool get hasLandsGallery =>
      _state.landChapter > 0 || _state.otherLands.isNotEmpty;

  /// Arrival meadow: the newest land, before its own glades open.
  bool get onFreshNewLand =>
      playingNewestLand &&
      _state.landChapter > 0 &&
      _state.sunnyGladeAnnounced == 0 &&
      !_state.mistyBiomeUnlocked;

  /// Send the youngest capy on. Grass and sparks stay. Old land is archived.
  bool launchToNewLand() {
    if (!_ready || !rocketUnlocked) return false;
    final synced = _state.withActiveSynced();
    if (synced.totalHerdAcrossMeadows < 2) return false;
    Capybara? traveler;
    String? fromMeadow;
    for (final entry in synced.meadows.entries) {
      for (final capy in entry.value.herd) {
        if (traveler == null || capy.level < traveler.level) {
          traveler = capy;
          fromMeadow = entry.key;
        }
      }
    }
    if (traveler == null || fromMeadow == null) return false;

    final meadows = Map<String, MeadowSnapshot>.from(synced.meadows);
    final snap = meadows[fromMeadow]!;
    final leftBehind = [
      for (final capy in snap.herd)
        if (capy.id != traveler.id) capy,
    ];
    meadows[fromMeadow] = snap.copyWith(herd: leftBehind);
    final travelerLeftActive = fromMeadow == synced.activeMeadowId;
    final archive = FamilyLand.fromState(
      synced.copyWith(
        meadows: meadows,
        herd: travelerLeftActive ? leftBehind : synced.herd,
        clearTwin:
            travelerLeftActive &&
            (synced.twinIdA == traveler.id || synced.twinIdB == traveler.id),
      ),
    );

    final grass = synced.grass;
    final uyut = synced.uyut;
    var nextId = synced.nextId;
    final arrived = traveler.copyWith(
      position: const Offset(0.30, 0.72),
      clearRole: true,
    );
    final companion = Capybara(
      id: 'c$nextId',
      level: BalanceV0.startingLevel,
      position: const Offset(0.68, 0.74),
    );
    nextId += 1;
    final freshHerd = [arrived, companion];
    _setState(
      GameState(
        herdProgress: 0,
        herd: freshHerd,
        nextId: nextId,
        savedAtMs: synced.savedAtMs,
        lastDailyClaimYmd: synced.lastDailyClaimYmd,
        sunnyGladeAnnounced: 0,
        grass: grass,
        sessionGoalIndex: 0,
        activeMeadowId: WorldZones.starterMeadowId,
        meadows: {WorldZones.starterMeadowId: MeadowSnapshot(herd: freshHerd)},
        uyut: uyut,
        mistyBiomeUnlocked: false,
        food: synced.food,
        ownedDecor: synced.ownedDecor,
        placedDecor: const {},
        researched: synced.researched,
        roleSlots: synced.roleSlots,
        tentUnlocked: synced.tentUnlocked,
        visitedMist: false,
        landChapter: synced.landChapter + 1,
        otherLands: [...synced.otherLands, archive],
      ),
    );
    return _state.grass == grass &&
        _state.uyut == uyut &&
        _state.landChapter > 0;
  }

  /// Swap the live land with an archived one. Nothing is deleted.
  bool visitLand(int chapter) {
    if (!_ready) return false;
    if (chapter == _state.landChapter) return true;
    final others = List<FamilyLand>.from(_state.otherLands);
    final index = others.indexWhere((land) => land.chapter == chapter);
    if (index < 0) return false;
    final target = others[index];
    others[index] = FamilyLand.fromState(_state);
    final grass = _state.grass;
    final uyut = _state.uyut;
    _setState(target.toGameState(globals: _state, otherLands: others));
    return _state.landChapter == chapter &&
        _state.grass == grass &&
        _state.uyut == uyut;
  }

  /// Give [role] to the first capy on this meadow who has none.
  bool assignRoleToFreeCapy(CapyRole role) {
    for (final capy in _state.herd) {
      if (capy.role == role) return true;
    }
    for (final entry in _state.meadows.entries) {
      if (entry.key == _state.activeMeadowId) continue;
      for (final capy in entry.value.herd) {
        if (capy.role == role) return true;
      }
    }
    for (final capy in _state.herd) {
      if (capy.role == null) return assignRole(capy.id, role);
    }
    return false;
  }

  /// Take [role] off whoever holds it, on any meadow of this land.
  bool clearRole(CapyRole role) {
    final synced = _state.withActiveSynced();
    final meadows = Map<String, MeadowSnapshot>.from(synced.meadows);
    var changed = false;
    for (final entry in meadows.entries) {
      final next = <Capybara>[];
      for (final capy in entry.value.herd) {
        if (capy.role == role) {
          changed = true;
          next.add(capy.copyWith(clearRole: true));
        } else {
          next.add(capy);
        }
      }
      meadows[entry.key] = entry.value.copyWith(herd: next);
    }
    if (!changed) return false;
    final active = meadows[synced.activeMeadowId]!;
    _setState(
      synced.copyWith(
        meadows: meadows,
        herd: active.herd,
        herdProgress: active.herdProgress,
        twinIdA: active.twinIdA,
        twinIdB: active.twinIdB,
        clearTwin: active.twinIdA == null || active.twinIdB == null,
      ),
    );
    return true;
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
    _disposed = true;
    // Before load finished [_state] is the empty placeholder — never write it.
    if (_ready) {
      unawaited(_persistence.save(_withSavedAt(_state)));
    }
    super.dispose();
  }
}
