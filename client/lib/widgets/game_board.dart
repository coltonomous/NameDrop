import 'package:flutter/material.dart';

import '../models/game_cell.dart';
import '../models/game_state.dart';
import 'axis_label.dart';
import 'game_cell_widget.dart';

class GameBoard extends StatelessWidget {
  final GameState gameState;
  final void Function(int row, int col, CellSlot slot) onSlotTap;

  const GameBoard({
    super.key,
    required this.gameState,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final gridSize = gameState.gridSize;
    final totalSize = gridSize + 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Square board sized to fit the smaller dimension.
        final boardSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        return Center(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: Column(
              children: List.generate(totalSize, (rowIndex) {
                return Expanded(
                  // Label row is shorter than game rows.
                  flex: rowIndex == 0 ? 1 : 2,
                  child: Row(
                    children: List.generate(totalSize, (colIndex) {
                      return Expanded(
                        // Label column is narrower than game columns.
                        flex: colIndex == 0 ? 1 : 2,
                        child: _buildCell(rowIndex, colIndex),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int rowIndex, int colIndex) {
    // Top-left corner: empty
    if (rowIndex == 0 && colIndex == 0) {
      return const SizedBox.shrink();
    }

    // Top row: column labels
    if (rowIndex == 0) {
      return AxisLabel(gameState.columnLetters[colIndex - 1]);
    }

    // Left column: row labels
    if (colIndex == 0) {
      return AxisLabel(gameState.rowLetters[rowIndex - 1]);
    }

    // Game cell
    final gameRow = rowIndex - 1;
    final gameCol = colIndex - 1;
    final cell = gameState.board[gameRow][gameCol];

    return GameCellWidget(
      cell: cell,
      onSlotTap: (slot) => onSlotTap(gameRow, gameCol, slot),
    );
  }
}
