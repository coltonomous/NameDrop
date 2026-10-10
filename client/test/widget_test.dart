import 'package:flutter_test/flutter_test.dart';

import 'package:namedrop/models/celebrity.dart';
import 'package:namedrop/models/game_cell.dart';
import 'package:namedrop/models/game_state.dart';

void main() {
  test('Celebrity parses from JSON', () {
    final json = {
      'name': 'James Joyce',
      'firstInitial': 'J',
      'lastInitial': 'J',
      'occupation': 'Writer',
      'birthYear': 1882,
      'hpi': 72.5,
    };
    final celebrity = Celebrity.fromJson(json);
    expect(celebrity.name, 'James Joyce');
    expect(celebrity.pairKey, 'JJ');
  });

  test('GameCell status transitions', () {
    final cell = GameCell(
      row: 0,
      col: 0,
      slotA: CellSlot(requiredFirstInitial: 'J', requiredLastInitial: 'K'),
      slotB: CellSlot(requiredFirstInitial: 'K', requiredLastInitial: 'J'),
    );
    expect(cell.status, CellStatus.empty);

    cell.slotA.answer = const Celebrity(
      name: 'John Kennedy',
      firstInitial: 'J',
      lastInitial: 'K',
      occupation: 'Politician',
      birthYear: 1917,
      hpi: 80.0,
    );
    expect(cell.status, CellStatus.partial);

    cell.slotB.answer = const Celebrity(
      name: 'Keanu Johansson',
      firstInitial: 'K',
      lastInitial: 'J',
      occupation: 'Actor',
      birthYear: 1964,
      hpi: 50.0,
    );
    expect(cell.status, CellStatus.complete);
  });

  test('Free cell is always free', () {
    final cell = GameCell(
      row: 0,
      col: 0,
      slotA: CellSlot(requiredFirstInitial: 'X', requiredLastInitial: 'Q'),
      slotB: CellSlot(requiredFirstInitial: 'Q', requiredLastInitial: 'X'),
      isFree: true,
    );
    expect(cell.status, CellStatus.free);
    expect(cell.nextUnfilledSlot, isNull);
  });

  group('autocorrect penalty', () {
    GameState makeState() => GameState(
          gridSize: 1,
          rowLetters: ['J'],
          columnLetters: ['L'],
          board: [
            [
              GameCell(
                row: 0,
                col: 0,
                slotA: CellSlot(
                    requiredFirstInitial: 'J', requiredLastInitial: 'L'),
                slotB: CellSlot(
                    requiredFirstInitial: 'L', requiredLastInitial: 'J'),
              ),
            ],
          ],
        );

    test('adds time per autocorrect to the total', () {
      final state = makeState()
        ..finalElapsed = const Duration(minutes: 2)
        ..correctionsUsed = 2;
      expect(state.penalty, const Duration(seconds: 20));
      expect(state.totalTime, const Duration(minutes: 2, seconds: 20));
    });

    test('survives a save and restore', () {
      final state = makeState()..correctionsUsed = 1;
      state.board[0][0].slotA.wasCorrected = true;

      final restored = GameState.fromJson(state.toJson());
      expect(restored.correctionsUsed, 1);
      expect(restored.board[0][0].slotA.wasCorrected, isTrue);
      expect(restored.board[0][0].slotB.wasCorrected, isFalse);
    });

    test('loads games saved before autocorrect existed', () {
      final json = makeState().toJson()..remove('correctionsUsed');
      final cell = (json['board'] as List)[0][0] as Map<String, dynamic>;
      (cell['slotA'] as Map<String, dynamic>).remove('wasCorrected');

      final restored = GameState.fromJson(json);
      expect(restored.correctionsUsed, 0);
      expect(restored.board[0][0].slotA.wasCorrected, isFalse);
    });
  });
}
