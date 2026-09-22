import 'world_zones.dart';

/// Kind of session milestone the player is aiming for.
enum SessionGoalKind {
  /// Unlock a Sunny Glade (sticky [sunnyGladeAnnounced] ≥ target index).
  glade,

  /// Own at least one capybara at [targetLevel].
  maxLevel,
}

/// One cozy session milestone (RU labels for HUD / daily tip).
class SessionGoal {
  const SessionGoal({
    required this.id,
    required this.kind,
    required this.titleRu,
    required this.celebrationRu,
    this.gladeIndex,
    this.targetLevel,
  });

  final String id;
  final SessionGoalKind kind;

  /// Short name in HUD: «Ягодная поляна», «Капи Lv.4».
  final String titleRu;

  /// Soft toast when completed.
  final String celebrationRu;

  /// For [SessionGoalKind.glade]: target [SunnyGlade.index].
  final int? gladeIndex;

  /// For [SessionGoalKind.maxLevel]: required max level.
  final int? targetLevel;

  String get hudLabelRu => 'Цель: $titleRu';
}

/// Ordered session goals for a cozy play loop.
///
/// Ягодная поляна → Солнечный прогал → Большой луг → Капи Lv.4.
abstract final class SessionGoals {
  static const List<SessionGoal> sequence = [
    SessionGoal(
      id: 'berry_glade',
      kind: SessionGoalKind.glade,
      titleRu: 'Ягодная поляна',
      celebrationRu: 'Цель достигнута: Ягодная поляна!',
      gladeIndex: 1,
    ),
    SessionGoal(
      id: 'sunny_clearing',
      kind: SessionGoalKind.glade,
      titleRu: 'Солнечный прогал',
      celebrationRu: 'Цель достигнута: Солнечный прогал!',
      gladeIndex: 2,
    ),
    SessionGoal(
      id: 'great_meadow',
      kind: SessionGoalKind.glade,
      titleRu: 'Большой луг',
      celebrationRu: 'Цель достигнута: Большой луг!',
      gladeIndex: 3,
    ),
    SessionGoal(
      id: 'capy_lv4',
      kind: SessionGoalKind.maxLevel,
      titleRu: 'Капи Lv.4',
      celebrationRu: 'Цель достигнута: Капи Lv.4!',
      targetLevel: 4,
    ),
  ];

  static SessionGoal? at(int index) {
    if (index < 0 || index >= sequence.length) return null;
    return sequence[index];
  }

  /// Progress 0–1 toward [goal].
  static double progressToward({
    required SessionGoal goal,
    required int sunnyGladeAnnounced,
    required int herdCount,
    required int maxCapyLevel,
  }) {
    switch (goal.kind) {
      case SessionGoalKind.glade:
        final idx = goal.gladeIndex!;
        if (sunnyGladeAnnounced >= idx) return 1.0;
        final need = WorldZones.glades[idx].minHerd;
        if (need <= 0) return 1.0;
        return (herdCount / need).clamp(0.0, 1.0);
      case SessionGoalKind.maxLevel:
        final need = goal.targetLevel!;
        if (need <= 0) return 1.0;
        return (maxCapyLevel / need).clamp(0.0, 1.0);
    }
  }

  static bool isComplete({
    required SessionGoal goal,
    required int sunnyGladeAnnounced,
    required int maxCapyLevel,
  }) {
    switch (goal.kind) {
      case SessionGoalKind.glade:
        return sunnyGladeAnnounced >= goal.gladeIndex!;
      case SessionGoalKind.maxLevel:
        return maxCapyLevel >= goal.targetLevel!;
    }
  }

  /// Soft daily tip: «Сегодня: доберись до …»
  static String dailyHintRu(SessionGoal? goal) {
    if (goal == null) return 'Сегодня: просто побудь с капи';
    return 'Сегодня: доберись до ${goal.titleRu}';
  }
}
