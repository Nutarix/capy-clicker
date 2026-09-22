import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/cozy_theme.dart';
import '../../controllers/game_controller.dart';
import '../../models/balance.dart';
import '../../models/multipliers/multipliers.dart';

/// Bottom sheet «Уют» with tabs: Еда / Роли / Дом / Исследования.
class UyutHubSheet extends StatefulWidget {
  const UyutHubSheet({
    super.key,
    required this.controller,
    this.initialTab = 0,
    this.focusCapyId,
  });

  final GameController controller;
  final int initialTab;
  final String? focusCapyId;

  static Future<void> show(
    BuildContext context, {
    required GameController controller,
    int initialTab = 0,
    String? focusCapyId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UyutHubSheet(
        controller: controller,
        initialTab: initialTab,
        focusCapyId: focusCapyId,
      ),
    );
  }

  @override
  State<UyutHubSheet> createState() => _UyutHubSheetState();
}

class _UyutHubSheetState extends State<UyutHubSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    c.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = c.state;
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
          ),
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.brown.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Уют семьи',
                  style: CozyTheme.hudChipStyle(fontSize: 18).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🌿 ${state.grass}   ✨ уют ${state.uyut}',
                  style: CozyTheme.hudChipMutedStyle(fontSize: 12),
                ),
                TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF5C3D1E),
                  unselectedLabelColor: Colors.brown.withValues(alpha: 0.45),
                  indicatorColor: const Color(0xFFC47820),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Еда'),
                    Tab(text: 'Роли'),
                    Tab(text: 'Дом'),
                    Tab(text: 'Наука'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _FoodTab(controller: c),
                      _RolesTab(
                        controller: c,
                        focusCapyId: widget.focusCapyId,
                      ),
                      _DecorTab(controller: c),
                      _ResearchTab(controller: c),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodTab extends StatelessWidget {
  const _FoodTab({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final food = controller.state.food;
    final selected = controller.selectedFood;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Корм для семьи — временный буст',
          style: CozyTheme.hudChipMutedStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in FamilyFood.values)
              _FoodChip(
                food: f,
                count: food.countOf(f),
                selected: selected == f,
                onSelect: () => controller.selectFood(f),
                onBuy: () {
                  HapticFeedback.lightImpact();
                  controller.buyFood(f);
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.canFeedSelected
              ? () {
                  HapticFeedback.mediumImpact();
                  controller.feedFamily();
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6B9B4A),
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Покормить семью · ${selected.emoji} ${selected.labelRu}',
          ),
        ),
        if (controller.isFoodBoostActive) ...[
          const SizedBox(height: 10),
          Text(
            'Активно: ${controller.activeFoodBoost?.labelRu} '
            '(${controller.foodBoostRemainingSeconds.ceil()}с)',
            style: CozyTheme.hudChipStyle(fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Цветы иногда дают еду. Или купи за траву:\n'
          'Травка ${BalanceV0.grassToTravkaCost}🌿 · '
          'Ягоды ${BalanceV0.grassToYagodyCost}🌿 · '
          'Орешки ${BalanceV0.grassToOreshkiCost}🌿',
          style: CozyTheme.hudChipMutedStyle(fontSize: 11),
        ),
      ],
    );
  }
}

class _FoodChip extends StatelessWidget {
  const _FoodChip({
    required this.food,
    required this.count,
    required this.selected,
    required this.onSelect,
    required this.onBuy,
  });

  final FamilyFood food;
  final int count;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5D8) : const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF6B9B4A) : const Color(0xFFE2CFA8),
            width: selected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${food.emoji} ${food.labelRu} ×$count'),
              Text(food.effectRu, style: CozyTheme.hudChipMutedStyle(fontSize: 10)),
              TextButton(
                onPressed: onBuy,
                child: const Text('Купить', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolesTab extends StatelessWidget {
  const _RolesTab({required this.controller, this.focusCapyId});
  final GameController controller;
  final String? focusCapyId;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final herd = List.of(state.herd)
      ..sort((a, b) {
        if (a.id == focusCapyId) return -1;
        if (b.id == focusCapyId) return 1;
        return a.level.compareTo(b.level);
      });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Слоты ролей: ${state.assignedRoleCount}/${state.roleSlots}',
          style: CozyTheme.hudChipStyle(fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          'Долгое нажатие на капи на лугу тоже открывает роли.',
          style: CozyTheme.hudChipMutedStyle(fontSize: 11),
        ),
        const SizedBox(height: 12),
        for (final capy in herd) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: capy.id == focusCapyId
                  ? const Color(0xFFE8F5D8)
                  : const Color(0xFFFFF3D6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2CFA8)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Капи ${capy.id} · Lv.${capy.level}'
                    '${capy.role != null ? ' · ${capy.role!.emoji} ${capy.role!.labelRu}' : ''}',
                    style: CozyTheme.hudChipStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final role in CapyRole.values)
                        ActionChip(
                          label: Text('${role.emoji} ${role.labelRu}',
                              style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            final ok = controller.assignRole(capy.id, role);
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Нет свободного слота роли'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                      ActionChip(
                        label: const Text('Снять', style: TextStyle(fontSize: 11)),
                        onPressed: () => controller.assignRole(capy.id, null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DecorTab extends StatelessWidget {
  const _DecorTab({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Уют дома — постоянные бонусы',
          style: CozyTheme.hudChipMutedStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        for (final d in HomeDecor.values) ...[
          _DecorRow(controller: controller, decor: d),
          const SizedBox(height: 8),
        ],
        if (state.ownedDecor.isEmpty)
          Text(
            'Купи первый декор за траву — семья станет уютнее.',
            style: CozyTheme.hudChipMutedStyle(fontSize: 12),
          ),
      ],
    );
  }
}

class _DecorRow extends StatelessWidget {
  const _DecorRow({required this.controller, required this.decor});
  final GameController controller;
  final HomeDecor decor;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final owned = state.ownsDecor(decor);
    final req = decor.requiresResearch;
    final locked = req != null && !state.hasResearch(req);
    final cost =
        '${decor.grassCost}🌿${decor.uyutCost > 0 ? ' + ${decor.uyutCost}✨' : ''}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: owned ? const Color(0xFFE8F5D8) : const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2CFA8)),
      ),
      child: ListTile(
        leading: Text(decor.emoji, style: const TextStyle(fontSize: 22)),
        title: Text(decor.labelRu, style: CozyTheme.hudChipStyle(fontSize: 13)),
        subtitle: Text(
          locked
              ? 'Нужно исследование'
              : '${decor.effectRu}${owned ? '' : ' · $cost'}',
          style: CozyTheme.hudChipMutedStyle(fontSize: 11),
        ),
        trailing: owned
            ? IconButton(
                icon: Icon(
                  state.placedDecor.contains(decor.id)
                      ? Icons.check_circle
                      : Icons.add_circle_outline,
                  color: const Color(0xFF6B9B4A),
                ),
                onPressed: () => controller.togglePlaceDecor(decor),
              )
            : TextButton(
                onPressed: locked
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        controller.buyDecor(decor);
                      },
                child: const Text('Купить'),
              ),
      ),
    );
  }
}

class _ResearchTab extends StatelessWidget {
  const _ResearchTab({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final unlocked = controller.state.researched;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Исследования уюта',
          style: CozyTheme.hudChipMutedStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        for (final node in UyutResearch.all) ...[
          _ResearchRow(controller: controller, node: node, unlocked: unlocked),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ResearchRow extends StatelessWidget {
  const _ResearchRow({
    required this.controller,
    required this.node,
    required this.unlocked,
  });

  final GameController controller;
  final ResearchNode node;
  final Set<String> unlocked;

  @override
  Widget build(BuildContext context) {
    final done = unlocked.contains(node.id);
    final can = UyutResearch.canUnlock(
      node: node,
      unlocked: unlocked,
      grass: controller.state.grass,
      uyut: controller.state.uyut,
    );
    final prereqOk = node.requires.every(unlocked.contains);
    final cost =
        '${node.grassCost}🌿${node.uyutCost > 0 ? ' + ${node.uyutCost}✨' : ''}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFFE8F5D8)
            : prereqOk
                ? const Color(0xFFFFF3D6)
                : const Color(0xFFF0E6D4).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done ? const Color(0xFF6B9B4A) : const Color(0xFFE2CFA8),
        ),
      ),
      child: ListTile(
        leading: Text(node.emoji, style: const TextStyle(fontSize: 22)),
        title: Text(node.labelRu, style: CozyTheme.hudChipStyle(fontSize: 13)),
        subtitle: Text(
          done
              ? 'Открыто · ${node.effectRu}'
              : '${node.effectRu} · $cost'
                  '${node.requires.isEmpty ? '' : '\nнужно: ${node.requires.join(", ")}'}',
          style: CozyTheme.hudChipMutedStyle(fontSize: 11),
        ),
        trailing: done
            ? const Icon(Icons.check, color: Color(0xFF6B9B4A))
            : TextButton(
                onPressed: can
                    ? () {
                        HapticFeedback.mediumImpact();
                        controller.unlockResearch(node.id);
                      }
                    : null,
                child: const Text('Открыть'),
              ),
      ),
    );
  }
}
