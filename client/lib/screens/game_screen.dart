import 'package:flutter/material.dart';

import '../models/game_cell.dart';
import '../models/game_state.dart';
import '../services/celebrity_service.dart';
import '../theme.dart';
import '../widgets/cell_input_dialog.dart';
import '../widgets/game_board.dart';
import 'results_screen.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;
  final CelebrityService service;

  const GameScreen({
    super.key,
    required this.gameState,
    required this.service,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameState _state;
  final Set<String> _usedNames = {};

  @override
  void initState() {
    super.initState();
    _state = widget.gameState;
  }

  @override
  Widget build(BuildContext context) {
    final completed = _state.completedSlots;
    final total = _state.totalPlayableSlots;
    final progress = total > 0 ? completed / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NAMEDROP'),
        leading: IconButton(
          icon: const Icon(Icons.close, color: NameDropTheme.cream),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$completed / $total',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: NameDropTheme.royalBlue,
            valueColor: const AlwaysStoppedAnimation(NameDropTheme.gold),
            minHeight: 3,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GameBoard(
                    gameState: _state,
                    onCellTap: _onCellTap,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCellTap(int row, int col) async {
    final cell = _state.board[row][col];
    final slot = cell.nextUnfilledSlot;
    if (slot == null) return;

    final result = await _showInputDialog(slot);
    if (result == null) return;

    switch (result) {
      case CellInputAnswer(:final celebrity):
        if (_usedNames.contains(celebrity.name.toLowerCase())) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${celebrity.name} has already been used!')),
          );
          return;
        }
        setState(() {
          slot.answer = celebrity;
          _usedNames.add(celebrity.name.toLowerCase());
        });

      case CellInputSkip():
        final revealed = _pickRevealCelebrity(slot);
        if (revealed == null) return;
        setState(() {
          slot.answer = revealed;
          slot.wasSkipped = true;
          _usedNames.add(revealed.name.toLowerCase());
          _state.skipsUsed++;
        });
    }

    // Prompt for the second slot if still unfilled.
    if (cell.nextUnfilledSlot != null) {
      await _onCellTap(row, col);
      return;
    }

    if (_state.isComplete) {
      _state.phase = GamePhase.complete;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(gameState: _state),
        ),
      );
    }
  }

  /// Pick a random celebrity for the slot that hasn't been used yet.
  _pickRevealCelebrity(CellSlot slot) {
    final candidates = widget.service
        .getByInitials(slot.requiredFirstInitial, slot.requiredLastInitial)
        .where((c) => !_usedNames.contains(c.name.toLowerCase()))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.shuffle();
    return candidates.first;
  }

  Future<CellInputResult?> _showInputDialog(CellSlot slot) {
    return showModalBottomSheet<CellInputResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CellInputDialog(
        slot: slot,
        service: widget.service,
        skipsRemaining: _state.skipsRemaining,
      ),
    );
  }
}
