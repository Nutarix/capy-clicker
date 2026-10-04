import 'dart:async';

import '../models/balance.dart';
import 'game_core.dart';
import 'game_events.dart';

/// One-shot messages: puddle, new glade, goal, role, offline, daily, name.
///
/// Each slot keeps its pending text (the controller getters and
/// `acknowledge*` read and clear it) and a «not sent yet» flag. [flush] runs
/// after every change notice and sends what is new as [GameEvent]s, in the
/// order the screen used to poll the fields.
class GameMessages extends GamePart {
  GameMessages(super.core);

  final StreamController<GameEvent> _events =
      StreamController<GameEvent>.broadcast(sync: true);

  Stream<GameEvent> get events => _events.stream;

  bool _flushing = false;

  /// «Лужа!» when a puddle appears.
  String? get puddleToast => _puddleToast;
  String? _puddleToast;
  bool _puddlePending = false;

  /// «Солнечные поляны» unlock line (e.g. «Открылась Ягодная поляна»).
  String? get gladeUnlockToast => _gladeUnlockToast;
  String? _gladeUnlockToast;
  bool _gladePending = false;

  /// Extra grass granted with the last glade unlock (for UI float).
  int get lastGladeGrassReward => _lastGladeGrassReward;
  int _lastGladeGrassReward = 0;

  /// Soft session-goal celebration line.
  String? get goalCompleteToast => _goalCompleteToast;
  String? _goalCompleteToast;
  bool _goalPending = false;

  /// After assigning a role («Няня: +15% авто»).
  String? _roleToast;
  bool _rolePending = false;

  /// Last growth in a pile since the last [flush] (spec 006).
  CapyGrew? _grew;

  /// «Малыш подрос — теперь это …» (spec 004, С1). Queued in order: two
  /// in one notice send both.
  final List<CapyNamed> _named = [];

  /// Progress granted from offline elapsed time (0 if none).
  double get offlineProgressGranted => _offlineProgressGranted;
  double _offlineProgressGranted = 0;

  /// Elapsed seconds used for the offline grant (capped).
  int get offlineSecondsApplied => _offlineSecondsApplied;
  int _offlineSecondsApplied = 0;
  bool _offlinePending = false;

  bool get hasOfflineWelcome => _offlineProgressGranted > 0.001;

  /// Daily gift availability at the last [flush].
  bool _dailyWas = false;

  void puddleAppeared() {
    _puddleToast = 'Лужа!';
    _puddlePending = true;
  }

  void acknowledgePuddle() {
    _puddleToast = null;
  }

  void announceGlade(String text) {
    _gladeUnlockToast = text;
    _lastGladeGrassReward = BalanceV0.gladeUnlockGrass;
    _gladePending = true;
  }

  void acknowledgeGladeUnlock() {
    _gladeUnlockToast = null;
    _lastGladeGrassReward = 0;
  }

  void goalCompleted(String text) {
    _goalCompleteToast = text;
    _goalPending = true;
  }

  void acknowledgeGoalComplete() {
    _goalCompleteToast = null;
  }

  void roleAssigned(String text) {
    _roleToast = text;
    _rolePending = true;
  }

  void capyNamed(String text, String capyId) {
    _named.add(CapyNamed(text: text, capyId: capyId));
    // Nobody listening (sims): keep only the latest few.
    if (_named.length > 8) _named.removeAt(0);
  }

  void capyGrew(String capyId, int level) {
    _grew = CapyGrew(capyId: capyId, level: level);
  }

  void offlineGranted(double progress, int seconds) {
    _offlineProgressGranted = progress;
    _offlineSecondsApplied = seconds;
    _offlinePending = true;
  }

  void acknowledgeOfflineWelcome() {
    _offlineProgressGranted = 0;
    _offlineSecondsApplied = 0;
  }

  /// A new load: the daily gift counts as «just became available» again.
  void resetDaily() {
    _dailyWas = false;
  }

  /// Send what is new. Nobody listening: everything waits, as the fields
  /// used to wait for the screen.
  void flush() {
    if (_flushing || !_events.hasListener) return;
    _flushing = true;
    try {
      if (_offlinePending && core.ready) {
        _offlinePending = false;
        if (hasOfflineWelcome) {
          _events.add(
            OfflineWelcome(
              seconds: _offlineSecondsApplied,
              progress: _offlineProgressGranted,
            ),
          );
        }
      }
      final daily = core.goals.isDailyBonusAvailable;
      if (daily && !_dailyWas) _events.add(const DailyBonusReady());
      _dailyWas = daily;
      if (_gladePending) {
        _gladePending = false;
        final text = _gladeUnlockToast;
        if (text != null && text.isNotEmpty) {
          _events.add(GladeUnlocked(text: text, grass: _lastGladeGrassReward));
        }
      }
      if (_puddlePending) {
        _puddlePending = false;
        final text = _puddleToast;
        if (text != null && text.isNotEmpty) _events.add(PuddleAppeared(text));
      }
      if (_goalPending) {
        _goalPending = false;
        final text = _goalCompleteToast;
        if (text != null && text.isNotEmpty) _events.add(GoalCompleted(text));
      }
      if (_rolePending) {
        _rolePending = false;
        final text = _roleToast;
        if (text != null && text.isNotEmpty) _events.add(RoleAssigned(text));
      }
      final grew = _grew;
      if (grew != null) {
        _grew = null;
        _events.add(grew);
      }
      if (_named.isNotEmpty) {
        final named = List<CapyNamed>.of(_named);
        _named.clear();
        named.forEach(_events.add);
      }
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _events.close();
  }
}
