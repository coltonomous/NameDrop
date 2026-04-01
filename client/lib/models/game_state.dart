import 'game_cell.dart';

enum GamePhase { playing, complete }

class GameState {
  final int gridSize;
  final List<String> rowLetters;
  final List<String> columnLetters;
  final List<List<GameCell>> board;
  int totalPlayableCells;
  final int maxSkips;
  final int maxRerolls;
  int skipsUsed = 0;
  int rerollsUsed = 0;
  GamePhase phase;
  final DateTime startTime;

  bool isDaily;
  int? puzzleNumber;
  String? dailyDateKey;
  Duration? finalElapsed;

  GameState({
    required this.gridSize,
    required this.rowLetters,
    required this.columnLetters,
    required this.board,
    required this.totalPlayableCells,
    this.maxSkips = 2,
    this.maxRerolls = 1,
    this.phase = GamePhase.playing,
    this.isDaily = false,
    this.puzzleNumber,
    this.dailyDateKey,
  }) : startTime = DateTime.now();

  int get skipsRemaining => maxSkips - skipsUsed;
  bool get canSkip => skipsRemaining > 0;
  int get rerollsRemaining => maxRerolls - rerollsUsed;
  bool get canReroll => rerollsRemaining > 0;

  int get completedSlots {
    int count = 0;
    for (final row in board) {
      for (final cell in row) {
        if (cell.isFree) continue;
        if (cell.slotA.isFilled) count++;
        if (cell.slotB.isFilled) count++;
      }
    }
    return count;
  }

  int get totalPlayableSlots => totalPlayableCells * 2;

  bool get isComplete => completedSlots >= totalPlayableSlots;

  Duration get elapsed => finalElapsed ?? DateTime.now().difference(startTime);
}
