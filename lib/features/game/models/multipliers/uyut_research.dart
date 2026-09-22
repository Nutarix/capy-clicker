/// Egg Inc.–lite research node for «Исследования уюта».
class ResearchNode {
  const ResearchNode({
    required this.id,
    required this.labelRu,
    required this.effectRu,
    required this.grassCost,
    this.uyutCost = 0,
    this.requires = const [],
    this.emoji = '🔬',
  });

  final String id;
  final String labelRu;
  final String effectRu;
  final int grassCost;
  final int uyutCost;
  final List<String> requires;
  final String emoji;
}

/// Vertical tech tree — unlock order via [requires].
abstract final class UyutResearch {
  /// Approved soft-pixel research / Уют icon.
  static const assetPath = 'assets/images/research_uyut.png';

  static const moreFlowers = ResearchNode(
    id: 'more_flowers',
    labelRu: 'Больше цветов',
    effectRu: '+8% с цветов',
    grassCost: 12,
    emoji: '🌸',
  );

  static const longerMud = ResearchNode(
    id: 'longer_mud',
    labelRu: 'Долгая лужа',
    effectRu: 'лужа +4 с',
    grassCost: 25,
    requires: ['more_flowers'],
    emoji: '🟤',
  );

  static const moreBerries = ResearchNode(
    id: 'more_berries',
    labelRu: 'Ягодный край',
    effectRu: 'ягоды быстрее',
    grassCost: 30,
    requires: ['more_flowers'],
    emoji: '🫐',
  );

  static const unlockTent = ResearchNode(
    id: 'unlock_tent',
    labelRu: 'Тент на поляне',
    effectRu: 'открывает Тент',
    grassCost: 40,
    uyutCost: 0,
    requires: ['longer_mud'],
    emoji: '⛺',
  );

  static const roleSlot2 = ResearchNode(
    id: 'role_slot_2',
    labelRu: 'Вторая роль',
    effectRu: 'слот ролей: 2',
    grassCost: 55,
    uyutCost: 1,
    requires: ['more_berries'],
    emoji: '🎭',
  );

  static const foodPouch = ResearchNode(
    id: 'food_pouch',
    labelRu: 'Сумочка еды',
    effectRu: 'еда с цветов чаще',
    grassCost: 35,
    requires: ['more_berries'],
    emoji: '👛',
  );

  static const cozyLamp = ResearchNode(
    id: 'cozy_lamp',
    labelRu: 'Уютная лампа',
    effectRu: 'открывает Лампу в магазине',
    grassCost: 48,
    uyutCost: 1,
    requires: ['unlock_tent', 'role_slot_2'],
    emoji: '💡',
  );

  static const softCapPlus = ResearchNode(
    id: 'soft_cap_plus',
    labelRu: 'Просторнее семье',
    effectRu: 'soft-cap +1',
    grassCost: 70,
    uyutCost: 1,
    requires: ['role_slot_2'],
    emoji: '🌿',
  );

  static const List<ResearchNode> all = [
    moreFlowers,
    longerMud,
    moreBerries,
    unlockTent,
    roleSlot2,
    foodPouch,
    cozyLamp,
    softCapPlus,
  ];

  static ResearchNode? byId(String id) {
    for (final n in all) {
      if (n.id == id) return n;
    }
    return null;
  }

  static bool canUnlock({
    required ResearchNode node,
    required Set<String> unlocked,
    required int grass,
    required int uyut,
  }) {
    if (unlocked.contains(node.id)) return false;
    for (final r in node.requires) {
      if (!unlocked.contains(r)) return false;
    }
    if (grass < node.grassCost) return false;
    if (uyut < node.uyutCost) return false;
    return true;
  }
}
