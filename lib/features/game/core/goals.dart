import '../models/balance.dart';
import '../models/game_state.dart';
import '../models/session_goals.dart';
import 'game_core.dart';

/// Session goals and the soft daily gift («Утренний уют»).
class GameGoals extends GamePart {
  GameGoals(super.core);

  /// Current session goal, or null when the sequence is finished.
  SessionGoal? get currentSessionGoal =>
      SessionGoals.at(state.sessionGoalIndex);

  /// 0–1 progress toward [currentSessionGoal].
  double get sessionGoalProgress {
    final goal = currentSessionGoal;
    if (goal == null) return 1.0;
    return SessionGoals.progressToward(
      goal: goal,
      sunnyGladeAnnounced: state.sunnyGladeAnnounced,
      herdCount: state.herdCount,
      maxCapyLevel: state.maxCapyLevel,
      mistyBiomeUnlocked: state.mistyBiomeUnlocked,
      activeMeadowId: state.activeMeadowId,
      uyut: state.uyut,
      familyPower: state.familyPower,
    );
  }

  /// Soft daily tip tied to the active goal.
  String get dailyGoalHintRu => SessionGoals.dailyHintRu(currentSessionGoal);

  /// Quietly catch up goal index on load (no celebration toast).
  GameState advanceGoalsQuiet(GameState state) {
    var idx = state.sessionGoalIndex.clamp(0, SessionGoals.sequence.length);
    while (idx < SessionGoals.sequence.length) {
      final goal = SessionGoals.sequence[idx];
      if (!SessionGoals.isComplete(
        goal: goal,
        sunnyGladeAnnounced: state.sunnyGladeAnnounced,
        maxCapyLevel: state.maxCapyLevel,
        mistyBiomeUnlocked: state.mistyBiomeUnlocked,
        activeMeadowId: state.activeMeadowId,
      )) {
        break;
      }
      idx++;
    }
    if (idx == state.sessionGoalIndex) return state;
    return state.copyWith(sessionGoalIndex: idx);
  }

  /// Check / advance session goals; may raise the celebration message.
  GameState checkGoals(GameState state, {required bool celebrate}) {
    var idx = state.sessionGoalIndex.clamp(0, SessionGoals.sequence.length);
    var grass = state.grass;
    String? toast;
    while (idx < SessionGoals.sequence.length) {
      final goal = SessionGoals.sequence[idx];
      if (!SessionGoals.isComplete(
        goal: goal,
        sunnyGladeAnnounced: state.sunnyGladeAnnounced,
        maxCapyLevel: state.maxCapyLevel,
        mistyBiomeUnlocked: state.mistyBiomeUnlocked,
        activeMeadowId: state.activeMeadowId,
      )) {
        break;
      }
      if (celebrate && core.ready) {
        toast = goal.celebrationRu;
        grass += BalanceV0.goalCompleteGrass;
      }
      idx++;
    }
    if (toast != null) {
      core.messages.goalCompleted(toast);
    }
    if (idx == state.sessionGoalIndex && grass == state.grass) return state;
    return state.copyWith(sessionGoalIndex: idx, grass: grass);
  }

  /// Local calendar day key `YYYY-MM-DD` for [instant].
  static String calendarDayKey(DateTime instant) {
    final y = instant.year.toString().padLeft(4, '0');
    final m = instant.month.toString().padLeft(2, '0');
    final d = instant.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Today's key, formatted once per day (read on every change notice).
  String get _todayKey {
    final now = core.now();
    final cached = _dayKey;
    if (cached != null &&
        now.day == _keyDay.day &&
        now.month == _keyDay.month &&
        now.year == _keyDay.year) {
      return cached;
    }
    _keyDay = now;
    return _dayKey = calendarDayKey(now);
  }

  String? _dayKey;
  DateTime _keyDay = DateTime(0);

  /// Soft daily gift available (once per local calendar day, not claimed yet).
  bool get isDailyBonusAvailable =>
      core.ready && state.lastDailyClaimYmd != _todayKey;

  /// Claim today's soft daily: +[BalanceV0.dailyBonusProgress] progress.
  /// Returns false if already claimed today.
  bool claimDailyBonus() {
    if (!isDailyBonusAvailable) return false;
    final day = _todayKey;
    core.commit(state.copyWith(lastDailyClaimYmd: day, grass: state.grass + 3));
    core.herd.addProgress(BalanceV0.dailyBonusProgress, fromTap: false);
    return true;
  }
}
