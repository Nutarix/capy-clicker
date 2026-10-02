import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/cozy_theme.dart';
import '../../../../widgets/cozy_pixel_button.dart';
import '../../controllers/game_controller.dart';
import '../../models/balance.dart';
import '../../models/multipliers/multipliers.dart';
import 'multiplier_icon.dart';
import '../home_meadow_scene.dart';

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
    _tabs.addListener(_onChanged);
    c.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Only the selected tab is built, so Еда cannot sit under Дом.
  Widget _tabBody(bool permanentUnlocked) {
    return switch (_tabs.index) {
      0 => _FoodTab(controller: c),
      1 => _RolesTab(controller: c, focusCapyId: widget.focusCapyId),
      2 => _DecorTab(controller: c, softLocked: !permanentUnlocked),
      _ => _ResearchTab(controller: c, softLocked: !permanentUnlocked),
    };
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    _tabs.removeListener(_onChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = c.state;
    // Soft-gate permanent layers until Ягодная поляна (announced ≥ 1).
    final permanentUnlocked = state.sunnyGladeAnnounced >= 1;
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
                  style: CozyTheme.hudChipStyle(fontSize: 18)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF5C3D1E),
                  unselectedLabelColor: Colors.brown.withValues(alpha: 0.45),
                  indicatorColor: const Color(0xFFC47820),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    const Tab(height: 48, child: _HubTabLabel('Еда')),
                    const Tab(height: 48, child: _HubTabLabel('Роли')),
                    const Tab(height: 48, child: _HubTabLabel('Дом')),
                    const Tab(height: 48, child: _HubTabLabel('Наука')),
                  ],
                ),
                Expanded(child: _tabBody(permanentUnlocked)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab title that always paints the full word (no «Наука · ско» clip).
class _HubTabLabel extends StatelessWidget {
  const _HubTabLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        title,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FoodTab extends StatelessWidget {
  const _FoodTab({required this.controller});
  final GameController controller;

  int _cost(FamilyFood food) => switch (food) {
    FamilyFood.travka => BalanceV0.grassToTravkaCost,
    FamilyFood.yagody => BalanceV0.grassToYagodyCost,
    FamilyFood.oreshki => BalanceV0.grassToOreshkiCost,
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final food in FamilyFood.values) ...[
          _FoodRow(
            food: food,
            cost: _cost(food),
            onBuy: () {
              HapticFeedback.lightImpact();
              controller.selectFood(food);
              controller.buyFood(food);
            },
          ),
          const SizedBox(height: 10),
        ],
        CozyPixelButton(
          label: 'Покормить семью',
          expand: true,
          onPressed: controller.canFeedSelected
              ? () {
                  HapticFeedback.mediumImpact();
                  controller.feedFamily();
                }
              : null,
        ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.cost, required this.onBuy});

  final FamilyFood food;
  final int cost;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onBuy,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFF3E6C8),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2CFA8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                MultiplierIcon(assetPath: food.assetPath, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    food.labelRu,
                    style: CozyTheme.hudChipStyle(fontSize: 16),
                  ),
                ),
                Image.asset(
                  'assets/images/ui/icon_grass.png',
                  width: 16,
                  height: 16,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(width: 4),
                Text('$cost', style: CozyTheme.hudChipStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RolesTab extends StatelessWidget {
  const _RolesTab({required this.controller, this.focusCapyId});
  final GameController controller;

  /// Kept so a long-press still opens this tab. Roles are not listed by id.
  final String? focusCapyId;

  bool _held(CapyRole role) {
    final state = controller.state;
    for (final capy in state.herd) {
      if (capy.role == role) return true;
    }
    for (final entry in state.meadows.entries) {
      if (entry.key == state.activeMeadowId) continue;
      for (final capy in entry.value.herd) {
        if (capy.role == role) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final any = CapyRole.values.any(_held);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (!any)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Роли пока не назначены',
              style: CozyTheme.hudChipMutedStyle(fontSize: 12),
            ),
          ),
        for (final role in CapyRole.values) ...[
          _RoleCard(
            role: role,
            held: _held(role),
            onAssign: () {
              HapticFeedback.lightImpact();
              controller.assignRoleToFreeCapy(role);
            },
            onClear: () {
              HapticFeedback.lightImpact();
              controller.clearRole(role);
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.held,
    required this.onAssign,
    required this.onClear,
  });

  final CapyRole role;
  final bool held;
  final VoidCallback onAssign;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: held ? const Color(0xFFE8F5D8) : const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2CFA8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            MultiplierIcon(assetPath: role.assetPath, size: 54),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.labelRu,
                    style: CozyTheme.hudChipStyle(fontSize: 15),
                  ),
                  Text(
                    role.tipRu,
                    style: CozyTheme.hudChipMutedStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            CozyPixelButton(
              label: held ? 'Снять' : 'Назначить',
              variant: held
                  ? CozyPixelButtonVariant.secondary
                  : CozyPixelButtonVariant.primary,
              compact: true,
              onPressed: held ? onClear : onAssign,
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorTab extends StatelessWidget {
  const _DecorTab({required this.controller, this.softLocked = false});
  final GameController controller;
  final bool softLocked;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    // One next buy, on the spot it will occupy. Empty places stay grass.
    final open = [
      for (final decor in HomeDecor.values)
        if (!state.ownsDecor(decor) &&
            !softLocked &&
            (decor.requiresResearch == null ||
                state.hasResearch(decor.requiresResearch!)))
          decor,
    ]..sort((a, b) => a.grassCost.compareTo(b.grassCost));
    final offer = <String>{if (open.isNotEmpty) open.first.id};
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'По одному. Каждая вещь — на своём месте.',
            style: CozyTheme.hudChipMutedStyle(fontSize: 12),
          ),
        ),
        if (softLocked)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Скоро — после Ягодной поляны.',
              style: CozyTheme.hudChipMutedStyle(fontSize: 12),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/bg_berry_glade.png',
                    fit: BoxFit.cover,
                  ),
                  HomeMeadowScene(
                    placedIds: state.placedDecor,
                    labelPlaced: true,
                    offerIds: offer,
                    canBuy: (decor) =>
                        state.grass >= decor.grassCost &&
                        state.uyut >= decor.uyutCost,
                    buyDecor: (decor) {
                      HapticFeedback.lightImpact();
                      controller.buyDecor(decor);
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

class _ResearchTab extends StatelessWidget {
  const _ResearchTab({required this.controller, this.softLocked = false});
  final GameController controller;
  final bool softLocked;

  static const _icons = <String, String>{
    'more_flowers': 'assets/images/ui/icon_science_flowers.png',
    'longer_mud': 'assets/images/ui/icon_science_mud.png',
    'more_berries': 'assets/images/ui/icon_science_berries.png',
    'unlock_tent': 'assets/images/ui/icon_science_tent.png',
    'role_slot_2': 'assets/images/ui/icon_science_role.png',
    'food_pouch': 'assets/images/ui/icon_science_pouch.png',
    'cozy_lamp': 'assets/images/ui/icon_science_lamp.png',
    'soft_cap_plus': 'assets/images/ui/icon_science_family.png',
  };

  @override
  Widget build(BuildContext context) {
    final nodes = UyutResearch.all;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              const MultiplierIcon(assetPath: UyutResearch.assetPath, size: 28),
              const SizedBox(width: 8),
              Text(
                'Исследования уюта',
                style: CozyTheme.hudChipMutedStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.55,
            ),
            itemCount: nodes.length,
            itemBuilder: (context, index) {
              final node = nodes[index];
              return _ResearchCard(
                controller: controller,
                node: node,
                icon: _icons[node.id] ?? UyutResearch.assetPath,
                softLocked: softLocked,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResearchCard extends StatelessWidget {
  const _ResearchCard({
    required this.controller,
    required this.node,
    required this.icon,
    required this.softLocked,
  });

  final GameController controller;
  final ResearchNode node;
  final String icon;
  final bool softLocked;

  @override
  Widget build(BuildContext context) {
    final unlocked = controller.state.researched;
    final done = unlocked.contains(node.id);
    final can =
        !softLocked &&
        UyutResearch.canUnlock(
          node: node,
          unlocked: unlocked,
          grass: controller.state.grass,
          uyut: controller.state.uyut,
        );
    final need = UyutResearch.requiresLine(node);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: can
            ? () {
                HapticFeedback.mediumImpact();
                controller.unlockResearch(node.id);
              }
            : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: done ? const Color(0xFFE8F5D8) : const Color(0xFFFFF8EC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done ? const Color(0xFF6B9B4A) : const Color(0xFFE2CFA8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Image.asset(
                  icon,
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        node.labelRu,
                        maxLines: 2,
                        style: CozyTheme.hudChipStyle(fontSize: 12),
                      ),
                      Text(
                        done ? 'есть' : node.effectRu,
                        maxLines: 2,
                        style: CozyTheme.hudChipMutedStyle(fontSize: 10),
                      ),
                      if (!done)
                        Text(
                          '${node.grassCost}'
                          '${node.uyutCost > 0 ? ' + ${node.uyutCost}' : ''}'
                          '${need.isEmpty ? '' : ' · $need'}',
                          maxLines: 2,
                          style: CozyTheme.hudChipMutedStyle(fontSize: 10),
                        ),
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
