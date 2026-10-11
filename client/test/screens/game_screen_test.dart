import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namedrop/models/celebrity.dart';
import 'package:namedrop/models/game_cell.dart';
import 'package:namedrop/models/game_state.dart';
import 'package:namedrop/screens/game_screen.dart';
import 'package:namedrop/services/celebrity_service.dart';
import 'package:namedrop/services/game_persistence_service.dart';
import 'package:namedrop/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets("clearing a skipped answer doesn't refund the skip",
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final persistence = GamePersistenceService();
    final stats = StatsService();
    await tester
        .runAsync(() => Future.wait([persistence.init(), stats.init()]));

    final skipped =
        CellSlot(requiredFirstInitial: 'T', requiredLastInitial: 'H')
          ..answer = const Celebrity(
            name: 'Tom Hanks',
            firstInitial: 'T',
            lastInitial: 'H',
            occupation: 'Actor',
            hpi: 80,
          )
          ..wasSkipped = true;
    final state = GameState(
      gridSize: 1,
      rowLetters: ['T'],
      columnLetters: ['H'],
      board: [
        [
          GameCell(
            row: 0,
            col: 0,
            slotA: skipped,
            slotB:
                CellSlot(requiredFirstInitial: 'H', requiredLastInitial: 'T'),
          ),
        ],
      ],
    )..skipsUsed = 1;

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        gameState: state,
        service: CelebrityService(),
        stats: stats,
        persistence: persistence,
      ),
    ));

    await tester.tap(find.text('Tom Hanks'));
    await tester.pumpAndSettle();
    expect(find.textContaining("You won't get the skip back."), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(skipped.isFilled, isFalse);
    expect(state.skipsUsed, 1);
    expect(state.skipsRemaining, 1);
  });
}
