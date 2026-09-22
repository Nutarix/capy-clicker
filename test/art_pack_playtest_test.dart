import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/game_state.dart';
import 'package:capy_clicker/features/game/models/meadow_snapshot.dart';
import 'package:capy_clicker/features/game/models/multipliers/multipliers.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';
import 'package:capy_clicker/features/game/widgets/uyut/cozy_place_marker.dart';
import 'package:capy_clicker/features/game/widgets/uyut/multiplier_icon.dart';
import 'package:capy_clicker/features/game/widgets/uyut/uyut_hub_sheet.dart';

/// All soft-pixel paths wired in the multipliers art sew-in (SHA 7c81af6).
List<String> get _allArtPaths => [
      for (final r in CapyRole.values) r.assetPath,
      for (final f in FamilyFood.values) f.assetPath,
      for (final p in CozyPlaceKind.values) p.assetPath,
      for (final d in HomeDecor.values) d.assetPath,
      UyutResearch.assetPath,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('art pack asset paths', () {
    test('18 unique paths registered and load via rootBundle', () async {
      final paths = _allArtPaths;
      expect(paths.toSet().length, paths.length);
      expect(paths, hasLength(18));
      for (final path in paths) {
        expect(path.startsWith('assets/images/'), isTrue);
        expect(path.endsWith('.png'), isTrue);
        final data = await rootBundle.load(path);
        expect(
          data.lengthInBytes,
          greaterThan(1000),
          reason: '$path should be a real PNG asset',
        );
      }
    });

    test('model assetPath keys match sew-in filenames', () {
      expect(CapyRole.nanya.assetPath, 'assets/images/role_nanny.png');
      expect(CapyRole.sobiratel.assetPath, 'assets/images/role_gatherer.png');
      expect(CapyRole.storozh.assetPath, 'assets/images/role_guard.png');
      expect(FamilyFood.travka.assetPath, 'assets/images/food_travka.png');
      expect(FamilyFood.yagody.assetPath, 'assets/images/food_yagody.png');
      expect(FamilyFood.oreshki.assetPath, 'assets/images/food_oreshki.png');
      expect(CozyPlaceKind.pen.assetPath, 'assets/images/place_pen.png');
      expect(
        CozyPlaceKind.warmStone.assetPath,
        'assets/images/place_warm_stone.png',
      );
      expect(CozyPlaceKind.tent.assetPath, 'assets/images/place_tent.png');
      expect(HomeDecor.fonarik.assetPath, 'assets/images/decor_fonarik.png');
      expect(HomeDecor.kovrik.assetPath, 'assets/images/decor_kovrik.png');
      expect(HomeDecor.vazon.assetPath, 'assets/images/decor_vazon.png');
      expect(HomeDecor.girlyanda.assetPath, 'assets/images/decor_girlyanda.png');
      expect(
        HomeDecor.skvorechnik.assetPath,
        'assets/images/decor_skvorechnik.png',
      );
      expect(HomeDecor.podushka.assetPath, 'assets/images/decor_podushka.png');
      expect(HomeDecor.lampa.assetPath, 'assets/images/decor_lampa.png');
      expect(HomeDecor.kormushka.assetPath, 'assets/images/decor_kormushka.png');
      expect(UyutResearch.assetPath, 'assets/images/research_uyut.png');
    });
  });

  group('MultiplierIcon / CozyPlaceMarker widgets', () {
    testWidgets('MultiplierIcon resolves Image.asset for every art path',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Wrap(
                children: [
                  for (final path in _allArtPaths)
                    MultiplierIcon(key: ValueKey(path), assetPath: path, size: 24),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final path in _allArtPaths) {
        expect(
          find.byKey(ValueKey(path)),
          findsOneWidget,
          reason: path,
        );
        expect(
          find.descendant(
            of: find.byKey(ValueKey(path)),
            matching: find.byType(Image),
          ),
          findsOneWidget,
          reason: 'Image.asset for $path',
        );
        // errorBuilder would show Icons.image_not_supported_outlined
        expect(
          find.descendant(
            of: find.byKey(ValueKey(path)),
            matching: find.byIcon(Icons.image_not_supported_outlined),
          ),
          findsNothing,
          reason: 'broken asset $path',
        );
      }
    });

    testWidgets('CozyPlaceMarker for each place does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                for (final kind in CozyPlaceKind.values)
                  CozyPlaceMarker(
                    key: ValueKey(kind.id),
                    kind: kind,
                    active: kind == CozyPlaceKind.pen,
                    onCooldown: kind == CozyPlaceKind.warmStone,
                    cooldownSeconds: kind == CozyPlaceKind.warmStone ? 3.2 : 0,
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final kind in CozyPlaceKind.values) {
        expect(find.byKey(ValueKey(kind.id)), findsOneWidget);
        expect(
          find.image(AssetImage(kind.assetPath)),
          findsWidgets,
        );
      }
      expect(find.textContaining('с'), findsOneWidget); // cooldown label
    });
  });

  group('Uyut hub sheets (food / roles / decor / research)', () {
    Future<GameController> readyController() async {
      SharedPreferences.setMockInitialValues({
        'capy_clicker_game_state_v1': jsonEncode({
          'herdProgress': 0.0,
          'nextId': 3,
          'grass': 200,
          'uyut': 2,
          'food': {'travka': 2, 'yagody': 1, 'oreshki': 0},
          'ownedDecor': ['fonarik'],
          'placedDecor': ['fonarik'],
          'roleSlots': 2,
          'tentUnlocked': true,
          'researched': ['more_flowers'],
          'activeMeadowId': 'warm_edge',
          'herd': [
            {
              'id': 'c1',
              'level': 2,
              'x': 0.4,
              'y': 0.7,
              'role': 'nanya',
            },
            {'id': 'c2', 'level': 1, 'x': 0.55, 'y': 0.7},
          ],
          'meadows': {
            'warm_edge': {
              'herdProgress': 0.0,
              'herd': [
                {
                  'id': 'c1',
                  'level': 2,
                  'x': 0.4,
                  'y': 0.7,
                  'role': 'nanya',
                },
                {'id': 'c2', 'level': 1, 'x': 0.55, 'y': 0.7},
              ],
            },
          },
        }),
      });
      final c = GameController(random: _FixedRandom(0.5));
      await c.init();
      return c;
    }

    Future<void> pumpTab(WidgetTester tester) async {
      // Tab animation ~300ms; avoid pumpAndSettle (GameController tickers).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    testWidgets('food / roles / decor / research tabs render art icons',
        (tester) async {
      final c = await readyController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UyutHubSheet(controller: c),
          ),
        ),
      );
      await pumpTab(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Уют семьи'), findsOneWidget);

      // Еда
      expect(find.text('Еда'), findsOneWidget);
      expect(find.textContaining('Травка'), findsWidgets);
      expect(
        find.image(const AssetImage('assets/images/food_travka.png')),
        findsWidgets,
      );
      expect(
        find.image(const AssetImage('assets/images/food_yagody.png')),
        findsWidgets,
      );

      // Роли
      await tester.tap(find.text('Роли'));
      await pumpTab(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Няня'), findsWidgets);
      expect(
        find.image(const AssetImage('assets/images/role_nanny.png')),
        findsWidgets,
      );
      expect(
        find.image(const AssetImage('assets/images/role_gatherer.png')),
        findsWidgets,
      );

      // Дом
      await tester.tap(find.text('Дом'));
      await pumpTab(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Фонарик'), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/images/decor_fonarik.png')),
        findsWidgets,
      );
      expect(
        find.image(const AssetImage('assets/images/decor_kovrik.png')),
        findsWidgets,
      );

      // Наука
      await tester.tap(find.text('Наука'));
      await pumpTab(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Исследования уюта'), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/images/research_uyut.png')),
        findsWidgets,
      );
      expect(find.text('Больше цветов'), findsOneWidget);

      c.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('save/load roles + decor', () {
    test('GamePersistence round-trips roles and decor with art-linked ids',
        () async {
      final herd = [
        Capybara(
          id: 'c1',
          level: 2,
          position: const Offset(0.4, 0.7),
          role: CapyRole.nanya,
        ),
        Capybara(
          id: 'c2',
          level: 1,
          position: const Offset(0.55, 0.7),
          role: CapyRole.sobiratel,
        ),
      ];
      final state = GameState(
        herdProgress: 0.3,
        herd: herd,
        nextId: 5,
        grass: 55,
        uyut: 3,
        food: const FoodInventory(travka: 1, yagody: 2, oreshki: 1),
        ownedDecor: {
          HomeDecor.fonarik.id,
          HomeDecor.kovrik.id,
          HomeDecor.vazon.id,
        },
        placedDecor: {HomeDecor.fonarik.id, HomeDecor.vazon.id},
        researched: {'more_flowers', 'longer_mud'},
        roleSlots: 2,
        tentUnlocked: true,
        activeMeadowId: WorldZones.starterMeadowId,
        meadows: {
          WorldZones.starterMeadowId: MeadowSnapshot(
            herd: herd,
            herdProgress: 0.3,
          ),
        },
      );

      final persistence = GamePersistence();
      await persistence.save(state);
      final loaded = await persistence.load();
      expect(loaded, isNotNull);
      expect(loaded!.herd.map((c) => c.role), [
        CapyRole.nanya,
        CapyRole.sobiratel,
      ]);
      expect(loaded.ownedDecor, containsAll([
        HomeDecor.fonarik.id,
        HomeDecor.kovrik.id,
        HomeDecor.vazon.id,
      ]));
      expect(loaded.placedDecor, containsAll([
        HomeDecor.fonarik.id,
        HomeDecor.vazon.id,
      ]));
      expect(loaded.food.yagody, 2);
      expect(loaded.roleSlots, 2);
      expect(loaded.tentUnlocked, isTrue);
      // asset paths still resolve after load
      for (final capy in loaded.herd) {
        if (capy.role != null) {
          final data = await rootBundle.load(capy.role!.assetPath);
          expect(data.lengthInBytes, greaterThan(1000));
        }
      }
      for (final id in loaded.ownedDecor) {
        final decor = HomeDecorX.tryParse(id)!;
        final data = await rootBundle.load(decor.assetPath);
        expect(data.lengthInBytes, greaterThan(1000));
      }
    });
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => value;
  @override
  bool nextBool() => false;
}
