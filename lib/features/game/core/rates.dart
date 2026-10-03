import '../models/balance.dart';
import '../models/multipliers/multipliers.dart';
import 'game_core.dart';

/// Every multiplier and derived number of the family, in one place.
///
/// Sections follow the boost groups of WBS 11.18: «Сейчас» (temporary),
/// «Семья» (roles, decor), «Память» (research, Уют sparks).
class GameRates extends GamePart {
  GameRates(super.core);

  /// Live auto fill rate (fraction/sec) — full stack for HUD «+X%/с».
  /// Order: base → temp (mud/grass/food/places) → roles → decor → research → Уют.
  double get autoRatePerSecond {
    return BalanceV0.autoProgressPerSecond *
        tempLayerMultiplier *
        roleAutoMultiplier *
        decorAutoMultiplier *
        researchAutoMultiplier *
        uyutMultiplier;
  }

  // --- Сейчас: temporary boosts ---

  /// Temporary layer: mud/grass take max; food & places multiply on top.
  double get tempLayerMultiplier {
    final boosts = core.boosts;
    var mudGrass = 1.0;
    if (boosts.isMudBoostActive) {
      mudGrass = mudGrass < BalanceV0.mudBoostMultiplier
          ? BalanceV0.mudBoostMultiplier
          : mudGrass;
    }
    if (boosts.isGrassBoostActive) {
      mudGrass = mudGrass < BalanceV0.grassBoostMultiplier
          ? BalanceV0.grassBoostMultiplier
          : mudGrass;
    }
    return mudGrass * foodAutoMultiplier * placeAutoMultiplier;
  }

  double get foodAutoMultiplier {
    final boosts = core.boosts;
    if (!boosts.isFoodBoostActive || boosts.foodBoostKind == null) return 1.0;
    return switch (boosts.foodBoostKind!) {
      FamilyFood.travka => BalanceV0.foodTravkaAutoMult,
      FamilyFood.yagody => BalanceV0.foodYagodyAutoMult,
      FamilyFood.oreshki => BalanceV0.foodOreshkiAutoMult,
    };
  }

  double get placeAutoMultiplier {
    final boosts = core.boosts;
    if (!boosts.isPlaceBoostActive || boosts.placeBoostKind == null) {
      return 1.0;
    }
    return switch (boosts.placeBoostKind!) {
      CozyPlaceKind.warmStone => BalanceV0.warmStoneGrassAutoMult,
      CozyPlaceKind.tent => BalanceV0.tentSpawnMult,
      CozyPlaceKind.pen => 1.0, // magnet/twin only
    };
  }

  double get effectiveMagnetRadius {
    final boosts = core.boosts;
    var r = BalanceV0.magnetRadius;
    if (boosts.isFoodBoostActive && boosts.foodBoostKind == FamilyFood.oreshki) {
      r *= (1.0 + BalanceV0.foodOreshkiMagnetBonus);
    }
    if (boosts.isPlaceBoostActive &&
        boosts.placeBoostKind == CozyPlaceKind.pen) {
      r *= (1.0 + BalanceV0.penMagnetBonus);
    }
    return r;
  }

  double get twinMarkChanceBonus {
    final boosts = core.boosts;
    var b = 0.0;
    if (boosts.isFoodBoostActive && boosts.foodBoostKind == FamilyFood.oreshki) {
      b += BalanceV0.foodOreshkiTwinChanceBonus;
    }
    if (boosts.isPlaceBoostActive &&
        boosts.placeBoostKind == CozyPlaceKind.pen) {
      b += BalanceV0.penTwinChanceBonus;
    }
    return b;
  }

  Duration get mudBoostDuration {
    var d = BalanceV0.mudBoostDuration;
    if (state.hasResearch('longer_mud')) {
      d += BalanceV0.researchMudExtra;
    }
    return d;
  }

  // --- Семья: roles and decor ---

  double get roleAutoMultiplier {
    var bonus = 0.0;
    for (final c in state.herd) {
      if (c.role == CapyRole.nanya) bonus += BalanceV0.roleNanyaAutoBonus;
    }
    return 1.0 + bonus;
  }

  double get decorAutoMultiplier {
    var bonus = 0.0;
    for (final id in state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) bonus += d.autoBonus;
    }
    return 1.0 + bonus;
  }

  int get effectiveMaxHerdSize {
    var cap = BalanceV0.maxHerdSize;
    if (state.hasResearch('soft_cap_plus')) cap += 1;
    for (final c in state.herd) {
      if (c.role == CapyRole.storozh) {
        cap += BalanceV0.roleStorozhSoftCapBonus;
      }
    }
    return cap;
  }

  /// Live RU summary of active role bonuses for Уют / HUD.
  String get activeRoleBonusesRu {
    var nanya = 0;
    var sobi = 0;
    var stor = 0;
    for (final c in state.herd) {
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

  // --- Память: research and Уют sparks ---

  /// Permanent Уют multiplier (1 + uyut * 3%).
  double get uyutMultiplier =>
      1.0 + state.uyut * BalanceV0.uyutAutoBoostPerPoint;

  /// Research does not add a flat auto % in v0 (effects are targeted).
  double get researchAutoMultiplier => 1.0;

  // --- Mixed: finds, grass, berries ---

  double get flowerFindMultiplier {
    var m = 1.0;
    if (state.hasResearch('more_flowers')) {
      m += BalanceV0.researchFlowerBonus;
    }
    for (final id in state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) m += d.flowerBonus;
    }
    for (final c in state.herd) {
      if (c.role == CapyRole.sobiratel) {
        m += BalanceV0.roleSobiratelFindBonus;
      }
    }
    return m;
  }

  double get grassAutoMultiplier {
    var m = uyutMultiplier;
    for (final id in state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) m *= (1.0 + d.grassAutoBonus);
    }
    final boosts = core.boosts;
    if (boosts.isPlaceBoostActive &&
        boosts.placeBoostKind == CozyPlaceKind.warmStone) {
      m *= BalanceV0.warmStoneGrassAutoMult;
    }
    return m;
  }

  double get foodDropChance {
    var c = BalanceV0.flowerFoodDropChance;
    if (state.hasResearch('food_pouch')) {
      c += BalanceV0.researchFoodDropBonus;
    }
    for (final id in state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) c += d.foodDropBonus;
    }
    for (final cap in state.herd) {
      if (cap.role == CapyRole.sobiratel) {
        c += BalanceV0.roleSobiratelFindBonus * 0.5;
      }
    }
    return c.clamp(0.0, 0.85);
  }

  double get berryRespawnFactor {
    var f = 1.0;
    if (state.hasResearch('more_berries')) {
      f *= BalanceV0.researchBerryRespawnFactor;
    }
    for (final id in state.ownedDecor) {
      final d = HomeDecorX.tryParse(id);
      if (d != null) f *= d.berryRespawnFactor;
    }
    for (final c in state.herd) {
      if (c.role == CapyRole.storozh) {
        f *= BalanceV0.roleStorozhBerryFactor;
      }
    }
    return f.clamp(0.5, 1.0);
  }
}
