import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/cozy_theme.dart';
import '../../../widgets/cozy_pixel_button.dart';
import '../models/world_zones.dart';

/// Soft full-screen forest map: biomes with unlocked meadows as cozy chips.
class ForestMapOverlay extends StatelessWidget {
  const ForestMapOverlay({
    super.key,
    required this.unlockedIds,
    required this.activeMeadowId,
    required this.herdCountFor,
    required this.onSelect,
    required this.onClose,
    this.mistyBiomeUnlocked = false,
  });

  final List<String> unlockedIds;
  final String activeMeadowId;
  final int Function(String meadowId) herdCountFor;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  /// When false, Туманный бор section shows a locked chip.
  final bool mistyBiomeUnlocked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A3A24).withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8EDD8).withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE2CFA8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text('🌲', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Карта леса',
                                style: CozyTheme.hudChipStyle(fontSize: 18),
                              ),
                            ),
                            CozyPixelIconButton(
                              tooltip: 'Назад',
                              icon: Icons.close_rounded,
                              onPressed: onClose,
                              size: 36,
                              iconSize: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Выбери поляну — семья ждёт на каждой своей.',
                          style: CozyTheme.hudChipMutedStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        _BiomeSection(
                          titleRu: WorldZones.sunnyBiomeNameRu,
                          emoji: '☀️',
                          children: [
                            for (final g in WorldZones.glades)
                              _MeadowChip(
                                glade: g,
                                unlocked: unlockedIds.contains(g.id),
                                active: g.id == activeMeadowId,
                                herdCount: unlockedIds.contains(g.id)
                                    ? herdCountFor(g.id)
                                    : 0,
                                onTap: unlockedIds.contains(g.id)
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        onSelect(g.id);
                                      }
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _BiomeSection(
                          titleRu: WorldZones.mistyBiomeNameRu,
                          emoji: '🌫️',
                          children: [
                            _MeadowChip(
                              glade: WorldZones.mistEdge,
                              unlocked: mistyBiomeUnlocked,
                              active: activeMeadowId ==
                                  WorldZones.mistEdgeMeadowId,
                              herdCount: mistyBiomeUnlocked
                                  ? herdCountFor(WorldZones.mistEdgeMeadowId)
                                  : 0,
                              lockedHintRu: 'После Большого луга и Капи Lv.4',
                              onTap: mistyBiomeUnlocked
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      onSelect(WorldZones.mistEdgeMeadowId);
                                    }
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Трава и искры общие · семьи — у каждой поляны свои',
                          textAlign: TextAlign.center,
                          style: CozyTheme.hudChipMutedStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BiomeSection extends StatelessWidget {
  const _BiomeSection({
    required this.titleRu,
    required this.emoji,
    required this.children,
  });

  final String titleRu;
  final String emoji;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              titleRu,
              style: CozyTheme.hudChipStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children,
        ),
      ],
    );
  }
}

class _MeadowChip extends StatelessWidget {
  const _MeadowChip({
    required this.glade,
    required this.unlocked,
    required this.active,
    required this.herdCount,
    required this.onTap,
    this.lockedHintRu,
  });

  final SunnyGlade glade;
  final bool unlocked;
  final bool active;
  final int herdCount;
  final VoidCallback? onTap;
  final String? lockedHintRu;

  @override
  Widget build(BuildContext context) {
    final bg = !unlocked
        ? const Color(0xFFE8DFD0).withValues(alpha: 0.7)
        : active
            ? const Color(0xFFD8EEC8)
            : const Color(0xFFFFF8EC);
    final border = active
        ? const Color(0xFF5A9A48)
        : const Color(0xFFE2CFA8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 160,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: active ? 2 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      unlocked ? '🌿' : '🔒',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        glade.nameRu,
                        style: CozyTheme.hudChipStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  unlocked
                      ? (active
                          ? 'здесь · семья $herdCount'
                          : 'семья $herdCount')
                      : (lockedHintRu ?? 'ещё закрыта'),
                  style: CozyTheme.hudChipMutedStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
