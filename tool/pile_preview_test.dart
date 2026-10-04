// Pile preview for Nikita (spec 006, Т8): not part of `flutter test`.
//
// Run from the project root:
//   flutter test --no-pub tool/pile_preview_test.dart --update-goldens
// Writes store/art-pack-traits/preview-piles.png (piles of 2, 3 and 4 with
// mixed looks and levels on the starter meadow, as on a phone) and
// preview-piles-names.png (the same with one pile touched: names shown).
// Real art and the fonts bundled in assets/google_fonts/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/audio/game_audio.dart';
import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/game_screen.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';
import 'package:capy_clicker/theme/cozy_theme.dart';

final Uri _out = Uri.directory(
  Directory.current.path,
).resolve('store/art-pack-traits/');

Future<void> _loadFamily(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family);
  loader.addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Map<String, Object?> _capy(
  String id,
  int level,
  double x,
  double y, {
  String? pile,
  String? role,
  String? name,
}) => {
  'id': id,
  'level': level,
  'x': x,
  'y': y,
  'role': ?role,
  if (name != null) ...{'name': name, 'trait': 'cuddler'},
  'pile': ?pile,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    goldenFileComparator = LocalFileComparator(
      _out.resolve('pile_preview_test.dart'),
    );
    GoogleFonts.config.allowRuntimeFetching = false;
    const dir = 'assets/google_fonts';
    for (final (family, file) in [
      ('Nunito_regular', 'Nunito-Regular.ttf'),
      ('Nunito_500', 'Nunito-Regular.ttf'),
      ('Nunito_600', 'Nunito-SemiBold.ttf'),
      ('Nunito_700', 'Nunito-Bold.ttf'),
      ('Nunito_800', 'Nunito-ExtraBold.ttf'),
      ('Nunito_w700', 'Nunito-Bold.ttf'),
      ('PixelifySans_700', 'PixelifySans-Bold.ttf'),
      ('PixelifySans_regular', 'PixelifySans-Bold.ttf'),
      ('Roboto', 'Nunito-Bold.ttf'),
    ]) {
      await _loadFamily(family, '$dir/$file');
    }
  });

  testWidgets('piles of two, three and four on the meadow', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    GameAudio.forceSilent = true;

    final now = DateTime.utc(2026, 10, 4, 9);
    final herd = [
      // Two: a named Lv.2 and a baby.
      _capy('a1', 2, 0.27, 0.66, pile: 'pA', name: 'button'),
      _capy('a2', 1, 0.27, 0.66, pile: 'pA'),
      // Three: Lv.3 look, a gatherer Lv.2, a baby.
      _capy('b1', 3, 0.68, 0.64, pile: 'pB', name: 'pinecone'),
      _capy('b2', 2, 0.68, 0.64, pile: 'pB', role: 'sobiratel', name: 'bun'),
      _capy('b3', 1, 0.68, 0.64, pile: 'pB'),
      // Four: a nanny Lv.4, a guard Lv.3, Lv.2, a baby.
      _capy('c1', 4, 0.47, 0.82, pile: 'pC', role: 'nanya', name: 'muffin'),
      _capy('c2', 3, 0.47, 0.82, pile: 'pC', role: 'storozh', name: 'pip'),
      _capy('c3', 2, 0.47, 0.82, pile: 'pC', name: 'cloudy'),
      _capy('c4', 1, 0.47, 0.82, pile: 'pC'),
      // Singles for scale.
      _capy('s1', 1, 0.16, 0.86),
      _capy('s2', 2, 0.82, 0.84, name: 'daisy'),
    ];
    final save = {
      'nextId': 100,
      'grass': 24,
      'sunnyGladeAnnounced': 0,
      'savedAtMs': now.millisecondsSinceEpoch,
      'lastDailyClaimYmd': GameController.calendarDayKey(now),
      'activeMeadowId': 'warm_edge',
      'roleSlots': 3,
      'meadows': {
        'warm_edge': {'herdProgress': 0.4, 'herd': herd},
      },
    };
    SharedPreferences.setMockInitialValues({
      BalanceV0.tipsSeenKey: true,
      'capy_clicker_game_state_v1': jsonEncode(save),
    });
    final controller = GameController(
      persistence: GamePersistence(),
      now: () => now,
      autoTick: false,
    );
    final audio = GameAudio(silent: true);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: CozyTheme.build(),
        home: GameScreen(controller: controller, audio: audio),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump(const Duration(milliseconds: 700));
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .removeCurrentSnackBar();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview-piles.png'),
    );

    // Touch the pile of four: everyone's names.
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('c4'))),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview-piles-names.png'),
    );
    await g.up();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    audio.dispose();
    await tester.pump(const Duration(seconds: 1));
    GameAudio.forceSilent = false;
  });
}
