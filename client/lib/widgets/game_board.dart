import 'package:flutter/material.dart';

import '../models/game_cell.dart';
import '../models/game_state.dart';
import 'axis_label.dart';
import 'game_cell_widget.dart';

class GameBoard extends StatelessWidget {
  final GameState gameState;
  final void Function(int row, int col, CellSlot slot) onSlotTap;
  final void Function(int row, int col, CellSlot slot)? onSlotClear;

  const GameBoard({
    super.key,
    required this.gameState,
    required this.onSlotTap,
    this.onSlotClear,
  });

  @override
  Widget build(BuildContext context) {
    final gridSize = gameState.gridSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelSize = 48.0;
        // Square game area sized to fit, minus space for labels.
        final available = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final gameSize = available - labelSize;

        return Center(
          child: Transform.translate(
            offset: Offset(-labelSize / 2, -labelSize / 2),
            child: SizedBox(
              width: gameSize + labelSize,
              height: gameSize + labelSize,
            child: Column(
              children: [
                // Column labels row
                SizedBox(
                  height: labelSize,
                  child: Row(
                    children: [
                      SizedBox(width: labelSize), // corner spacer
                      ...List.generate(gridSize, (c) {
                        return Expanded(
                          child: AxisLabel(gameState.columnLetters[c]),
                        );
                      }),
                    ],
                  ),
                ),
                // Game rows with row labels
                Expanded(
                  child: Row(
                    children: [
                      // Row labels column
                      SizedBox(
                        width: labelSize,
                        child: Column(
                          children: List.generate(gridSize, (r) {
                            return Expanded(
                              child: AxisLabel(gameState.rowLetters[r]),
                            );
                          }),
                        ),
                      ),
                      // Game cells grid (square)
                      Expanded(
                        child: Column(
                          children: List.generate(gridSize, (r) {
                            return Expanded(
                              child: Row(
                                children: List.generate(gridSize, (c) {
                                  final cell = gameState.board[r][c];
                                  return Expanded(
                                    child: GameCellWidget(
                                      cell: cell,
                                      onSlotTap: (slot) =>
                                          onSlotTap(r, c, slot),
                                      onSlotClear: onSlotClear != null
                                          ? (slot) =>
                                              onSlotClear!(r, c, slot)
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
