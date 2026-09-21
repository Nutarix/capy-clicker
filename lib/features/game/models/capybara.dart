import 'dart:ui';

/// A single capybara entity on the meadow.
class Capybara {
  Capybara({required this.id, required this.level, required this.position});

  final String id;
  final int level;

  /// Normalized meadow position (0–1 in both axes), relative to playfield.
  final Offset position;

  Capybara copyWith({String? id, int? level, Offset? position}) {
    return Capybara(
      id: id ?? this.id,
      level: level ?? this.level,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'level': level,
    'x': position.dx,
    'y': position.dy,
  };

  factory Capybara.fromJson(Map<String, dynamic> json) {
    return Capybara(
      id: json['id'] as String,
      level: json['level'] as int,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Capybara &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          level == other.level &&
          position == other.position;

  @override
  int get hashCode => Object.hash(id, level, position);
}
