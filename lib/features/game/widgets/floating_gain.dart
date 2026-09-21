import 'package:flutter/material.dart';

/// One floating «+N%» / «×2» popup over the meadow or HUD.
class FloatingGainEvent {
  FloatingGainEvent({
    required this.id,
    required this.label,
    required this.globalAnchor,
    this.color = const Color(0xFF5A9A48),
  });

  final int id;
  final String label;
  final Offset globalAnchor;
  final Color color;
}

/// Stack of rising fade-out gain labels.
class FloatingGainLayer extends StatelessWidget {
  const FloatingGainLayer({
    super.key,
    required this.events,
    required this.onFinished,
  });

  final List<FloatingGainEvent> events;
  final ValueChanged<int> onFinished;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final e in events)
            _FloatingGainPopup(
              key: ValueKey(e.id),
              event: e,
              onFinished: () => onFinished(e.id),
            ),
        ],
      ),
    );
  }
}

class _FloatingGainPopup extends StatefulWidget {
  const _FloatingGainPopup({
    super.key,
    required this.event,
    required this.onFinished,
  });

  final FloatingGainEvent event;
  final VoidCallback onFinished;

  @override
  State<_FloatingGainPopup> createState() => _FloatingGainPopupState();
}

class _FloatingGainPopupState extends State<_FloatingGainPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _dy;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward().whenComplete(() {
        if (mounted) widget.onFinished();
      });
    _dy = Tween<double>(begin: 0, end: -42).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 40),
    ]).animate(_ctrl);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.12), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 75),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final local = box != null && box.hasSize
        ? box.globalToLocal(widget.event.globalAnchor)
        : widget.event.globalAnchor;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Positioned(
          left: local.dx - 36,
          top: local.dy - 18 + _dy.value,
          child: Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scale.value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.event.color.withValues(alpha: 0.55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.event.color.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    widget.event.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: widget.event.color,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
