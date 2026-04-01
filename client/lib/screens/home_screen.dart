import 'package:flutter/material.dart';

import '../services/board_generator.dart';
import '../services/celebrity_service.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  final CelebrityService service;

  const HomeScreen({super.key, required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _gridSize = 3;

  @override
  Widget build(BuildContext context) {
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
                  'NameDrop',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Celebrity Initials Game',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Grid Size',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 3, label: Text('3×3')),
                    ButtonSegment(value: 4, label: Text('4×4')),
                    ButtonSegment(value: 5, label: Text('5×5')),
                  ],
                  selected: {_gridSize},
                  onSelectionChanged: (value) {
                    setState(() => _gridSize = value.first);
                  },
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _startGame,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('New Game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startGame() {
    final generator = BoardGenerator(widget.service);
    final gameState = generator.generate(_gridSize);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameState: gameState,
          service: widget.service,
        ),
      ),
    );
  }
}
