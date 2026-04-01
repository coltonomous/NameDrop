import 'package:flutter/material.dart';

import '../services/board_generator.dart';
import '../services/celebrity_service.dart';
import '../theme.dart';
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
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // Title with glow effect
                Text(
                  'NAMEDROP',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        shadows: [
                          Shadow(
                            color: NameDropTheme.gold.withValues(alpha: 0.6),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'THE CELEBRITY INITIALS GAME',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        letterSpacing: 3,
                      ),
                ),
                const SizedBox(height: 56),
                Text(
                  'GRID SIZE',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _gridButton(3, '3x3'),
                    const SizedBox(width: 12),
                    _gridButton(4, '4x4'),
                    const SizedBox(width: 12),
                    _gridButton(5, '5x5'),
                  ],
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: _startGame,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('NEW GAME'),
                ),
                const SizedBox(height: 32),
                Text(
                  _buildLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NameDropTheme.dimGold,
                        fontSize: 10,
                      ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridButton(int size, String label) {
    final selected = _gridSize == size;
    return GestureDetector(
      onTap: () => setState(() => _gridSize = size),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: selected ? NameDropTheme.gold : NameDropTheme.panelBlue,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? NameDropTheme.gold : NameDropTheme.dimGold,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: NameDropTheme.gold.withValues(alpha: 0.3),
                    blurRadius: 12,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: selected ? NameDropTheme.navy : NameDropTheme.cream,
                ),
          ),
        ),
      ),
    );
  }

  static const _sha = String.fromEnvironment('BUILD_SHA', defaultValue: 'dev');
  static const _num = String.fromEnvironment('BUILD_NUM', defaultValue: '0');
  static String get _buildLabel => 'build #$_num ($_sha)';

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
