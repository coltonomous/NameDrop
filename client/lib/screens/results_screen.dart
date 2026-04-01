import 'package:flutter/material.dart';

import '../models/game_state.dart';

class ResultsScreen extends StatelessWidget {
  final GameState gameState;

  const ResultsScreen({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    final elapsed = gameState.elapsed;
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final freeCells = gameState.board
        .expand((row) => row)
        .where((cell) => cell.isFree)
        .length;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.celebration, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Board Complete!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 32),
                _statRow(context, 'Grid', '${gameState.gridSize}×${gameState.gridSize}'),
                _statRow(context, 'Time', '${minutes}m ${seconds}s'),
                _statRow(context, 'Slots Filled', '${gameState.completedSlots}'),
                if (freeCells > 0) _statRow(context, 'Free Cells', '$freeCells'),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Play Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
