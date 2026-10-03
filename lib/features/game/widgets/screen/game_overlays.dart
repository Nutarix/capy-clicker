import 'package:flutter/material.dart';

import '../../../../theme/cozy_theme.dart';
import '../../controllers/game_controller.dart';
import '../../game_screen.dart';
import '../../models/family_land.dart';
import '../../models/world_zones.dart';
import '../forest_map_overlay.dart';
import '../game_selector.dart';
import '../rocket_chapter.dart';

enum _RocketPhase { none, farewell, flight }

/// The screen's sheet layer: gift button, forest map, rocket, lands.
///
/// Opening or closing one rebuilds the screen (the rocket hides the bars);
/// while open, each shows live numbers through its own selector.
mixin GameOverlaysMixin on State<GameScreen> {
  GameController get game;

  /// The gift button opens «Утренний уют» (see the message layer).
  Future<void> openDailyBonus();

  bool _forestMapOpen = false;
  _RocketPhase _rocketPhase = _RocketPhase.none;
  bool _landsOpen = false;

  /// The rocket chapter takes the whole screen: no top and bottom bars.
  bool get chromeHidden => _rocketPhase != _RocketPhase.none;

  void openForestMap() => setState(() => _forestMapOpen = true);

  List<Widget> buildOverlays() {
    return [
      GameSelector<bool>(
        listenable: game,
        select: () => game.isDailyBonusAvailable,
        builder: (context, available) =>
            available ? _giftButton() : const SizedBox.shrink(),
      ),
      if (_forestMapOpen) Positioned.fill(child: _forestMap()),
      if (_rocketPhase == _RocketPhase.farewell)
        Positioned.fill(
          child: RocketFarewell(
            onStay: () => setState(() => _rocketPhase = _RocketPhase.none),
            onSend: () => setState(() => _rocketPhase = _RocketPhase.flight),
          ),
        ),
      if (_rocketPhase == _RocketPhase.flight)
        Positioned.fill(
          child: RocketFlight(
            onArrive: () {
              final ok = game.launchToNewLand();
              setState(() => _rocketPhase = _RocketPhase.none);
              if (!ok) return;
            },
          ),
        ),
      if (_landsOpen) Positioned.fill(child: _lands()),
    ];
  }

  Widget _giftButton() {
    return Positioned(
      right: 16,
      bottom: 48,
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: 'Утренний уют',
          child: InkWell(
            onTap: openDailyBonus,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2CFA8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text('Уют', style: CozyTheme.hudChipStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What the map shows: unlocked meadows, who lives where, the wallet.
  (String, String, bool, int, int, bool, bool, String) _mapView() {
    final state = game.state;
    final counts = [
      for (final g in WorldZones.glades) game.herdCountForMeadow(g.id),
      game.herdCountForMeadow(WorldZones.mistEdgeMeadowId),
    ];
    return (
      game.unlockedMeadowIds.join(','),
      state.activeMeadowId,
      state.mistyBiomeUnlocked,
      state.grass,
      state.uyut,
      game.rocketUnlocked,
      game.hasLandsGallery,
      counts.join(','),
    );
  }

  Widget _forestMap() {
    return GameSelector(
      listenable: game,
      select: _mapView,
      builder: (context, _) => ForestMapOverlay(
        unlockedIds: game.unlockedMeadowIds,
        activeMeadowId: game.state.activeMeadowId,
        herdCountFor: game.herdCountForMeadow,
        mistyBiomeUnlocked: game.state.mistyBiomeUnlocked,
        grass: game.state.grass,
        uyut: game.state.uyut,
        showRocket: game.rocketUnlocked,
        showLands: game.hasLandsGallery,
        onRocket: () => setState(() {
          _forestMapOpen = false;
          _rocketPhase = _RocketPhase.farewell;
        }),
        onLands: () => setState(() {
          _forestMapOpen = false;
          _landsOpen = true;
        }),
        onClose: () => setState(() => _forestMapOpen = false),
        onSelect: (id) {
          if (game.switchToMeadow(id)) {
            setState(() => _forestMapOpen = false);
          }
        },
      ),
    );
  }

  Widget _lands() {
    return GameSelector<(List<FamilyLand>, int, int, String)>(
      listenable: game,
      select: () => (
        game.state.otherLands,
        game.state.landChapter,
        game.state.totalHerdAcrossMeadows,
        game.state.activeMeadowId,
      ),
      builder: (context, _) => FamilyLandsSheet(
        state: game.state,
        onClose: () => setState(() => _landsOpen = false),
        onVisit: (chapter) {
          game.visitLand(chapter);
          setState(() => _landsOpen = false);
        },
      ),
    );
  }
}
