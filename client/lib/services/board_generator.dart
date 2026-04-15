import 'dart:math';

import '../models/game_cell.dart';
import '../models/game_state.dart';
import 'celebrity_service.dart';

class BoardGenerator {
  final CelebrityService _service;

  BoardGenerator(this._service);

  GameState generate(int gridSize, {int? seed}) {
    final random = seed != null ? Random(seed) : Random();
    final letters = _selectLetters(gridSize, random);
    final rowLetters = letters.$1;
    final columnLetters = letters.$2;

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
    );
  }

  static const _vowels = {'A', 'E', 'I', 'O', 'U'};

  static bool _hasVowel(List<String> letters) =>
      letters.any((l) => _vowels.contains(l));

  /// Select row and column letters. Letters CAN repeat across axes
  /// (enabling alliterative cells). Each axis gets at least one vowel.
  /// Letters are chosen uniformly at random (X is excluded).
  (List<String>, List<String>) _selectLetters(int gridSize, Random random) {
    // Build pool: all letters except X, filtered to those with coverage.
    final pool = <String>[];
    for (int i = 0; i < 26; i++) {
      final letter = String.fromCharCode(65 + i);
      if (letter == 'X') continue;
      for (int j = 0; j < 26; j++) {
        final other = String.fromCharCode(65 + j);
        if (_service.hasCelebrities(letter, other) ||
            _service.hasCelebrities(other, letter)) {
          pool.add(letter);
          break;
        }
      }
    }

    List<String> bestRows = [];
    List<String> bestCols = [];
    int bestScore = -1;

    for (int attempt = 0; attempt < 100; attempt++) {
      final rows = _pickUniform(pool, gridSize, random);
      final cols = _pickUniform(pool, gridSize, random);

      // Reject candidates without at least one vowel per axis.
      if (!_hasVowel(rows) || !_hasVowel(cols)) continue;

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

  /// Pick n unique letters uniformly at random from the pool.
  List<String> _pickUniform(List<String> pool, int n, Random random) {
    final picked = <String>[];
    final remaining = List<String>.from(pool);

    for (int i = 0; i < n && remaining.isNotEmpty; i++) {
      final index = random.nextInt(remaining.length);
      picked.add(remaining[index]);
      remaining.removeAt(index);
    }

    return picked;
  }
}
