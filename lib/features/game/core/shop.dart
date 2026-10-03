import 'dart:ui';

import '../models/balance.dart';
import '../models/multipliers/multipliers.dart';
import '../models/world_zones.dart';
import 'game_core.dart';

/// Spending grass and sparks: call a capy, grass boost, food, cozy places,
/// decor, research.
class GameShop extends GamePart {
  GameShop(super.core);

  /// Selected food for next feed (UI picker).
  FamilyFood selectedFood = FamilyFood.travka;

  void selectFood(FamilyFood food) {
    selectedFood = food;
    core.notify();
  }

  /// Spend grass to spawn a Lv.1 capy if under soft herd cap.
  bool spendCallCapy() {
    if (state.grass < BalanceV0.callCapyGrassCost) return false;
    if (state.herdCount >= core.rates.effectiveMaxHerdSize) return false;
    var next = state.copyWith(grass: state.grass - BalanceV0.callCapyGrassCost);
    next = core.herd.spawnCapybara(next, level: BalanceV0.startingLevel);
    core.commit(next);
    return true;
  }

  /// Spend grass for a short auto-progress boost (weaker than mud).
  bool spendGrassBoost() {
    if (state.grass < BalanceV0.grassBoostCost) return false;
    core.commit(state.copyWith(grass: state.grass - BalanceV0.grassBoostCost));
    core.boosts.startGrass();
    core.notify();
    return true;
  }

  bool get canCallCapy =>
      state.grass >= BalanceV0.callCapyGrassCost &&
      state.herdCount < core.rates.effectiveMaxHerdSize;

  /// Why «Позвать капи» is gray. Null while the call is available.
  /// A full семья wins over low grass — leftover grass must not look like a bug.
  String? get callCapyBlockedReason {
    if (state.herdCount >= core.rates.effectiveMaxHerdSize) {
      return 'Семья полная';
    }
    if (state.grass < BalanceV0.callCapyGrassCost) return 'Не хватает травы';
    return null;
  }

  bool get canGrassBoost => state.grass >= BalanceV0.grassBoostCost;

  /// Convert grass into one food unit of [food].
  bool buyFood(FamilyFood food) {
    final cost = switch (food) {
      FamilyFood.travka => BalanceV0.grassToTravkaCost,
      FamilyFood.yagody => BalanceV0.grassToYagodyCost,
      FamilyFood.oreshki => BalanceV0.grassToOreshkiCost,
    };
    if (state.grass < cost) return false;
    core.commit(
      state.copyWith(grass: state.grass - cost, food: state.food.add(food)),
    );
    core.finds.lastDroppedFood = food;
    return true;
  }

  /// Feed selected / given food to the family (temporary boost).
  bool feedFamily([FamilyFood? food]) {
    final kind = food ?? selectedFood;
    final nextInv = state.food.trySpend(kind);
    if (nextInv == null) return false;
    core.commit(state.copyWith(food: nextInv));
    core.boosts.startFood(kind);
    if (kind == FamilyFood.yagody) {
      core.herd.addProgress(BalanceV0.foodYagodyProgressBurst, fromTap: false);
    }
    core.notify();
    return true;
  }

  bool get canFeedSelected => state.food.countOf(selectedFood) > 0;

  /// Drag capy onto place OR tap place → activate (with cooldown).
  bool tryActivatePlace(CozyPlaceKind kind, {String? capyId, Offset? standAt}) {
    if (kind == CozyPlaceKind.tent && !state.tentUnlocked) return false;
    if (core.boosts.isPlaceOnCooldown(kind)) return false;

    if (capyId != null) {
      final at = standAt ?? Offset(kind.center.$1, kind.center.$2);
      core.herd.updatePosition(
        capyId,
        WorldZones.clampToMeadow(at, herdCount: core.meadows.meadowKey),
      );
    }

    core.boosts.startPlace(kind);
    core.notify();
    return true;
  }

  /// Buy a decor item if affordable and research-unlocked.
  bool buyDecor(HomeDecor decor) {
    if (state.ownsDecor(decor)) return false;
    final req = decor.requiresResearch;
    if (req != null && !state.hasResearch(req)) return false;
    if (state.grass < decor.grassCost) return false;
    if (state.uyut < decor.uyutCost) return false;
    final owned = Set<String>.from(state.ownedDecor)..add(decor.id);
    final placed = Set<String>.from(state.placedDecor)..add(decor.id);
    core.commit(
      state.copyWith(
        grass: state.grass - decor.grassCost,
        uyut: state.uyut - decor.uyutCost,
        ownedDecor: owned,
        placedDecor: placed,
      ),
    );
    return true;
  }

  bool togglePlaceDecor(HomeDecor decor) {
    if (!state.ownsDecor(decor)) return false;
    final placed = Set<String>.from(state.placedDecor);
    if (placed.contains(decor.id)) {
      placed.remove(decor.id);
    } else {
      placed.add(decor.id);
    }
    core.commit(state.copyWith(placedDecor: placed));
    return true;
  }

  /// Unlock a research node if prereqs + cost met.
  bool unlockResearch(String nodeId) {
    final node = UyutResearch.byId(nodeId);
    if (node == null) return false;
    if (!UyutResearch.canUnlock(
      node: node,
      unlocked: state.researched,
      grass: state.grass,
      uyut: state.uyut,
    )) {
      return false;
    }
    final researched = Set<String>.from(state.researched)..add(node.id);
    var roleSlots = state.roleSlots;
    var tent = state.tentUnlocked;
    if (node.id == 'role_slot_2') roleSlots = 2;
    if (node.id == 'unlock_tent') tent = true;
    core.commit(
      state.copyWith(
        grass: state.grass - node.grassCost,
        uyut: state.uyut - node.uyutCost,
        researched: researched,
        roleSlots: roleSlots,
        tentUnlocked: tent,
      ),
    );
    return true;
  }
}
