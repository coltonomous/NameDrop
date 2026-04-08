import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../services/stats_service.dart';
import '../theme.dart';

class ResultsScreen extends StatefulWidget {
  final GameState gameState;
  final StatsService stats;

  const ResultsScreen({
    super.key,
    required this.gameState,
    required this.stats,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _copied = false;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    if (!_recorded) {
      _recorded = true;
      widget.stats.recordGame(
        gridSize: widget.gameState.gridSize,
        elapsed: widget.gameState.elapsed,
        isDaily: widget.gameState.isDaily,
        dailyDateKey: widget.gameState.dailyDateKey,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = widget.gameState;
    final elapsed = gs.elapsed;
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final freeCells = gs.board
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
                          '${gs.gridSize} x ${gs.gridSize}'),
                      const Divider(color: NameDropTheme.dimGold, height: 24),
                      _statRow(context, 'Time', '${minutes}m ${seconds}s'),
                      const Divider(color: NameDropTheme.dimGold, height: 24),
                      _statRow(
                          context, 'Slots Filled', '${gs.completedSlots}'),
                      if (gs.skipsUsed > 0) ...[
                        const Divider(color: NameDropTheme.dimGold, height: 24),
                        _statRow(context, 'Skips Used', '${gs.skipsUsed}'),
                      ],
                      if (freeCells > 0) ...[
                        const Divider(color: NameDropTheme.dimGold, height: 24),
                        _statRow(context, 'Free Cells', '$freeCells'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Share card preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NameDropTheme.navy,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NameDropTheme.dimGold),
                  ),
                  child: Text(
                    _buildShareCard(),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: NameDropTheme.cream,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _share,
                      icon: Icon(_copied ? Icons.check : Icons.share),
                      label: Text(_copied ? 'COPIED!' : 'SHARE'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('PLAY AGAIN'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NameDropTheme.brightGold,
                        side: const BorderSide(color: NameDropTheme.dimGold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildShareCard() {
    final gs = widget.gameState;
    final elapsed = gs.elapsed;
    final minutes = elapsed.inMinutes;
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    final buf = StringBuffer();

    if (gs.isDaily) {
      buf.writeln('NameDrop #${gs.puzzleNumber} ${gs.gridSize}x${gs.gridSize}');
    } else {
      buf.writeln('NameDrop ${gs.gridSize}x${gs.gridSize}');
    }

    for (final row in gs.board) {
      for (final cell in row) {
        if (cell.isFree) {
          buf.write('\u2B1C'); // white square
        } else if (cell.slotA.wasSkipped || cell.slotB.wasSkipped) {
          buf.write('\uD83D\uDFE8'); // yellow square
        } else {
          buf.write('\uD83D\uDFE9'); // green square
        }
      }
      buf.writeln();
    }

    buf.write('\u23F1\uFE0F $minutes:$seconds');
    if (gs.skipsUsed > 0) {
      buf.write(' | \u23ED\uFE0F ${gs.skipsUsed} skip${gs.skipsUsed > 1 ? 's' : ''}');
    }
    buf.writeln();
    buf.write('https://coltonomous.github.io/NameDrop/');

    return buf.toString();
  }

  void _share() {
    Clipboard.setData(ClipboardData(text: _buildShareCard()));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!')),
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
