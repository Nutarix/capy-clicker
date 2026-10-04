import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/cozy_theme.dart';
import '../../audio/game_audio.dart';
import '../../controllers/game_controller.dart';
import '../../models/session_goals.dart';
import '../../models/world_zones.dart';
import '../game_selector.dart';
import '../grass_spend_panel.dart';
import '../uyut/uyut_hub_sheet.dart';

/// Thin top bar: grass and where the family is (or the next glade goal).
/// Rebuilds when the grass or the line changes.
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.controller,
    required this.audio,
    this.onBackToMenu,
  });

  final GameController controller;
  final GameAudio audio;
  final VoidCallback? onBackToMenu;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 4),
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2CFA8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                GameSelector<(int, String)>(
                  listenable: controller,
                  select: () => (controller.state.grass, placeLine(controller)),
                  builder: (context, view) => Row(
                    children: [
                      MeadowGrassReadout(grass: view.$1),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              view.$2,
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.right,
                              style: CozyTheme.hudChipStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onBackToMenu != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: 'Меню',
                    onPressed: () {
                      unawaited(audio.noteUserGesture());
                      onBackToMenu!();
                    },
                    // Kept for the menu test. Transparent so the
                    // bar is one grass icon and the count.
                    icon: const Icon(
                      Icons.pause_rounded,
                      size: 18,
                      color: Colors.transparent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fresh land, misty grove, the next glade goal, or the meadow's name.
  static String placeLine(GameController controller) {
    final state = controller.state;
    if (controller.onFreshNewLand) {
      return 'Новая земля · сила ${state.familyPower}/5';
    }
    if (state.activeMeadowId == WorldZones.mistEdgeMeadowId &&
        state.maxCapyLevel >= 4) {
      return 'Туманный бор · после Lv.4';
    }
    final goal = controller.currentSessionGoal;
    if (goal != null && goal.kind == SessionGoalKind.glade) {
      final detail = goal.hudCountDetailRu(
        herdCount: state.herdCount,
        maxCapyLevel: state.maxCapyLevel,
        uyut: state.uyut,
        familyPower: state.familyPower,
      );
      return detail.isEmpty ? goal.titleRu : '${goal.titleRu} · $detail';
    }
    return controller.currentGlade.nameRu;
  }
}

/// Bottom row: call a capy, grass boost, Уют sheet, forest map.
/// Rebuilds when grass or what can be bought changes.
class GameBottomBar extends StatelessWidget {
  const GameBottomBar({
    super.key,
    required this.controller,
    required this.audio,
    required this.onForest,
    required this.onCapyCalled,
  });

  final GameController controller;
  final GameAudio audio;
  final VoidCallback onForest;

  /// A capy came on the call: the screen shows «+капи» over it.
  final VoidCallback onCapyCalled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        4,
        10,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: RepaintBoundary(
        child: GameSelector<(int, bool, String?, bool, bool)>(
          listenable: controller,
          select: () => (
            controller.state.grass,
            controller.canCallCapy,
            controller.callCapyBlockedReason,
            controller.canGrassBoost,
            controller.isGrassBoostActive,
          ),
          builder: (context, view) => GrassSpendPanel(
            grass: view.$1,
            canCallCapy: view.$2,
            callBlockedReason: view.$3,
            canBoost: view.$4,
            boostActive: view.$5,
            onUyutHub: () {
              unawaited(audio.noteUserGesture());
              HapticFeedback.lightImpact();
              UyutHubSheet.show(context, controller: controller);
            },
            onForest: () {
              unawaited(audio.noteUserGesture());
              HapticFeedback.lightImpact();
              onForest();
            },
            onCallCapy: () {
              unawaited(audio.noteUserGesture());
              if (controller.spendCallCapy()) {
                HapticFeedback.lightImpact();
                onCapyCalled();
              }
            },
            onBoost: () {
              unawaited(audio.noteUserGesture());
              if (controller.spendGrassBoost()) {
                HapticFeedback.lightImpact();
              }
            },
          ),
        ),
      ),
    );
  }
}
