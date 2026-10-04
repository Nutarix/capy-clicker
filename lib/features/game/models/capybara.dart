import 'dart:ui';

import 'capy_names.dart';
import 'multipliers/capy_role.dart';

/// A single capybara entity on the meadow.
class Capybara {
  Capybara({
    required this.id,
    required this.level,
    required this.position,
    this.role,
    this.nameKey,
    this.nameEpithet = false,
    this.customName,
    this.trait,
    this.pileId,
    this.growth = 0,
  });

  final String id;
  final int level;

  /// Normalized meadow position (0–1 in both axes), relative to playfield.
  final Offset position;

  /// Optional Семья role (Няня / Собиратель / Сторож).
  final CapyRole? role;

  /// Game name by key ([CapyNames]); null for a baby (spec 004, Т1).
  final String? nameKey;

  /// The name carries the trait: «Шишка-соня» (all hundred were taken).
  final bool nameEpithet;

  /// The player's own name, shown as is.
  final String? customName;

  /// One trait per named capy: meadow behavior only.
  final CapyTrait? trait;

  /// The pile this capy sits in (spec 006), or null on its own.
  /// Everyone with the same id on a meadow is one pile.
  final String? pileId;

  /// Growth toward the next level, 0–1. Grows only in a pile; kept when the
  /// capy stands up.
  final double growth;

  bool get isNamed => nameKey != null;

  bool get inPile => pileId != null;

  /// Shown name: the player's own, else the game name in RU. Null for a baby.
  String? get displayNameRu {
    final own = customName;
    if (own != null && own.isNotEmpty) return own;
    final name = CapyNames.byKey(nameKey);
    if (name == null) return null;
    final t = trait;
    if (nameEpithet && t != null) return CapyNames.ruWithTrait(name, t);
    return name.ru;
  }

  /// [displayNameRu], or «Малыш» for a baby (lists).
  String get listNameRu => displayNameRu ?? CapyNames.babyRu;

  Capybara copyWith({
    String? id,
    int? level,
    Offset? position,
    CapyRole? role,
    bool clearRole = false,
    String? nameKey,
    bool? nameEpithet,
    String? customName,
    bool clearCustomName = false,
    CapyTrait? trait,
    String? pileId,
    bool clearPile = false,
    double? growth,
  }) {
    return Capybara(
      id: id ?? this.id,
      level: level ?? this.level,
      position: position ?? this.position,
      role: clearRole ? null : (role ?? this.role),
      nameKey: nameKey ?? this.nameKey,
      nameEpithet: nameEpithet ?? this.nameEpithet,
      customName: clearCustomName ? null : (customName ?? this.customName),
      trait: trait ?? this.trait,
      pileId: clearPile ? null : (pileId ?? this.pileId),
      growth: growth ?? this.growth,
    );
  }

  /// Name and pile fields go last and only when set: an unnamed capy on its
  /// own writes the same JSON as before specs 004 and 006.
  Map<String, dynamic> toJson() => {
    'id': id,
    'level': level,
    'x': position.dx,
    'y': position.dy,
    if (role != null) 'role': role!.id,
    if (nameKey != null) 'name': nameKey,
    if (nameEpithet) 'epithet': true,
    if (customName != null) 'customName': customName,
    if (trait != null) 'trait': trait!.id,
    if (pileId != null) 'pile': pileId,
    if (growth > 0) 'grow': growth,
  };

  factory Capybara.fromJson(Map<String, dynamic> json) {
    return Capybara(
      id: json['id'] as String,
      level: json['level'] as int,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      role: CapyRoleX.tryParse(json['role'] as String?),
      nameKey: json['name'] as String?,
      nameEpithet: json['epithet'] as bool? ?? false,
      customName: json['customName'] as String?,
      trait: CapyTraitX.tryParse(json['trait'] as String?),
      pileId: json['pile'] as String?,
      growth: (json['grow'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Capybara &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          level == other.level &&
          position == other.position &&
          role == other.role &&
          nameKey == other.nameKey &&
          nameEpithet == other.nameEpithet &&
          customName == other.customName &&
          trait == other.trait &&
          pileId == other.pileId &&
          growth == other.growth;

  @override
  int get hashCode => Object.hash(
    id,
    level,
    position,
    role,
    nameKey,
    nameEpithet,
    customName,
    trait,
    pileId,
    growth,
  );
}
