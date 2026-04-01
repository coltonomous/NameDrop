import 'celebrity.dart';

enum CellStatus { empty, partial, complete, free }

class CellSlot {
  final String requiredFirstInitial;
  final String requiredLastInitial;
  Celebrity? answer;

  CellSlot({
    required this.requiredFirstInitial,
    required this.requiredLastInitial,
  });

  bool get isFilled => answer != null;

  String get label => '${requiredFirstInitial}.${requiredLastInitial}.';
}

class GameCell {
  final int row;
  final int col;
  final CellSlot slotA; // first initial = row letter, last initial = col letter
  final CellSlot slotB; // first initial = col letter, last initial = row letter
  final bool isFree;

  GameCell({
    required this.row,
    required this.col,
    required this.slotA,
    required this.slotB,
    this.isFree = false,
  });

  CellStatus get status {
    if (isFree) return CellStatus.free;
    if (slotA.isFilled && slotB.isFilled) return CellStatus.complete;
    if (slotA.isFilled || slotB.isFilled) return CellStatus.partial;
    return CellStatus.empty;
  }

  /// Returns the next unfilled slot, or null if complete/free.
  CellSlot? get nextUnfilledSlot {
    if (isFree) return null;
    if (!slotA.isFilled) return slotA;
    if (!slotB.isFilled) return slotB;
    return null;
  }
}
