import 'package:flutter/material.dart';

import '../models/celebrity.dart';
import '../models/game_cell.dart';
import '../models/game_state.dart';
import '../services/celebrity_service.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('NameDrop'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$completed / $total',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: Center(
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
    );
  }

  Future<void> _onCellTap(int row, int col) async {
    final cell = _state.board[row][col];
    final slot = cell.nextUnfilledSlot;
    if (slot == null) return;

    final celebrity = await _showInputDialog(slot);
    if (celebrity == null) return;

    if (_usedNames.contains(celebrity.name.toLowerCase())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${celebrity.name} has already been used!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      slot.answer = celebrity;
      _usedNames.add(celebrity.name.toLowerCase());
    });

    // If the cell still has an unfilled slot, prompt for it.
    if (cell.nextUnfilledSlot != null) {
      await _onCellTap(row, col);
      return;
    }

    // Check for game completion.
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

  Future<Celebrity?> _showInputDialog(CellSlot slot) {
    return showModalBottomSheet<Celebrity>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CellInputDialog(
        slot: slot,
        service: widget.service,
      ),
    );
  }
}
