import 'package:flutter/material.dart';

import '../models/game_cell.dart';
import '../theme.dart';

class GameCellWidget extends StatelessWidget {
  final GameCell cell;
  final VoidCallback? onTap;

  const GameCellWidget({super.key, required this.cell, this.onTap});

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;
    switch (cell.status) {
      case CellStatus.complete:
        decoration = NameDropTheme.completedPanelDecoration;
      case CellStatus.partial:
        decoration = NameDropTheme.partialPanelDecoration;
      case CellStatus.free:
        decoration = NameDropTheme.freePanelDecoration;
      case CellStatus.empty:
        decoration = NameDropTheme.panelDecoration;
    }

    return GestureDetector(
      onTap: cell.status == CellStatus.free ||
              cell.status == CellStatus.complete
          ? null
          : onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: decoration,
        padding: const EdgeInsets.all(4),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (cell.isFree) {
      return Center(
        child: Icon(Icons.star_rounded, size: 20, color: NameDropTheme.gold.withValues(alpha: 0.4)),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSlotDisplay(context, cell.slotA),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Divider(
            height: 4,
            thickness: 0.5,
            color: NameDropTheme.gold.withValues(alpha: 0.3),
          ),
        ),
        _buildSlotDisplay(context, cell.slotB),
      ],
    );
  }

  Widget _buildSlotDisplay(BuildContext context, CellSlot slot) {
    if (slot.isFilled) {
      return Flexible(
        child: Text(
          slot.answer!.name,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Flexible(
      child: Text(
        slot.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NameDropTheme.dimGold,
              fontWeight: FontWeight.w500,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
