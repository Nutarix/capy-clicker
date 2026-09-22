import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/balance.dart';
import '../models/capybara.dart';
import '../models/merge_magnet.dart';
import 'capybara_placeholder.dart';
import 'mud_puddle.dart';

/// Meadow-aware draggable: merge on same-level drop, soft magnet assist,
/// wallow on mud drop.
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
    this.isWallowing = false,
    this.mergeFlash = false,
    this.twinSparkle = false,
    this.magnetAttractedId,
    this.promoteLevelBadge = false,
    this.onDragBadge,
    this.onMagnetTargetChanged,
  });

  final Capybara capybara;
  final List<Capybara> herd;
  final Size meadowSize;
  final Offset meadowOriginGlobal;
  final bool Function(String draggedId, String targetId) onMerge;
  final void Function(String id, Offset normalized) onDropPosition;
  final bool Function(String id) onMudDrop;
  final bool Function(Offset normalized) isOverMud;
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

  @override
  State<MeadowDraggableCapybara> createState() =>
      _MeadowDraggableCapybaraState();
}

class _MeadowDraggableCapybaraState extends State<MeadowDraggableCapybara> {
  /// Soft-magnet target id while dragging (for subtle pull glow).
  String? _magnetTargetId;

  /// True after a mid-drag magnet merge so onDragEnd skips drop/mud.
  bool _mergedDuringDrag = false;

  /// Extra offset applied to feedback when soft-pulling toward a magnet.
  Offset _pullOffset = Offset.zero;

  double get _bodyWidth => BalanceV0.capySizeForLevel(widget.capybara.level);

  Size get _footprint {
    final w = _bodyWidth;
    return Size(w + 8, w * 0.95 + 26);
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
    if (hit != null && MergeMagnet.withinSnapDistance(hit.distance)) {
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
    _notifyMagnet(null);
    if (mounted) setState(() => _pullOffset = Offset.zero);

    if (mergedAlready || details.wasAccepted) return;

    final normalized = _normalizedFromFeedbackTopLeft(details.offset);

    // Soft magnet on release: any same-level within full magnetRadius.
    final hit = _hitAt(normalized);
    if (hit != null && _tryMagnetMerge(hit)) return;

    if (widget.isOverMud(normalized)) {
      final ok = widget.onMudDrop(widget.capybara.id);
      if (ok) {
        HapticFeedback.mediumImpact();
        return;
      }
    }
    widget.onDropPosition(widget.capybara.id, normalized);
  }

  @override
  Widget build(BuildContext context) {
    final footprint = _footprint;
    final left =
        widget.capybara.position.dx * widget.meadowSize.width -
        footprint.width / 2;
    final top =
        widget.capybara.position.dy * widget.meadowSize.height -
        footprint.height / 2;

    final magnetHighlight =
        widget.magnetAttractedId == widget.capybara.id;
    final fullBadge = widget.promoteLevelBadge || magnetHighlight;

    Widget visual = CapybaraPlaceholder(
      level: widget.capybara.level,
      flash: widget.mergeFlash,
        twinSparkle: widget.twinSparkle,
      compactLabel: !fullBadge,
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
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != widget.capybara.id,
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
                    compactLabel: false,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.22,
              child: CapybaraPlaceholder(
                level: widget.capybara.level,
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
