import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/features/game/audio/game_audio.dart';

/// Records what the game asks of a player; no platform channels.
class _FakePlayer extends Fake implements AudioPlayer {
  final calls = <String>[];
  PlayerState _state = PlayerState.stopped;

  @override
  PlayerState get state => _state;

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSource(Source source) async {}

  @override
  Future<void> resume() async {
    calls.add('resume');
    _state = PlayerState.playing;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _state = PlayerState.paused;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _state = PlayerState.stopped;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    calls.add('play');
    _state = PlayerState.playing;
  }

  @override
  Future<void> dispose() async {}
}

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
    SharedPreferences.setMockInitialValues({GameAudio.mutedPrefsKey: true});
    final audio = GameAudio(silent: true);
    await audio.init();
    expect(audio.isMuted, isTrue);
    await audio.setMuted(false);
    expect(audio.isMuted, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(GameAudio.mutedPrefsKey), isFalse);
    audio.dispose();
  });

  group('background (С3, Т4)', () {
    late _FakePlayer bgm;
    late _FakePlayer sfx;

    Future<GameAudio> ready() async {
      bgm = _FakePlayer();
      sfx = _FakePlayer();
      final audio = GameAudio(bgm: bgm, sfx: sfx);
      await audio.init();
      return audio;
    }

    test('hidden: music paused, no effects; shown: music goes on', () async {
      final audio = await ready();
      expect(bgm.state, PlayerState.playing);

      await audio.setInBackground(true);
      expect(audio.isInBackground, isTrue);
      expect(bgm.state, PlayerState.paused);
      sfx.calls.clear();
      audio.playFlower();
      audio.playMerge();
      await audio.noteUserGesture();
      await pumpEventQueue();
      expect(sfx.calls, isNot(contains('play')));
      expect(bgm.state, PlayerState.paused);

      await audio.setInBackground(false);
      expect(bgm.state, PlayerState.playing);
      audio.playFlower();
      await pumpEventQueue();
      expect(sfx.calls, contains('play'));
      audio.dispose();
    });

    test('muted before hiding stays silent after return', () async {
      SharedPreferences.setMockInitialValues({GameAudio.mutedPrefsKey: true});
      final audio = await ready();
      expect(bgm.state, isNot(PlayerState.playing));

      await audio.setInBackground(true);
      await audio.setInBackground(false);
      audio.playFlower();
      await pumpEventQueue();
      expect(bgm.state, isNot(PlayerState.playing));
      expect(sfx.calls, isNot(contains('play')));
      audio.dispose();
    });

    test('unmuted while hidden: music starts only on return', () async {
      SharedPreferences.setMockInitialValues({GameAudio.mutedPrefsKey: true});
      final audio = await ready();
      await audio.setInBackground(true);
      await audio.setMuted(false);
      expect(bgm.state, isNot(PlayerState.playing));

      await audio.setInBackground(false);
      expect(bgm.state, PlayerState.playing);
      audio.dispose();
    });
  });
}
