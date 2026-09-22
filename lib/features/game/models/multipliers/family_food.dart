/// Family food types — spendable temporary boosts for the Семья.
enum FamilyFood {
  /// Steady idle auto boost.
  travka,

  /// Burst-ish short stronger auto.
  yagody,

  /// Rarer: twin/magnet luck OR strong short boost.
  oreshki,
}

extension FamilyFoodX on FamilyFood {
  String get id => name;


  /// Soft-pixel icon (chroma-keyed).
  String get assetPath => switch (this) {
        FamilyFood.travka => 'assets/images/food_travka.png',
        FamilyFood.yagody => 'assets/images/food_yagody.png',
        FamilyFood.oreshki => 'assets/images/food_oreshki.png',
      };

  String get emoji => switch (this) {
        FamilyFood.travka => '🌱',
        FamilyFood.yagody => '🫐',
        FamilyFood.oreshki => '🥜',
      };

  String get labelRu => switch (this) {
        FamilyFood.travka => 'Травка',
        FamilyFood.yagody => 'Ягоды',
        FamilyFood.oreshki => 'Орешки',
      };

  String get effectRu => switch (this) {
        FamilyFood.travka => 'спокойный авто-буст',
        FamilyFood.yagody => 'короткий сильный авто',
        FamilyFood.oreshki => 'удача слияния + авто',
      };

  static FamilyFood? tryParse(String? raw) {
    if (raw == null) return null;
    for (final f in FamilyFood.values) {
      if (f.id == raw) return f;
    }
    return null;
  }
}

/// Persisted food inventory counts.
class FoodInventory {
  const FoodInventory({
    this.travka = 0,
    this.yagody = 0,
    this.oreshki = 0,
  });

  final int travka;
  final int yagody;
  final int oreshki;

  int countOf(FamilyFood food) => switch (food) {
        FamilyFood.travka => travka,
        FamilyFood.yagody => yagody,
        FamilyFood.oreshki => oreshki,
      };

  int get total => travka + yagody + oreshki;

  FoodInventory copyWith({int? travka, int? yagody, int? oreshki}) {
    return FoodInventory(
      travka: travka ?? this.travka,
      yagody: yagody ?? this.yagody,
      oreshki: oreshki ?? this.oreshki,
    );
  }

  FoodInventory add(FamilyFood food, [int n = 1]) {
    if (n <= 0) return this;
    return switch (food) {
      FamilyFood.travka => copyWith(travka: travka + n),
      FamilyFood.yagody => copyWith(yagody: yagody + n),
      FamilyFood.oreshki => copyWith(oreshki: oreshki + n),
    };
  }

  FoodInventory? trySpend(FamilyFood food, [int n = 1]) {
    if (countOf(food) < n) return null;
    return switch (food) {
      FamilyFood.travka => copyWith(travka: travka - n),
      FamilyFood.yagody => copyWith(yagody: yagody - n),
      FamilyFood.oreshki => copyWith(oreshki: oreshki - n),
    };
  }

  Map<String, dynamic> toJson() => {
        'travka': travka,
        'yagody': yagody,
        'oreshki': oreshki,
      };

  factory FoodInventory.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FoodInventory();
    return FoodInventory(
      travka: (json['travka'] as num?)?.toInt() ?? 0,
      yagody: (json['yagody'] as num?)?.toInt() ?? 0,
      oreshki: (json['oreshki'] as num?)?.toInt() ?? 0,
    );
  }
}
