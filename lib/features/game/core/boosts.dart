import '../models/balance.dart';
import '../models/multipliers/multipliers.dart';
import 'game_core.dart';

/// Temporary boosts on the clock: mud, grass, food, cozy places, cooldowns.
/// Session-only — never written to the save.
class GameBoosts extends GamePart {
  GameBoosts(super.core);

  /// Active mud boost ends at this instant (null = inactive).
  DateTime? mudBoostUntil;

  /// Grass-spend auto boost (weaker than mud).
  DateTime? grassBoostUntil;

  /// Active family-food temporary boost.
  FamilyFood? foodBoostKind;
  DateTime? foodBoostUntil;

  /// Active cozy-place temporary boost.
  CozyPlaceKind? placeBoostKind;
  DateTime? placeBoostUntil;

  /// Per-place cooldown ends-at.
  final Map<CozyPlaceKind, DateTime> placeCooldownUntil = {};

  DateTime _now() => core.now();

  bool get isMudBoostActive =>
      mudBoostUntil != null && _now().isBefore(mudBoostUntil!);

  double get mudBoostRemainingSeconds {
    if (!isMudBoostActive) return 0;
    return mudBoostUntil!.difference(_now()).inMilliseconds / 1000.0;
  }

  bool get isGrassBoostActive =>
      grassBoostUntil != null && _now().isBefore(grassBoostUntil!);

  double get grassBoostRemainingSeconds {
    if (!isGrassBoostActive) return 0;
    return grassBoostUntil!.difference(_now()).inMilliseconds / 1000.0;
  }

  bool get isFoodBoostActive =>
      foodBoostUntil != null && _now().isBefore(foodBoostUntil!);

  double get foodBoostRemainingSeconds {
    if (!isFoodBoostActive) return 0;
    return foodBoostUntil!.difference(_now()).inMilliseconds / 1000.0;
  }

  FamilyFood? get activeFoodBoost => isFoodBoostActive ? foodBoostKind : null;

  bool get isPlaceBoostActive =>
      placeBoostUntil != null && _now().isBefore(placeBoostUntil!);

  double get placeBoostRemainingSeconds {
    if (!isPlaceBoostActive) return 0;
    return placeBoostUntil!.difference(_now()).inMilliseconds / 1000.0;
  }

  CozyPlaceKind? get activePlaceBoost =>
      isPlaceBoostActive ? placeBoostKind : null;

  bool isPlaceOnCooldown(CozyPlaceKind kind) {
    final until = placeCooldownUntil[kind];
    return until != null && _now().isBefore(until);
  }

  double placeCooldownRemaining(CozyPlaceKind kind) {
    final until = placeCooldownUntil[kind];
    if (until == null || !_now().isBefore(until)) return 0;
    return until.difference(_now()).inMilliseconds / 1000.0;
  }

  /// Clear boosts that ended by [now]. True when something ended.
  bool expire(DateTime now) {
    var dirty = false;
    if (mudBoostUntil != null && now.isAfter(mudBoostUntil!)) {
      mudBoostUntil = null;
      dirty = true;
    }
    if (grassBoostUntil != null && now.isAfter(grassBoostUntil!)) {
      grassBoostUntil = null;
      dirty = true;
    }
    if (foodBoostUntil != null && now.isAfter(foodBoostUntil!)) {
      foodBoostUntil = null;
      foodBoostKind = null;
      dirty = true;
    }
    if (placeBoostUntil != null && now.isAfter(placeBoostUntil!)) {
      placeBoostUntil = null;
      placeBoostKind = null;
      dirty = true;
    }
    return dirty;
  }

  void startMud() {
    mudBoostUntil = _now().add(core.rates.mudBoostDuration);
  }

  void startGrass() {
    grassBoostUntil = _now().add(BalanceV0.grassBoostDuration);
  }

  void startFood(FamilyFood kind) {
    foodBoostKind = kind;
    final dur = switch (kind) {
      FamilyFood.travka => BalanceV0.foodTravkaDuration,
      FamilyFood.yagody => BalanceV0.foodYagodyDuration,
      FamilyFood.oreshki => BalanceV0.foodOreshkiDuration,
    };
    foodBoostUntil = _now().add(dur);
  }

  void startPlace(CozyPlaceKind kind) {
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
    placeBoostKind = kind;
    placeBoostUntil = _now().add(dur);
    placeCooldownUntil[kind] = _now().add(cd);
  }
}
