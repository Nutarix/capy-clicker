import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capy_clicker/app.dart';
import 'package:capy_clicker/features/game/audio/game_audio.dart';
import 'package:capy_clicker/features/game/models/balance.dart';

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
  Future<void> setSource(Source source) async {
    calls.add('setSource');
  }

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

  group('С8 музыка при входе', () {
    test('a second init leaves the playing music alone', () async {
      final bgm = _FakePlayer();
      final audio = GameAudio(bgm: bgm, sfx: _FakePlayer());
      await audio.init();
      expect(bgm.calls, ['setSource', 'resume']);
      await audio.init();
      await audio.init();
      expect(bgm.calls, ['setSource', 'resume']);
      expect(bgm.state, PlayerState.playing);
      audio.dispose();
    });

    testWidgets('«Играть» from the menu: the music goes on', (tester) async {
      SharedPreferences.setMockInitialValues({BalanceV0.tipsSeenKey: true});
      final bgm = _FakePlayer();
      final audio = GameAudio(bgm: bgm, sfx: _FakePlayer());
      await tester.pumpWidget(
        CapyClickerApp(audio: audio, now: () => DateTime.utc(2026, 9, 21, 9)),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(bgm.calls, ['setSource', 'resume']);

      await tester.tap(find.text('Играть'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Лес'), findsOneWidget, reason: 'in the game');
      expect(bgm.calls, ['setSource', 'resume']);
      expect(bgm.state, PlayerState.playing);

      // Leave before the soft daily sheet's timer fires.
      await tester.tap(find.byIcon(Icons.pause_rounded));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpWidget(const SizedBox());
      audio.dispose();
    });
  });
}
