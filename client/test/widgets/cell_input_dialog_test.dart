import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namedrop/models/celebrity.dart';
import 'package:namedrop/models/game_cell.dart';
import 'package:namedrop/services/celebrity_service.dart';
import 'package:namedrop/widgets/cell_input_dialog.dart';

class _FakeService extends CelebrityService {
  _FakeService(this.result);
  final ValidationResult result;

  @override
  Future<ValidationResult> validate(
          String name, String firstInitial, String lastInitial) async =>
      result;
}

const _lennon = Celebrity(
  name: 'John Lennon',
  firstInitial: 'J',
  lastInitial: 'L',
  occupation: 'Musician',
  hpi: 90,
);

void main() {
  const nearMiss = ValidationResult.nearMiss(
      _lennon, 'So close! Both names are a little off.');

  /// Opens the dialog and submits a name. Returns a getter for whatever the
  /// dialog closes with.
  Future<CellInputResult? Function()> submitName(
    WidgetTester tester, {
    required ValidationResult result,
    Set<String> usedNames = const {},
  }) async {
    CellInputResult? popped;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await showModalBottomSheet<CellInputResult>(
                context: context,
                isScrollControlled: true,
                builder: (_) => CellInputDialog(
                  slot: CellSlot(
                      requiredFirstInitial: 'J', requiredLastInitial: 'L'),
                  service: _FakeService(result),
                  skipsRemaining: 2,
                  usedNames: usedNames,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Jon Lenon');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    return () => popped;
  }

  testWidgets('near miss hints without revealing the name', (tester) async {
    await submitName(tester, result: nearMiss);
    expect(find.text('So close! Both names are a little off.'), findsOneWidget);
    expect(find.text('AUTOCORRECT +10s'), findsOneWidget);
    expect(find.textContaining('Lennon'), findsNothing);
  });

  testWidgets('autocorrect fills the slot as a corrected answer',
      (tester) async {
    final popped = await submitName(tester, result: nearMiss);
    await tester.tap(find.text('AUTOCORRECT +10s'));
    await tester.pumpAndSettle();

    final answer = popped() as CellInputAnswer;
    expect(answer.corrected, isTrue);
    expect(answer.celebrity.name, 'John Lennon');
  });

  testWidgets('editing the name dismisses the hint', (tester) async {
    await submitName(tester, result: nearMiss);
    await tester.enterText(find.byType(TextField), 'John Lenon');
    await tester.pump();
    expect(find.text('AUTOCORRECT +10s'), findsNothing);
  });

  testWidgets('a near miss on an already used name says so', (tester) async {
    await submitName(tester, result: nearMiss, usedNames: {'john lennon'});
    expect(find.text('John Lennon has already been used'), findsOneWidget);
    expect(find.text('AUTOCORRECT +10s'), findsNothing);
  });
}
