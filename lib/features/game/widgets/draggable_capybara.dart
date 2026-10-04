import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/balance.dart';
import '../models/capy_wander.dart';
import '../models/capy_walk.dart';
import '../models/capybara.dart';
import '../models/multipliers/capy_role.dart';
import 'uyut/multiplier_icon.dart';
import '../models/multipliers/cozy_place.dart';
import '../models/merge_magnet.dart';
import 'capybara_placeholder.dart';
import 'meadow_space.dart';
import 'mud_puddle.dart';

/// Meadow-aware draggable: merge on same-level drop, soft magnet assist,
/// wallow on mud drop, idle bob + wander walk.
class MeadowDraggableCapybara extends StatefulWidget {
  const MeadowDraggableCapybara({
    super.key,
    required this.capybara,
    required this.herd,
    required this.meadowSize,
    this.space,
    required this.onMerge,
    required this.onDropPosition,
    required this.onMudDrop,
    required this.isOverMud,
    this.herdCount = 0,
    this.isWallowing = false,
    this.mergeFlash = false,
    this.twinSparkle = false,
    this.magnetAttractedId,
    this.promoteLevelBadge = false,
    this.onDragBadge,
    this.onMagnetTargetChanged,
    this.magnetRadius = BalanceV0.magnetRadius,
    this.onPlaceDrop,
    this.placeAt,
    this.onLongPress,
    this.mudCenter,
    this.livePositions,
  });

  final Capybara capybara;
  final List<Capybara> herd;
  final Size meadowSize;

  /// Screen ↔ meadow (spec 003, Т2), read when a drag needs it: the camera
  /// may still be easing. Null or not laid out: the meadow starts at the
  /// screen origin, unscaled (bare widget tests).
  final MeadowSpace? space;
  final bool Function(String draggedId, String targetId) onMerge;
  final void Function(String id, Offset normalized) onDropPosition;
  final bool Function(String id) onMudDrop;
  final bool Function(Offset normalized) isOverMud;

  /// Active herd size for [WorldZones] clamp / random wander.
  final int herdCount;

  final bool isWallowing;
  final bool mergeFlash;

  /// Subtle twin-sparkle mark for the skill-merge pair.
  final bool twinSparkle;

  /// Herd id currently being soft-pulled toward (set by the dragged sibling).
  final String? magnetAttractedId;

  /// Show full Lv badge (dragged / recently merged / magnet target).
  final bool promoteLevelBadge;

  /// Called when this capy starts being dragged (promote its badge).
  final VoidCallback? onDragBadge;

  /// Reports magnet target changes so the parent can glow the attracted capy.
  final ValueChanged<String?>? onMagnetTargetChanged;

  /// Effective magnet radius (food/place bonuses).
  final double magnetRadius;

  /// Drop onto cozy place (пень / камень / тент).
  final bool Function(String id, CozyPlaceKind kind)? onPlaceDrop;

  /// Resolve place under normalized point.
  final CozyPlaceKind? Function(Offset normalized)? placeAt;

  /// Long-press → role menu.
  final VoidCallback? onLongPress;

  /// Live puddle center, so wander does not park a body on the stump-top.
  final Offset? mudCenter;

  /// Latest displayed anchor per capy, shared by the meadow's family, so a
  /// walk does not cut through a peer that has not persisted its destination
  /// yet. Owned by the meadow (one per game screen). Null: this capy only.
  final Map<String, Offset>? livePositions;

  @override
  State<MeadowDraggableCapybara> createState() =>
      _MeadowDraggableCapybaraState();
}

class _MeadowDraggableCapybaraState extends State<MeadowDraggableCapybara>
    with TickerProviderStateMixin {
  /// Soft-magnet target id while dragging (for subtle pull glow).
  String? _magnetTargetId;

  /// True after a mid-drag magnet merge so onDragEnd skips drop/mud.
  bool _mergedDuringDrag = false;

  /// Soft pull toward the magnet target, meadow pixels. The feedback is
  /// built once at drag start, so it listens to this (spec 003, Т4).
  final ValueNotifier<Offset> _pull = ValueNotifier(Offset.zero);

  /// Last finger point in meadow space (hit mud even if the sprite center misses).
  Offset? _lastPointerNorm;

  /// Screen pixels per meadow pixel when this drag started (camera zoom).
  /// The feedback is drawn at this size, so it matches the capy on the meadow.
  final ValueNotifier<double> _dragScale = ValueNotifier(1);

  /// Finger inside the sprite at drag start, meadow pixels.
  Offset _dragAnchor = Offset.zero;

  late final AnimationController _idleBob;
  late final AnimationController _walk;

  /// 4-frame walk-cycle loop (paws); repeats only while [_walking].
  late final AnimationController _walkCycle;

  final math.Random _rng = math.Random();

  /// Display position (may ease during wander before persisting).
  late Offset _displayPos;
  Offset? _walkFrom;
  Offset? _walkTo;
  bool _walking = false;
  bool _dragging = false;
  bool _faceRight = true;
  Timer? _wanderTimer;
  bool _escapeScheduled = false;

  final Map<String, Offset> _ownLivePositions = {};

  Map<String, Offset> get _live => widget.livePositions ?? _ownLivePositions;

  double get _bodyWidth => BalanceV0.capySizeForLevel(widget.capybara.level);

  Size get _footprint {
    final w = _bodyWidth;
    return Size(w + 8, w * 0.95 + 26);
  }

  bool get _wanderBlocked =>
      _dragging || widget.isWallowing || widget.mergeFlash;

  CapyWalkSheet get _sheet => CapyWalk.sheetFor(
    level: widget.capybara.level,
    role: widget.capybara.role,
  );

  int get _currentWalkFrame {
    if (!_walking) return 0;
    return CapyWalk.frameFromLoop01(_walkCycle.value);
  }

  @override
  void initState() {
    super.initState();
    _displayPos = widget.capybara.position;
    _live[widget.capybara.id] = _displayPos;
    _idleBob = AnimationController(
      vsync: this,
      duration: CapyWalk.idlePeriod(_sheet, widget.capybara.id),
    );
    // Phase-offset start so the Семья does not bob in sync.
    _idleBob.value = CapyWander.phase01(widget.capybara.id);
    _idleBob.repeat(reverse: true);

    _walkCycle = AnimationController(vsync: this);

    _walk = AnimationController(vsync: this)
      ..addListener(() {
        if (!_walking || _walkFrom == null || _walkTo == null) return;
        final next = CapyWander.lerp(_walkFrom!, _walkTo!, _walk.value);
        final peers = _peers();
        if (_walkEntersNew(next, peers)) {
          // Hold the last clear spot. Stopping the controller from its
          // listener must not re-enter via the completed status.
          _walking = false;
          _walk.stop();
          _walkCycle.stop();
          _walkCycle.value = 0;
          _walkFrom = null;
          _walkTo = null;
          _live[widget.capybara.id] = _displayPos;
          widget.onDropPosition(widget.capybara.id, _displayPos);
          _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
          return;
        }
        _live[widget.capybara.id] = next;
        if (mounted) setState(() => _displayPos = next);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onWalkCompleted();
        }
      });

    _scheduleWander(
      CapyWander.initialDelay(widget.capybara.id, _rng.nextDouble),
    );
    _scheduleEscape();
  }

  @override
  void didUpdateWidget(covariant MeadowDraggableCapybara oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWallowing && !oldWidget.isWallowing) {
      _cancelWalk(commit: false);
      _displayPos = widget.capybara.position;
      _live[widget.capybara.id] = _displayPos;
    }
    if (widget.mergeFlash && !oldWidget.mergeFlash) {
      _cancelWalk(commit: false);
    }
    // Role / level change → switch walk sheet + idle flavour.
    if (widget.capybara.role != oldWidget.capybara.role ||
        widget.capybara.level != oldWidget.capybara.level) {
      _idleBob.duration = CapyWalk.idlePeriod(_sheet, widget.capybara.id);
      if (!_idleBob.isAnimating) {
        _idleBob.repeat(reverse: true);
      }
      if (_walking) {
        _walkCycle.duration = CapyWalk.loopDuration(_sheet);
        if (!_walkCycle.isAnimating) {
          _walkCycle.repeat();
        }
      }
    }
    // External position change (merge spawn, mud snap, load) — sync when idle.
    final posMoved = widget.capybara.position != oldWidget.capybara.position;
    if (!_walking && !_dragging && posMoved) {
      _displayPos = widget.capybara.position;
      _live[widget.capybara.id] = _displayPos;
    }
    final wallowEnded = oldWidget.isWallowing && !widget.isWallowing;
    final mudMoved = widget.mudCenter != oldWidget.mudCenter;
    final meadowMoved = widget.meadowSize != oldWidget.meadowSize;
    // Wallow parks the body on the disc for the splash. As soon as that
    // ends — or the puddle appears under someone — step off the wood ring
    // and off the «сюда!» chip. Do not wait for the next wander hop.
    if (!widget.isWallowing &&
        (wallowEnded || mudMoved || meadowMoved || posMoved)) {
      _scheduleEscape();
    }
  }

  void _scheduleEscape() {
    if (_escapeScheduled) return;
    _escapeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _escapeScheduled = false;
      if (mounted) _escapeForbiddenGround();
    });
  }

  /// Snap off the painted wood ring and the hint chip. Peers already in
  /// [MeadowDraggableCapybara.livePositions] keep the grass gap, so a herd
  /// leaving the same disc does not restack.
  void _escapeForbiddenGround() {
    if (!mounted || _dragging || widget.isWallowing || widget.mergeFlash) {
      return;
    }
    final meadow = widget.meadowSize;
    if (meadow.width < 8 || meadow.height < 8) return;
    final mud = widget.mudCenter;
    final width = _bodyWidth;
    bool blocked(Offset p) => CapyWander.hitsProp(
      p,
      mudCenter: mud,
      meadowSize: meadow,
      capyWidth: width,
    );
    if (!blocked(_displayPos)) return;

    _cancelWalk(commit: false);
    final peers = _peers();
    var dest = CapyWander.pickTarget(
      from: _displayPos,
      random01: _rng.nextDouble,
      herdCount: widget.herdCount,
      others: peers.positions,
      mudCenter: mud,
      meadowSize: meadow,
      capyWidth: width,
      spreadSalt: CapyWander.phase01(widget.capybara.id),
      peerWidths: peers.widths,
      minDist: 0.02,
    );
    if (blocked(dest)) {
      dest = CapyWander.clearProps(
        _displayPos,
        herdCount: widget.herdCount,
        mudCenter: mud,
        meadowSize: meadow,
        capyWidth: width,
        salt: CapyWander.phase01(widget.capybara.id),
      );
    }
    if (blocked(dest) || (dest - _displayPos).distance < 0.008) return;
    _displayPos = dest;
    _live[widget.capybara.id] = dest;
    widget.onDropPosition(widget.capybara.id, dest);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _live.remove(widget.capybara.id);
    _wanderTimer?.cancel();
    _idleBob.dispose();
    _walkCycle.dispose();
    _walk.dispose();
    _dragScale.dispose();
    _pull.dispose();
    super.dispose();
  }

  bool _walkEntersNew(
    Offset next,
    ({List<Offset> positions, List<double> widths}) peers,
  ) {
    final meadow = widget.meadowSize;
    final mud = widget.mudCenter;
    final width = _bodyWidth;
    final nextProp = CapyWander.hitsProp(
      next,
      mudCenter: mud,
      meadowSize: meadow,
      capyWidth: width,
    );
    final hereProp = CapyWander.hitsProp(
      _displayPos,
      mudCenter: mud,
      meadowSize: meadow,
      capyWidth: width,
    );
    if (nextProp && !hereProp) return true;
    // A full strip may narrow down to peerGrassPx. Below that, only a step
    // that opens grass is allowed, so a walk cannot pull two sprites together.
    return CapyWander.peerGapShrinks(
      _displayPos,
      next,
      peers.positions,
      meadowSize: meadow,
      capyWidth: width,
      peerWidths: peers.widths,
    );
  }

  ({List<Offset> positions, List<double> widths}) _peers() {
    final positions = <Offset>[];
    final widths = <double>[];
    for (final c in widget.herd) {
      if (c.id == widget.capybara.id) continue;
      positions.add(_live[c.id] ?? c.position);
      widths.add(BalanceV0.capySizeForLevel(c.level));
    }
    return (positions: positions, widths: widths);
  }

  void _scheduleWander(Duration delay) {
    _wanderTimer?.cancel();
    _wanderTimer = Timer(delay, _tryStartWalk);
  }

  void _tryStartWalk() {
    if (!mounted) return;
    if (_wanderBlocked) {
      _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
      return;
    }
    final from = _displayPos;
    final peers = _peers();
    final picked = CapyWander.pickTarget(
      from: from,
      random01: _rng.nextDouble,
      herdCount: widget.herdCount,
      others: peers.positions,
      mudCenter: widget.mudCenter,
      meadowSize: widget.meadowSize,
      capyWidth: _bodyWidth,
      spreadSalt: CapyWander.phase01(widget.capybara.id),
      peerWidths: peers.widths,
    );
    final to = CapyWander.clipTravel(
      from: from,
      to: picked,
      others: peers.positions,
      herdCount: widget.herdCount,
      mudCenter: widget.mudCenter,
      meadowSize: widget.meadowSize,
      capyWidth: _bodyWidth,
      peerWidths: peers.widths,
    );
    // Tiny hops look twitchy — skip and retry later.
    if ((to - from).distance < 0.03) {
      _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
      return;
    }
    _walkFrom = from;
    _walkTo = to;
    _faceRight = CapyWander.faceRight(from, to);
    _walking = true;
    _walk.duration = CapyWander.walkDuration(from, to);
    _walkCycle.duration = CapyWalk.loopDuration(_sheet);
    _walkCycle.repeat();
    _walk.forward(from: 0);
  }

  void _onWalkCompleted() {
    if (!mounted) return;
    final dest = _walkTo ?? _displayPos;
    _walking = false;
    _walkCycle.stop();
    _walkCycle.value = 0;
    _walkFrom = null;
    _walkTo = null;
    _displayPos = dest;
    _live[widget.capybara.id] = dest;
    // Persist like drag-end (clamped inside controller).
    widget.onDropPosition(widget.capybara.id, dest);
    _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
  }

  void _cancelWalk({required bool commit}) {
    _wanderTimer?.cancel();
    if (_walking) {
      _walk.stop();
      _walkCycle.stop();
      _walkCycle.value = 0;
      _walking = false;
      if (commit && _walkTo != null) {
        widget.onDropPosition(widget.capybara.id, _displayPos);
      } else {
        _displayPos = widget.capybara.position;
        _live[widget.capybara.id] = _displayPos;
      }
      _walkFrom = null;
      _walkTo = null;
    }
    if (!_dragging && mounted) {
      _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
    }
  }

  /// Screen point → meadow pixels (live transform: offset, zoom, center).
  Offset _meadowLocal(Offset global) =>
      widget.space?.globalToLocal(global) ?? global;

  Offset _normalized(Offset local) => Offset(
    local.dx / widget.meadowSize.width,
    local.dy / widget.meadowSize.height,
  );

  /// Where the sprite center lands: the finger keeps its spot in the sprite.
  /// [feedbackTopLeft] is the drag's top-left on screen (finger − anchor).
  Offset _normalizedFromFeedbackTopLeft(Offset feedbackTopLeft) {
    final finger = feedbackTopLeft + _dragAnchor * _dragScale.value;
    final footprint = _footprint;
    final local =
        _meadowLocal(finger) -
        _dragAnchor +
        Offset(footprint.width / 2, footprint.height / 2);
    return _normalized(local);
  }

  Offset _normalizedFromPointer(Offset globalPointer) =>
      _normalized(_meadowLocal(globalPointer));

  /// Grab point: the finger in the sprite, scaled like the feedback, so the
  /// feedback lies exactly over the capy at drag start at any zoom.
  Offset _dragAnchorStrategy(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    final box = context.findRenderObject() as RenderBox?;
    _dragAnchor = box == null ? Offset.zero : box.globalToLocal(position);
    _dragScale.value = widget.space?.scale ?? 1;
    return _dragAnchor * _dragScale.value;
  }

  MergeMagnetHit? _hitAt(Offset dragNormalized) {
    return MergeMagnet.nearestEligible(
      draggedId: widget.capybara.id,
      draggedLevel: widget.capybara.level,
      dragNormalized: dragNormalized,
      herd: widget.herd,
      radius: widget.magnetRadius,
    );
  }

  bool _tryMagnetMerge(MergeMagnetHit hit) {
    // Haptics live in the parent's onMerge callback (same juice as manual).
    return widget.onMerge(widget.capybara.id, hit.target.id);
  }

  void _notifyMagnet(String? id) {
    if (_magnetTargetId == id) return;
    _magnetTargetId = id;
    widget.onMagnetTargetChanged?.call(id);
  }

  void _updateMagnetVisual(MergeMagnetHit? hit, Offset dragNormalized) {
    if (hit == null) {
      _notifyMagnet(null);
      _pull.value = Offset.zero;
      return;
    }

    // Subtle pull: lerp feedback toward target in meadow pixel space.
    final pulled = MergeMagnet.lerpToward(
      dragNormalized,
      hit.target.position,
      BalanceV0.magnetPullLerp,
    );
    final dx = (pulled.dx - dragNormalized.dx) * widget.meadowSize.width;
    final dy = (pulled.dy - dragNormalized.dy) * widget.meadowSize.height;
    final nextPull = Offset(dx, dy);
    _notifyMagnet(hit.target.id);
    _pull.value = nextPull;
  }

  void _onDragStarted() {
    _dragging = true;
    _lastPointerNorm = null;
    _cancelWalk(commit: false);
    _mergedDuringDrag = false;
    _pull.value = Offset.zero;
    _notifyMagnet(null);
    widget.onDragBadge?.call();
  }

  bool _droppedOnMud(Offset spriteCenter) {
    if (widget.isOverMud(spriteCenter)) return true;
    final finger = _lastPointerNorm;
    return finger != null && widget.isOverMud(finger);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_mergedDuringDrag) return;
    final normalized = _normalizedFromPointer(details.globalPosition);
    _lastPointerNorm = normalized;
    final hit = _hitAt(normalized);
    _updateMagnetVisual(hit, normalized);

    // Mid-drag complete only when clearly inside the snap band.
    if (hit != null &&
        MergeMagnet.withinSnapDistance(
          hit.distance,
          radius: widget.magnetRadius,
        )) {
      if (_tryMagnetMerge(hit)) {
        _mergedDuringDrag = true;
        _notifyMagnet(null);
        _pull.value = Offset.zero;
      }
    }
  }

  void _onDragEnd(DraggableDetails details) {
    final mergedAlready = _mergedDuringDrag;
    _mergedDuringDrag = false;
    _dragging = false;
    _notifyMagnet(null);
    _pull.value = Offset.zero;

    if (mergedAlready || details.wasAccepted) {
      _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
      return;
    }

    final normalized = _normalizedFromFeedbackTopLeft(details.offset);

    // Soft magnet on release: any same-level within full magnetRadius.
    final hit = _hitAt(normalized);
    if (hit != null && _tryMagnetMerge(hit)) {
      _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
      return;
    }

    if (_droppedOnMud(normalized)) {
      // Haptics live in the meadow's callbacks: one per action (Т5).
      final ok = widget.onMudDrop(widget.capybara.id);
      if (ok) {
        _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
        return;
      }
    }
    final place = widget.placeAt?.call(normalized);
    if (place != null && widget.onPlaceDrop != null) {
      final ok = widget.onPlaceDrop!(widget.capybara.id, place);
      if (ok) {
        _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
        return;
      }
    }
    _displayPos = normalized;
    _live[widget.capybara.id] = normalized;
    widget.onDropPosition(widget.capybara.id, normalized);
    _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
  }

  @override
  Widget build(BuildContext context) {
    final footprint = _footprint;
    final left = _displayPos.dx * widget.meadowSize.width - footprint.width / 2;
    final top =
        _displayPos.dy * widget.meadowSize.height - footprint.height / 2;

    final magnetHighlight = widget.magnetAttractedId == widget.capybara.id;
    final fullBadge = widget.promoteLevelBadge || magnetHighlight;

    // Idle bob (unique per sheet) + walk bounce; facing via faceRight.
    // Walk-cycle frames rebuild via _walkCycle. Wallow/merge wrap OUTSIDE
    // so stateful overlays are not recreated every tick.
    Widget visual = AnimatedBuilder(
      animation: Listenable.merge([_idleBob, _walk, _walkCycle]),
      builder: (context, child) {
        Widget body = CapybaraPlaceholder(
          level: widget.capybara.level,
          role: widget.capybara.role,
          walkFrame: _currentWalkFrame,
          flash: widget.mergeFlash,
          twinSparkle: widget.twinSparkle,
          compactLabel: !fullBadge,
          faceRight: _faceRight,
        );
        final role = widget.capybara.role;
        if (role != null) {
          body = Stack(
            clipBehavior: Clip.none,
            children: [
              body,
              Positioned(
                right: -4,
                top: -6,
                child: MultiplierIcon(assetPath: role.assetPath, size: 20),
              ),
            ],
          );
        }
        final sheet = _sheet;
        final idleY = _walking ? 0.0 : CapyWalk.idleBobY(sheet, _idleBob.value);
        final idleX = _walking
            ? 0.0
            : CapyWalk.idleSwayX(sheet, _idleBob.value);
        final walkY = _walking ? CapyWander.walkBounceY(_walk.value) : 0.0;
        final squash = _walking
            ? 1.0
            : CapyWalk.idleSquashY(sheet, _idleBob.value);
        return Transform.translate(
          offset: Offset(idleX, idleY + walkY),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1.0, squash, 1.0),
            child: body,
          ),
        );
      },
    );
    if (widget.isWallowing) {
      visual = WallowOverlay(child: visual);
    }
    if (widget.mergeFlash) {
      visual = _MergePunch(child: visual);
    }

    return Positioned(
      left: left,
      top: top,
      // Bob and walk repaint this capy only (spec 002, Т8).
      child: RepaintBoundary(
        child: GestureDetector(
          onLongPress: widget.onLongPress,
          child: DragTarget<String>(
            onWillAcceptWithDetails: (details) =>
                details.data != widget.capybara.id,
            // The meadow's onMerge buzzes, as for the magnet.
            onAcceptWithDetails: (details) =>
                widget.onMerge(details.data, widget.capybara.id),
            builder: (context, candidate, _) {
              final highlight = candidate.isNotEmpty || magnetHighlight;
              return Draggable<String>(
                data: widget.capybara.id,
                dragAnchorStrategy: _dragAnchorStrategy,
                // Built once at drag start: what changes later is listened to.
                feedback: ValueListenableBuilder<double>(
                  key: const ValueKey('capy-drag-feedback'),
                  valueListenable: _dragScale,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: child,
                  ),
                  // Pull in meadow pixels, inside the scale; eased so the
                  // lean is soft, not a jump at the magnet edge.
                  child: ValueListenableBuilder<Offset>(
                    valueListenable: _pull,
                    builder: (context, pull, child) =>
                        TweenAnimationBuilder<Offset>(
                          tween: Tween(begin: Offset.zero, end: pull),
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOut,
                          builder: (context, offset, child) =>
                              Transform.translate(offset: offset, child: child),
                          child: child,
                        ),
                    child: Material(
                      color: Colors.transparent,
                      child: Opacity(
                        opacity: 0.92,
                        child: CapybaraPlaceholder(
                          level: widget.capybara.level,
                          role: widget.capybara.role,
                          walkFrame: 0,
                          compactLabel: false,
                        ),
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.22,
                  child: CapybaraPlaceholder(
                    level: widget.capybara.level,
                    role: widget.capybara.role,
                    walkFrame: 0,
                    compactLabel: true,
                  ),
                ),
                onDragStarted: _onDragStarted,
                onDragUpdate: _onDragUpdate,
                onDragEnd: _onDragEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: highlight
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: magnetHighlight
                              ? Border.all(
                                  color: const Color(0xFFFFD54F),
                                  width: 2.5,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(
                                alpha: magnetHighlight ? 0.85 : 0.55,
                              ),
                              blurRadius: magnetHighlight ? 26 : 16,
                              spreadRadius: magnetHighlight ? 5 : 2,
                            ),
                          ],
                        )
                      : null,
                  child: visual,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Brief scale punch when a merge creates this capy.
class _MergePunch extends StatefulWidget {
  const _MergePunch({required this.child});

  final Widget child;

  @override
  State<_MergePunch> createState() => _MergePunchState();
}

class _MergePunchState extends State<_MergePunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: BalanceV0.mergeFlashDuration,
    )..forward();
    // The bounce is in the sequence. A curve that overshoots 1 (easeOutBack)
    // would push the sequence past its end: an error box, gray in release
    // (spec 003, Т12).
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.22), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
