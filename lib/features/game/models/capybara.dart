import 'dart:ui';

import 'multipliers/capy_role.dart';

/// A single capybara entity on the meadow.
class Capybara {
  Capybara({
    required this.id,
    required this.level,
    required this.position,
    this.role,
  });

  final String id;
  final int level;

  /// Normalized meadow position (0–1 in both axes), relative to playfield.
  final Offset position;

  /// Optional Семья role (Няня / Собиратель / Сторож).
  final CapyRole? role;

  Capybara copyWith({
    String? id,
    int? level,
    Offset? position,
    CapyRole? role,
    bool clearRole = false,
  }) {
    return Capybara(
      id: id ?? this.id,
      level: level ?? this.level,
      position: position ?? this.position,
      role: clearRole ? null : (role ?? this.role),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'x': position.dx,
        'y': position.dy,
        if (role != null) 'role': role!.id,
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
          role == other.role;

  @override
  int get hashCode => Object.hash(id, level, position, role);
}
