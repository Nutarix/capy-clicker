/// Role a single capy can hold in the Семья (one role per capy).
enum CapyRole {
  /// Faster auto progress.
  nanya,

  /// More flower / food finds.
  sobiratel,

  /// Slightly higher soft herd cap / berry lean.
  storozh,
}

extension CapyRoleX on CapyRole {
  String get id => name;


  /// Soft-pixel icon (chroma-keyed).
  String get assetPath => switch (this) {
        CapyRole.nanya => 'assets/images/role_nanny.png',
        CapyRole.sobiratel => 'assets/images/role_gatherer.png',
        CapyRole.storozh => 'assets/images/role_guard.png',
      };

  String get emoji => switch (this) {
        CapyRole.nanya => '🍼',
        CapyRole.sobiratel => '🧺',
        CapyRole.storozh => '🛡️',
      };

  String get labelRu => switch (this) {
        CapyRole.nanya => 'Няня',
        CapyRole.sobiratel => 'Собиратель',
        CapyRole.storozh => 'Сторож',
      };

  String get effectRu => switch (this) {
        CapyRole.nanya => '+15% авто',
        CapyRole.sobiratel => '+20% находки с цветов',
        CapyRole.storozh => '+1 к мягкому лимиту · ягоды',
      };

  /// Toast / HUD when the role is assigned («Няня: +15% авто»).
  String get assignToastRu => '$labelRu: $effectRu';

  /// One-liner under Роли tab.
  String get tipRu => switch (this) {
        CapyRole.nanya => 'Няня ускоряет авто-прогресс семьи (+15%).',
        CapyRole.sobiratel => 'Собиратель чаще находит еду на цветах (+20%).',
        CapyRole.storozh => 'Сторож расширяет мягкий лимит стада и бережёт ягоды.',
      };

  static CapyRole? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final r in CapyRole.values) {
      if (r.id == raw) return r;
    }
    return null;
  }
}
