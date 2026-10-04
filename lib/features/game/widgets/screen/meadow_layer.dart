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
import '../meadow_space.dart';
import '../mud_puddle.dart';
import '../placed_home_decor.dart';
import '../quiet_merge_arc.dart';
import '../uyut/uyut_hub_sheet.dart';
import 'place_slot.dart';

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
    this.space,
  });

  final GameController controller;
  final GameAudio audio;

  /// Screen ↔ meadow for this meadow (spec 003, Т2). The screen hands its
  /// own in, so the HUD can place «+капи» over the new capy. Null: own one.
  final MeadowSpace? space;

  /// Floating «+N%» / «×2» at a screen point.
  final void Function(String label, Offset globalAnchor, {Color? color})
  onFloat;

  @override
  State<MeadowLayer> createState() => _MeadowLayerState();
}

class _MeadowLayerState extends State<MeadowLayer> {
  late final MeadowSpace _space = widget.space ?? MeadowSpace();

  /// Soft-magnet target while a capy is being dragged (glow on attracted).
  String? _magnetAttractedId;

  /// Capy ids that should show a prominent Lv badge (drag / recent merge).
  final Set<String> _badgePromoted = {};
  Timer? _badgeClearTimer;

  /// Capys whose name shows by the level (spec 004, Т6): touched now, or
  /// let go less than [nameHold] ago.
  final Set<String> _namesShown = {};
  final Map<String, Timer> _nameTimers = {};

  /// How long a name stays after the finger leaves.
  static const nameHold = Duration(seconds: 2);

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
    for (final t in _nameTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  /// Finger on a capy: its name shows; off: it fades [nameHold] later.
  void _onCapyTouch(String id, bool down) {
    _nameTimers.remove(id)?.cancel();
    if (down) {
      if (_namesShown.add(id)) setState(() {});
      return;
    }
    _hideNameLater(id);
  }

  void _hideNameLater(String id) {
    _nameTimers[id] = Timer(nameHold, () {
      _nameTimers.remove(id);
      if (!mounted) return;
      if (_namesShown.remove(id)) setState(() {});
    });
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
      if (flash != null) {
        _promoteBadge(flash);
        // Who stayed: the merged capy shows its name for a moment.
        _namesShown.add(flash);
        _nameTimers.remove(flash)?.cancel();
        _hideNameLater(flash);
      }
    }
    return ok;
  }

  /// The place's sign rises from the place itself.
  void _floatAtPlace(CozyPlaceKind kind, MeadowProps props) {
    final place = props.places[kind];
    final at = place == null ? null : _space.toGlobal(place);
    if (at != null) widget.onFloat(kind.emoji, at);
  }

  bool _onMudDrop(String id) {
    final ok = _controller.tryMudWallow(id);
    if (ok) {
      HapticFeedback.lightImpact();
      unawaited(_audio.noteUserGesture());
      _audio.playWallow();
      // Float at the puddle center.
      final center =
          _controller.mudCenter ??
          const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY);
      final at = _space.toGlobal(center);
      if (at != null) {
        widget.onFloat('×2', at, color: const Color(0xFFB8860B));
      }
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    // Meadow animations repaint the meadow, never the bars around it.
    // Tight size: a looping child re-lays out the LayoutBuilder every frame,
    // and that layout must stop at this boundary, not reach the screen.
    return SizedBox.expand(
      child: RepaintBoundary(
        child: GameSelector<_MeadowView>(
          listenable: _controller,
          select: _view,
          builder: (context, view) => LayoutBuilder(
            builder: (context, constraints) =>
                _meadow(view, constraints.maxWidth, constraints.maxHeight),
          ),
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
        // The meadow box hands itself to [_space] while attached (spec 003,
        // Т1): a drag reads the live transform, zoom mid-ease included.
        child: MeadowSpaceAnchor(
          space: _space,
          child: SizedBox(
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
                      child: PlaceSlot(
                        controller: _controller,
                        kind: kind,
                        onTap: () {
                          unawaited(_audio.noteUserGesture());
                          final ok = _controller.tryActivatePlace(kind);
                          if (ok) _floatAtPlace(kind, props);
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
                if (QuietMergeArc.pairFor(herd, Size(w, h)) case final pair?)
                  QuietMergeArc(from: pair.$1, to: pair.$2),
                // A capy showing its name (touched, merge target) paints last,
                // so passing capys never cover the chip. Keys keep state.
                for (final capy in _paintOrder(herd))
                  _capy(capy, view, meadowKey, Size(w, h), props),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Capybara> _paintOrder(List<Capybara> herd) {
    bool onTop(Capybara c) =>
        _namesShown.contains(c.id) || _magnetAttractedId == c.id;
    if (!herd.any(onTop)) return herd;
    return [...herd.where((c) => !onTop(c)), ...herd.where(onTop)];
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
      space: _space,
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
      showName: _namesShown.contains(capy.id),
      berryVisible: view.berry,
      onTouch: (down) => _onCapyTouch(capy.id, down),
      onPlaceDrop: (id, kind) {
        unawaited(_audio.noteUserGesture());
        final ok = _controller.tryActivatePlace(
          kind,
          capyId: id,
          standAt: props.places[kind],
        );
        if (ok) {
          HapticFeedback.mediumImpact();
          _floatAtPlace(kind, props);
        }
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
}
