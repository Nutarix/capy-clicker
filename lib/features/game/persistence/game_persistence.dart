import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';

/// Loads / saves [GameState] via shared_preferences JSON blob.
class GamePersistence {
  GamePersistence({this._prefs});

  static const _key = 'capy_clicker_game_state_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<GameState?> load() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return GameState.fromJson(map);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(GameState state) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> clear() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_key);
  }
}
