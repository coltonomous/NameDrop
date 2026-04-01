import 'package:flutter/material.dart';

import '../models/game_cell.dart';
import '../theme.dart';

class GameCellWidget extends StatelessWidget {
  final GameCell cell;
  final void Function(CellSlot slot)? onSlotTap;

  const GameCellWidget({super.key, required this.cell, this.onSlotTap});

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

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: decoration,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (cell.isFree) {
      return Center(
        child: Icon(Icons.star_rounded,
            size: 20, color: NameDropTheme.gold.withValues(alpha: 0.4)),
      );
    }

    return Column(
      children: [
        Expanded(child: _buildSlotArea(context, cell.slotA)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: NameDropTheme.gold.withValues(alpha: 0.3),
          ),
        ),
        Expanded(child: _buildSlotArea(context, cell.slotB)),
      ],
    );
  }

  Widget _buildSlotArea(BuildContext context, CellSlot slot) {
    final tappable = !slot.isFilled && onSlotTap != null;

    return GestureDetector(
      onTap: tappable ? () => onSlotTap!(slot) : null,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: _buildSlotText(context, slot),
        ),
      ),
    );
  }

  Widget _buildSlotText(BuildContext context, CellSlot slot) {
    if (slot.isFilled) {
      return Text(
        slot.answer!.name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: slot.wasSkipped ? FontWeight.w400 : FontWeight.w600,
              fontStyle:
                  slot.wasSkipped ? FontStyle.italic : FontStyle.normal,
              color: slot.wasSkipped
                  ? NameDropTheme.hotCoral.withValues(alpha: 0.8)
                  : Colors.white,
            ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      slot.label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NameDropTheme.dimGold,
            fontWeight: FontWeight.w500,
          ),
      textAlign: TextAlign.center,
    );
  }
}
