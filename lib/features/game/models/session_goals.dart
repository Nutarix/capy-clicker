import 'world_zones.dart';

/// Kind of session milestone the player is aiming for.
enum SessionGoalKind {
  /// Unlock a Sunny Glade (sticky [sunnyGladeAnnounced] ≥ target index).
  glade,

  /// Own at least one capybara at [targetLevel].
  maxLevel,

  /// Unlock second forest biome (Туманный бор).
  biomeUnlock,

  /// Visit / enter a specific meadow (activeMeadowId).
  visitMeadow,

  /// Soft infinite-horizon tip (never auto-completes).
  metaSoft,
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
    this.meadowId,
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

  /// For [SessionGoalKind.visitMeadow]: meadow machine id.
  final String? meadowId;

  String get hudLabelRu => 'Цель: $titleRu';
}

/// Ordered session goals for a cozy play loop (infinite horizon).
///
/// Ягодная → Солнечный прогал → Большой луг → Капи Lv.4 →
/// Открой Туманный бор → Загляни в Туманный бор → Собери искры уюта.
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
    SessionGoal(
      id: 'unlock_misty',
      kind: SessionGoalKind.biomeUnlock,
      titleRu: 'Открой Туманный бор',
      celebrationRu: 'Открыт Туманный бор! Искра уюта мерцает…',
    ),
    SessionGoal(
      id: 'visit_misty',
      kind: SessionGoalKind.visitMeadow,
      titleRu: 'Загляни в Туманный бор',
      celebrationRu: 'Новая опушка встречает семью!',
      meadowId: WorldZones.mistEdgeMeadowId,
    ),
    SessionGoal(
      id: 'uyut_sparks',
      kind: SessionGoalKind.metaSoft,
      titleRu: 'Собери искры уюта',
      celebrationRu: 'Ещё одна искра уюта!',
    ),
  ];

  /// Goal at [index], or the soft horizon goal when past the end.
  /// Never returns null for index ≥ 0 — infinite cozy horizon.
  static SessionGoal? at(int index) {
    if (index < 0) return null;
    if (index >= sequence.length) return sequence.last;
    return sequence[index];
  }

  /// Progress 0–1 toward [goal].
  static double progressToward({
    required SessionGoal goal,
    required int sunnyGladeAnnounced,
    required int herdCount,
    required int maxCapyLevel,
    required bool mistyBiomeUnlocked,
    required String activeMeadowId,
    required int uyut,
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
      case SessionGoalKind.biomeUnlock:
        return mistyBiomeUnlocked ? 1.0 : 0.0;
      case SessionGoalKind.visitMeadow:
        final id = goal.meadowId!;
        return activeMeadowId == id ? 1.0 : (mistyBiomeUnlocked ? 0.5 : 0.0);
      case SessionGoalKind.metaSoft:
        // Soft forever: show mild progress from Уют without completing.
        return (uyut / (uyut + 2)).clamp(0.0, 0.95);
    }
  }

  static bool isComplete({
    required SessionGoal goal,
    required int sunnyGladeAnnounced,
    required int maxCapyLevel,
    required bool mistyBiomeUnlocked,
    required String activeMeadowId,
  }) {
    switch (goal.kind) {
      case SessionGoalKind.glade:
        return sunnyGladeAnnounced >= goal.gladeIndex!;
      case SessionGoalKind.maxLevel:
        return maxCapyLevel >= goal.targetLevel!;
      case SessionGoalKind.biomeUnlock:
        return mistyBiomeUnlocked;
      case SessionGoalKind.visitMeadow:
        return activeMeadowId == goal.meadowId;
      case SessionGoalKind.metaSoft:
        return false; // infinite horizon
    }
  }

  /// Soft daily tip: «Сегодня: доберись до …»
  static String dailyHintRu(SessionGoal? goal) {
    if (goal == null) return 'Сегодня: просто побудь с капи';
    return 'Сегодня: доберись до ${goal.titleRu}';
  }
}
