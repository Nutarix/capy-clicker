import 'package:flutter/material.dart';

/// White affordance pill on the meadow («сюда!», «нажми!»).
///
/// Sizes to the full word. No ellipsis, no emoji stand-in.
class MeadowHintChip extends StatelessWidget {
  const MeadowHintChip({super.key, required this.text, this.fontSize = 12});

  final String text;
  final double fontSize;

  /// Wide enough for «сюда!» / «нажми!» at the default label size.
  static const double minWidth = 92;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.brown.shade900.withValues(alpha: 0.86),
          height: 1.1,
        ),
      ),
    );
  }
}
