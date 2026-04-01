import 'package:flutter/material.dart';

import '../models/game_cell.dart';

class GameCellWidget extends StatelessWidget {
  final GameCell cell;
  final VoidCallback? onTap;

  const GameCellWidget({super.key, required this.cell, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    switch (cell.status) {
      case CellStatus.complete:
        backgroundColor = colorScheme.primaryContainer;
      case CellStatus.partial:
        backgroundColor = colorScheme.tertiaryContainer;
      case CellStatus.free:
        backgroundColor = colorScheme.surfaceContainerHighest;
      case CellStatus.empty:
        backgroundColor = colorScheme.surface;
    }

    return GestureDetector(
      onTap: cell.status == CellStatus.free || cell.status == CellStatus.complete
          ? null
          : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
        ),
        padding: const EdgeInsets.all(4),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (cell.isFree) {
      return const Center(
        child: Icon(Icons.star_rounded, size: 20, color: Colors.amber),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSlotDisplay(context, cell.slotA, textTheme),
        const Divider(height: 4, thickness: 0.5),
        _buildSlotDisplay(context, cell.slotB, textTheme),
      ],
    );
  }

  Widget _buildSlotDisplay(
      BuildContext context, CellSlot slot, TextTheme textTheme) {
    if (slot.isFilled) {
      return Flexible(
        child: Text(
          slot.answer!.name,
          style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Flexible(
      child: Text(
        slot.label,
        style: textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
