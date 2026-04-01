import 'dart:math';

import '../models/game_cell.dart';
import '../models/game_state.dart';
import 'celebrity_service.dart';

class BoardGenerator {
  final CelebrityService _service;
  final Random _random = Random();

  BoardGenerator(this._service);

  GameState generate(int gridSize) {
    final letters = _selectLetters(gridSize);
    final rowLetters = letters.$1;
    final columnLetters = letters.$2;

    int playableCells = 0;
    final board = <List<GameCell>>[];

    for (int r = 0; r < gridSize; r++) {
      final row = <GameCell>[];
      for (int c = 0; c < gridSize; c++) {
        final rowLetter = rowLetters[r];
        final colLetter = columnLetters[c];

        final hasA = _service.hasCelebrities(rowLetter, colLetter);
        final hasB = _service.hasCelebrities(colLetter, rowLetter);
        // Both pairs must have celebrities for the cell to be playable.
        final isFree = !hasA || !hasB;

        if (!isFree) playableCells++;

        row.add(GameCell(
          row: r,
          col: c,
          slotA: CellSlot(
            requiredFirstInitial: rowLetter,
            requiredLastInitial: colLetter,
          ),
          slotB: CellSlot(
            requiredFirstInitial: colLetter,
            requiredLastInitial: rowLetter,
          ),
          isFree: isFree,
        ));
      }
      board.add(row);
    }

    return GameState(
      gridSize: gridSize,
      rowLetters: rowLetters,
      columnLetters: columnLetters,
      board: board,
      totalPlayableCells: playableCells,
    );
  }

  /// Select row and column letters that maximize playable cells.
  (List<String>, List<String>) _selectLetters(int gridSize) {
    // Score each letter by how many initial pairs it participates in.
    final letterScores = <String, int>{};
    for (int i = 0; i < 26; i++) {
      final letter = String.fromCharCode(65 + i); // A-Z
      int score = 0;
      for (int j = 0; j < 26; j++) {
        final other = String.fromCharCode(65 + j);
        if (_service.hasCelebrities(letter, other)) score++;
        if (_service.hasCelebrities(other, letter)) score++;
      }
      letterScores[letter] = score;
    }

    // Sort letters by score descending.
    final rankedLetters = letterScores.keys.toList()
      ..sort((a, b) => letterScores[b]!.compareTo(letterScores[a]!));

    // Take the top candidates (enough headroom for variety).
    final candidatePool = rankedLetters.take(max(gridSize * 4, 16)).toList();

    // Try multiple random selections, pick the best one.
    List<String> bestRows = [];
    List<String> bestCols = [];
    int bestScore = -1;

    for (int attempt = 0; attempt < 50; attempt++) {
      final shuffled = List<String>.from(candidatePool)..shuffle(_random);
      final rows = shuffled.sublist(0, gridSize);
      final cols = shuffled.sublist(gridSize, gridSize * 2);

      int score = 0;
      for (final r in rows) {
        for (final c in cols) {
          // Only count cells where BOTH pairs are covered.
          if (_service.hasCelebrities(r, c) &&
              _service.hasCelebrities(c, r)) {
            score += 2;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestRows = rows;
        bestCols = cols;
      }
    }

    return (bestRows, bestCols);
  }
}
