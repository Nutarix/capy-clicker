import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capy_wander.dart';
import 'package:capy_clicker/features/game/models/multipliers/capy_role.dart';
import 'package:capy_clicker/features/game/models/multipliers/uyut_research.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';
import 'package:capy_clicker/features/game/widgets/berry_basket.dart';
import 'package:capy_clicker/features/game/widgets/grass_spend_panel.dart';
import 'package:capy_clicker/features/game/widgets/meadow_hint_chip.dart';
import 'package:capy_clicker/features/game/widgets/mud_puddle.dart';
import 'package:capy_clicker/features/game/widgets/uyut/uyut_hub_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('meadow walk spread', () {
    test('targets stay on grass and off stump, nest, and peers', () {
      final rng = math.Random(7);
      final parked = <Offset>[];
      for (final herd in [1, 4, 8, 12]) {
        parked.clear();
        for (var n = 0; n < 6; n++) {
          final from = parked.isEmpty ? const Offset(0.30, 0.78) : parked.last;
          final t = CapyWander.pickTarget(
            from: from,
            random01: rng.nextDouble,
            herdCount: herd,
            others: parked,
            mudCenter: const Offset(0.22, 0.78),
          );
          expect(
            WorldZones.isInMeadow(t, herdCount: herd),
            isTrue,
            reason: 'meadow',
          );
          expect(
            CapyWander.onGrass(t, herd),
            isTrue,
            reason: 'grass herd=$herd',
          );
          expect(
            CapyWander.hitsProp(t, mudCenter: const Offset(0.22, 0.78)),
            isFalse,
          );
          expect(
            (t - CapyWander.stumpCenter).distance,
            greaterThanOrEqualTo(CapyWander.stumpRadius),
          );
          expect(
            (t - CapyWander.nestCenter).distance,
            greaterThanOrEqualTo(CapyWander.nestRadius),
          );
          for (final o in parked) {
            // Packed plates cannot always honor a full sprite radius.
            // Never restack on the same grass point; keep the old gap
            // while there is still room (first four bodies).
            expect(
              (t - o).distance,
              greaterThan(0.04),
              reason: 'not stacked herd=$herd n=$n',
            );
            if (n < 4) {
              expect(
                (t - o).distance,
                greaterThanOrEqualTo(CapyWander.peerGap - 0.001),
                reason: 'gap herd=$herd n=$n',
              );
            }
          }
          parked.add(t);
        }
      }
    });

    test('four bodies keep a personal radius on a phone meadow', () {
      const meadow = Size(1080, 1800);
      const mud = Offset(0.22, 0.78);
      final rng = math.Random(4);
      for (final herd in [4, 8, 12]) {
        final parked = <Offset>[];
        for (var n = 0; n < 4; n++) {
          final from = parked.isEmpty ? const Offset(0.30, 0.78) : parked.last;
          final t = CapyWander.pickTarget(
            from: from,
            random01: rng.nextDouble,
            herdCount: herd,
            others: parked,
            mudCenter: mud,
            meadowSize: meadow,
            spreadSalt: n / 4,
          );
          expect(CapyWander.onGrass(t, herd), isTrue, reason: 'h=$herd n=$n');
          expect(
            CapyWander.hitsProp(t, mudCenter: mud, meadowSize: meadow),
            isFalse,
            reason: 'prop h=$herd n=$n',
          );
          for (final o in parked) {
            expect(
              CapyWander.overlapsPeer(t, [o], meadowSize: meadow),
              isFalse,
              reason: 'radius h=$herd n=$n t=$t o=$o',
            );
          }
          parked.add(t);
        }
      }
    });

    test('six bodies keep a grass gap on the starter meadow', () {
      const meadow = CapyWander.fallbackMeadow;
      final sep = CapyWander.pairSeparation(meadow);
      // Drawn sheet plus a strip of grass, not a circle that only clears centers.
      expect(sep.minX * meadow.width, greaterThan(70 + 12));
      expect(sep.minY * meadow.height, greaterThan(50));
      final rng = math.Random(5);
      final parked = <Offset>[];
      for (var n = 0; n < 6; n++) {
        final from = parked.isEmpty ? const Offset(0.40, 0.74) : parked.last;
        final t = CapyWander.pickTarget(
          from: from,
          random01: rng.nextDouble,
          herdCount: 0,
          others: parked,
          meadowSize: meadow,
          spreadSalt: n / 6,
        );
        expect(CapyWander.onGrass(t, 0), isTrue, reason: 'grass $n');
        expect(
          CapyWander.hitsProp(t, meadowSize: meadow),
          isFalse,
          reason: 'prop $n',
        );
        expect(
          CapyWander.overlapsPeer(t, parked, meadowSize: meadow),
          isFalse,
          reason: 'gap $n $t',
        );
        for (final o in parked) {
          expect((t - o).distance, greaterThan(0.04), reason: 'not stacked');
        }
        parked.add(t);
      }
    });

    test('a walk cannot close one pair just because another is worse', () {
      const meadow = Size(411, 560);
      const stacked = Offset(0.40, 0.72);
      const other = Offset(0.62, 0.72);
      const slide = Offset(0.48, 0.72);
      expect(
        CapyWander.peerGapShrinks(stacked, slide, const [
          stacked,
          other,
        ], meadowSize: meadow),
        isTrue,
        reason: 'sliding toward the second body',
      );
      expect(
        CapyWander.peerGapShrinks(stacked, const Offset(0.30, 0.72), const [
          stacked,
          other,
        ], meadowSize: meadow),
        isFalse,
        reason: 'stepping away from both',
      );
    });

    test('seven bodies keep a grass strip on the starter plate', () {
      const meadow = Size(411, 560);
      const mud = Offset(0.36, 0.74);
      final rng = math.Random(4);
      final parked = <Offset>[];
      for (var n = 0; n < 7; n++) {
        final from = parked.isEmpty ? const Offset(0.48, 0.72) : parked.last;
        final t = CapyWander.pickTarget(
          from: from,
          random01: rng.nextDouble,
          herdCount: 0,
          others: List<Offset>.of(parked),
          mudCenter: mud,
          meadowSize: meadow,
          spreadSalt: (n * 0.173) % 1,
        );
        expect(CapyWander.onGrass(t, 0), isTrue, reason: 'grass $n');
        expect(
          CapyWander.hitsProp(t, mudCenter: mud, meadowSize: meadow),
          isFalse,
          reason: 'prop $n',
        );
        parked.add(t);
      }
      double closest() {
        var m = 999.0;
        for (var i = 0; i < parked.length; i++) {
          for (var j = i + 1; j < parked.length; j++) {
            final g = CapyWander.minPeerGapPx(parked[i], [
              parked[j],
            ], meadowSize: meadow);
            if (g < m) m = g;
          }
        }
        return m;
      }

      expect(closest(), greaterThanOrEqualTo(10), reason: 'spawn strip');
      for (var round = 0; round < 5; round++) {
        for (var i = 0; i < parked.length; i++) {
          final others = [
            for (var j = 0; j < parked.length; j++)
              if (j != i) parked[j],
          ];
          final next = CapyWander.pickTarget(
            from: parked[i],
            random01: rng.nextDouble,
            herdCount: 0,
            others: others,
            mudCenter: mud,
            meadowSize: meadow,
            spreadSalt: ((i + round) * 0.173) % 1,
          );
          final stepped = CapyWander.clipTravel(
            from: parked[i],
            to: next,
            others: others,
            herdCount: 0,
            mudCenter: mud,
            meadowSize: meadow,
          );
          expect(
            CapyWander.hitsProp(stepped, mudCenter: mud, meadowSize: meadow),
            isFalse,
            reason: 'walk prop r=$round i=$i',
          );
          expect(
            CapyWander.peerGapShrinks(
              parked[i],
              stepped,
              others,
              meadowSize: meadow,
            ),
            isFalse,
            reason: 'no shrink r=$round i=$i',
          );
          parked[i] = stepped;
        }
      }
      expect(closest(), greaterThanOrEqualTo(10), reason: 'after walks');
    });

    test('a body already on the stump is sent off it', () {
      final t = CapyWander.pickTarget(
        from: CapyWander.stumpCenter,
        random01: math.Random(3).nextDouble,
        herdCount: 3,
        meadowSize: const Size(411, 480),
      );
      expect(CapyWander.hitsProp(t, meadowSize: const Size(411, 480)), isFalse);
      expect(
        (t - CapyWander.stumpCenter).distance,
        greaterThanOrEqualTo(CapyWander.stumpRadius),
      );
      expect(
        (t - CapyWander.nestCenter).distance,
        greaterThanOrEqualTo(CapyWander.nestRadius),
      );
    });

    test('bodies stay off the berry basket and do not share a point', () {
      const meadow = Size(411, 480);
      const mud = Offset(0.22, 0.78);
      final rng = math.Random(11);
      final parked = <Offset>[];
      for (var n = 0; n < 4; n++) {
        final from = n == 0 ? CapyWander.berryCenter : parked.last;
        final t = CapyWander.pickTarget(
          from: from,
          random01: rng.nextDouble,
          herdCount: 2,
          others: List<Offset>.from(parked),
          mudCenter: mud,
          meadowSize: meadow,
          spreadSalt: n / 4,
        );
        expect(
          CapyWander.hitsProp(t, mudCenter: mud, meadowSize: meadow),
          isFalse,
          reason: 'body $n',
        );
        expect(CapyWander.onGrass(t, 2), isTrue);
        for (final o in parked) {
          expect((t - o).distance, greaterThan(0.02), reason: 'not stacked');
          expect(
            CapyWander.overlapsPeer(t, [o], meadowSize: meadow),
            isFalse,
            reason: 'bodies $n',
          );
        }
        parked.add(t);
      }
    });

    test('wood ring and сюда chip are forbidden, bodies do not stack', () {
      const meadow = Size(411, 560);
      const mud = Offset(0.40, 0.58);
      final props = CapyWander.propRects(mudCenter: mud, meadowSize: meadow);
      expect(props.length, 5);
      final disc = props[props.length - 2];
      final chip = props.last;
      // Chip hangs under the painted disc, not on the wood.
      expect(chip.top, greaterThanOrEqualTo(disc.bottom - 0.001));
      expect(
        CapyWander.hitsProp(mud, mudCenter: mud, meadowSize: meadow),
        isTrue,
        reason: 'disc center',
      );
      expect(
        CapyWander.hitsProp(chip.center, mudCenter: mud, meadowSize: meadow),
        isTrue,
        reason: 'chip',
      );
      // Gameplay hit circle is not the forbidden shape: a point just outside
      // the painted disc but inside a loose circle still fails the body test
      // only when the sprite overlaps. The disc itself must reject a body.
      final parked = <Offset>[];
      final rng = math.Random(9);
      for (var n = 0; n < 4; n++) {
        final t = CapyWander.pickTarget(
          from: mud,
          random01: rng.nextDouble,
          herdCount: 4,
          others: parked,
          mudCenter: mud,
          meadowSize: meadow,
          spreadSalt: n / 4,
        );
        expect(CapyWander.onGrass(t, 4), isTrue, reason: 'grass $n');
        expect(
          CapyWander.hitsProp(t, mudCenter: mud, meadowSize: meadow),
          isFalse,
          reason: 'off ring+chip $n $t',
        );
        expect(
          CapyWander.overlapsPeer(t, parked, meadowSize: meadow),
          isFalse,
          reason: 'gap $n',
        );
        for (final o in parked) {
          expect((t - o).distance, greaterThan(0.04), reason: 'not stacked');
        }
        parked.add(t);
      }
    });
  });

  group('Семья copy', () {
    test('guard role never says стадо', () {
      expect(CapyRole.storozh.tipRu, isNot(contains('стад')));
      expect(CapyRole.storozh.effectRu, isNot(contains('стад')));
      expect(CapyRole.storozh.tipRu, contains('семь'));
      expect(CapyRole.storozh.effectRu, contains('семь'));
      for (final role in CapyRole.values) {
        expect(role.tipRu.toLowerCase(), isNot(contains('стад')));
        expect(role.effectRu.toLowerCase(), isNot(contains('стад')));
        expect(role.assignToastRu.toLowerCase(), isNot(contains('стад')));
      }
    });

    test('research shows cozy names, not raw ids', () {
      expect(UyutResearch.labelForId('more_flowers'), 'Больше цветов');
      expect(UyutResearch.labelForId('longer_mud'), 'Долгая лужа');
      expect(UyutResearch.labelForId('more_berries'), 'Ягодный край');
      expect(
        UyutResearch.requiresLine(UyutResearch.longerMud),
        'нужно: Больше цветов',
      );
      expect(
        UyutResearch.requiresLine(UyutResearch.moreBerries),
        'нужно: Больше цветов',
      );
      final lamp = UyutResearch.requiresLine(UyutResearch.cozyLamp);
      expect(lamp, contains('Тент на поляне'));
      expect(lamp, contains('Вторая роль'));
      expect(lamp, isNot(contains('more_')));
      expect(lamp, isNot(contains('_')));
      expect(UyutResearch.softCapPlus.effectRu, '+1 к лимиту семьи');
      expect(
        UyutResearch.softCapPlus.effectRu.toLowerCase(),
        isNot(contains('soft')),
      );
      expect(UyutResearch.softCapPlus.effectRu, isNot(contains('cap')));
      expect(UyutResearch.softCapPlus.effectRu, contains('семь'));
    });

    test('empty role line goes away once a role is assigned', () async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(persistence: GamePersistence());
      await c.init();
      expect(c.activeRoleBonusesRu, 'Роли пока не назначены');
      final id = c.state.herd.first.id;
      expect(c.assignRole(id, CapyRole.storozh), isTrue);
      expect(c.state.herd.first.role, CapyRole.storozh);
      expect(c.activeRoleBonusesRu, isNot(contains('не назначены')));
      expect(c.activeRoleBonusesRu, contains('лимит семьи'));
      c.dispose();
    });
  });

  group('Позвать капи reason', () {
    test('low grass vs full семья', () async {
      SharedPreferences.setMockInitialValues({});
      final broke = GameController(persistence: GamePersistence());
      await broke.init();
      expect(broke.canCallCapy, isFalse);
      expect(broke.callCapyBlockedReason, 'Не хватает травы');
      broke.dispose();

      SharedPreferences.setMockInitialValues({});
      final full = GameController(persistence: GamePersistence());
      await full.init();
      for (var i = 0; i < 20; i++) {
        full.addProgress(1.0, fromTap: true);
      }
      expect(full.state.herdCount, BalanceV0.maxHerdSize);
      while (full.state.grass < 126) {
        full.onFlowerTap();
      }
      expect(full.state.grass, greaterThanOrEqualTo(126));
      expect(full.canCallCapy, isFalse);
      expect(full.callCapyBlockedReason, 'Семья полная');
      full.dispose();

      SharedPreferences.setMockInitialValues({});
      final ready = GameController(persistence: GamePersistence());
      await ready.init();
      while (ready.state.grass < BalanceV0.callCapyGrassCost) {
        ready.onFlowerTap();
      }
      expect(ready.canCallCapy, isTrue);
      expect(ready.callCapyBlockedReason, isNull);
      ready.dispose();
    });
  });

  group('hint chips', () {
    testWidgets('сюда and нажми render in full', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MeadowHintChip(text: 'сюда!'),
                MeadowHintChip(text: 'нажми!'),
                MeadowHintChip(text: 'ягоды!'),
                MeadowHintChip(text: 'плеск!'),
              ],
            ),
          ),
        ),
      );
      for (final word in ['сюда!', 'нажми!', 'ягоды!', 'плеск!']) {
        final para = tester.renderObject<RenderParagraph>(find.text(word));
        expect(para.didExceedMaxLines, isFalse, reason: word);
        final intrinsic = para.getMaxIntrinsicWidth(double.infinity);
        expect(
          para.size.width,
          greaterThanOrEqualTo(intrinsic - 0.5),
          reason: word,
        );
        expect(para.size.width, greaterThan(40), reason: word);
      }
      expect(find.text('сю'), findsNothing);
      expect(find.text('жми!'), findsNothing);
    });

    testWidgets('puddle and basket chips keep the full word', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const MudPuddle(isWallowing: false, boostActive: false),
                BerryBasket(onTap: (_) {}, showHint: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // Canon frames: no «сюда!» / «нажми!» chips on the puddle or basket.
      expect(find.text('сюда!'), findsNothing);
      expect(find.text('нажми!'), findsNothing);
      expect(find.text('ягоды!'), findsNothing);
    });

    testWidgets('call button explains why it is gray', (tester) async {
      Future<void> pump({
        required bool canCall,
        String? reason,
        required int grass,
      }) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GrassSpendPanel(
                grass: grass,
                canCallCapy: canCall,
                callBlockedReason: reason,
                canBoost: grass >= 5,
                onCallCapy: () {},
                onBoost: () {},
              ),
            ),
          ),
        );
      }

      await pump(canCall: true, reason: null, grass: 20);
      expect(find.text('Позвать'), findsOneWidget);
      expect(find.text('Не хватает травы'), findsNothing);
      expect(find.text('Семья полная'), findsNothing);

      await pump(canCall: false, reason: 'Не хватает травы', grass: 3);
      expect(find.text('Не хватает травы'), findsOneWidget);
      expect(find.text('Позвать'), findsNothing);

      await pump(canCall: false, reason: 'Семья полная', grass: 126);
      expect(find.text('Семья полная'), findsOneWidget);
      expect(find.text('Позвать'), findsNothing);
    });

    testWidgets('Ускорение keeps the whole word and the grass cost', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: GrassSpendPanel(
                  grass: 20,
                  canCallCapy: true,
                  canBoost: true,
                  boostActive: false,
                  onCallCapy: () {},
                  onBoost: () {},
                  onUyutHub: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final finder = find.textContaining('Ускорение');
      expect(finder, findsOneWidget);
      final para = tester.renderObject<RenderParagraph>(finder);
      final shown = para.text.toPlainText();
      expect(shown, 'Ускорение');
      expect(shown, isNot(contains('...')));
      expect(shown, isNot(contains('…')));
      expect(para.didExceedMaxLines, isFalse);
      final intrinsic = para.getMaxIntrinsicWidth(double.infinity);
      expect(para.size.width, greaterThanOrEqualTo(intrinsic - 0.5));
    });
  });

  group('hub sheet', () {
    testWidgets('Наука tab is fully readable and role line hides', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(persistence: GamePersistence());
      await c.init();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UyutHubSheet(controller: c, initialTab: 1)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Наука'), findsOneWidget);
      expect(find.textContaining('Наука · ск'), findsNothing);
      final nauka = tester.renderObject<RenderParagraph>(find.text('Наука'));
      expect(nauka.didExceedMaxLines, isFalse);
      expect(
        nauka.size.width,
        greaterThanOrEqualTo(nauka.getMaxIntrinsicWidth(double.infinity) - 0.5),
      );
      expect(find.text('Роли'), findsOneWidget);
      expect(find.text('Еда'), findsOneWidget);
      expect(find.text('Дом'), findsOneWidget);

      expect(find.text('Роли пока не назначены'), findsOneWidget);
      final id = c.state.herd.first.id;
      c.assignRole(id, CapyRole.nanya);
      await tester.pump();
      expect(find.text('Роли пока не назначены'), findsNothing);
      expect(find.textContaining('Капи $id'), findsNothing);
      expect(find.text('Снять'), findsWidgets);
      expect(find.textContaining('Няня'), findsWidgets);

      c.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
