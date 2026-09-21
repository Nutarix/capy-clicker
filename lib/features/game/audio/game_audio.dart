import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Soft cozy BGM + gentle SFX for Grow! Capy!.
///
/// Uses [audioplayers]. On Flutter **web**, browsers block autoplay until a
/// user gesture — call [noteUserGesture] after the first tap/drag so BGM can
/// start. Mute preference is persisted and silences both BGM and SFX.
class GameAudio extends ChangeNotifier {
  GameAudio({
    this.silent = false,
    this._prefs,
    this._bgm,
    this._sfx,
  });

  /// No-op audio for unit / widget tests (no platform channels).
  factory GameAudio.disabled() => GameAudio(silent: true);

  /// When true, never touch platform audio (unit / widget tests).
  final bool silent;

  /// Set in test `setUp` so [CapyClickerApp] / default [GameScreen] stay quiet.
  static bool forceSilent = false;

  static const mutedPrefsKey = 'capy_clicker_audio_muted_v1';
  static const defaultBgmVolume = 0.30;
  static const defaultSfxVolume = 0.55;

  static const _bgmAsset = 'audio/bgm_cozy.wav';
  static const _flowerAsset = 'audio/sfx_flower.wav';
  static const _berryAsset = 'audio/sfx_berry.wav';
  static const _mergeAsset = 'audio/sfx_merge.wav';
  static const _wallowAsset = 'audio/sfx_wallow.wav';
  static const _gladeAsset = 'audio/sfx_glade.wav';

  SharedPreferences? _prefs;
  AudioPlayer? _bgm;
  AudioPlayer? _sfx;

  bool _ready = false;
  bool _muted = false;
  bool _bgmStarted = false;
  bool _userGestureSeen = false;
  bool _available = true;

  bool get isReady => _ready;
  bool get isMuted => _muted;
  bool get isAvailable => _available && !silent;

  /// Load mute preference and prepare players (no autoplay on web).
  Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _muted = _prefs!.getBool(mutedPrefsKey) ?? false;
    } catch (_) {
      // prefs may be unavailable in exotic test embeds
    }
    if (silent || forceSilent) {
      _ready = true;
      notifyListeners();
      return;
    }
    try {
      _bgm ??= AudioPlayer(playerId: 'capy_bgm');
      _sfx ??= AudioPlayer(playerId: 'capy_sfx');
      await _bgm!.setReleaseMode(ReleaseMode.loop);
      await _bgm!.setVolume(_muted ? 0 : defaultBgmVolume);
      await _sfx!.setVolume(_muted ? 0 : defaultSfxVolume);
      // Preload BGM source; play waits for [noteUserGesture] on web.
      await _bgm!.setSource(AssetSource(_bgmAsset));
      if (!kIsWeb && !_muted) {
        await _bgm!.resume();
        _bgmStarted = true;
        _userGestureSeen = true;
      }
      _ready = true;
    } catch (e, st) {
      debugPrint('GameAudio.init failed: $e\n$st');
      _available = false;
      _ready = true;
    }
    notifyListeners();
  }

  /// Call after any player interaction (tap / drag). Required for web BGM.
  Future<void> noteUserGesture() async {
    if (silent || forceSilent || !_available || !_ready) return;
    _userGestureSeen = true;
    if (_muted || _bgmStarted) return;
    await _startBgm();
  }

  Future<void> _startBgm() async {
    if (silent || forceSilent || !_available || _bgm == null || _muted) return;
    try {
      await _bgm!.setVolume(defaultBgmVolume);
      // resume if already setSource; else play
      final state = _bgm!.state;
      if (state == PlayerState.paused || state == PlayerState.stopped) {
        await _bgm!.resume();
      } else if (state == PlayerState.completed) {
        await _bgm!.seek(Duration.zero);
        await _bgm!.resume();
      } else {
        await _bgm!.play(AssetSource(_bgmAsset), volume: defaultBgmVolume);
      }
      _bgmStarted = true;
    } catch (e) {
      // First resume can fail if source not fully ready — try play once.
      try {
        await _bgm!.play(AssetSource(_bgmAsset), volume: defaultBgmVolume);
        _bgmStarted = true;
      } catch (e2) {
        debugPrint('GameAudio BGM start failed: $e2');
      }
    }
  }

  Future<void> setMuted(bool muted) async {
    if (_muted == muted) return;
    _muted = muted;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(mutedPrefsKey, muted);
    } catch (_) {}
    if (silent || forceSilent || !_available) return;
    try {
      if (muted) {
        await _bgm?.setVolume(0);
        await _sfx?.setVolume(0);
        await _bgm?.pause();
      } else {
        await _sfx?.setVolume(defaultSfxVolume);
        await _bgm?.setVolume(defaultBgmVolume);
        if (_userGestureSeen || !kIsWeb) {
          await _startBgm();
        }
      }
    } catch (e) {
      debugPrint('GameAudio.setMuted failed: $e');
    }
  }

  Future<void> toggleMute() => setMuted(!_muted);

  void playFlower() => _playSfx(_flowerAsset);
  void playBerry() => _playSfx(_berryAsset);
  void playMerge() => _playSfx(_mergeAsset);
  void playWallow() => _playSfx(_wallowAsset);
  void playGlade() => _playSfx(_gladeAsset);

  void _playSfx(String asset) {
    if (silent || forceSilent || !_available || !_ready || _muted) return;
    unawaited(_playSfxAsync(asset));
  }

  Future<void> _playSfxAsync(String asset) async {
    try {
      await noteUserGesture();
      final sfx = _sfx;
      if (sfx == null) return;
      await sfx.stop();
      await sfx.play(AssetSource(asset), volume: defaultSfxVolume);
    } catch (e) {
      debugPrint('GameAudio SFX failed ($asset): $e');
    }
  }

  @override
  void dispose() {
    unawaited(_disposePlayers());
    super.dispose();
  }

  Future<void> _disposePlayers() async {
    try {
      await _bgm?.dispose();
      await _sfx?.dispose();
    } catch (_) {}
    _bgm = null;
    _sfx = null;
  }
}
