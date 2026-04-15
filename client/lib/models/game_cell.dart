import 'celebrity.dart';

enum CellStatus { empty, partial, complete, free }

class CellSlot {
  final String requiredFirstInitial;
  final String requiredLastInitial;
  Celebrity? answer;
  bool wasSkipped = false;

  CellSlot({
    required this.requiredFirstInitial,
    required this.requiredLastInitial,
  });

  bool get isFilled => answer != null;

  String get label => '${requiredFirstInitial}.${requiredLastInitial}.';

  Map<String, dynamic> toJson() => {
        'requiredFirstInitial': requiredFirstInitial,
        'requiredLastInitial': requiredLastInitial,
        'answer': answer?.toJson(),
        'wasSkipped': wasSkipped,
      };

  factory CellSlot.fromJson(Map<String, dynamic> json) {
    final slot = CellSlot(
      requiredFirstInitial: json['requiredFirstInitial'] as String,
      requiredLastInitial: json['requiredLastInitial'] as String,
    );
    if (json['answer'] != null) {
      slot.answer =
          Celebrity.fromJson(json['answer'] as Map<String, dynamic>);
    }
    slot.wasSkipped = json['wasSkipped'] as bool;
    return slot;
  }
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

  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
        'slotA': slotA.toJson(),
        'slotB': slotB.toJson(),
        'isFree': isFree,
      };

  factory GameCell.fromJson(Map<String, dynamic> json) => GameCell(
        row: json['row'] as int,
        col: json['col'] as int,
        slotA: CellSlot.fromJson(json['slotA'] as Map<String, dynamic>),
        slotB: CellSlot.fromJson(json['slotB'] as Map<String, dynamic>),
        isFree: json['isFree'] as bool,
      );
}
