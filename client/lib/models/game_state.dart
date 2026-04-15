import 'game_cell.dart';

enum GamePhase { playing, complete }

class GameState {
  final int gridSize;
  final List<String> rowLetters;
  final List<String> columnLetters;
  final List<List<GameCell>> board;
  int get totalPlayableCells {
    int count = 0;
    for (final row in board) {
      for (final cell in row) {
        if (!cell.isFree) count++;
      }
    }
    return count;
  }
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
    this.maxSkips = 2,
    this.maxRerolls = 1,
    this.phase = GamePhase.playing,
    this.isDaily = false,
    this.puzzleNumber,
    this.dailyDateKey,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

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

  Map<String, dynamic> toJson() => {
        'gridSize': gridSize,
        'rowLetters': rowLetters,
        'columnLetters': columnLetters,
        'board': board
            .map((row) => row.map((cell) => cell.toJson()).toList())
            .toList(),
        'maxSkips': maxSkips,
        'maxRerolls': maxRerolls,
        'skipsUsed': skipsUsed,
        'rerollsUsed': rerollsUsed,
        'isDaily': isDaily,
        'puzzleNumber': puzzleNumber,
        'dailyDateKey': dailyDateKey,
        'elapsedSeconds': elapsed.inSeconds,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final elapsedSeconds = json['elapsedSeconds'] as int;
    final state = GameState(
      gridSize: json['gridSize'] as int,
      rowLetters: (json['rowLetters'] as List).cast<String>(),
      columnLetters: (json['columnLetters'] as List).cast<String>(),
      board: (json['board'] as List)
          .map((row) => (row as List)
              .map((cell) =>
                  GameCell.fromJson(cell as Map<String, dynamic>))
              .toList())
          .toList(),
      maxSkips: json['maxSkips'] as int,
      maxRerolls: json['maxRerolls'] as int,
      isDaily: json['isDaily'] as bool,
      puzzleNumber: json['puzzleNumber'] as int?,
      dailyDateKey: json['dailyDateKey'] as String?,
      startTime: DateTime.now().subtract(Duration(seconds: elapsedSeconds)),
    );
    state.skipsUsed = json['skipsUsed'] as int;
    state.rerollsUsed = json['rerollsUsed'] as int;
    return state;
  }
}
