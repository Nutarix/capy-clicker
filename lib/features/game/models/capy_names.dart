/// Capy names and traits (spec 004, `docs/NAMES.md`, WBS 11.16).
///
/// A name is stored by key and shown in the player's language. Only RU is
/// shown for now; EN waits for spec 013. No gendered forms anywhere.
library;

/// One trait per named capy: behavior on the meadow only, no numbers.
enum CapyTrait { sleepyhead, fidget, sweetTooth, splasher, cuddler, dreamer }

extension CapyTraitX on CapyTrait {
  /// Save key.
  String get id => name;

  String get labelRu => switch (this) {
    CapyTrait.sleepyhead => 'соня',
    CapyTrait.fidget => 'непоседа',
    CapyTrait.sweetTooth => 'лакомка',
    CapyTrait.splasher => 'плюх',
    CapyTrait.cuddler => 'обнимашка',
    CapyTrait.dreamer => 'мечтатель',
  };

  String get labelEn => switch (this) {
    CapyTrait.sleepyhead => 'Sleepyhead',
    CapyTrait.fidget => 'Fidget',
    CapyTrait.sweetTooth => 'Sweet Tooth',
    CapyTrait.splasher => 'Splasher',
    CapyTrait.cuddler => 'Cuddler',
    CapyTrait.dreamer => 'Dreamer',
  };

  /// Second half of «Шишка-соня».
  String get epithetRu => labelRu;

  /// First word of «Sleepy Pinecone».
  String get epithetEn => switch (this) {
    CapyTrait.sleepyhead => 'Sleepy',
    CapyTrait.fidget => 'Fidgety',
    CapyTrait.sweetTooth => 'Sweet',
    CapyTrait.splasher => 'Splashy',
    CapyTrait.cuddler => 'Cuddly',
    CapyTrait.dreamer => 'Dreamy',
  };

  static CapyTrait? tryParse(String? id) {
    if (id == null) return null;
    for (final t in CapyTrait.values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// One approved name: save key, RU and EN forms.
class CapyName {
  const CapyName(this.key, this.ru, this.en);

  /// Stable save key (the EN name in lower case). Order of the list may change.
  final String key;
  final String ru;
  final String en;
}

abstract final class CapyNames {
  /// All one hundred, in the order of `docs/NAMES.md`.
  static const List<CapyName> all = [
    // Базовые шестнадцать.
    CapyName('button', 'Пуговка', 'Button'),
    CapyName('pinecone', 'Шишка', 'Pinecone'),
    CapyName('muffin', 'Ватрушка', 'Muffin'),
    CapyName('pip', 'Кнопка', 'Pip'),
    CapyName('cloudy', 'Облачко', 'Cloudy'),
    CapyName('bun', 'Булочка', 'Bun'),
    CapyName('pumpkin', 'Тыковка', 'Pumpkin'),
    CapyName('raisin', 'Изюм', 'Raisin'),
    CapyName('fig', 'Финик', 'Fig'),
    CapyName('bead', 'Бусинка', 'Bead'),
    CapyName('sundae', 'Пломбир', 'Sundae'),
    CapyName('carrot', 'Морковка', 'Carrot'),
    CapyName('daisy', 'Ромашка', 'Daisy'),
    CapyName('ginger', 'Пряник', 'Ginger'),
    CapyName('jelly', 'Кисель', 'Jelly'),
    CapyName('pretzel', 'Сушка', 'Pretzel'),
    // Сладкое и выпечка.
    CapyName('cookie', 'Печенька', 'Cookie'),
    CapyName('donut', 'Пончик', 'Donut'),
    CapyName('mallow', 'Зефирка', 'Mallow'),
    CapyName('caramel', 'Карамелька', 'Caramel'),
    CapyName('toffee', 'Ириска', 'Toffee'),
    CapyName('waffle', 'Вафелька', 'Waffle'),
    CapyName('pancake', 'Блинчик', 'Pancake'),
    CapyName('crumpet', 'Оладушек', 'Crumpet'),
    CapyName('cupcake', 'Кексик', 'Cupcake'),
    CapyName('lolly', 'Леденец', 'Lolly'),
    CapyName('gummy', 'Мармеладка', 'Gummy'),
    CapyName('fudge', 'Помадка', 'Fudge'),
    CapyName('sugar', 'Сахарок', 'Sugar'),
    CapyName('bagel', 'Бублик', 'Bagel'),
    CapyName('plushie', 'Плюшка', 'Plushie'),
    CapyName('pie', 'Пирожок', 'Pie'),
    CapyName('twist', 'Кренделёк', 'Twist'),
    CapyName('rusk', 'Сухарик', 'Rusk'),
    CapyName('dumpling', 'Пельмешек', 'Dumpling'),
    CapyName('scone', 'Сырок', 'Scone'),
    CapyName('nugget', 'Батончик', 'Nugget'),
    CapyName('cream', 'Сливочка', 'Cream'),
    // Орехи и ягоды.
    CapyName('almond', 'Миндаль', 'Almond'),
    CapyName('filbert', 'Фундук', 'Filbert'),
    CapyName('chestnut', 'Каштан', 'Chestnut'),
    CapyName('acorn', 'Жёлудь', 'Acorn'),
    CapyName('cranberry', 'Клюковка', 'Cranberry'),
    CapyName('lingon', 'Брусничка', 'Lingon'),
    CapyName('raspberry', 'Малинка', 'Raspberry'),
    CapyName('cherry', 'Вишенка', 'Cherry'),
    CapyName('currant', 'Смородинка', 'Currant'),
    CapyName('gooseberry', 'Крыжовник', 'Gooseberry'),
    // Фрукты, овощи, крупы.
    CapyName('plum', 'Сливка', 'Plum'),
    CapyName('apricot', 'Абрикос', 'Apricot'),
    CapyName('peach', 'Персик', 'Peach'),
    CapyName('pear', 'Грушка', 'Pear'),
    CapyName('apple', 'Яблочко', 'Apple'),
    CapyName('lemon', 'Лимончик', 'Lemon'),
    CapyName('tangerine', 'Мандаринка', 'Tangerine'),
    CapyName('melon', 'Арбузик', 'Melon'),
    CapyName('pea', 'Горошек', 'Pea'),
    CapyName('bean', 'Фасолька', 'Bean'),
    CapyName('radish', 'Редиска', 'Radish'),
    CapyName('squash', 'Кабачок', 'Squash'),
    CapyName('pickle', 'Огурчик', 'Pickle'),
    CapyName('spud', 'Картошка', 'Spud'),
    CapyName('kernel', 'Кукурузка', 'Kernel'),
    CapyName('oats', 'Овсянка', 'Oats'),
    CapyName('buckwheat', 'Гречка', 'Buckwheat'),
    CapyName('crumb', 'Крупинка', 'Crumb'),
    CapyName('turnip', 'Репка', 'Turnip'),
    CapyName('cabbage', 'Капустка', 'Cabbage'),
    // Природа.
    CapyName('leaf', 'Листик', 'Leaf'),
    CapyName('sprout', 'Стебелёк', 'Sprout'),
    CapyName('droplet', 'Капелька', 'Droplet'),
    CapyName('icicle', 'Льдинка', 'Icicle'),
    CapyName('breeze', 'Ветерок', 'Breeze'),
    CapyName('sunbeam', 'Лучик', 'Sunbeam'),
    CapyName('feather', 'Пёрышко', 'Feather'),
    CapyName('pebble', 'Камешек', 'Pebble'),
    CapyName('shell', 'Ракушка', 'Shell'),
    CapyName('twig', 'Веточка', 'Twig'),
    CapyName('bud', 'Бутон', 'Bud'),
    CapyName('tulip', 'Тюльпан', 'Tulip'),
    CapyName('dandy', 'Одуванчик', 'Dandy'),
    CapyName('burdock', 'Лопушок', 'Burdock'),
    CapyName('lilypad', 'Кувшинка', 'Lilypad'),
    CapyName('drizzle', 'Тучка', 'Drizzle'),
    CapyName('grain', 'Песчинка', 'Grain'),
    // Уютные вещи.
    CapyName('yarn', 'Клубочек', 'Yarn'),
    CapyName('socks', 'Носочек', 'Socks'),
    CapyName('mitten', 'Варежка', 'Mitten'),
    CapyName('scarf', 'Шарфик', 'Scarf'),
    CapyName('blankie', 'Одеяльце', 'Blankie'),
    CapyName('slipper', 'Тапочек', 'Slipper'),
    CapyName('candle', 'Свечка', 'Candle'),
    CapyName('bow', 'Бантик', 'Bow'),
    CapyName('puff', 'Пуфик', 'Puff'),
    CapyName('teacup', 'Чашечка', 'Teacup'),
    CapyName('ribbon', 'Тесёмка', 'Ribbon'),
    CapyName('pompom', 'Помпон', 'Pompom'),
    CapyName('freckle', 'Пятнышко', 'Freckle'),
    CapyName('roundie', 'Кругляшок', 'Roundie'),
    CapyName('bouncy', 'Мячик', 'Bouncy'),
  ];

  static final Map<String, CapyName> _byKey = {for (final n in all) n.key: n};

  static CapyName? byKey(String? key) => key == null ? null : _byKey[key];

  /// «Шишка-соня».
  static String ruWithTrait(CapyName name, CapyTrait trait) =>
      '${name.ru}-${trait.epithetRu}';

  /// «Sleepy Pinecone».
  static String enWithTrait(CapyName name, CapyTrait trait) =>
      '${trait.epithetEn} ${name.en}';

  /// What a baby without a name is called in lists.
  static const String babyRu = 'Малыш';

  /// Longest own name the player may give (spec 004, Т7).
  static const int maxCustomLength = 16;
}
