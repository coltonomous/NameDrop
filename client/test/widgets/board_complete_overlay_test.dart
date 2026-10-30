import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namedrop/widgets/board_complete_overlay.dart';
import 'package:namedrop/widgets/fireworks.dart';

class _Taps {
  int continued = 0;
  int viewed = 0;
}

void main() {
  Future<_Taps> showOverlay(WidgetTester tester,
      {bool reduceMotion = false}) async {
    final taps = _Taps();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: BoardCompleteOverlay(
            onContinue: () => taps.continued++,
            onViewBoard: () => taps.viewed++,
          ),
        ),
      ),
    ));
    return taps;
  }

  testWidgets('celebrates with fireworks, then offers Continue',
      (tester) async {
    final taps = await showOverlay(tester);
    expect(find.text('BOARD\nCOMPLETE!'), findsOneWidget);
    expect(find.byType(Fireworks), findsOneWidget);

    // A tap right away (say, left over from the last answer) is ignored.
    await tester.tap(find.text('CONTINUE'), warnIfMissed: false);
    expect(taps.continued, 0);

    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    expect(taps.continued, 1);
  });

  testWidgets('offers to view the board instead', (tester) async {
    final taps = await showOverlay(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIEW BOARD'));
    expect(taps.viewed, 1);
    expect(taps.continued, 0);
  });

  testWidgets('skips the fireworks when animations are reduced',
      (tester) async {
    final taps = await showOverlay(tester, reduceMotion: true);
    expect(find.byType(Fireworks), findsNothing);
    await tester.tap(find.text('CONTINUE'));
    expect(taps.continued, 1);
  });

  testWidgets('fireworks play once and stop', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Fireworks(seed: 1)));
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.hasRunningAnimations, isFalse);
  });
}
