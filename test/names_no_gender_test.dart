import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capy_names.dart';

import 'support/test_game.dart';

/// Spec 004, Т5 (WBS 11.16 «Без пола»): no text around a capy needs a gender.
void main() {
  /// Words that give a capy a gender (or speak of «it» as he / she).
  const word = '(?<![А-Яа-яЁё])';
  const end = '(?![А-Яа-яЁё])';
  final gendered = RegExp(
    'подросла|выросла|уснула|улетела|заснула|малышка|девочк|мальчик|'
    '$word(её|Её|она|Она|он|Он|его|Его|сама|Сама)$end',
  );

  test('the check itself catches gendered words', () {
    expect(gendered.hasMatch('Она спит'), isTrue);
    expect(gendered.hasMatch('у неё, её имя'), isTrue);
    expect(gendered.hasMatch('Малыш подросла'), isTrue);
    expect(gendered.hasMatch('Сонная Шишка, Онега'), isFalse);
    expect(gendered.hasMatch('Летит Пуговка.'), isFalse);
  });

  /// String literals of the files spec 004 writes texts in.
  const files = [
    'lib/features/game/core/names.dart',
    'lib/features/game/models/capy_names.dart',
    'lib/features/game/models/capy_naming.dart',
    'lib/features/game/models/capybara.dart',
    'lib/features/game/widgets/rocket_chapter.dart',
    'lib/features/game/widgets/uyut/uyut_hub_sheet.dart',
    'lib/features/game/widgets/capybara_placeholder.dart',
    // Spec 006: the pile.
    'lib/features/game/core/pile.dart',
    'lib/features/game/core/shop.dart',
    'lib/features/game/models/capy_pile.dart',
    'lib/features/game/widgets/pile_caption.dart',
    'lib/features/game/widgets/tip_overlay.dart',
    'lib/features/game/widgets/screen/game_hud.dart',
    'lib/features/game/widgets/forest_map_overlay.dart',
    'lib/features/game/models/multipliers/cozy_place.dart',
    'lib/features/game/models/multipliers/family_food.dart',
  ];

  test('no gendered word in the strings of spec 004 and 006 files', () {
    final literal = RegExp(r"'([^'\\]|\\.)*'");
    for (final path in files) {
      final source = File(path).readAsStringSync();
      for (final m in literal.allMatches(source)) {
        final text = m.group(0)!;
        expect(gendered.hasMatch(text), isFalse, reason: '$path: $text');
      }
    }
  });

  test('the name plate and every epithet read without a gender', () async {
    SharedPreferences.setMockInitialValues(
      herdSave([testCapy('e', 3, pile: 'p'), testCapy('b', 1, pile: 'p')]),
    );
    final c = testController();
    final got = <GameEvent>[];
    c.events.listen(got.add);
    await c.init();
    c.debugAdvance(BalanceV0.pileCatchUpSeconds(1) + 1);
    final text = got.whereType<CapyNamed>().single.text;
    expect(text, startsWith('Малыш подрос — теперь это '));
    expect(gendered.hasMatch(text), isFalse);
    for (final t in CapyTrait.values) {
      for (final n in CapyNames.all) {
        final shown = CapyNames.ruWithTrait(n, t);
        expect(gendered.hasMatch(shown), isFalse, reason: shown);
      }
    }
    c.dispose();
  });
}
