import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/balance.dart';
import '../models/capy_wander.dart';
import '../models/capy_walk.dart';
import '../models/capybara.dart';
import '../models/multipliers/capy_role.dart';
import 'uyut/multiplier_icon.dart';
import '../models/multipliers/cozy_place.dart';
import '../models/merge_magnet.dart';
import 'capybara_placeholder.dart';
import 'mud_puddle.dart';

/// Meadow-aware draggable: merge on same-level drop, soft magnet assist,
/// wallow on mud drop, idle bob + wander walk.
class MeadowDraggableCapybara extends StatefulWidget {
  const MeadowDraggableCapybara({
    super.key,
    required this.capybara,
    required this.herd,
    required this.meadowSize,
    required this.meadowOriginGlobal,
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
  });

  final Capybara capybara;
  final List<Capybara> herd;
  final Size meadowSize;
  final Offset meadowOriginGlobal;
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

  /// Extra offset applied to feedback when soft-pulling toward a magnet.
  Offset _pullOffset = Offset.zero;

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
  }

  @override
  void didUpdateWidget(covariant MeadowDraggableCapybara oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWallowing && !oldWidget.isWallowing) {
      _cancelWalk(commit: false);
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
    if (!_walking &&
        !_dragging &&
        widget.capybara.position != oldWidget.capybara.position) {
      _displayPos = widget.capybara.position;
    }
  }

  @override
  void dispose() {
    _wanderTimer?.cancel();
    _idleBob.dispose();
    _walkCycle.dispose();
    _walk.dispose();
    super.dispose();
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
    final to = CapyWander.pickTarget(
      from: from,
      random01: _rng.nextDouble,
      herdCount: widget.herdCount,
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
      }
      _walkFrom = null;
      _walkTo = null;
    }
    if (!_dragging && mounted) {
      _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
    }
  }

  Offset _normalizedFromFeedbackTopLeft(Offset feedbackTopLeft) {
    final footprint = _footprint;
    final local = feedbackTopLeft - widget.meadowOriginGlobal;
    final nx = (local.dx + footprint.width / 2) / widget.meadowSize.width;
    final ny = (local.dy + footprint.height / 2) / widget.meadowSize.height;
    return Offset(nx, ny);
  }

  Offset _normalizedFromPointer(Offset globalPointer) {
    final local = globalPointer - widget.meadowOriginGlobal;
    return Offset(
      local.dx / widget.meadowSize.width,
      local.dy / widget.meadowSize.height,
    );
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
      if (_pullOffset != Offset.zero && mounted) {
        setState(() => _pullOffset = Offset.zero);
      }
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
    if (_pullOffset != nextPull && mounted) {
      setState(() => _pullOffset = nextPull);
    }
  }

  void _onDragStarted() {
    _dragging = true;
    _cancelWalk(commit: false);
    _mergedDuringDrag = false;
    _pullOffset = Offset.zero;
    _notifyMagnet(null);
    widget.onDragBadge?.call();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_mergedDuringDrag) return;
    final normalized = _normalizedFromPointer(details.globalPosition);
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
        if (mounted) setState(() => _pullOffset = Offset.zero);
      }
    }
  }

  void _onDragEnd(DraggableDetails details) {
    final mergedAlready = _mergedDuringDrag;
    _mergedDuringDrag = false;
    _dragging = false;
    _notifyMagnet(null);
    if (mounted) setState(() => _pullOffset = Offset.zero);

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

    if (widget.isOverMud(normalized)) {
      final ok = widget.onMudDrop(widget.capybara.id);
      if (ok) {
        HapticFeedback.mediumImpact();
        _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
        return;
      }
    }
    final place = widget.placeAt?.call(normalized);
    if (place != null && widget.onPlaceDrop != null) {
      final ok = widget.onPlaceDrop!(widget.capybara.id, place);
      if (ok) {
        HapticFeedback.mediumImpact();
        _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
        return;
      }
    }
    _displayPos = normalized;
    widget.onDropPosition(widget.capybara.id, normalized);
    _scheduleWander(CapyWander.pauseBetweenWalks(_rng.nextDouble));
  }

  @override
  Widget build(BuildContext context) {
    final footprint = _footprint;
    final left =
        _displayPos.dx * widget.meadowSize.width - footprint.width / 2;
    final top =
        _displayPos.dy * widget.meadowSize.height - footprint.height / 2;

    final magnetHighlight =
        widget.magnetAttractedId == widget.capybara.id;
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
        final idleY =
            _walking ? 0.0 : CapyWalk.idleBobY(sheet, _idleBob.value);
        final idleX =
            _walking ? 0.0 : CapyWalk.idleSwayX(sheet, _idleBob.value);
        final walkY =
            _walking ? CapyWander.walkBounceY(_walk.value) : 0.0;
        final squash =
            _walking ? 1.0 : CapyWalk.idleSquashY(sheet, _idleBob.value);
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
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: DragTarget<String>(
          onWillAcceptWithDetails: (details) =>
              details.data != widget.capybara.id,
          onAcceptWithDetails: (details) {
            final ok = widget.onMerge(details.data, widget.capybara.id);
            if (ok) HapticFeedback.mediumImpact();
          },
          builder: (context, candidate, _) {
            final highlight = candidate.isNotEmpty || magnetHighlight;
            return Draggable<String>(
              data: widget.capybara.id,
              feedback: Transform.translate(
                offset: _pullOffset,
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
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.22), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
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
