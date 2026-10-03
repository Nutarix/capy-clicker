import '../models/balance.dart';
import 'game_core.dart';

/// One-shot messages for the screen: puddle, new glade, goal, role, offline.
class GameMessages extends GamePart {
  GameMessages(super.core);

  /// «Лужа!» when a puddle appears.
  String? puddleToast;

  /// «Солнечные поляны» unlock line (e.g. «Открылась Ягодная поляна»).
  String? gladeUnlockToast;

  /// Extra grass granted with the last glade unlock (for UI float).
  int lastGladeGrassReward = 0;

  /// Soft session-goal celebration line.
  String? goalCompleteToast;

  /// After assigning a role («Няня: +15% авто»).
  String? roleToast;

  /// Progress granted from offline elapsed time (0 if none).
  double offlineProgressGranted = 0;

  /// Elapsed seconds used for the offline grant (capped).
  int offlineSecondsApplied = 0;

  bool get hasOfflineWelcome => offlineProgressGranted > 0.001;

  void announceGlade(String text) {
    gladeUnlockToast = text;
    lastGladeGrassReward = BalanceV0.gladeUnlockGrass;
  }

  void acknowledgeGladeUnlock() {
    gladeUnlockToast = null;
    lastGladeGrassReward = 0;
  }

  void offlineGranted(double progress, int seconds) {
    offlineProgressGranted = progress;
    offlineSecondsApplied = seconds;
  }

  void acknowledgeOfflineWelcome() {
    offlineProgressGranted = 0;
    offlineSecondsApplied = 0;
  }
}
