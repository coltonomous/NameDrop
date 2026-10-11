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
  late GamePersistenceService persistence;
  late StatsService stats;
  late CellSlot answered;
  late GameState state;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    persistence = GamePersistenceService();
    stats = StatsService();
    wiki = FakeWikimedia()..offline = true;

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
        service: CelebrityService(client: wiki.client),
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
