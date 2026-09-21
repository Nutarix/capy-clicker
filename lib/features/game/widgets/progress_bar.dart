import 'package:flutter/material.dart';

import '../models/balance.dart';

/// Soft cream track + leafy green fill with visible idle motion.
class CreamProgressBar extends StatefulWidget {
  const CreamProgressBar({
    super.key,
    required this.value,
    this.boostActive = false,
    this.boostSeconds = 0,
    this.autoRatePerSecond,
    this.pulseToken = 0,
  });

  /// Progress in range 0.0–1.0.
  final double value;

  final bool boostActive;
  final double boostSeconds;

  /// Live auto fill rate (fraction/sec) for the tiny «+X%/с» hint.
  final double? autoRatePerSecond;

  /// Bumps when a tap/berry grants progress — triggers a brief bar pulse.
  final int pulseToken;

  @override
  State<CreamProgressBar> createState() => _CreamProgressBarState();
}

class _CreamProgressBarState extends State<CreamProgressBar>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;
  double _displayed = 0;

  @override
  void initState() {
    super.initState();
    _displayed = widget.value.clamp(0.0, 1.0);
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.035), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.035, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant CreamProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulseToken != oldWidget.pulseToken && widget.pulseToken > 0) {
      _pulse.forward(from: 0);
    }
    _displayed = widget.value.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rate = widget.autoRatePerSecond;
    final ratePct = rate == null ? null : (rate * 100);
    final boostLabel = widget.boostActive
        ? 'грязь ×${BalanceV0.mudBoostMultiplier.toStringAsFixed(0)} '
            '(${widget.boostSeconds.ceil()}с)'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Прогресс',
                style: TextStyle(
                  color: Color(0xFF5C3D1E),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (ratePct != null)
              Text(
                '+${ratePct.toStringAsFixed(1)}%/с',
                style: TextStyle(
                  color: widget.boostActive
                      ? const Color(0xFFB8860B)
                      : const Color(0xFF5C3D1E).withValues(alpha: 0.62),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            if (boostLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                boostLabel,
                style: const TextStyle(
                  color: Color(0xFFB8860B),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ScaleTransition(
          scale: _pulseScale,
          child: Container(
            height: 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF8EDD8),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFFF3E4C4)),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: _displayed),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.linear,
                    builder: (context, animatedT, _) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: animatedT.clamp(0.0, 1.0),
                        child: AnimatedBuilder(
                          animation: _shimmer,
                          builder: (context, _) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: widget.boostActive
                                      ? const [
                                          Color(0xFFF0D060),
                                          Color(0xFFD4A017),
                                          Color(0xFFB8860B),
                                        ]
                                      : const [
                                          Color(0xFFA8E070),
                                          Color(0xFF7EC850),
                                          Color(0xFF4F9A30),
                                        ],
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: 0.42,
                                      widthFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.28),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Gentle shimmer while auto is running.
                                  FractionallySizedBox(
                                    alignment: Alignment(
                                      -1.2 + _shimmer.value * 2.4,
                                      0,
                                    ),
                                    widthFactor: 0.28,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0),
                                            Colors.white
                                                .withValues(alpha: 0.35),
                                            Colors.white.withValues(alpha: 0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
