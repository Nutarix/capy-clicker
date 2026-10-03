import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/game_audio.dart';
import '../../controllers/game_controller.dart';
import '../../models/balance.dart';
import '../../models/capy_wander.dart';
import '../../models/capybara.dart';
import '../../models/meadow_occupancy.dart';
import '../../models/multipliers/multipliers.dart';
import '../../models/world_zones.dart';
import '../berry_basket.dart';
import '../draggable_capybara.dart';
import '../flower_dot.dart';
import '../game_selector.dart';
import '../meadow_decor.dart';
import '../mud_puddle.dart';
import '../placed_home_decor.dart';
import '../quiet_merge_arc.dart';
import '../uyut/cozy_place_marker.dart';
import '../uyut/uyut_hub_sheet.dart';

/// What the meadow shows. Rebuilt only when one of these changes (spec 002,
/// Т6): not on a tick that moved the bar alone.
typedef _MeadowView = ({
  String meadowId,
  List<Capybara> herd,
  String? twinA,
  String? twinB,
  Offset? mud,
  String? wallowing,
  bool mudBoost,
  Set<String> placed,
  bool tent,
  bool berry,
  String? flash,
  double magnet,
});

/// The meadow under the HUD: capys, flowers, puddle, berry basket, cozy
/// places, decor, the camera. Owns drag-time UI state (magnet glow, badges).
class MeadowLayer extends StatefulWidget {
  const MeadowLayer({
    super.key,
    required this.controller,
    required this.audio,
    required this.onFloat,
  });

  final GameController controller;
  final GameAudio audio;

  /// Floating «+N%» / «×2» at a global point (Offset.zero = default spot).
  final void Function(String label, Offset globalAnchor, {Color? color})
  onFloat;

  @override
  State<MeadowLayer> createState() => _MeadowLayerState();
}

class _MeadowLayerState extends State<MeadowLayer> {
  final GlobalKey _meadowKey = GlobalKey();

  /// Soft-magnet target while a capy is being dragged (glow on attracted).
  String? _magnetAttractedId;

  /// Capy ids that should show a prominent Lv badge (drag / recent merge).
  final Set<String> _badgePromoted = {};
  Timer? _badgeClearTimer;

  /// Soft first-appearance hint on berry basket (session).
  bool _berryHintSeen = false;

  /// Where each capy is drawn right now (mid-walk too). Belongs to this
  /// meadow: a new game screen starts with an empty one (spec 002, Т11).
  final Map<String, Offset> _livePositions = {};

  /// Colors paired with [WorldZones.flowerPositions] (meadow grass only).
  static const _flowerColors = <Color>[
    Color(0xFFE87AA0),
    Color(0xFFF0C040),
    Color(0xFF9B6BDE),
    Color(0xFFE85A5A),
    Color(0xFF5AB8E8),
  ];

  GameController get _controller => widget.controller;
  GameAudio get _audio => widget.audio;

  _MeadowView _view() {
    final c = _controller;
    final state = c.state;
    return (
      meadowId: state.activeMeadowId,
      herd: state.herd,
      twinA: state.twinIdA,
      twinB: state.twinIdB,
      mud: c.mudVisible ? c.mudCenter : null,
      wallowing: c.wallowingCapyId,
      mudBoost: c.isMudBoostActive,
      placed: state.placedDecor,
      tent: state.tentUnlocked,
      berry: c.isBerryVisible,
      flash: c.mergeFlashId,
      magnet: c.effectiveMagnetRadius,
    );
  }

  @override
  void dispose() {
    _badgeClearTimer?.cancel();
    super.dispose();
  }

  void _onFlowerTap(Offset globalAnchor) {
    HapticFeedback.lightImpact();
    unawaited(_audio.noteUserGesture());
    _audio.playFlower();
    final gain = _controller.onFlowerTap();
    final pct = (gain * 100).round().clamp(1, 99);
    final g = _controller.lastTapGrass;
    final food = _controller.lastDroppedFood;
    final foodBit = food != null ? ' · ${food.emoji}' : '';
    widget.onFloat(
      g > 0 ? '+$pct% · +$g🌿$foodBit' : '+$pct%$foodBit',
      globalAnchor,
    );
  }

  void _onBerryTap(Offset globalAnchor) {
    HapticFeedback.mediumImpact();
    unawaited(_audio.noteUserGesture());
    _audio.playBerry();
    final gain = _controller.onBerryTap();
    if (gain == null) return;
    _berryHintSeen = true;
    final pct = (gain * 100).round().clamp(1, 99);
    final g = _controller.lastTapGrass;
    widget.onFloat(
      g > 0 ? '+$pct% · +$g🌿' : '+$pct%',
      globalAnchor,
      color: const Color(0xFFE03A5C),
    );
  }

  void _promoteBadge(String id, {Duration hold = const Duration(seconds: 2)}) {
    setState(() => _badgePromoted.add(id));
    _badgeClearTimer?.cancel();
    _badgeClearTimer = Timer(hold, () {
      if (!mounted) return;
      setState(() => _badgePromoted.clear());
    });
  }

  bool _onMerge(String a, String b) {
    final ok = _controller.tryMerge(a, b);
    if (ok) {
      HapticFeedback.mediumImpact();
      unawaited(_audio.noteUserGesture());
      _audio.playMerge();
      final flash = _controller.mergeFlashId;
      if (flash != null) _promoteBadge(flash);
    }
    return ok;
  }

  bool _onMudDrop(String id) {
    final ok = _controller.tryMudWallow(id);
    if (ok) {
      HapticFeedback.lightImpact();
      unawaited(_audio.noteUserGesture());
      _audio.playWallow();
      // Float near puddle center in meadow space.
      final box = _meadowKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final center =
            _controller.mudCenter ??
            const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY);
        final local = Offset(
          center.dx * box.size.width,
          center.dy * box.size.height,
        );
        widget.onFloat(
          '×2',
          box.localToGlobal(local),
          color: const Color(0xFFB8860B),
        );
      }
    }
    return ok;
  }

  /// Read when a drag needs it, not at build: the camera may still be easing.
  Offset _meadowOriginGlobal() {
    final ctx = _meadowKey.currentContext;
    // Rocket chrome toggles the column; the previous meadow element can be
    // inactive for the frame that rebuilds it. Do not touch a defunct render
    // object (that throws during layout).
    // Inactive elements still report mounted until the frame finishes.
    if (ctx is! Element || !ctx.debugIsActive) return Offset.zero;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return Offset.zero;
    return box.localToGlobal(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    // Meadow animations repaint the meadow, never the bars around it.
    return RepaintBoundary(
      child: GameSelector<_MeadowView>(
        listenable: _controller,
        select: _view,
        builder: (context, view) => LayoutBuilder(
          builder: (context, constraints) =>
              _meadow(view, constraints.maxWidth, constraints.maxHeight),
        ),
      ),
    );
  }

  Widget _meadow(_MeadowView view, double w, double h) {
    final herd = view.herd;
    final meadowKey = WorldZones.gladeById(view.meadowId).minHerd;
    final mud = view.mud;
    final props = MeadowOccupancy.layout(
      meadow: Size(w, h),
      herdCount: meadowKey,
      mud: mud,
      capyAnchors: [for (final c in herd) c.position],
      capyWidths: [for (final c in herd) BalanceV0.capySizeForLevel(c.level)],
      tentUnlocked: view.tent,
    );

    return ClipRect(
      child: AnimatedScale(
        scale: _controller.cameraZoom,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        child: SizedBox(
          key: _meadowKey,
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Each looping animation paints in its own layer (spec 002, Т8).
              RepaintBoundary(
                child: MeadowDecorLayer(
                  herdCount: herd.length,
                  meadowSize: Size(w, h),
                ),
              ),
              RepaintBoundary(
                child: PlacedHomeDecorLayer(
                  placedIds: view.placed,
                  meadowSize: Size(w, h),
                ),
              ),
              // Temporary mud puddle (behind capys). Absent during cooldown.
              if (mud != null)
                Positioned(
                  left: mud.dx * w - CapyWander.mudAnchorX,
                  top: mud.dy * h - CapyWander.mudAnchorY,
                  child: RepaintBoundary(
                    child: MudPuddle(
                      key: ValueKey(
                        '${mud.dx.toStringAsFixed(3)}:'
                        '${mud.dy.toStringAsFixed(3)}',
                      ),
                      isWallowing: view.wallowing != null,
                      boostActive: view.mudBoost,
                    ),
                  ),
                ),
              // Cozy places (пень / камень / тент)
              for (final kind in props.places.keys)
                Positioned(
                  left: props.places[kind]!.dx * w - 36,
                  top: props.places[kind]!.dy * h - 32,
                  child: RepaintBoundary(
                    child: _PlaceSlot(
                      controller: _controller,
                      kind: kind,
                      onTap: () {
                        unawaited(_audio.noteUserGesture());
                        final ok = _controller.tryActivatePlace(kind);
                        if (ok) widget.onFloat(kind.emoji, Offset.zero);
                      },
                    ),
                  ),
                ),
              ...List.generate(props.flowers.length, (i) {
                final flower = props.flowers[i];
                return Positioned(
                  left: flower.dx * w - FlowerDot.hitSize / 2,
                  top: flower.dy * h - FlowerDot.hitSize / 2,
                  child: RepaintBoundary(
                    child: FlowerDot(
                      color: _flowerColors[i % _flowerColors.length],
                      swayPhase: i / props.flowers.length,
                      onTap: _onFlowerTap,
                    ),
                  ),
                );
              }),
              if (view.berry)
                Positioned(
                  left: BalanceV0.berryPosX * w - 60,
                  top: BalanceV0.berryPosY * h - 44,
                  child: RepaintBoundary(
                    child: BerryBasket(
                      onTap: _onBerryTap,
                      showHint: !_berryHintSeen,
                    ),
                  ),
                ),
              if (_mergePair(herd, Size(w, h)) case final pair?)
                QuietMergeArc(from: pair.$1, to: pair.$2),
              for (final capy in herd)
                _capy(capy, view, meadowKey, Size(w, h), props),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capy(
    Capybara capy,
    _MeadowView view,
    int meadowKey,
    Size meadow,
    MeadowProps props,
  ) {
    final promote =
        _badgePromoted.contains(capy.id) ||
        view.flash == capy.id ||
        _magnetAttractedId == capy.id;
    return MeadowDraggableCapybara(
      key: ValueKey(capy.id),
      capybara: capy,
      herd: view.herd,
      // Active glade rect, not body count. Count was read as family power
      // and walked them off the meadow, then the drop clamp piled them back
      // onto one edge.
      herdCount: meadowKey,
      meadowSize: meadow,
      meadowOriginGlobal: _meadowOriginGlobal,
      onMerge: _onMerge,
      onDropPosition: _controller.updatePosition,
      onMudDrop: _onMudDrop,
      isOverMud: _controller.isOverMud,
      isWallowing: view.wallowing == capy.id,
      mergeFlash: view.flash == capy.id,
      twinSparkle: capy.id == view.twinA || capy.id == view.twinB,
      magnetAttractedId: _magnetAttractedId,
      promoteLevelBadge: promote,
      magnetRadius: view.magnet,
      placeAt: (o) {
        for (final e in props.places.entries) {
          if ((o - e.value).distance <= BalanceV0.placeHitRadius) {
            return e.key;
          }
        }
        return null;
      },
      mudCenter: view.mud,
      livePositions: _livePositions,
      onPlaceDrop: (id, kind) {
        unawaited(_audio.noteUserGesture());
        final ok = _controller.tryActivatePlace(
          kind,
          capyId: id,
          standAt: props.places[kind],
        );
        if (ok) widget.onFloat(kind.emoji, Offset.zero);
        return ok;
      },
      onLongPress: () {
        unawaited(_audio.noteUserGesture());
        HapticFeedback.mediumImpact();
        UyutHubSheet.show(
          context,
          controller: _controller,
          initialTab: 1,
          focusCapyId: capy.id,
        );
      },
      onDragBadge: () => _promoteBadge(capy.id),
      onMagnetTargetChanged: (id) {
        if (_magnetAttractedId == id) return;
        setState(() => _magnetAttractedId = id);
      },
    );
  }

  /// Dotted arc for a same-level pair that is close, but not stacked.
  ///
  /// Magnet snap stays at [GameController.effectiveMagnetRadius]. The arc
  /// uses sprite pixels so a grass gap still reads, and a pile does not.
  static (Offset, Offset)? _mergePair(List<Capybara> herd, Size meadow) {
    (Offset, Offset)? best;
    var bestDist = double.infinity;
    final minPx = BalanceV0.baseCapySize * 0.95;
    final maxPx = BalanceV0.baseCapySize * 2.6;
    final min2 = minPx * minPx;
    final max2 = maxPx * maxPx;
    for (var i = 0; i < herd.length; i++) {
      for (var j = i + 1; j < herd.length; j++) {
        final a = herd[i];
        final b = herd[j];
        if (a.level != b.level) continue;
        final dx = (a.position.dx - b.position.dx) * meadow.width;
        final dy = (a.position.dy - b.position.dy) * meadow.height;
        final dist2 = dx * dx + dy * dy;
        if (dist2 < min2 || dist2 > max2) continue;
        if (dist2 < bestDist) {
          bestDist = dist2;
          best = (a.position, b.position);
        }
      }
    }
    return best;
  }
}

/// One cozy place marker. Rebuilds when it turns on or off, its cooldown
/// starts or ends, or the seconds on it change — not every tick.
class _PlaceSlot extends StatelessWidget {
  const _PlaceSlot({
    required this.controller,
    required this.kind,
    required this.onTap,
  });

  final GameController controller;
  final CozyPlaceKind kind;
  final VoidCallback onTap;

  /// The marker shows `ceil()` seconds above 0.4 s; below it, nothing.
  (bool, bool, int) _view() {
    final cooling = controller.isPlaceOnCooldown(kind);
    final left = controller.placeCooldownRemaining(kind);
    return (
      controller.activePlaceBoost == kind,
      cooling,
      cooling && left > 0.4 ? left.ceil() : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameSelector<(bool, bool, int)>(
      listenable: controller,
      select: _view,
      builder: (context, view) => CozyPlaceMarker(
        kind: kind,
        active: view.$1,
        onCooldown: view.$2,
        cooldownSeconds: controller.placeCooldownRemaining(kind),
        onTap: onTap,
      ),
    );
  }
}
