import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../audio/game_audio.dart';
import '../../controllers/game_controller.dart';
import '../../game_screen.dart';
import '../../models/balance.dart';
import '../morning_cozy_sheet.dart';

/// The screen's message layer: game events become plates and sheets.
///
/// Each event is shown once and acknowledged on the controller, as the
/// screen used to do when it polled the fields after every notice.
mixin GameMessagesMixin on State<GameScreen> {
  GameController get game;
  GameAudio get audio;

  StreamSubscription<GameEvent>? _gameEvents;
  bool _dailyPromptShown = false;
  bool _dailySheetOpen = false;

  /// Subscribe before `init()`: the first events come with the load.
  void listenToGameEvents() {
    _gameEvents = game.events.listen(_onGameEvent);
  }

  void stopGameEvents() {
    _gameEvents?.cancel();
  }

  void _onGameEvent(GameEvent event) {
    if (!mounted) return;
    switch (event) {
      case OfflineWelcome(:final seconds, :final progress):
        _showOfflineWelcome(seconds, progress);
      case DailyBonusReady():
        _maybeShowDailyBonus();
      case GladeUnlocked(:final text, :final grass):
        _showGladeUnlock(text, grass);
      case PuddleAppeared():
        _showPuddle();
      case GoalCompleted(:final text):
        _showGoalComplete(text);
      case RoleAssigned():
        break;
    }
  }

  /// Next frame, with a frame asked for: a quiet notice no longer rebuilds
  /// the whole screen, so nothing else may schedule one.
  void _afterFrame(void Function() show) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      show();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _showGladeUnlock(String msg, int grassReward) {
    game.acknowledgeGladeUnlock();
    audio.playGlade();
    _afterFrame(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF5A9A48).withValues(alpha: 0.94),
          content: Row(
            children: [
              const Text('☀️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  grassReward > 0 ? '$msg · +$grassReward🌿' : msg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showPuddle() {
    game.acknowledgePuddleToast();
    _afterFrame(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF8B5A2B).withValues(alpha: 0.94),
          content: const Text(
            'Лужа!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    });
  }

  void _showGoalComplete(String msg) {
    game.acknowledgeGoalComplete();
    audio.playGlade();
    _afterFrame(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFFC47820).withValues(alpha: 0.94),
          content: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Cold start and every return from background (acknowledge = once).
  void _showOfflineWelcome(int seconds, double progress) {
    game.acknowledgeOfflineWelcome();
    _afterFrame(() {
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      final timeLabel = mins > 0 ? '$mins мин $secs с' : '$secs с';
      final bars = (progress / BalanceV0.spawnThreshold).clamp(0.0, 99.0);
      final barsLabel = bars >= 1
          ? '≈${bars.toStringAsFixed(1)} шкалы'
          : '+${(progress * 100).round()}%';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF5C3D1E).withValues(alpha: 0.92),
          content: Text(
            'Пока тебя не было… семья подросла ($timeLabel → $barsLabel)',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    });
  }

  void _maybeShowDailyBonus() {
    if (_dailyPromptShown || _dailySheetOpen) return;
    if (!game.isReady || !game.isDailyBonusAvailable) return;
    // Soft: wait a beat so tips / offline snackbar settle first.
    _dailyPromptShown = true;
    _afterFrame(() async {
      // Delay slightly so first-launch tips can appear above without stacking.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      // 🎁 may have opened it meanwhile (spec 003, Т6).
      if (!mounted || !game.isDailyBonusAvailable || _dailySheetOpen) return;
      await _showDailySheet();
    });
  }

  /// The gift button: «Утренний уют» unless the sheet is already up.
  Future<void> openDailyBonus() async {
    if (!game.isDailyBonusAvailable || _dailySheetOpen) return;
    await _showDailySheet();
  }

  /// One sheet at a time, whoever asks.
  Future<void> _showDailySheet() async {
    if (_dailySheetOpen) return;
    _dailySheetOpen = true;
    final claimed = await MorningCozySheet.show(
      context,
      dailyGoalHint: game.dailyGoalHintRu,
      onClaim: () {
        game.claimDailyBonus();
      },
    );
    _dailySheetOpen = false;
    if (!mounted) return;
    if (claimed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF5C3D1E).withValues(alpha: 0.92),
          content: Text(
            'Уют получен: +${(BalanceV0.dailyBonusProgress * 100).round()}% прогресса',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    }
  }
}
