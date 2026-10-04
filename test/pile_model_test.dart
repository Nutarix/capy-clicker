import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capy_pile.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/multipliers/capy_role.dart';

/// Spec 006, Т2, Т3, Т5: the pile as a capy field, places, who grows.
void main() {
  Capybara capy(
    String id,
    int level, {
    String? pile,
    double growth = 0,
    CapyRole? role,
  }) => Capybara(
    id: id,
    level: level,
    position: const Offset(0.5, 0.7),
    pileId: pile,
    growth: growth,
    role: role,
  );

  group('Capybara pile fields', () {
    test('JSON: pile and growth only when set', () {
      final plain = capy('c1', 2);
      expect(plain.toJson().containsKey('pile'), isFalse);
      expect(plain.toJson().containsKey('grow'), isFalse);
      final seated = capy('c2', 1, pile: 'p7', growth: 0.25);
      final json = seated.toJson();
      expect(json['pile'], 'p7');
      expect(json['grow'], 0.25);
      final back = Capybara.fromJson(json);
      expect(back, seated);
      expect(back.pileId, 'p7');
      expect(back.growth, 0.25);
      expect(Capybara.fromJson(plain.toJson()), plain);
    });

    test('copyWith keeps, sets and clears the pile', () {
      final a = capy('c1', 1, pile: 'p1', growth: 0.5);
      expect(a.copyWith(level: 2).pileId, 'p1');
      expect(a.copyWith(level: 2).growth, 0.5);
      expect(a.copyWith(clearPile: true).pileId, isNull);
      expect(a.copyWith(clearPile: true).growth, 0.5);
      expect(a.copyWith(pileId: 'p9').pileId, 'p9');
      expect(a.copyWith(growth: 0).growth, 0);
      expect(a.inPile, isTrue);
      expect(capy('c2', 1).inPile, isFalse);
    });
  });

  group('places', () {
    test('a single and a pile take one place each', () {
      final herd = [
        capy('c1', 1),
        capy('c2', 1, pile: 'p1'),
        capy('c3', 2, pile: 'p1'),
        capy('c4', 1, pile: 'p2'),
        capy('c5', 1, pile: 'p2'),
        capy('c6', 1, pile: 'p2'),
        capy('c7', 3),
      ];
      expect(CapyPiles.placesOf(herd), 4);
      expect(CapyPiles.placesOf(const []), 0);
      expect(CapyPiles.membersOf(herd, 'p2').map((c) => c.id), [
        'c4',
        'c5',
        'c6',
      ]);
      expect(CapyPiles.groups(herd).keys, ['p1', 'p2']);
    });

    test('sanitize: a pile of one dissolves, over four stand up', () {
      final herd = [
        capy('c1', 1, pile: 'p1'),
        capy('c2', 1),
        for (var i = 0; i < 5; i++) capy('d$i', 1, pile: 'p2'),
      ];
      final clean = CapyPiles.sanitize(herd);
      expect(clean.first.pileId, isNull);
      expect(CapyPiles.membersOf(clean, 'p2'), hasLength(BalanceV0.pileMaxSize));
      expect(clean.last.pileId, isNull);
      final ok = [capy('c1', 1, pile: 'p1'), capy('c2', 2, pile: 'p1')];
      expect(identical(CapyPiles.sanitize(ok), ok), isTrue);
    });
  });

  group('who grows', () {
    test('nursery: the young catch up, the eldest waits', () {
      final members = [
        capy('a', 3, pile: 'p'),
        capy('b', 1, pile: 'p'),
        capy('c', 2, pile: 'p'),
      ];
      expect(CapyPiles.growKind(members[0], members), PileGrowKind.none);
      expect(CapyPiles.growKind(members[1], members), PileGrowKind.catchUp);
      expect(CapyPiles.growKind(members[2], members), PileGrowKind.catchUp);
    });

    test('three peers grow up, a pair does not', () {
      final trio = [for (final id in ['a', 'b', 'c']) capy(id, 2, pile: 'p')];
      for (final c in trio) {
        expect(CapyPiles.growKind(c, trio), PileGrowKind.peers);
      }
      final pair = [for (final id in ['a', 'b']) capy(id, 2, pile: 'p')];
      for (final c in pair) {
        expect(CapyPiles.growKind(c, pair), PileGrowKind.none);
      }
      final mixed = [
        ...trio,
        capy('d', 1, pile: 'p'),
      ];
      expect(CapyPiles.growKind(mixed[0], mixed), PileGrowKind.peers);
      expect(CapyPiles.growKind(mixed[3], mixed), PileGrowKind.catchUp);
    });

    test('one step at a time, up to the eldest, never above', () {
      var herd = [
        capy('a', 3, pile: 'p'),
        capy('b', 1, pile: 'p'),
      ];
      final grown = <String>[];
      // Far more time than needed: still level by level.
      for (var i = 0; i < 20000; i++) {
        final r = CapyPiles.grow(herd, 1.0);
        herd = r.herd;
        grown.addAll(r.grown);
      }
      expect(herd[1].level, 3);
      expect(herd[0].level, 3);
      expect(grown, ['b', 'b']);
    });

    test('step time comes from balance; the nanny speeds the pile', () {
      final secs = BalanceV0.pileCatchUpSeconds(1);
      var herd = [capy('a', 2, pile: 'p'), capy('b', 1, pile: 'p')];
      var r = CapyPiles.grow(herd, secs * 0.5);
      expect(r.grown, isEmpty);
      expect(r.herd[1].growth, closeTo(0.5, 1e-9));
      r = CapyPiles.grow(r.herd, secs * 0.5 + 1e-6);
      expect(r.grown, ['b']);
      expect(r.herd[1].level, 2);
      expect(r.herd[1].growth, 0);

      herd = [
        capy('a', 2, pile: 'p', role: CapyRole.nanya),
        capy('b', 1, pile: 'p'),
      ];
      r = CapyPiles.grow(herd, secs * 0.5);
      expect(
        r.herd[1].growth,
        closeTo(0.5 * (1 + BalanceV0.pileNanyaGrowBonus), 1e-9),
      );
    });

    test('outside a pile nobody grows; growth stays', () {
      final herd = [capy('a', 1, growth: 0.4), capy('b', 2)];
      final r = CapyPiles.grow(herd, 1000);
      expect(identical(r.herd, herd), isTrue);
      expect(r.grown, isEmpty);
    });

    test('higher levels take longer', () {
      for (var lv = 1; lv < 8; lv++) {
        expect(
          BalanceV0.pilePeerSeconds(lv + 1),
          greaterThan(BalanceV0.pilePeerSeconds(lv)),
        );
        expect(
          BalanceV0.pileCatchUpSeconds(lv + 1),
          greaterThanOrEqualTo(BalanceV0.pileCatchUpSeconds(lv)),
        );
        expect(
          BalanceV0.pilePeerSeconds(lv),
          greaterThan(BalanceV0.pileCatchUpSeconds(lv)),
        );
      }
    });
  });
}
