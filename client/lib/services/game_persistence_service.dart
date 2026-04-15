import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';
import 'daily_service.dart';

class GamePersistenceService {
  static const _key = 'saved_game_state';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get hasSavedGame => savedGameInfo != null;

  /// Returns metadata about the saved game, or null if none exists
  /// (also discards stale daily games from previous days).
  Map<String, dynamic>? get savedGameInfo {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['isDaily'] == true &&
          map['dailyDateKey'] != DailyService.todayDateKey) {
        clear();
        return null;
      }
      return {
        'isDaily': map['isDaily'],
        'puzzleNumber': map['puzzleNumber'],
        'gridSize': map['gridSize'],
      };
    } catch (_) {
      clear();
      return null;
    }
  }

  void save(GameState state) {
    _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  GameState? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['isDaily'] == true &&
          map['dailyDateKey'] != DailyService.todayDateKey) {
        clear();
        return null;
      }
      return GameState.fromJson(map);
    } catch (_) {
      clear();
      return null;
    }
  }

  void clear() {
    _prefs.remove(_key);
  }
}
