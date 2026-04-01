import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../theme.dart';

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
                Text(
                  'BOARD\nCOMPLETE!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        shadows: [
                          Shadow(
                            color: NameDropTheme.gold.withValues(alpha: 0.6),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: NameDropTheme.panelDecoration,
                  child: Column(
                    children: [
                      _statRow(context, 'Grid',
                          '${gameState.gridSize} x ${gameState.gridSize}'),
                      const Divider(color: NameDropTheme.dimGold, height: 24),
                      _statRow(context, 'Time', '${minutes}m ${seconds}s'),
                      const Divider(color: NameDropTheme.dimGold, height: 24),
                      _statRow(
                          context, 'Slots Filled', '${gameState.completedSlots}'),
                      if (freeCells > 0) ...[
                        const Divider(color: NameDropTheme.dimGold, height: 24),
                        _statRow(context, 'Free Cells', '$freeCells'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('PLAY AGAIN'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
      ],
    );
  }
}
