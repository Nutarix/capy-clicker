import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/balance.dart';
import '../models/capybara.dart';
import '../models/game_state.dart';
import '../persistence/game_persistence.dart';

/// Owns [GameState], tick loop, spawn/merge, mud boost, berry basket,
/// offline progress, soft daily bonus, persist.
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

  /// Progress granted on this launch from offline elapsed time (0 if none).
  double _offlineProgressGranted = 0;

  /// Elapsed seconds used for the offline grant (capped).
  int _offlineSecondsApplied = 0;

  GameState get state => _state;
  bool get isReady => _ready;
  double get cameraZoom => BalanceV0.zoomForHerdCount(_state.herdCount);

  bool get isMudBoostActive =>
      _mudBoostUntil != null && _now().isBefore(_mudBoostUntil!);

  double get mudBoostRemainingSeconds {
    if (!isMudBoostActive) return 0;
    return _mudBoostUntil!.difference(_now()).inMilliseconds / 1000.0;
  }

  String? get wallowingCapyId => _wallowingCapyId;
  bool get isBerryVisible => _berryVisible;
  String? get mergeFlashId => _mergeFlashId;

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
    _setState(_state.copyWith(lastDailyClaimYmd: day));
    addProgress(BalanceV0.dailyBonusProgress, fromTap: false);
    return true;
  }

  /// Load save (or bootstrap), grant capped offline progress, start ticker.
  Future<void> init() async {
    final loaded = await _persistence.load();
    if (loaded != null && loaded.herd.isNotEmpty) {
      _state = loaded;
      _applyOfflineProgress();
    } else {
      _state = _bootstrap();
      await _persistence.save(_withSavedAt(_state));
    }
    _ready = true;
    _lastTick = _now();
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

    // Clear expired mud boost.
    if (_mudBoostUntil != null && now.isAfter(_mudBoostUntil!)) {
      _mudBoostUntil = null;
      notifyListeners();
    }

    final mult = isMudBoostActive ? BalanceV0.mudBoostMultiplier : 1.0;
    addProgress(BalanceV0.autoProgressPerSecond * mult * dt, fromTap: false);
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

  void onFlowerTap() {
    final gain =
        BalanceV0.flowerTapGainMin +
        _random.nextDouble() *
            (BalanceV0.flowerTapGainMax - BalanceV0.flowerTapGainMin);
    addProgress(gain, fromTap: true);
  }

  void onBerryTap() {
    if (!_berryVisible) return;
    final gain =
        BalanceV0.berryTapGainMin +
        _random.nextDouble() *
            (BalanceV0.berryTapGainMax - BalanceV0.berryTapGainMin);
    addProgress(gain, fromTap: true);
    _berryVisible = false;
    _scheduleBerryRespawn();
    notifyListeners();
  }

  /// Drop a capybara onto the mud puddle → wallow anim + temporary boost.
  bool tryMudWallow(String capyId) {
    final capy = _find(capyId);
    if (capy == null) return false;

    // Snap capy onto puddle center while animating.
    updatePosition(
      capyId,
      const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY),
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

    final newLevel = dragged.level + 1;
    final remaining = _state.herd
        .where((c) => c.id != draggedId && c.id != targetId)
        .toList();

    final merged = Capybara(
      id: 'c${_state.nextId}',
      level: newLevel,
      position: target.position,
    );

    _setState(
      _state.copyWith(herd: [...remaining, merged], nextId: _state.nextId + 1),
    );
    _triggerMergeFlash(merged.id);
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
    final clamped = Offset(
      normalized.dx.clamp(0.08, 0.92),
      normalized.dy.clamp(0.2, 0.88),
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
    const attempts = 24;
    for (var i = 0; i < attempts; i++) {
      final candidate = Offset(
        0.12 + _random.nextDouble() * 0.76,
        0.28 + _random.nextDouble() * 0.55,
      );
      // Keep away from mud puddle and berry spot.
      final mudDx = candidate.dx - BalanceV0.mudCenterX;
      final mudDy = candidate.dy - BalanceV0.mudCenterY;
      if (sqrt(mudDx * mudDx + mudDy * mudDy) < BalanceV0.mudHitRadius + 0.08) {
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
    return Offset(
      (0.5 + 0.22 * cos(angle)).clamp(0.12, 0.88),
      (0.55 + 0.18 * sin(angle)).clamp(0.28, 0.85),
    );
  }

  void _setState(GameState next) {
    _state = next;
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
