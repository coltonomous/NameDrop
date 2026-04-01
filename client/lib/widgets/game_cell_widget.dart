import 'package:flutter/material.dart';

import '../models/game_cell.dart';
import '../theme.dart';

class GameCellWidget extends StatefulWidget {
  final GameCell cell;
  final void Function(CellSlot slot)? onSlotTap;
  final void Function(CellSlot slot)? onSlotClear;

  const GameCellWidget({
    super.key,
    required this.cell,
    this.onSlotTap,
    this.onSlotClear,
  });

  @override
  State<GameCellWidget> createState() => _GameCellWidgetState();
}

class _GameCellWidgetState extends State<GameCellWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _previousFilledCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _previousFilledCount = _filledCount;
  }

  int get _filledCount {
    int count = 0;
    if (widget.cell.slotA.isFilled) count++;
    if (widget.cell.slotB.isFilled) count++;
    return count;
  }

  @override
  void didUpdateWidget(GameCellWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCount = _filledCount;
    if (newCount > _previousFilledCount && !widget.cell.isFree) {
      _pulseController.forward(from: 0);
    }
    _previousFilledCount = newCount;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;
    switch (widget.cell.status) {
      case CellStatus.complete:
        decoration = NameDropTheme.completedPanelDecoration;
      case CellStatus.partial:
        decoration = NameDropTheme.partialPanelDecoration;
      case CellStatus.free:
        decoration = NameDropTheme.freePanelDecoration;
      case CellStatus.empty:
        decoration = NameDropTheme.panelDecoration;
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowOpacity = (1 - _pulseAnimation.value) * 0.6;
        final scale = 1.0 + (1 - _pulseAnimation.value) * 0.03;

        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: decoration.copyWith(
              boxShadow: glowOpacity > 0.01
                  ? [
                      BoxShadow(
                        color: NameDropTheme.gold
                            .withValues(alpha: glowOpacity),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        );
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.cell.isFree) {
      final isWide = MediaQuery.of(context).size.width > 600;
      return Center(
        child: Icon(Icons.star_rounded,
            size: isWide ? 28 : 20,
            color: NameDropTheme.gold.withValues(alpha: 0.4)),
      );
    }

    return Column(
      children: [
        Expanded(child: _buildSlotArea(context, widget.cell.slotA)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: NameDropTheme.gold.withValues(alpha: 0.3),
          ),
        ),
        Expanded(child: _buildSlotArea(context, widget.cell.slotB)),
      ],
    );
  }

  Widget _buildSlotArea(BuildContext context, CellSlot slot) {
    return GestureDetector(
      onTap: slot.isFilled
          ? (widget.onSlotClear != null
              ? () => widget.onSlotClear!(slot)
              : null)
          : (widget.onSlotTap != null
              ? () => widget.onSlotTap!(slot)
              : null),
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
    final isWide = MediaQuery.of(context).size.width > 600;
    final textStyle = isWide
        ? Theme.of(context).textTheme.bodySmall
        : Theme.of(context).textTheme.labelSmall;

    if (slot.isFilled) {
      final hasWiki = slot.answer?.wikiUrl != null;
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              slot.answer!.name,
              style: textStyle?.copyWith(
                    fontWeight:
                        slot.wasSkipped ? FontWeight.w400 : FontWeight.w600,
                    fontStyle:
                        slot.wasSkipped ? FontStyle.italic : FontStyle.normal,
                    color: slot.wasSkipped
                        ? NameDropTheme.hotCoral.withValues(alpha: 0.8)
                        : Colors.white,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasWiki)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Icon(
                Icons.open_in_new,
                size: isWide ? 12 : 8,
                color: NameDropTheme.dimGold,
              ),
            ),
        ],
      );
    }

    return Text(
      slot.label,
      style: textStyle?.copyWith(
            color: NameDropTheme.dimGold,
            fontWeight: FontWeight.w500,
          ),
      textAlign: TextAlign.center,
    );
  }
}
