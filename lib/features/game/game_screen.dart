import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/capybara_placeholder.dart';
import 'widgets/flower_dot.dart';
import 'widgets/meadow_background.dart';
import 'widgets/progress_bar.dart';

/// Main game screen mock: meadow, progress, one capy, tappable flowers.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  /// Starting fill ~55% as a visual placeholder.
  double _progress = 0.55;

  static const _flowerLayouts = <({double left, double top, Color color})>[
    (left: 0.18, top: 0.42, color: Color(0xFFE87AA0)),
    (left: 0.72, top: 0.38, color: Color(0xFFF0C040)),
    (left: 0.28, top: 0.58, color: Color(0xFF9B6BDE)),
    (left: 0.78, top: 0.55, color: Color(0xFFE85A5A)),
    (left: 0.48, top: 0.48, color: Color(0xFF5AB8E8)),
  ];

  void _onFlowerTap() {
    HapticFeedback.lightImpact();
    setState(() {
      _progress = (_progress + 0.03).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeadowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              return Stack(
                children: [
                  Positioned(
                    top: 16,
                    left: 24,
                    right: 24,
                    child: CreamProgressBar(value: _progress),
                  ),
                  ..._flowerLayouts.map((f) {
                    return Positioned(
                      left: f.left * w - 14,
                      top: f.top * h - 14,
                      child: FlowerDot(
                        color: f.color,
                        onTap: _onFlowerTap,
                      ),
                    );
                  }),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: h * 0.12,
                    child: const Center(
                      child: CapybaraPlaceholder(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
