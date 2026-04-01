import 'dart:math';

import '../models/game_cell.dart';
import '../models/game_state.dart';
import 'celebrity_service.dart';

class BoardGenerator {
  final CelebrityService _service;
  final Random _random = Random();

  static const _vowels = {'A', 'E', 'I', 'O', 'U'};

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

        // For alliterative cells (same letter on both axes),
        // both slots need the same pair — require it exists.
        final hasA = _service.hasCelebrities(rowLetter, colLetter);
        final hasB = _service.hasCelebrities(colLetter, rowLetter);
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

  /// Select row and column letters. Letters CAN repeat across axes
  /// (enabling alliterative cells). Each axis gets at least one vowel.
  /// Selection is weighted toward letters with more coverage.
  (List<String>, List<String>) _selectLetters(int gridSize) {
    // Build weighted scores for each letter.
    final letterScores = <String, int>{};
    for (int i = 0; i < 26; i++) {
      final letter = String.fromCharCode(65 + i);
      int score = 0;
      for (int j = 0; j < 26; j++) {
        final other = String.fromCharCode(65 + j);
        if (_service.hasCelebrities(letter, other)) score++;
        if (_service.hasCelebrities(other, letter)) score++;
      }
      letterScores[letter] = score;
    }

    // Build candidate pool: top letters by score, with enough variety.
    final rankedLetters = letterScores.keys.toList()
      ..sort((a, b) => letterScores[b]!.compareTo(letterScores[a]!));
    final candidatePool = rankedLetters.take(max(gridSize * 4, 18)).toSet();

    // Ensure vowels are in the pool.
    candidatePool.addAll(_vowels.where((v) => letterScores[v]! > 0));

    List<String> bestRows = [];
    List<String> bestCols = [];
    int bestScore = -1;

    for (int attempt = 0; attempt < 100; attempt++) {
      final rows = _pickWeighted(candidatePool.toList(), gridSize, letterScores);
      final cols = _pickWeighted(candidatePool.toList(), gridSize, letterScores);

      // Require at least one vowel per axis.
      if (!rows.any((l) => _vowels.contains(l))) continue;
      if (!cols.any((l) => _vowels.contains(l))) continue;

      int score = 0;
      for (final r in rows) {
        for (final c in cols) {
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

  /// Pick n unique letters weighted by their scores.
  List<String> _pickWeighted(
      List<String> pool, int n, Map<String, int> scores) {
    final picked = <String>[];
    final remaining = List<String>.from(pool);

    for (int i = 0; i < n && remaining.isNotEmpty; i++) {
      // Build cumulative weights.
      final totalWeight =
          remaining.fold<int>(0, (sum, l) => sum + (scores[l] ?? 1));
      int target = _random.nextInt(totalWeight);

      String selected = remaining.last;
      for (final letter in remaining) {
        target -= scores[letter] ?? 1;
        if (target < 0) {
          selected = letter;
          break;
        }
      }

      picked.add(selected);
      remaining.remove(selected);
    }

    return picked;
  }
}
