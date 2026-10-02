import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/app.dart';
import 'package:capy_clicker/features/game/audio/game_audio.dart';
import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/game_screen.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';
import 'package:capy_clicker/features/game/widgets/home_meadow_scene.dart';
import 'package:capy_clicker/features/game/widgets/mud_puddle.dart';
import 'package:capy_clicker/features/game/widgets/quiet_merge_arc.dart';
import 'package:capy_clicker/theme/cozy_theme.dart';

String _today() => GameController.calendarDayKey(DateTime.now());

const _out = '/workspace/capy-clicker/store/playtest-mockup';

final _kill = <GameController, void Function()>{};

void _close(GameController c) => _kill[c]?.call();

Future<void> _shoot(WidgetTester tester, String name) async {
  debugPrint('SHOOT $name');
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));
  debugPrint('SHOT $name');
}

Future<void> _settleImages(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump(const Duration(milliseconds: 50));
}

void _phoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _hideSnack(WidgetTester tester) {
  final ctx = tester.element(find.byType(Scaffold).first);
  ScaffoldMessenger.maybeOf(ctx)?.hideCurrentSnackBar();
}

Future<GameController> _open(
  WidgetTester tester,
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues({
    BalanceV0.tipsSeenKey: true,
    ...prefs,
  });
  final persistence = GamePersistence();
  final audio = GameAudio();
  final controller = GameController(persistence: persistence);
  var dead = false;
  void kill() {
    if (dead) return;
    dead = true;
    audio.dispose();
    controller.dispose();
  }

  _kill[controller] = kill;
  addTearDown(kill);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CozyTheme.build(),
      home: GameScreen(
        controller: controller,
        audio: audio,
        onBackToMenu: () {},
      ),
    ),
  );
  await _settleImages(tester);
  controller.debugShowBerry();
  await tester.pump(const Duration(milliseconds: 50));
  _hideSnack(tester);
  await tester.pump(const Duration(milliseconds: 50));
  return controller;
}

Future<void> _loadFamily(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family);
  loader.addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final out = Directory(_out);
    await out.create(recursive: true);
    goldenFileComparator = _TolerantGolden(
      Uri.parse('${out.path}/playtest_mockup_shots_test.dart'),
    );

    GoogleFonts.config.allowRuntimeFetching = false;
    const nunito = '/tmp/capy-fonts/nunito.ttf';
    const pixel = '/tmp/capy-fonts/pixelify.ttf';
    for (final family in [
      'Nunito_regular',
      'Nunito_500',
      'Nunito_600',
      'Nunito_700',
      'Nunito_800',
      'Nunito_w700',
    ]) {
      await _loadFamily(family, nunito);
    }
    await _loadFamily('PixelifySans_700', pixel);
    await _loadFamily('PixelifySans_regular', pixel);
  });

  setUp(() {
    GameAudio.forceSilent = true;
  });

  tearDown(() {
    GameAudio.forceSilent = false;
  });

  testWidgets('menu matches frame 01', (tester) async {
    _phoneSurface(tester);
    SharedPreferences.setMockInitialValues({BalanceV0.tipsSeenKey: true});
    debugPrint('MENU pump');
    await tester.pumpWidget(const CapyClickerApp());
    debugPrint('MENU pumped');
    await _settleImages(tester);
    debugPrint('MENU settled');

    expect(find.text('Grow! Capy!'), findsOneWidget);
    expect(find.text('Играть'), findsOneWidget);
    expect(find.textContaining('цветы'), findsNothing);
    expect(find.textContaining('Nutarix'), findsNothing);
    expect(find.byType(DecoratedBox), findsWidgets);
    await _shoot(tester, '01-menu');
  });

  testWidgets('early meadow matches frame 02', (tester) async {
    _phoneSurface(tester);
    final ymd = _today();
    // Two same-level bodies close enough for the quiet arc, a third apart.
    const herd =
        '['
        '{"id":"c1","level":1,"x":0.20,"y":0.68},'
        '{"id":"c2","level":1,"x":0.46,"y":0.62},'
        '{"id":"c3","level":2,"x":0.78,"y":0.58}'
        ']';
    final c = await _open(tester, {
      'capy_clicker_game_state_v1':
          '{"herdProgress":0.2,"nextId":4,"lastDailyClaimYmd":"$ymd",'
          '"grass":36,"sunnyGladeAnnounced":0,"herd":$herd}',
    });

    expect(find.text('Позвать'), findsOneWidget);
    expect(find.text('Ускорение'), findsOneWidget);
    expect(find.text('Еда'), findsOneWidget);
    expect(find.text('Лес'), findsOneWidget);
    expect(find.text('сюда!'), findsNothing);
    expect(find.text('нажми!'), findsNothing);
    expect(find.textContaining('стадо'), findsNothing);
    expect(find.textContaining('warm_edge'), findsNothing);

    // Escape/wander may have stepped the loaded pair apart. Park two
    // same-level bodies inside the magnet band, on open grass.
    // Close enough for the dotted arc, far enough that the sheets do not stack.
    c.updatePosition('c1', const Offset(0.20, 0.68));
    c.updatePosition('c2', const Offset(0.46, 0.62));
    c.updatePosition('c3', const Offset(0.78, 0.58));
    await tester.pump(const Duration(milliseconds: 40));

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final puddle = find.byType(MudPuddle);
    expect(puddle, findsOneWidget);
    final puddleDy = tester.getCenter(puddle).dy / size.height;
    expect(
      puddleDy,
      greaterThan(0.55),
      reason: 'puddle should sit on the grass',
    );

    expect(find.byType(QuietMergeArc), findsOneWidget);
    await _shoot(tester, '02-meadow-early');

    // Drag the pair even closer without releasing into a merge, then drop
    // just outside the snap so we can see whether the arc survives a gesture.
    final capys = find.byType(Image);
    // Gesture on the left body (first meadow capy image is not stable).
    final dragTarget = find.byKey(const ValueKey('c1'));
    expect(dragTarget, findsOneWidget);
    final start = tester.getCenter(dragTarget);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(18, 8));
    await tester.pump(const Duration(milliseconds: 50));
    await _shoot(tester, '02-meadow-drag');
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 80));
    await _shoot(tester, '02-meadow-after-drag');
    // Keep the controller alive until the file writes finish.
    expect(c.state.grass, 36);
    expect(capys, findsWidgets);
    _close(c);
  });

  testWidgets('home tab matches frame 06', (tester) async {
    _phoneSurface(tester);
    final ymd = _today();
    const herd =
        '[{"id":"c1","level":3,"x":0.40,"y":0.70},{"id":"c2","level":2,"x":0.62,"y":0.74}]';
    final c = await _open(tester, {
      'capy_clicker_game_state_v1':
          '{"herdProgress":0.4,"nextId":3,"lastDailyClaimYmd":"$ymd",'
          '"grass":80,"uyut":2,"sunnyGladeAnnounced":1,"herd":$herd}',
    });
    expect(c.state.sunnyGladeAnnounced, greaterThanOrEqualTo(1));

    await tester.tap(find.text('Еда'));
    await tester.pump(const Duration(milliseconds: 50));
    await _settleImages(tester);
    expect(find.text('Уют семьи'), findsOneWidget);
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    tabs.controller!.index = 2;
    await tester.pump();
    await _settleImages(tester);
    debugPrint('HOME TAB INDEX ${tabs.controller!.index}');
    final sceneFinder = find.byWidgetPredicate(
      (w) => w is HomeMeadowScene && w.offerIds.isNotEmpty,
    );
    final scene = tester.getRect(sceneFinder);
    final fon = tester.getRect(find.text('Фонарик'));
    debugPrint(
      'SCENE $scene FONARIK $fon screen ${tester.view.physicalSize / tester.view.devicePixelRatio}',
    );
    expect(
      scene.contains(fon.center),
      isTrue,
      reason: 'buy sits on the meadow',
    );

    expect(
      find.text('По одному. Каждая вещь — на своём месте.'),
      findsOneWidget,
    );
    expect(find.text('Фонарик'), findsOneWidget);
    expect(find.text('Покормить семью'), findsNothing);
    expect(find.textContaining('Травка'), findsNothing);
    expect(find.text('Скоро — после Ягодной поляны.'), findsNothing);
    await _shoot(tester, '06-home-before-buy');

    final grassBefore = c.state.grass;
    await tester.tap(find.text('Фонарик'));
    await tester.pump(const Duration(milliseconds: 80));
    await _settleImages(tester);
    expect(c.state.grass, grassBefore - 12);
    expect(c.state.placedDecor, contains('fonarik'));
    expect(find.text('Коврик'), findsOneWidget);
    await _shoot(tester, '06-home-after-fonarik');
    _close(c);
  });

  testWidgets('rocket path matches frames 10 13 14 11', (tester) async {
    _phoneSurface(tester);
    final ymd = _today();
    const herd =
        '['
        '{"id":"c1","level":1,"x":0.30,"y":0.72},'
        '{"id":"c2","level":4,"x":0.55,"y":0.68},'
        '{"id":"c3","level":2,"x":0.72,"y":0.76}'
        ']';
    final c = await _open(tester, {
      'capy_clicker_game_state_v1':
          '{"herdProgress":0.2,"nextId":4,"lastDailyClaimYmd":"$ymd",'
          '"grass":186,"uyut":4,"sunnyGladeAnnounced":3,'
          '"mistyBiomeUnlocked":true,"visitedMist":true,"herd":$herd}',
    });
    expect(c.rocketUnlocked, isTrue);
    expect(c.state.grass, 186);

    await tester.tap(find.text('Лес'));
    await tester.pump(const Duration(milliseconds: 80));
    await _settleImages(tester);
    expect(find.text('Семья провожает'), findsOneWidget);
    await _shoot(tester, '08-forest-map');

    await tester.tap(find.text('Семья провожает'));
    await tester.pump(const Duration(milliseconds: 80));
    await _settleImages(tester);
    expect(find.text('Отправить одного'), findsOneWidget);
    expect(find.text('Ещё побыть'), findsOneWidget);
    await _shoot(tester, '10-rocket-farewell');

    await tester.tap(find.text('Отправить одного'));
    await tester.pump(const Duration(milliseconds: 80));
    await _settleImages(tester);
    expect(find.text('Один в пути'), findsOneWidget);
    expect(find.text('К новой земле'), findsOneWidget);
    await _shoot(tester, '13-rocket-flight');

    await tester.tap(find.text('К новой земле'));
    await tester.pump(const Duration(milliseconds: 80));
    await _settleImages(tester);
    expect(c.state.grass, 186);
    expect(c.state.uyut, 4);
    expect(find.textContaining('Новая земля'), findsWidgets);
    expect(find.textContaining('стадо'), findsNothing);
    await _shoot(tester, '14-arrival');

    await tester.tap(find.text('Лес'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Земли семьи'), findsOneWidget);
    await tester.tap(find.text('Земли семьи'));
    await tester.pump(const Duration(milliseconds: 80));
    await _settleImages(tester);
    expect(find.text('Прежняя земля'), findsOneWidget);
    expect(find.text('Новая земля'), findsWidgets);
    expect(find.textContaining('планет'), findsNothing);
    expect(find.textContaining('стадо'), findsNothing);
    expect(c.state.grass, 186);
    await _shoot(tester, '11-family-lands');
    _close(c);
  });
}

/// Idle bob and font fallback move a few percent of pixels between runs.
class _TolerantGolden extends LocalFileComparator {
  _TolerantGolden(super.testFile);

  static const double tolerance = 0.10;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
