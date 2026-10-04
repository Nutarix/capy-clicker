import 'package:flutter/material.dart';

import '../models/balance.dart';
import '../models/capybara.dart';
import '../models/pile_layout.dart';

/// Under a pile (spec 006, 11.16.3): quietly the levels («3·1·1»); while
/// touched, everyone's name with the level («Пуговка · Lv.3», «Малыш ·
/// Lv.1»). Never takes a tap: the capys above it do.
class PileCaption extends StatelessWidget {
  const PileCaption({super.key, required this.members, this.expanded = false});

  final List<Capybara> members;

  /// Names shown (a capy of the pile is touched or was just now).
  final bool expanded;

  static Color _badge(int level) {
    final t = ((level - 1) / (BalanceV0.maxVisualLevel - 1)).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFFF5E6C8), const Color(0xFFFFC14A), t)!;
  }

  static Color _border(int level) {
    final t = ((level - 1) / (BalanceV0.maxVisualLevel - 1)).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFF8B6914), const Color(0xFFC87820), t)!;
  }

  static const _ink = Color(0xFF5C3D1E);

  /// «Пуговка · Lv.3» or «Малыш · Lv.1».
  static String lineFor(Capybara c) => '${c.listNameRu} · Lv.${c.level}';

  /// «3·1·1»: levels, eldest first.
  static String levelsFor(List<Capybara> members) =>
      PileLayout.ranked(members).map((c) => '${c.level}').join('·');

  @override
  Widget build(BuildContext context) {
    final ranked = PileLayout.ranked(members);
    if (ranked.isEmpty) return const SizedBox.shrink();
    final top = ranked.first.level;
    if (!expanded) {
      return Container(
        key: const ValueKey('pile-caption'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: _badge(top).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: _border(top).withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Text(
          levelsFor(ranked),
          style: TextStyle(
            color: _ink.withValues(alpha: 0.75),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      );
    }
    return Column(
      key: const ValueKey('pile-names'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in ranked)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: _badge(c.level).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _border(c.level).withValues(alpha: 0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                lineFor(c),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
