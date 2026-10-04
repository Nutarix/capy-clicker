import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/capy_names.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/multipliers/capy_role.dart';

/// Spec 004, Т1 and Т4: names live in the game by key, RU and EN.
void main() {
  group('CapyNames', () {
    test('one hundred names, unique keys and forms', () {
      expect(CapyNames.all, hasLength(100));
      expect({for (final n in CapyNames.all) n.key}, hasLength(100));
      expect({for (final n in CapyNames.all) n.ru}, hasLength(100));
      expect({for (final n in CapyNames.all) n.en}, hasLength(100));
      expect(CapyNames.all.first.ru, 'Пуговка');
      expect(CapyNames.all.first.en, 'Button');
      expect(CapyNames.all[1].ru, 'Шишка');
      expect(CapyNames.all.last.ru, 'Мячик');
      expect(CapyNames.all.last.en, 'Bouncy');
      for (final n in CapyNames.all) {
        expect(n.key, matches(RegExp(r'^[a-z]+$')), reason: n.en);
        expect(CapyNames.byKey(n.key), same(n));
      }
      expect(CapyNames.byKey('nope'), isNull);
    });

    test('six traits with epithets from NAMES.md', () {
      expect(CapyTrait.values, hasLength(6));
      final pinecone = CapyNames.byKey('pinecone')!;
      expect(
        CapyNames.ruWithTrait(pinecone, CapyTrait.sleepyhead),
        'Шишка-соня',
      );
      expect(
        CapyNames.ruWithTrait(pinecone, CapyTrait.fidget),
        'Шишка-непоседа',
      );
      expect(
        CapyNames.ruWithTrait(pinecone, CapyTrait.sweetTooth),
        'Шишка-лакомка',
      );
      expect(CapyNames.ruWithTrait(pinecone, CapyTrait.splasher), 'Шишка-плюх');
      expect(
        CapyNames.ruWithTrait(pinecone, CapyTrait.cuddler),
        'Шишка-обнимашка',
      );
      expect(
        CapyNames.ruWithTrait(pinecone, CapyTrait.dreamer),
        'Шишка-мечтатель',
      );
      expect(
        CapyNames.enWithTrait(pinecone, CapyTrait.sleepyhead),
        'Sleepy Pinecone',
      );
      expect(
        CapyNames.enWithTrait(pinecone, CapyTrait.fidget),
        'Fidgety Pinecone',
      );
      expect(
        CapyNames.enWithTrait(pinecone, CapyTrait.sweetTooth),
        'Sweet Pinecone',
      );
      expect(
        CapyNames.enWithTrait(pinecone, CapyTrait.splasher),
        'Splashy Pinecone',
      );
      expect(
        CapyNames.enWithTrait(pinecone, CapyTrait.cuddler),
        'Cuddly Pinecone',
      );
      expect(
        CapyNames.enWithTrait(pinecone, CapyTrait.dreamer),
        'Dreamy Pinecone',
      );
      expect(
        [for (final t in CapyTrait.values) t.labelRu],
        ['соня', 'непоседа', 'лакомка', 'плюх', 'обнимашка', 'мечтатель'],
      );
      for (final t in CapyTrait.values) {
        expect(CapyTraitX.tryParse(t.id), t);
      }
      expect(CapyTraitX.tryParse(null), isNull);
      expect(CapyTraitX.tryParse('grumpy'), isNull);
    });
  });

  group('Capybara name fields', () {
    const pos = Offset(0.4, 0.6);

    test('JSON round trip keeps name, epithet, own name, trait', () {
      final capy = Capybara(
        id: 'c7',
        level: 2,
        position: pos,
        role: CapyRole.nanya,
        nameKey: 'pinecone',
        nameEpithet: true,
        customName: 'Пух',
        trait: CapyTrait.dreamer,
      );
      final json = capy.toJson();
      expect(json['name'], 'pinecone');
      expect(json['epithet'], true);
      expect(json['customName'], 'Пух');
      expect(json['trait'], 'dreamer');
      // New keys go last: the old ones keep their order.
      expect(json.keys.toList(), [
        'id',
        'level',
        'x',
        'y',
        'role',
        'name',
        'epithet',
        'customName',
        'trait',
      ]);
      expect(Capybara.fromJson(json), capy);
    });

    test('old save capy: no fields, unnamed; JSON unchanged', () {
      final json = {'id': 'c1', 'level': 3, 'x': 0.5, 'y': 0.5};
      final capy = Capybara.fromJson(json);
      expect(capy.nameKey, isNull);
      expect(capy.trait, isNull);
      expect(capy.customName, isNull);
      expect(capy.nameEpithet, isFalse);
      expect(capy.isNamed, isFalse);
      expect(capy.toJson(), json);
    });

    test('display: own name wins, then RU name, epithet form', () {
      final plain = Capybara(
        id: 'c1',
        level: 2,
        position: pos,
        nameKey: 'button',
        trait: CapyTrait.fidget,
      );
      expect(plain.displayNameRu, 'Пуговка');
      final epithet = plain.copyWith(nameKey: 'pinecone', nameEpithet: true);
      expect(epithet.displayNameRu, 'Шишка-непоседа');
      final own = epithet.copyWith(customName: 'Пух');
      expect(own.displayNameRu, 'Пух');
      final baby = Capybara(id: 'c2', level: 1, position: pos);
      expect(baby.displayNameRu, isNull);
      expect(baby.listNameRu, 'Малыш');
      expect(plain.listNameRu, 'Пуговка');
    });

    test('copyWith keeps the name; equality sees it', () {
      final a = Capybara(
        id: 'c1',
        level: 2,
        position: pos,
        nameKey: 'button',
        trait: CapyTrait.cuddler,
      );
      final moved = a.copyWith(position: const Offset(0.1, 0.2));
      expect(moved.nameKey, 'button');
      expect(moved.trait, CapyTrait.cuddler);
      expect(a == a.copyWith(customName: 'Пух'), isFalse);
      expect(a.copyWith(customName: 'Пух').copyWith(clearCustomName: true), a);
    });
  });
}
