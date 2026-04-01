import 'game_cell.dart';

enum GamePhase { playing, complete }

class GameState {
  final int gridSize;
  final List<String> rowLetters;
  final List<String> columnLetters;
  final List<List<GameCell>> board;
  int totalPlayableCells;
  final int maxSkips;
  int skipsUsed = 0;
  bool rerollUsed = false;
  GamePhase phase;
  final DateTime startTime;

  GameState({
    required this.gridSize,
    required this.rowLetters,
    required this.columnLetters,
    required this.board,
    required this.totalPlayableCells,
    this.maxSkips = 2,
    this.phase = GamePhase.playing,
  }) : startTime = DateTime.now();

  int get skipsRemaining => maxSkips - skipsUsed;
  bool get canSkip => skipsRemaining > 0;

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

  Duration get elapsed => DateTime.now().difference(startTime);
}
