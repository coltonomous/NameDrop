import 'package:flutter_test/flutter_test.dart';
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
}
