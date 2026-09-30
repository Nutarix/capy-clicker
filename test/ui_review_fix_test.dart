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
            expect(
              (t - o).distance,
              greaterThanOrEqualTo(CapyWander.peerGap - 0.001),
            );
          }
          parked.add(t);
        }
      }
    });

    test('a body already on the stump is sent off it', () {
      final t = CapyWander.pickTarget(
        from: CapyWander.stumpCenter,
        random01: math.Random(3).nextDouble,
        herdCount: 3,
      );
      expect(
        (t - CapyWander.stumpCenter).distance,
        greaterThanOrEqualTo(CapyWander.stumpRadius),
      );
      expect(
        (t - CapyWander.nestCenter).distance,
        greaterThanOrEqualTo(CapyWander.nestRadius),
      );
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
      for (final word in ['сюда!', 'нажми!']) {
        expect(find.text(word), findsOneWidget);
        final para = tester.renderObject<RenderParagraph>(find.text(word));
        expect(para.didExceedMaxLines, isFalse);
        final intrinsic = para.getMaxIntrinsicWidth(double.infinity);
        expect(para.size.width, greaterThanOrEqualTo(intrinsic - 0.5));
      }
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
      expect(find.textContaining('Позвать капи'), findsOneWidget);
      expect(find.text('Не хватает травы'), findsNothing);
      expect(find.text('Семья полная'), findsNothing);

      await pump(canCall: false, reason: 'Не хватает травы', grass: 3);
      expect(find.text('Не хватает травы'), findsOneWidget);
      expect(find.textContaining('Позвать капи'), findsNothing);

      await pump(canCall: false, reason: 'Семья полная', grass: 126);
      expect(find.text('Семья полная'), findsOneWidget);
      expect(find.textContaining('Позвать капи'), findsNothing);
    });
  });
}
