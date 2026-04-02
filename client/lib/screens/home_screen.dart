import 'package:flutter/material.dart';

import '../services/board_generator.dart';
import '../services/celebrity_service.dart';
import '../services/daily_service.dart';
import '../services/stats_service.dart';
import '../theme.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  final CelebrityService service;
  final StatsService stats;

  const HomeScreen({super.key, required this.service, required this.stats});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _gridSize = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {}); // Rebuild with fresh date
    }
  }

  @override
  Widget build(BuildContext context) {
    final puzzleNumber = DailyService.todayPuzzleNumber;
    final dailyCompleted =
        widget.stats.isDailyCompleted(DailyService.todayDateKey);

    return Scaffold(
      body: FocusScope(
        autofocus: false,
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title with glow effect
                    Text(
                      'NAMEDROP',
                      style:
                          Theme.of(context).textTheme.displayLarge?.copyWith(
                                shadows: [
                                  Shadow(
                                    color: NameDropTheme.gold
                                        .withValues(alpha: 0.6),
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
                    const SizedBox(height: 48),

                    // Daily puzzle button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: dailyCompleted ? null : _startDailyGame,
                        icon: Icon(
                          dailyCompleted ? Icons.check_circle : Icons.today,
                        ),
                        label: Text(
                          dailyCompleted
                              ? 'DAILY #$puzzleNumber COMPLETE'
                              : 'DAILY PUZZLE #$puzzleNumber',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '4x4 grid \u2022 same for everyone \u2022 resets at midnight UTC',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: NameDropTheme.dimGold,
                            fontSize: 11,
                          ),
                    ),
                    const SizedBox(height: 40),

                    // Divider
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: NameDropTheme.dimGold)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: NameDropTheme.dimGold),
                          ),
                        ),
                        const Expanded(
                            child: Divider(color: NameDropTheme.dimGold)),
                      ],
                    ),
                    const SizedBox(height: 32),

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
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _startPracticeGame,
                      autofocus: false,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('PRACTICE GAME'),
                    ),
                    const SizedBox(height: 32),

                    // Stats button
                    TextButton.icon(
                      onPressed: _showStats,
                      icon: const Icon(Icons.bar_chart, size: 18),
                      label: const Text('STATS'),
                      style: TextButton.styleFrom(
                        foregroundColor: NameDropTheme.brightGold,
                      ),
                    ),
                    const SizedBox(height: 12),
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

  static const _sha =
      String.fromEnvironment('BUILD_SHA', defaultValue: 'dev');
  static const _num =
      String.fromEnvironment('BUILD_NUM', defaultValue: '0');
  static String get _buildLabel => 'build #$_num ($_sha)';

  void _startDailyGame() {
    final generator = BoardGenerator(widget.service);
    final gameState = generator.generate(4, seed: DailyService.todaySeed);
    gameState.isDaily = true;
    gameState.puzzleNumber = DailyService.todayPuzzleNumber;
    gameState.dailyDateKey = DailyService.todayDateKey;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameState: gameState,
          service: widget.service,
          stats: widget.stats,
        ),
      ),
    );
  }

  void _startPracticeGame() {
    final generator = BoardGenerator(widget.service);
    final gameState = generator.generate(_gridSize);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameState: gameState,
          service: widget.service,
          stats: widget.stats,
        ),
      ),
    );
  }

  void _showStats() {
    final stats = widget.stats;

    String formatTime(Duration? d) {
      if (d == null) return '--';
      return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NameDropTheme.royalBlue,
        title: const Text('Stats', style: TextStyle(color: NameDropTheme.gold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statsRow(ctx, 'Games Played', '${stats.totalGames}'),
            _statsRow(ctx, 'Daily Puzzles', '${stats.dailyGames}'),
            _statsRow(ctx, 'Current Streak', '${stats.currentStreak}'),
            _statsRow(ctx, 'Max Streak', '${stats.maxStreak}'),
            const Divider(color: NameDropTheme.dimGold, height: 20),
            _statsRow(ctx, 'Best 3x3', formatTime(stats.bestTime(3))),
            _statsRow(ctx, 'Best 4x4', formatTime(stats.bestTime(4))),
            _statsRow(ctx, 'Best 5x5', formatTime(stats.bestTime(5))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: NameDropTheme.cream, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: NameDropTheme.brightGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
