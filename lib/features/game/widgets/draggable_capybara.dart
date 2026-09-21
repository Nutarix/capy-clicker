import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/balance.dart';
import '../models/capybara.dart';
import 'capybara_placeholder.dart';
import 'mud_puddle.dart';

/// Meadow-aware draggable: merge on same-level drop, wallow on mud drop.
class MeadowDraggableCapybara extends StatelessWidget {
  const MeadowDraggableCapybara({
    super.key,
    required this.capybara,
    required this.meadowSize,
    required this.meadowOriginGlobal,
    required this.onMerge,
    required this.onDropPosition,
    required this.onMudDrop,
    required this.isOverMud,
    this.isWallowing = false,
    this.mergeFlash = false,
  });

  final Capybara capybara;
  final Size meadowSize;
  final Offset meadowOriginGlobal;
  final bool Function(String draggedId, String targetId) onMerge;
  final void Function(String id, Offset normalized) onDropPosition;
  final bool Function(String id) onMudDrop;
  final bool Function(Offset normalized) isOverMud;
  final bool isWallowing;
  final bool mergeFlash;

  double get _bodyWidth => BalanceV0.capySizeForLevel(capybara.level);

  Size get _footprint {
    final w = _bodyWidth;
    return Size(w + 8, w * 0.95 + 26);
  }

  @override
  Widget build(BuildContext context) {
    final footprint = _footprint;
    final left = capybara.position.dx * meadowSize.width - footprint.width / 2;
    final top = capybara.position.dy * meadowSize.height - footprint.height / 2;

    Widget visual = CapybaraPlaceholder(
      level: capybara.level,
      flash: mergeFlash,
    );
    if (isWallowing) {
      visual = WallowOverlay(child: visual);
    }
    if (mergeFlash) {
      visual = _MergePunch(child: visual);
    }

    return Positioned(
      left: left,
      top: top,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != capybara.id,
        onAcceptWithDetails: (details) {
          final ok = onMerge(details.data, capybara.id);
          if (ok) HapticFeedback.mediumImpact();
        },
        builder: (context, candidate, _) {
          final highlight = candidate.isNotEmpty;
          return Draggable<String>(
            data: capybara.id,
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.92,
                child: CapybaraPlaceholder(level: capybara.level),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.22,
              child: CapybaraPlaceholder(level: capybara.level),
            ),
            onDragEnd: (details) {
              if (details.wasAccepted) return;
              final local = details.offset - meadowOriginGlobal;
              final nx = (local.dx + footprint.width / 2) / meadowSize.width;
              final ny = (local.dy + footprint.height / 2) / meadowSize.height;
              final normalized = Offset(nx, ny);
              if (isOverMud(normalized)) {
                final ok = onMudDrop(capybara.id);
                if (ok) {
                  HapticFeedback.mediumImpact();
                  return;
                }
              }
              onDropPosition(capybara.id, normalized);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: highlight
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.6),
                          blurRadius: 18,
                          spreadRadius: 3,
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
