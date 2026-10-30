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

import '../services/fake_wikimedia.dart';

void main() {
  late FakeWikimedia wiki;
  late CelebrityService service;
  late GamePersistenceService persistence;
  late StatsService stats;
  late CellSlot answered;
  late GameState state;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    persistence = GamePersistenceService();
    stats = StatsService();
    wiki = FakeWikimedia()..offline = true;
    service = CelebrityService(client: wiki.client);

    // One answered slot, accepted while offline so it has no link yet.
    answered = CellSlot(requiredFirstInitial: 'T', requiredLastInitial: 'H')
      ..answer = const Celebrity(
        name: 'Tom Hanks',
        firstInitial: 'T',
        lastInitial: 'H',
        occupation: 'Actor',
        hpi: 80,
      );
    state = GameState(
      gridSize: 1,
      rowLetters: ['T'],
      columnLetters: ['H'],
      board: [
        [
          GameCell(
            row: 0,
            col: 0,
            slotA: answered,
            slotB:
                CellSlot(requiredFirstInitial: 'H', requiredLastInitial: 'T'),
          ),
        ],
      ],
    );
  });

  Future<void> showGame(WidgetTester tester) async {
    await tester
        .runAsync(() => Future.wait([persistence.init(), stats.init()]));
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        gameState: state,
        service: service,
        stats: stats,
        persistence: persistence,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets("clearing a skipped answer doesn't refund the skip",
      (tester) async {
    answered.wasSkipped = true;
    state.skipsUsed = 1;
    await showGame(tester);

    await tester.tap(find.text('Tom Hanks'));
    await tester.pumpAndSettle();
    expect(find.textContaining("You won't get the skip back."), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(answered.isFilled, isFalse);
    expect(state.skipsUsed, 1);
    expect(state.skipsRemaining, 1);
  });

  testWidgets('a skip reveals the best-known person who fits', (tester) async {
    await tester.runAsync(service.init);
    answered.answer = null;
    await showGame(tester);

    await tester.tap(find.text('T.H.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip (2 left)'));
    await tester.pumpAndSettle(); // Reveal dialog shows...
    await tester.pump(const Duration(seconds: 2)); // ...and dismisses itself.
    await tester.pumpAndSettle();

    final fits = service.getByInitials('T', 'H').toList()
      ..sort(Celebrity.byFame);
    expect(answered.answer?.name, fits.first.name);
    expect(answered.wasSkipped, isTrue);
  });

  /// Fill the one empty slot, finishing the board.
  Future<void> finishBoard(WidgetTester tester) async {
    wiki
      ..offline = false
      ..addPerson('Henry Thomas', 'American actor (born 1971)', 'Q1');
    await showGame(tester);
    await tester.tap(find.text('H.T.'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Henry Thomas');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
  }

  testWidgets('finishing the board celebrates, then shows results',
      (tester) async {
    state.isDaily = true;
    state.dailyDateKey = '2026-10-25';
    await finishBoard(tester);

    expect(find.text('BOARD\nCOMPLETE!'), findsOneWidget);
    // Recorded before Continue, so leaving now doesn't lose the result.
    expect(stats.totalGames, 1);
    expect(stats.isDailyCompleted('2026-10-25'), isTrue);
    expect(persistence.hasSavedGame, isFalse);

    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(stats.totalGames, 1);
  });

  testWidgets('the finished board can be looked over before leaving',
      (tester) async {
    await finishBoard(tester);
    await tester.pumpAndSettle();

    // From the celebration...
    await tester.tap(find.text('VIEW BOARD'));
    await tester.pumpAndSettle();
    expect(find.text('BOARD\nCOMPLETE!'), findsNothing);
    expect(find.text('Henry Thomas'), findsOneWidget);

    // ...answers can be looked at but not cleared.
    await tester.tap(find.text('Tom Hanks'));
    await tester.pumpAndSettle();
    expect(find.text('Clear'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(answered.answer?.name, 'Tom Hanks');

    // ...then on to the results, and back to the board from there.
    await tester.tap(find.text('SEE RESULTS'));
    await tester.pumpAndSettle();
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    await tester.ensureVisible(find.text('VIEW BOARD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIEW BOARD'));
    await tester.pumpAndSettle();
    expect(find.text('SEE RESULTS'), findsOneWidget);
    expect(find.text('BOARD\nCOMPLETE!'), findsNothing);
    expect(stats.totalGames, 1);
  });

  testWidgets('links offline answers once Wikipedia is back', (tester) async {
    await showGame(tester);
    expect(answered.answer!.wikiUrl, isNull);
    expect(find.byIcon(Icons.open_in_new), findsNothing);

    wiki
      ..offline = false
      ..addPerson('Tom Hanks', 'American actor (born 1956)', 'Q2263');
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();

    const url = 'https://en.wikipedia.org/wiki/Tom_Hanks';
    expect(answered.answer!.wikiUrl, url);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(persistence.load()!.board[0][0].slotA.answer!.wikiUrl, url);
  });

  testWidgets('stops looking once Wikipedia says there is no page',
      (tester) async {
    wiki.offline = false;
    await showGame(tester);
    final requests = wiki.requests.length;
    expect(requests, greaterThan(0));
    expect(answered.answer!.wikiUrl, isNull);

    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(wiki.requests.length, requests);
  });
}
