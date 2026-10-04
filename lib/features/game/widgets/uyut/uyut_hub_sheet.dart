import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/cozy_theme.dart';
import '../../../../widgets/cozy_pixel_button.dart';
import '../../controllers/game_controller.dart';
import '../../models/balance.dart';
import '../../models/capy_names.dart';
import '../../models/capybara.dart';
import '../../models/multipliers/multipliers.dart';
import '../game_selector.dart';
import 'multiplier_icon.dart';
import '../home_meadow_scene.dart';

/// Bottom sheet «Уют» with tabs: Еда / Роли / Дом / Исследования.
///
/// The sheet rebuilds on a tab switch. Each tab listens to what it shows
/// and rebuilds only when that changes, not on every game tick (spec 002, Т7).
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

  /// The sheet's own plates: the screen's lie under the modal sheet
  /// (spec 003, Т7).
  final GlobalKey<ScaffoldMessengerState> _messenger = GlobalKey();
  StreamSubscription<GameEvent>? _events;

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
    _events = c.events.listen(_onGameEvent);
  }

  void _onGameEvent(GameEvent event) {
    if (event is RoleAssigned) _plate(event.text);
  }

  void _plate(String text) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF5C3D1E).withValues(alpha: 0.94),
          content: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Only the selected tab is built, so Еда cannot sit under Дом.
  Widget _tabBody() {
    return switch (_tabs.index) {
      0 => _FoodTab(controller: c),
      1 => _RolesTab(
        controller: c,
        focusCapyId: widget.focusCapyId,
        onPlate: _plate,
      ),
      2 => _DecorTab(controller: c),
      _ => _ResearchTab(controller: c),
    };
  }

  @override
  void dispose() {
    _events?.cancel();
    _tabs.removeListener(_onChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).height;
    // The rename field (spec 004) lifts the sheet over the keyboard.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = (screen * 0.72).clamp(0.0, screen - keyboard - 48);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + keyboard),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
          ),
          child: SizedBox(
            height: height,
            child: ScaffoldMessenger(
              key: _messenger,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Column(
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
                      unselectedLabelColor: Colors.brown.withValues(
                        alpha: 0.45,
                      ),
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
                    Expanded(child: _tabBody()),
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
    return GameSelector<bool>(
      listenable: controller,
      select: () => controller.canFeedSelected,
      builder: (context, canFeed) => _list(canFeed),
    );
  }

  Widget _list(bool canFeed) {
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
          onPressed: canFeed
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
  const _RolesTab({
    required this.controller,
    required this.onPlate,
    this.focusCapyId,
  });
  final GameController controller;

  /// A plate over the sheet (why a role could not be given).
  final ValueChanged<String> onPlate;

  /// The capy a long press came from: first in the family list.
  final String? focusCapyId;

  /// Who holds [role] on this land, or null.
  Capybara? _holder(CapyRole role) {
    final state = controller.state;
    for (final capy in state.herd) {
      if (capy.role == role) return capy;
    }
    for (final entry in state.meadows.entries) {
      if (entry.key == state.activeMeadowId) continue;
      for (final capy in entry.value.herd) {
        if (capy.role == role) return capy;
      }
    }
    return null;
  }

  /// The family on this meadow, the long-pressed one first.
  List<Capybara> _family() {
    final herd = controller.state.herd;
    final focus = focusCapyId;
    return [
      for (final c in herd)
        if (c.id == focus) c,
      for (final c in herd)
        if (c.id != focus) c,
    ];
  }

  /// What the list shows, as a value: a tick that moved the bar or a capy's
  /// spot does not rebuild it (spec 002, Т7).
  String _familyView() => [
    for (final c in _family())
      '${c.id}|${c.listNameRu}|${c.level}|${c.role?.id}|${c.trait?.id}',
  ].join(';');

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

  /// Why nobody took the role. Reads the same counts as the rule.
  String _whyNot() {
    final state = controller.state;
    final held = CapyRole.values.where(_held).length;
    if (held >= state.roleSlots) {
      return state.roleSlots < 2
          ? 'Все слоты ролей заняты. Сними роль или изучи «Вторая роль»'
          : 'Все слоты ролей заняты. Сначала сними роль';
    }
    return 'На этой поляне все капи уже с ролями';
  }

  @override
  Widget build(BuildContext context) {
    return GameSelector<(bool, bool, bool, String)>(
      listenable: controller,
      select: () => (
        _held(CapyRole.nanya),
        _held(CapyRole.sobiratel),
        _held(CapyRole.storozh),
        _familyView(),
      ),
      builder: (context, _) => _list(),
    );
  }

  Widget _list() {
    final any = CapyRole.values.any(_held);
    final family = _family();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Семья на поляне · имя можно поменять',
            style: CozyTheme.hudChipMutedStyle(fontSize: 12),
          ),
        ),
        for (final capy in family) ...[
          _CapyRow(
            key: ValueKey('family-${capy.id}'),
            capy: capy,
            focused: capy.id == focusCapyId,
            onRename: (name) {
              HapticFeedback.lightImpact();
              return controller.renameCapy(capy.id, name);
            },
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 8),
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
            holderName: _holder(role)?.listNameRu,
            onAssign: () {
              HapticFeedback.lightImpact();
              // Success shows the role's own plate (RoleAssigned).
              if (!controller.assignRoleToFreeCapy(role)) onPlate(_whyNot());
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
    this.holderName,
  });

  final CapyRole role;
  final bool held;

  /// Who holds the role («Пуговка», «Малыш»).
  final String? holderName;
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
                  if (holderName != null)
                    Text(
                      'Сейчас: $holderName',
                      style: CozyTheme.hudChipStyle(fontSize: 12),
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

/// One capy of the family: «Пуговка — няня», «Lv.2 · непоседа». Tap the
/// name of a named capy to give your own (spec 004, С3): at once, free.
class _CapyRow extends StatefulWidget {
  const _CapyRow({
    super.key,
    required this.capy,
    required this.focused,
    required this.onRename,
  });

  final Capybara capy;
  final bool focused;

  /// False: refused (empty), the old name stays.
  final bool Function(String name) onRename;

  @override
  State<_CapyRow> createState() => _CapyRowState();
}

class _CapyRowState extends State<_CapyRow> {
  final TextEditingController _text = TextEditingController();
  bool _editing = false;

  Capybara get capy => widget.capy;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _edit() {
    if (!capy.isNamed) return;
    _text.text = capy.displayNameRu ?? '';
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
    setState(() => _editing = true);
  }

  void _done() {
    if (!_editing) return;
    widget.onRename(_text.text);
    if (mounted) setState(() => _editing = false);
  }

  String get _title {
    final role = capy.role;
    final name = capy.listNameRu;
    return role == null ? name : '$name — ${role.labelRu.toLowerCase()}';
  }

  String get _subtitle {
    final trait = capy.trait;
    return trait == null
        ? 'Lv.${capy.level}'
        : 'Lv.${capy.level} · ${trait.labelRu}';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.focused
            ? const Color(0xFFFFF0D0)
            : const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.focused
              ? const Color(0xFFC47820)
              : const Color(0xFFE2CFA8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: _editing ? _field() : _label(),
      ),
    );
  }

  Widget _label() {
    return InkWell(
      onTap: capy.isNamed ? _edit : null,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: CozyTheme.hudChipStyle(fontSize: 14)),
                Text(
                  _subtitle,
                  style: CozyTheme.hudChipMutedStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          if (capy.isNamed)
            Icon(
              Icons.edit,
              size: 16,
              color: Colors.brown.withValues(alpha: 0.45),
            ),
        ],
      ),
    );
  }

  Widget _field() {
    return TextField(
      controller: _text,
      autofocus: true,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [
        LengthLimitingTextInputFormatter(CapyNames.maxCustomLength),
      ],
      style: CozyTheme.hudChipStyle(fontSize: 14),
      decoration: const InputDecoration(
        isDense: true,
        hintText: 'Своё имя',
        border: InputBorder.none,
      ),
      onSubmitted: (_) => _done(),
      onTapOutside: (_) => _done(),
    );
  }
}

class _DecorTab extends StatelessWidget {
  const _DecorTab({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return GameSelector<(Set<String>, Set<String>, Set<String>, int, int, int)>(
      listenable: controller,
      select: () {
        final state = controller.state;
        return (
          state.ownedDecor,
          state.placedDecor,
          state.researched,
          state.grass,
          state.uyut,
          state.sunnyGladeAnnounced,
        );
      },
      builder: (context, _) => _scene(),
    );
  }

  Widget _scene() {
    final state = controller.state;
    // Soft-gate permanent layers until Ягодная поляна (announced ≥ 1).
    final softLocked = state.sunnyGladeAnnounced < 1;
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
  const _ResearchTab({required this.controller});
  final GameController controller;

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
    return GameSelector<(Set<String>, int, int, int)>(
      listenable: controller,
      select: () {
        final state = controller.state;
        return (
          state.researched,
          state.grass,
          state.uyut,
          state.sunnyGladeAnnounced,
        );
      },
      builder: (context, _) => _grid(),
    );
  }

  Widget _grid() {
    // Soft-gate permanent layers until Ягодная поляна (announced ≥ 1).
    final softLocked = controller.state.sunnyGladeAnnounced < 1;
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
