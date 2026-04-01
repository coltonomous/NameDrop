import 'package:flutter_test/flutter_test.dart';

import 'package:namedrop/models/celebrity.dart';
import 'package:namedrop/models/game_cell.dart';

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
}
