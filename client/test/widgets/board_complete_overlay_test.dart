import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namedrop/widgets/board_complete_overlay.dart';
import 'package:namedrop/widgets/fireworks.dart';

void main() {
  Future<int Function()> showOverlay(WidgetTester tester,
      {bool reduceMotion = false}) async {
    var continued = 0;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: BoardCompleteOverlay(onContinue: () => continued++),
        ),
      ),
    ));
    return () => continued;
  }

  testWidgets('celebrates with fireworks, then offers Continue',
      (tester) async {
    final continued = await showOverlay(tester);
    expect(find.text('BOARD\nCOMPLETE!'), findsOneWidget);
    expect(find.byType(Fireworks), findsOneWidget);

    // A tap right away (say, left over from the last answer) is ignored.
    await tester.tap(find.text('CONTINUE'), warnIfMissed: false);
    expect(continued(), 0);

    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    expect(continued(), 1);
  });

  testWidgets('skips the fireworks when animations are reduced',
      (tester) async {
    final continued = await showOverlay(tester, reduceMotion: true);
    expect(find.byType(Fireworks), findsNothing);
    await tester.tap(find.text('CONTINUE'));
    expect(continued(), 1);
  });

  testWidgets('fireworks play once and stop', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Fireworks(seed: 1)));
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.hasRunningAnimations, isFalse);
  });
}
