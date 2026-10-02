import 'package:flutter/material.dart';

import '../../../theme/cozy_theme.dart';
import '../../../widgets/cozy_pixel_button.dart';
import '../models/family_land.dart';
import '../models/game_state.dart';
import '../models/world_zones.dart';
import 'cozy_rocket.dart';

/// «Семья провожает» — one capy leaves, the rest stay.
class RocketFarewell extends StatelessWidget {
  const RocketFarewell({super.key, required this.onSend, required this.onStay});

  final VoidCallback onSend;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    return _ChapterFrame(
      title: 'Семья провожает',
      body: 'Один улетает. Остальные остаются дома.\nМожно будет вернуться.',
      rocketAlign: Alignment.centerRight,
      actions: [
        CozyPixelButton(label: 'Отправить одного', onPressed: onSend),
        const SizedBox(width: 8),
        CozyPixelButton(
          label: 'Ещё побыть',
          variant: CozyPixelButtonVariant.secondary,
          onPressed: onStay,
        ),
      ],
    );
  }
}

/// Moment of flight. The meadow underneath is the family waving.
class RocketFlight extends StatelessWidget {
  const RocketFlight({super.key, required this.onArrive});

  final VoidCallback onArrive;

  @override
  Widget build(BuildContext context) {
    return _ChapterFrame(
      title: 'Один в пути',
      body: 'Семья машет. Дом остаётся.',
      rocketAlign: Alignment.topCenter,
      actions: [
        CozyPixelButton(
          label: 'К новой земле',
          expand: true,
          onPressed: onArrive,
        ),
      ],
    );
  }
}

class _ChapterFrame extends StatelessWidget {
  const _ChapterFrame({
    required this.title,
    required this.body,
    required this.rocketAlign,
    required this.actions,
  });

  final String title;
  final String body;
  final Alignment rocketAlign;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Align(
            alignment: rocketAlign,
            child: Padding(
              padding: const EdgeInsets.only(top: 72, right: 28),
              child: const CozyRocket(height: 260),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8EC).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2CFA8)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        children: [
                          Text(
                            title,
                            style: CozyTheme.hudChipStyle(fontSize: 18)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: CozyTheme.hudChipMutedStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      for (final action in actions)
                        if (action is CozyPixelButton)
                          Expanded(child: action)
                        else
                          action,
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Земли семьи» — visit the previous land. Nothing is erased.
class FamilyLandsSheet extends StatelessWidget {
  const FamilyLandsSheet({
    super.key,
    required this.state,
    required this.onVisit,
    required this.onClose,
  });

  final GameState state;
  final ValueChanged<int> onVisit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final lands = <_LandRow>[
      _LandRow.fromState(state, current: true),
      for (final land in state.otherLands) _LandRow.fromLand(land),
    ]..sort((a, b) => a.chapter.compareTo(b.chapter));
    final newest = lands.map((e) => e.chapter).reduce((a, b) => a > b ? a : b);

    return Material(
      color: const Color(0xFF2A3A24).withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Земли семьи',
                      style: CozyTheme.hudChipStyle(fontSize: 22)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Можно заглянуть, как живут. Ничего не стирается.',
                      textAlign: TextAlign.center,
                      style: CozyTheme.hudChipMutedStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Где уже обжились',
                        style: CozyTheme.hudChipStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final row in lands) ...[
                      _LandCard(
                        row: row,
                        newest: newest,
                        onVisit: row.current
                            ? null
                            : () => onVisit(row.chapter),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Трава и искры общие.\nСемья на каждой земле своя.',
                      textAlign: TextAlign.center,
                      style: CozyTheme.hudChipMutedStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    CozyPixelButton(
                      label: 'Закрыть',
                      variant: CozyPixelButtonVariant.secondary,
                      compact: true,
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandRow {
  _LandRow({
    required this.chapter,
    required this.familyCount,
    required this.current,
    required this.thumb,
  });

  final int chapter;
  final int familyCount;
  final bool current;
  final String thumb;

  factory _LandRow.fromState(GameState state, {required bool current}) {
    return _LandRow(
      chapter: state.landChapter,
      familyCount: state.totalHerdAcrossMeadows,
      current: current,
      thumb: WorldZones.backgroundAssetForMeadow(state.activeMeadowId),
    );
  }

  factory _LandRow.fromLand(FamilyLand land) {
    return _LandRow(
      chapter: land.chapter,
      familyCount: land.familyCount,
      current: false,
      thumb: WorldZones.backgroundAssetForMeadow(land.activeMeadowId),
    );
  }
}

class _LandCard extends StatelessWidget {
  const _LandCard({
    required this.row,
    required this.newest,
    required this.onVisit,
  });

  final _LandRow row;
  final int newest;
  final VoidCallback? onVisit;

  @override
  Widget build(BuildContext context) {
    final isNew = row.chapter == newest && newest > 0;
    final title = isNew ? 'Новая земля' : 'Прежняя земля';
    final subtitle = isNew ? 'только начинаем снова' : 'большая семья на месте';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: row.current ? const Color(0xFFE8F5D8) : const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: row.current
              ? const Color(0xFF6B9B4A)
              : const Color(0xFFE2CFA8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                row.thumb,
                width: 72,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: CozyTheme.hudChipStyle(fontSize: 14)),
                      if (row.current) ...[
                        const SizedBox(width: 6),
                        const _HereChip(),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: CozyTheme.hudChipMutedStyle(fontSize: 12),
                  ),
                  Text(
                    'семья ${row.familyCount}',
                    style: CozyTheme.hudChipStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onVisit != null)
              CozyPixelButton(
                label: 'Навестить',
                compact: true,
                onPressed: onVisit,
              ),
          ],
        ),
      ),
    );
  }
}

class _HereChip extends StatelessWidget {
  const _HereChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFD8EEC8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text('здесь', style: CozyTheme.hudChipStyle(fontSize: 10)),
      ),
    );
  }
}
