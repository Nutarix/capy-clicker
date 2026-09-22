/// Permanent cozy decor with small % effects («Уют дома»).
enum HomeDecor {
  fonarik,
  kovrik,
  vazon,
  girlyanda,
  skvorechnik,
  podushka,
  lampa,
  kormushka,
}

extension HomeDecorX on HomeDecor {
  String get id => name;


  /// Soft-pixel icon (chroma-keyed).
  String get assetPath => switch (this) {
        HomeDecor.fonarik => 'assets/images/decor_fonarik.png',
        HomeDecor.kovrik => 'assets/images/decor_kovrik.png',
        HomeDecor.vazon => 'assets/images/decor_vazon.png',
        HomeDecor.girlyanda => 'assets/images/decor_girlyanda.png',
        HomeDecor.skvorechnik => 'assets/images/decor_skvorechnik.png',
        HomeDecor.podushka => 'assets/images/decor_podushka.png',
        HomeDecor.lampa => 'assets/images/decor_lampa.png',
        HomeDecor.kormushka => 'assets/images/decor_kormushka.png',
      };

  String get emoji => switch (this) {
        HomeDecor.fonarik => '🏮',
        HomeDecor.kovrik => '🧶',
        HomeDecor.vazon => '🪴',
        HomeDecor.girlyanda => '✨',
        HomeDecor.skvorechnik => '🏠',
        HomeDecor.podushka => '🛋️',
        HomeDecor.lampa => '💡',
        HomeDecor.kormushka => '🥣',
      };

  String get labelRu => switch (this) {
        HomeDecor.fonarik => 'Фонарик',
        HomeDecor.kovrik => 'Коврик',
        HomeDecor.vazon => 'Вазон',
        HomeDecor.girlyanda => 'Гирлянда',
        HomeDecor.skvorechnik => 'Скворечник',
        HomeDecor.podushka => 'Подушка',
        HomeDecor.lampa => 'Лампа',
        HomeDecor.kormushka => 'Кормушка',
      };

  String get effectRu => switch (this) {
        HomeDecor.fonarik => '+3% авто',
        HomeDecor.kovrik => '+4% с цветов',
        HomeDecor.vazon => 'ягоды чуть чаще',
        HomeDecor.girlyanda => '+4% авто-трава',
        HomeDecor.skvorechnik => '+2% спавн-прогресс',
        HomeDecor.podushka => '+3% тапы',
        HomeDecor.lampa => '+5% авто',
        HomeDecor.kormushka => 'еда с цветов чаще',
      };

  /// Grass cost to buy once unlocked.
  int get grassCost => switch (this) {
        HomeDecor.fonarik => 18,
        HomeDecor.kovrik => 22,
        HomeDecor.vazon => 28,
        HomeDecor.girlyanda => 32,
        HomeDecor.skvorechnik => 40,
        HomeDecor.podushka => 36,
        HomeDecor.lampa => 45,
        HomeDecor.kormushka => 50,
      };

  /// Extra Уют cost (optional).
  int get uyutCost => switch (this) {
        HomeDecor.lampa => 1,
        HomeDecor.kormushka => 1,
        _ => 0,
      };

  /// Requires research node id, or null if always buyable.
  String? get requiresResearch => switch (this) {
        HomeDecor.lampa => 'cozy_lamp',
        _ => null,
      };

  /// Permanent auto-progress additive fraction.
  double get autoBonus => switch (this) {
        HomeDecor.fonarik => 0.03,
        HomeDecor.lampa => 0.05,
        HomeDecor.skvorechnik => 0.02,
        _ => 0.0,
      };

  double get flowerBonus => switch (this) {
        HomeDecor.kovrik => 0.04,
        HomeDecor.podushka => 0.03,
        _ => 0.0,
      };

  double get grassAutoBonus => switch (this) {
        HomeDecor.girlyanda => 0.04,
        _ => 0.0,
      };

  /// Multiplier on berry respawn delay (<1 = faster).
  double get berryRespawnFactor => switch (this) {
        HomeDecor.vazon => 0.88,
        _ => 1.0,
      };

  double get foodDropBonus => switch (this) {
        HomeDecor.kormushka => 0.12,
        _ => 0.0,
      };

  static HomeDecor? tryParse(String? raw) {
    if (raw == null) return null;
    for (final d in HomeDecor.values) {
      if (d.id == raw) return d;
    }
    return null;
  }
}
