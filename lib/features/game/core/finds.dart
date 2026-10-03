import 'dart:async';

import '../models/balance.dart';
import '../models/multipliers/multipliers.dart';
import 'game_core.dart';

/// Finds on the meadow: flower taps, the berry basket and its timer, food
/// that drops from flowers.
class GameFinds extends GamePart {
  GameFinds(super.core);

  /// Grass granted by the most recent flower/berry tap (for UI float).
  int lastTapGrass = 0;

  /// Last food granted by flower/buy (UI float); null if none.
  FamilyFood? lastDroppedFood;

  /// Berry basket visibility + next spawn clock.
  bool berryVisible = false;
  Timer? _berryTimer;

  /// Returns progress fraction granted (for floating «+N%» feedback).
  double onFlowerTap() {
    final random = core.random;
    final base =
        BalanceV0.flowerTapGainMin +
        random.nextDouble() *
            (BalanceV0.flowerTapGainMax - BalanceV0.flowerTapGainMin);
    final gain = base * core.rates.flowerFindMultiplier;
    final grass =
        BalanceV0.flowerTapGrassMin +
        random.nextInt(
          BalanceV0.flowerTapGrassMax - BalanceV0.flowerTapGrassMin + 1,
        );
    lastTapGrass = grass;
    var food = state.food;
    final dropped = _maybeDropFood();
    if (dropped != null) {
      food = food.add(dropped);
      lastDroppedFood = dropped;
    } else {
      lastDroppedFood = null;
    }
    core.state = state.copyWith(grass: state.grass + grass, food: food);
    core.herd.addProgress(gain, fromTap: true);
    return gain;
  }

  FamilyFood? _maybeDropFood() {
    final loot = core.lootRandom;
    if (loot.nextDouble() > core.rates.foodDropChance) return null;
    final wT = BalanceV0.foodDropTravkaWeight;
    final wY = BalanceV0.foodDropYagodyWeight;
    final wO = BalanceV0.foodDropOreshkiWeight;
    final roll = loot.nextDouble() * (wT + wY + wO);
    if (roll < wT) return FamilyFood.travka;
    if (roll < wT + wY) return FamilyFood.yagody;
    return FamilyFood.oreshki;
  }

  /// Returns progress fraction granted, or null if basket not visible.
  double? onBerryTap() {
    if (!berryVisible) return null;
    final random = core.random;
    final gain =
        BalanceV0.berryTapGainMin +
        random.nextDouble() *
            (BalanceV0.berryTapGainMax - BalanceV0.berryTapGainMin);
    final grass =
        BalanceV0.berryGrassMin +
        random.nextInt(BalanceV0.berryGrassMax - BalanceV0.berryGrassMin + 1);
    lastTapGrass = grass;
    core.state = state.copyWith(grass: state.grass + grass);
    core.herd.addProgress(gain, fromTap: true);
    berryVisible = false;
    _scheduleBerryRespawn();
    core.notify();
    return gain;
  }

  void scheduleFirstBerry() {
    final span = BalanceV0.berryFirstSpawnMax - BalanceV0.berryFirstSpawnMin;
    final delay =
        BalanceV0.berryFirstSpawnMin +
        Duration(milliseconds: core.random.nextInt(span.inMilliseconds + 1));
    _berryTimer?.cancel();
    _berryTimer = Timer(delay, _spawnBerry);
  }

  void _scheduleBerryRespawn() {
    final span = BalanceV0.berryRespawnMax - BalanceV0.berryRespawnMin;
    var delayMs =
        BalanceV0.berryRespawnMin.inMilliseconds +
        core.random.nextInt(span.inMilliseconds + 1);
    delayMs = (delayMs * core.rates.berryRespawnFactor).round();
    final delay = Duration(milliseconds: delayMs.clamp(8000, 60000));
    _berryTimer?.cancel();
    _berryTimer = Timer(delay, _spawnBerry);
  }

  void _spawnBerry() {
    berryVisible = true;
    core.notify();
  }

  /// Force berry visible (tests / sims).
  void debugShowBerry() {
    berryVisible = true;
    core.notify();
  }

  void dispose() {
    _berryTimer?.cancel();
  }
}
