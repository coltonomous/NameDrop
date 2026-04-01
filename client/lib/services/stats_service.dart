import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  late SharedPreferences _prefs;

  static const _totalGamesKey = 'stats_total_games';
  static const _dailyGamesKey = 'stats_daily_games';
  static const _currentStreakKey = 'stats_current_streak';
  static const _maxStreakKey = 'stats_max_streak';
  static const _completedDailyDatesKey = 'stats_completed_daily_dates';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int get totalGames => _prefs.getInt(_totalGamesKey) ?? 0;
  int get dailyGames => _prefs.getInt(_dailyGamesKey) ?? 0;
  int get currentStreak => _prefs.getInt(_currentStreakKey) ?? 0;
  int get maxStreak => _prefs.getInt(_maxStreakKey) ?? 0;

  Duration? bestTime(int gridSize) {
    final seconds = _prefs.getInt('stats_best_time_$gridSize');
    return seconds != null ? Duration(seconds: seconds) : null;
  }

  Set<String> get _completedDailyDates =>
      (_prefs.getStringList(_completedDailyDatesKey) ?? []).toSet();

  bool isDailyCompleted(String dateKey) =>
      _completedDailyDates.contains(dateKey);

  Future<void> recordGame({
    required int gridSize,
    required Duration elapsed,
    required bool isDaily,
    String? dailyDateKey,
  }) async {
    await _prefs.setInt(_totalGamesKey, totalGames + 1);

    // Best time per grid size.
    final currentBest = bestTime(gridSize);
    if (currentBest == null || elapsed < currentBest) {
      await _prefs.setInt('stats_best_time_$gridSize', elapsed.inSeconds);
    }

    // Daily-specific tracking.
    if (isDaily && dailyDateKey != null) {
      await _prefs.setInt(_dailyGamesKey, dailyGames + 1);
      final dates = _completedDailyDates..add(dailyDateKey);
      await _prefs.setStringList(_completedDailyDatesKey, dates.toList());
      await _recalculateStreak(dates);
    }
  }

  Future<void> _recalculateStreak(Set<String> dates) async {
    int streak = 0;
    var day = DateTime.now().toUtc();
    while (dates.contains(_dateToKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    await _prefs.setInt(_currentStreakKey, streak);
    if (streak > maxStreak) {
      await _prefs.setInt(_maxStreakKey, streak);
    }
  }

  static String _dateToKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
