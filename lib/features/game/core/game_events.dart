/// One-shot happenings the screen shows once: a plate, a sound, a sheet.
///
/// They arrive on `GameController.events` right after the change notice
/// that brought them, in a fixed order: offline, daily, glade, puddle, goal,
/// role, name. The matching `acknowledge*` on the controller clears the pending
/// field, as before.
sealed class GameEvent {
  const GameEvent();
}

/// «Пока тебя не было…»: time away granted [progress] over [seconds].
class OfflineWelcome extends GameEvent {
  const OfflineWelcome({required this.seconds, required this.progress});

  final int seconds;
  final double progress;
}

/// Today's «Утренний уют» became available.
class DailyBonusReady extends GameEvent {
  const DailyBonusReady();
}

/// A glade or the misty grove opened; [grass] came with it.
class GladeUnlocked extends GameEvent {
  const GladeUnlocked({required this.text, required this.grass});

  final String text;
  final int grass;
}

/// «Лужа!» — a puddle appeared.
class PuddleAppeared extends GameEvent {
  const PuddleAppeared(this.text);

  final String text;
}

/// A session goal is done.
class GoalCompleted extends GameEvent {
  const GoalCompleted(this.text);

  final String text;
}

/// A role was given («Няня: +15% авто»). Not shown on the meadow yet.
class RoleAssigned extends GameEvent {
  const RoleAssigned(this.text);

  final String text;
}

/// A baby grew up and got a name: «Малыш подрос — теперь это Пуговка».
class CapyNamed extends GameEvent {
  const CapyNamed({required this.text, required this.capyId});

  final String text;
  final String capyId;
}
