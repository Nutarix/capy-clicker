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
        CapyRole.nanya => '+авто семьи',
        CapyRole.sobiratel => 'больше находок с цветов',
        CapyRole.storozh => 'мягкий лимит / ягоды',
      };

  static CapyRole? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final r in CapyRole.values) {
      if (r.id == raw) return r;
    }
    return null;
  }
}
