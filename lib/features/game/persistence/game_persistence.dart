import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';

/// Loads / saves [GameState] via shared_preferences JSON blob.
///
/// Main save keeps the v1 key and format. Next to it: the previous good save
/// (raised when the main one cannot be read) and damaged blobs set aside for
/// a look later — never wiped silently, not even by a new game.
///
/// Operations run one at a time, in call order: a save fired on the way to
/// the menu lands before the «Заново» clear that follows it. Share one
/// instance between menu and game for that.
class GamePersistence {
  GamePersistence({this._prefs});

  static const _key = 'capy_clicker_game_state_v1';
  static const _prevKey = '${_key}_prev';
  static const _brokenKey = '${_key}_broken';

  /// Set-aside slots. Later damage past this is only logged.
  static const _maxBroken = 4;

  SharedPreferences? _prefs;

  /// Last save known to read back: what [load] returned or [save] wrote.
  String? _lastGoodRaw;

  /// Operation in flight; null when idle. Not a chained future on purpose:
  /// a finished chain would outlive the zone it was made in (fake time).
  Future<void>? _busy;

  Future<T> _serial<T>(Future<T> Function() op) async {
    while (_busy != null) {
      await _busy;
    }
    final done = Completer<void>();
    _busy = done.future;
    try {
      return await op();
    } finally {
      _busy = null;
      done.complete();
    }
  }

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// True when any meadow has a non-empty herd (menu «Продолжить»).
  Future<bool> hasSave() async {
    final state = await load();
    return state != null && state.totalHerdAcrossMeadows > 0;
  }

  Future<GameState?> load() => _serial(_load);

  Future<GameState?> _load() async {
    final prefs = await _ensurePrefs();
    final raw = _readRaw(prefs, _key);
    // No main save: new game. The copy is not raised — «Заново» stays new.
    if (raw == null || raw.isEmpty) return null;
    final state = _decode(raw);
    if (state != null) {
      _lastGoodRaw = raw;
      return state;
    }
    await _setAside(prefs, _key, raw);
    final prev = _readRaw(prefs, _prevKey);
    if (prev == null || prev.isEmpty) return null;
    final fallback = _decode(prev);
    if (fallback != null) {
      _lastGoodRaw = prev;
      return fallback;
    }
    await _setAside(prefs, _prevKey, prev);
    return null;
  }

  Future<void> save(GameState state) => _serial(() => _save(state));

  Future<void> _save(GameState state) async {
    final prefs = await _ensurePrefs();
    final raw = jsonEncode(state.toJson());
    var prev = _lastGoodRaw;
    if (prev == null) {
      final current = _readRaw(prefs, _key);
      if (current != null && _decode(current) != null) prev = current;
    }
    // Copy first: a write cut halfway leaves both keys readable.
    if (prev != null && prev != raw) {
      await prefs.setString(_prevKey, prev);
    }
    await prefs.setString(_key, raw);
    if (_decode(raw) != null) _lastGoodRaw = raw;
  }

  /// «Заново»: drop main and copy. Set-aside blobs stay.
  Future<void> clear() => _serial(_clear);

  Future<void> _clear() async {
    final prefs = await _ensurePrefs();
    _lastGoodRaw = null;
    // Copy first: a cut here must not leave an old copy without a main.
    await prefs.remove(_prevKey);
    await prefs.remove(_key);
  }

  static String? _readRaw(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    return value?.toString();
  }

  static GameState? _decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return GameState.fromJson(map);
    } catch (_) {
      // Any parse / shape error: the blob is unreadable for this build.
      return null;
    }
  }

  Future<void> _setAside(
    SharedPreferences prefs,
    String fromKey,
    String raw,
  ) async {
    final list = <Object?>[];
    final existing = prefs.getString(_brokenKey);
    if (existing != null) {
      try {
        list.addAll(jsonDecode(existing) as List);
      } catch (_) {
        // Keep the unreadable list itself as the first entry.
        list.add({'from': _brokenKey, 'raw': existing});
      }
    }
    for (final e in list) {
      if (e is Map && e['raw'] == raw) return;
    }
    if (list.length >= _maxBroken) {
      debugPrint('GamePersistence: set-aside slots full, $fromKey not kept');
      return;
    }
    list.add({'from': fromKey, 'raw': raw});
    await prefs.setString(_brokenKey, jsonEncode(list));
  }
}
