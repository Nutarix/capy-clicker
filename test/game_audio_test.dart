import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/audio/game_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameAudio.forceSilent = false;
  });

  tearDown(() {
    GameAudio.forceSilent = false;
  });

  test('disabled audio init is ready and stays muted-safe', () async {
    final audio = GameAudio.disabled();
    await audio.init();
    expect(audio.isReady, isTrue);
    expect(audio.isMuted, isFalse);
    audio.playFlower();
    audio.playMerge();
    await audio.setMuted(true);
    expect(audio.isMuted, isTrue);
    audio.dispose();
  });

  test('mute preference persists across instances (silent path)', () async {
    SharedPreferences.setMockInitialValues({
      GameAudio.mutedPrefsKey: true,
    });
    final audio = GameAudio(silent: true);
    await audio.init();
    expect(audio.isMuted, isTrue);
    await audio.setMuted(false);
    expect(audio.isMuted, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(GameAudio.mutedPrefsKey), isFalse);
    audio.dispose();
  });
}
