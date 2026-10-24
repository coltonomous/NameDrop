import 'dart:math';

import '../models/game_cell.dart';
import '../models/game_state.dart';
import 'celebrity_service.dart';

typedef _HasPair = bool Function(String firstInitial, String lastInitial);

class BoardGenerator {
  final CelebrityService _service;

  /// Letters with few well-known people. They come up a little less often
  /// and never cross each other, so there are no cells like Z.Z. or Q.Z.
  final Set<String> hardLetters;

  BoardGenerator(this._service) : hardLetters = findHardLetters(_service);

  /// First daily puzzle (2026-11-01) built with the current letter rules.
  /// Earlier dailies are rebuilt exactly as they were first published, so a
  /// deploy never changes the board people are already playing. The legacy
  /// path can be deleted once this date has passed.
  static const currentRulesFromPuzzle = 670;

  static const _vowels = {'A', 'E', 'I', 'O', 'U'};
  static const _secondAxisCandidates = 10;
  static final _letters = [
    for (var i = 0; i < 26; i++)
      if (i != 23) String.fromCharCode(65 + i), // X is never used.
  ];

  GameState generateDaily(int puzzleNumber) {
    final random = Random(puzzleNumber);
    if (puzzleNumber < currentRulesFromPuzzle) {
      return _build(4, _selectLettersLegacy(4, random), _legacyHasPair);
    }
    return _build(4, _selectLetters(4, random), _service.hasCelebrities);
  }

  GameState generate(int gridSize, {int? seed}) {
    final random = seed != null ? Random(seed) : Random();
    return _build(
        gridSize, _selectLetters(gridSize, random), _service.hasCelebrities);
  }

  GameState _build(
      int gridSize, (List<String>, List<String>) letters, _HasPair hasPair) {
    final (rowLetters, columnLetters) = letters;
    final board = <List<GameCell>>[];

    for (int r = 0; r < gridSize; r++) {
      final row = <GameCell>[];
      for (int c = 0; c < gridSize; c++) {
        final rowLetter = rowLetters[r];
        final colLetter = columnLetters[c];

        // For alliterative cells (same letter on both axes),
        // both slots need the same pair — require it exists.
        final hasA = hasPair(rowLetter, colLetter);
        final hasB = hasPair(colLetter, rowLetter);
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

  /// Letters that start under 30% as many well-known first and last names
  /// as the median letter. Relative, so it doesn't drift with list size.
  static Set<String> findHardLetters(CelebrityService service) {
    final counts = {for (final l in _letters) l: 0};
    for (final c in service.celebrities.where((c) => c.isWellKnown)) {
      counts.update(c.firstInitial, (n) => n + 1, ifAbsent: () => 1);
      counts.update(c.lastInitial, (n) => n + 1, ifAbsent: () => 1);
    }
    final sorted = [for (final l in _letters) counts[l]!]..sort();
    final median = sorted[sorted.length ~/ 2];
    return {
      for (final l in _letters)
        if (counts[l]! < median * 0.3) l,
    };
  }

  /// Letters a row (or column) can be rerolled to: not already on the
  /// board, and not a hard letter if the other axis already has one.
  List<String> rerollOptions(GameState state, {required bool isRow}) {
    final onBoard = {...state.rowLetters, ...state.columnLetters};
    final otherAxis = isRow ? state.columnLetters : state.rowLetters;
    final noHard = otherAxis.any(hardLetters.contains);
    return [
      for (final letter in _letters)
        if (!onBoard.contains(letter) &&
            !(noHard && hardLetters.contains(letter)))
          letter,
    ];
  }

  static bool _hasVowel(List<String> letters) =>
      letters.any((l) => _vowels.contains(l));

  /// Select row and column letters. Letters can repeat across axes
  /// (alliterative cells like B.B.) except hard letters: if one axis has a
  /// hard letter, the other gets none. Each axis has at least one vowel.
  ///
  /// The first axis is drawn uniformly. For the second, the best of a few
  /// draws (fewest free cells) is kept. Hard letters on the first axis are
  /// never penalized for that, so they still turn up regularly, just less
  /// than other letters. Which axis becomes the rows is a coin flip.
  (List<String>, List<String>) _selectLetters(int gridSize, Random random) {
    final hasPair = _service.hasCelebrities;
    final pool = _letterPool(hasPair);
    final first = _pickAxis(pool, gridSize, random);
    final secondPool = first.any(hardLetters.contains)
        ? pool.where((l) => !hardLetters.contains(l)).toList()
        : pool;

    var second = _pickAxis(secondPool, gridSize, random);
    var fewestFree = _freeCells(first, second, hasPair);
    for (var i = 1; i < _secondAxisCandidates && fewestFree > 0; i++) {
      final candidate = _pickAxis(secondPool, gridSize, random);
      final free = _freeCells(first, candidate, hasPair);
      if (free < fewestFree) {
        second = candidate;
        fewestFree = free;
      }
    }

    return random.nextBool() ? (first, second) : (second, first);
  }

  /// Draw [n] distinct letters, redrawing until there's a vowel.
  List<String> _pickAxis(List<String> pool, int n, Random random) {
    var letters = _pickUniform(pool, n, random);
    for (var i = 0; i < 100 && !_hasVowel(letters); i++) {
      letters = _pickUniform(pool, n, random);
    }
    return letters;
  }

  static int _freeCells(
      List<String> rows, List<String> cols, _HasPair hasPair) {
    var free = 0;
    for (final r in rows) {
      for (final c in cols) {
        if (!hasPair(r, c) || !hasPair(c, r)) free++;
      }
    }
    return free;
  }

  /// Letters (except X) that start anyone's first or last name.
  static List<String> _letterPool(_HasPair hasPair) {
    bool covered(String letter) {
      for (var j = 0; j < 26; j++) {
        final other = String.fromCharCode(65 + j);
        if (hasPair(letter, other) || hasPair(other, letter)) return true;
      }
      return false;
    }

    return _letters.where(covered).toList();
  }

  /// The letter selection used before [currentRulesFromPuzzle]: uniform
  /// letters, keeping the best of 100 draws by covered cells.
  (List<String>, List<String>) _selectLettersLegacy(
      int gridSize, Random random) {
    final pool = _letterPool(_legacyHasPair);

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
          if (_legacyHasPair(r, c) && _legacyHasPair(c, r)) {
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

  /// Initials pairs nobody had in the celebrity list that legacy dailies
  /// were published with, so those boards don't change if the list does.
  static const _legacyMissingPairs = {
    'BQ', 'EX', 'FU', 'FY', 'GQ', 'HQ', 'HU', 'IU', 'IX', 'KQ', 'KX', 'LQ', //
    'NX', 'OJ', 'OQ', 'OX', 'QA', 'QC', 'QD', 'QO', 'QQ', 'QU', 'QV', 'QX',
    'QY', 'QZ', 'RX', 'SX', 'TX', 'UO', 'UP', 'UQ', 'UU', 'UW', 'UX', 'UY',
    'UZ', 'VQ', 'VU', 'VX', 'WI', 'WQ', 'WU', 'WX', 'WY', 'XC', 'XD', 'XF',
    'XK', 'XO', 'XP', 'XQ', 'XU', 'XV', 'XX', 'XY', 'XZ', 'YE', 'YJ', 'YQ',
    'YX', 'YZ', 'ZD', 'ZQ', 'ZU',
  };

  static bool _legacyHasPair(String first, String last) =>
      !_legacyMissingPairs.contains('$first$last');

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
