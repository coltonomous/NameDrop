class DailyService {
  static final _epoch = DateTime.utc(2025, 1, 1);

  static int get todayPuzzleNumber {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.difference(_epoch).inDays + 1;
  }

  static int get todaySeed => todayPuzzleNumber;

  static String get todayDateKey {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
