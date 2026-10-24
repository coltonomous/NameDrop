import 'package:flutter_test/flutter_test.dart';
import 'package:namedrop/models/game_state.dart';
import 'package:namedrop/services/board_generator.dart';
import 'package:namedrop/services/celebrity_service.dart';

void main() {
  late CelebrityService service;
  late BoardGenerator generator;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    service = CelebrityService();
    await service.init();
    generator = BoardGenerator(service);
  });

  group('seeded generation', () {
    test('same seed produces identical board', () {
      final board1 = generator.generate(4, seed: 42);
      final board2 = generator.generate(4, seed: 42);

      expect(board1.rowLetters, equals(board2.rowLetters));
      expect(board1.columnLetters, equals(board2.columnLetters));
      expect(board1.totalPlayableCells, equals(board2.totalPlayableCells));

      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
          expect(board1.board[r][c].isFree, equals(board2.board[r][c].isFree));
          expect(
            board1.board[r][c].slotA.requiredFirstInitial,
            equals(board2.board[r][c].slotA.requiredFirstInitial),
          );
          expect(
            board1.board[r][c].slotA.requiredLastInitial,
            equals(board2.board[r][c].slotA.requiredLastInitial),
          );
        }
      }
    });

    test('different seeds produce different boards', () {
      final board1 = generator.generate(4, seed: 1);
      final board2 = generator.generate(4, seed: 2);

      // At least one axis should differ.
      final different = board1.rowLetters.join() != board2.rowLetters.join() ||
          board1.columnLetters.join() != board2.columnLetters.join();
      expect(different, true);
    });
  });

  group('board dimensions', () {
    for (final size in [3, 4, 5]) {
      test('generates correct ${size}x$size grid', () {
        final board = generator.generate(size, seed: 99);

        expect(board.gridSize, size);
        expect(board.rowLetters.length, size);
        expect(board.columnLetters.length, size);
        expect(board.board.length, size);
        for (final row in board.board) {
          expect(row.length, size);
        }
      });
    }
  });

  group('board properties', () {
    test('row and column letters are single uppercase chars', () {
      final board = generator.generate(4, seed: 50);

      for (final letter in [...board.rowLetters, ...board.columnLetters]) {
        expect(letter.length, 1);
        expect(letter, matches(RegExp(r'^[A-Z]$')));
      }
    });

    test('free cells lack celebrity pairs in at least one direction', () {
      final board = generator.generate(4, seed: 100);

      for (final row in board.board) {
        for (final cell in row) {
          if (cell.isFree) {
            final hasA = service.hasCelebrities(
              cell.slotA.requiredFirstInitial,
              cell.slotA.requiredLastInitial,
            );
            final hasB = service.hasCelebrities(
              cell.slotB.requiredFirstInitial,
              cell.slotB.requiredLastInitial,
            );
            expect(hasA && hasB, false,
                reason:
                    'Free cell at (${cell.row},${cell.col}) has both directions covered');
          }
        }
      }
    });

    test('playable cell count matches non-free cells', () {
      final board = generator.generate(4, seed: 77);

      int count = 0;
      for (final row in board.board) {
        for (final cell in row) {
          if (!cell.isFree) count++;
        }
      }
      expect(board.totalPlayableCells, count);
    });

    test('slot initials match row and column letters', () {
      final board = generator.generate(3, seed: 33);

      for (int r = 0; r < board.gridSize; r++) {
        for (int c = 0; c < board.gridSize; c++) {
          final cell = board.board[r][c];
          expect(cell.slotA.requiredFirstInitial, board.rowLetters[r]);
          expect(cell.slotA.requiredLastInitial, board.columnLetters[c]);
          expect(cell.slotB.requiredFirstInitial, board.columnLetters[c]);
          expect(cell.slotB.requiredLastInitial, board.rowLetters[r]);
        }
      }
    });
  });

  group('dailies', () {
    test('puzzles before the cutover keep their published boards', () {
      // Captured from the generator these puzzles were published with.
      const published = {
        655: 'BESG/DJET',
        656: 'SICB/ZRHE',
        657: 'ATLC/AYRW',
        658: 'GSON/HAGD',
        659: 'RABJ/PJCE',
        660: 'WIDV/FMAE',
        661: 'JGBI/NIKS',
        662: 'KIAY/YKOH',
        663: 'RDGI/YHDI',
        664: 'RSHO/EAPB',
        665: 'ABMT/BGEM',
        666: 'EFWS/EVTB',
        667: 'ASIO/SYEZ',
        668: 'ZRBE/GNCA',
        669: 'INHJ/MEKI',
      };
      for (final MapEntry(key: puzzle, value: letters) in published.entries) {
        final board = generator.generateDaily(puzzle);
        expect(
            '${board.rowLetters.join()}/${board.columnLetters.join()}', letters,
            reason: 'puzzle #$puzzle');
        expect(board.totalPlayableCells, 16, reason: 'puzzle #$puzzle');
      }
    });

    test('puzzles from the cutover use the current rules', () {
      for (var puzzle = BoardGenerator.currentRulesFromPuzzle;
          puzzle < BoardGenerator.currentRulesFromPuzzle + 200;
          puzzle++) {
        final board = generator.generateDaily(puzzle);
        expect(_hardOnBothAxes(board, generator.hardLetters), isFalse,
            reason: 'puzzle #$puzzle');
        final again = generator.generateDaily(puzzle);
        expect(again.rowLetters, board.rowLetters);
        expect(again.columnLetters, board.columnLetters);
      }
    });
  });

  group('hard letters', () {
    test('are the letters with few well-known people', () {
      expect(generator.hardLetters, {'Q', 'U', 'Y', 'Z'});
    });

    test('never appear on both axes', () {
      for (final size in [3, 4, 5]) {
        for (var seed = 0; seed < 500; seed++) {
          final board = generator.generate(size, seed: seed);
          expect(_hardOnBothAxes(board, generator.hardLetters), isFalse,
              reason: '${size}x$size seed $seed');
        }
      }
    });

    test('still come up, just less often than similar letters', () {
      const boards = 3000;
      final seen = <String, int>{};
      for (var seed = 0; seed < boards; seed++) {
        final board = generator.generate(4, seed: seed);
        for (final l in {...board.rowLetters, ...board.columnLetters}) {
          seen[l] = (seen[l] ?? 0) + 1;
        }
      }
      const vowels = {'A', 'E', 'I', 'O', 'U'};
      double average(bool vowel) {
        final peers = seen.keys.where((l) =>
            vowels.contains(l) == vowel && !generator.hardLetters.contains(l));
        return peers.map((l) => seen[l]!).reduce((a, b) => a + b) /
            peers.length;
      }

      for (final letter in generator.hardLetters) {
        final share = (seen[letter] ?? 0) / average(vowels.contains(letter));
        expect(share, inInclusiveRange(0.3, 0.9), reason: letter);
      }
    });

    test('every axis has a vowel', () {
      for (var seed = 0; seed < 500; seed++) {
        final board = generator.generate(4, seed: seed);
        for (final axis in [board.rowLetters, board.columnLetters]) {
          expect(axis.any(const {'A', 'E', 'I', 'O', 'U'}.contains), isTrue,
              reason: 'seed $seed');
        }
      }
    });
  });

  group('rerollOptions', () {
    test('skips letters already on the board, and X', () {
      final board = generator.generate(4, seed: 5);
      final options = generator.rerollOptions(board, isRow: true);
      expect(options, isNot(contains('X')));
      for (final l in [...board.rowLetters, ...board.columnLetters]) {
        expect(options, isNot(contains(l)));
      }
    });

    test('leaves out hard letters only if the other axis has one', () {
      final board = generator.generate(4, seed: 1)
        ..rowLetters.setAll(0, ['A', 'B', 'C', 'D'])
        ..columnLetters.setAll(0, ['E', 'F', 'G', 'Z']);
      expect(generator.rerollOptions(board, isRow: true),
          isNot(anyOf(contains('Q'), contains('U'), contains('Y'))));
      expect(generator.rerollOptions(board, isRow: false),
          containsAll(['Q', 'U', 'Y']));
    });
  });
}

bool _hardOnBothAxes(GameState board, Set<String> hard) =>
    board.rowLetters.any(hard.contains) &&
    board.columnLetters.any(hard.contains);
