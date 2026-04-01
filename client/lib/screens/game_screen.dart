import 'package:flutter/material.dart';

import '../models/celebrity.dart';
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
  late GameState _state;
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
        bottom: _state.rerollUsed
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: _showRerollDialog,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.casino, size: 14, color: NameDropTheme.brightGold),
                        const SizedBox(width: 6),
                        Text(
                          'REROLL A LETTER',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: NameDropTheme.brightGold,
                                letterSpacing: 1.5,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                    onSlotTap: _onSlotTap,
                    onSlotClear: _onSlotClear,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSlotTap(int row, int col, CellSlot slot) async {
    if (slot.isFilled) return;

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
        await _showRevealAnimation(revealed);
        if (!mounted) return;
        setState(() {
          slot.answer = revealed;
          slot.wasSkipped = true;
          _usedNames.add(revealed.name.toLowerCase());
          _state.skipsUsed++;
        });
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

  void _onSlotClear(int row, int col, CellSlot slot) {
    if (!slot.isFilled) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NameDropTheme.royalBlue,
        title: Text('Clear ${slot.answer!.name}?',
            style: const TextStyle(color: NameDropTheme.cream)),
        content: Text(
          slot.answer?.wikiUrl != null
              ? 'This will remove the answer. You can also view their Wikipedia page.'
              : 'This will remove the answer from this slot.',
          style: const TextStyle(color: NameDropTheme.brightGold),
        ),
        actions: [
          if (slot.answer?.wikiUrl != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openWikiUrl(slot.answer!.wikiUrl!);
              },
              child: const Text('View Wikipedia'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _usedNames.remove(slot.answer!.name.toLowerCase());
                if (slot.wasSkipped) _state.skipsUsed--;
                slot.answer = null;
                slot.wasSkipped = false;
              });
            },
            style: TextButton.styleFrom(
                foregroundColor: NameDropTheme.hotCoral),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _openWikiUrl(String url) {
    // Use url_launcher if available, otherwise show the URL.
    // For web, we can use dart:html or just show a snackbar with the link.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(url), behavior: SnackBarBehavior.floating),
    );
  }

  void _showRerollDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reroll a letter',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Pick one letter to replace. This clears any answers in that row or column.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _state.rowLetters.length; i++)
                  _rerollChip(ctx, 'Row ${_state.rowLetters[i]}', i, true),
                for (int i = 0; i < _state.columnLetters.length; i++)
                  _rerollChip(ctx, 'Col ${_state.columnLetters[i]}', i, false),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rerollChip(BuildContext ctx, String label, int index, bool isRow) {
    return ActionChip(
      label: Text(label),
      backgroundColor: NameDropTheme.panelBlue,
      labelStyle: const TextStyle(color: NameDropTheme.gold),
      side: const BorderSide(color: NameDropTheme.dimGold),
      onPressed: () {
        Navigator.of(ctx).pop();
        _performReroll(index, isRow);
      },
    );
  }

  void _performReroll(int index, bool isRow) {
    // Pick a new letter not already on either axis.
    final usedLetters = {
      ..._state.rowLetters,
      ..._state.columnLetters,
    };
    final available = List.generate(26, (i) => String.fromCharCode(65 + i))
        .where((l) => !usedLetters.contains(l) && widget.service.getByInitials(l, l).isNotEmpty || !usedLetters.contains(l))
        .toList()
      ..shuffle();

    if (available.isEmpty) return;

    final newLetter = available.first;

    setState(() {
      if (isRow) {
        _state.rowLetters[index] = newLetter;
        // Clear and rebuild cells in this row.
        for (int c = 0; c < _state.gridSize; c++) {
          final cell = _state.board[index][c];
          _clearCell(cell);
          _rebuildCell(index, c);
        }
      } else {
        _state.columnLetters[index] = newLetter;
        // Clear and rebuild cells in this column.
        for (int r = 0; r < _state.gridSize; r++) {
          final cell = _state.board[r][index];
          _clearCell(cell);
          _rebuildCell(r, index);
        }
      }
      _state.rerollUsed = true;
      _recountPlayableCells();
    });
  }

  void _clearCell(GameCell cell) {
    if (cell.slotA.isFilled) {
      _usedNames.remove(cell.slotA.answer!.name.toLowerCase());
      if (cell.slotA.wasSkipped) _state.skipsUsed--;
    }
    if (cell.slotB.isFilled) {
      _usedNames.remove(cell.slotB.answer!.name.toLowerCase());
      if (cell.slotB.wasSkipped) _state.skipsUsed--;
    }
  }

  void _rebuildCell(int r, int c) {
    final rowLetter = _state.rowLetters[r];
    final colLetter = _state.columnLetters[c];

    final hasA = widget.service.hasCelebrities(rowLetter, colLetter);
    final hasB = widget.service.hasCelebrities(colLetter, rowLetter);

    _state.board[r][c] = GameCell(
      row: r,
      col: c,
      slotA: CellSlot(
        requiredFirstInitial: rowLetter,
        requiredLastInitial: colLetter,
      ),
      slotB: CellSlot(
        requiredFirstInitial: colLetter,
        requiredLastInitial: rowLetter,
      ),
      isFree: !hasA || !hasB,
    );
  }

  void _recountPlayableCells() {
    int count = 0;
    for (final row in _state.board) {
      for (final cell in row) {
        if (!cell.isFree) count++;
      }
    }
    _state.totalPlayableCells = count;
  }

  Future<void> _showRevealAnimation(Celebrity celebrity) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(32),
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              decoration: BoxDecoration(
                color: NameDropTheme.navy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NameDropTheme.gold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: NameDropTheme.gold.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    celebrity.name,
                    style: const TextStyle(
                      fontFamily: 'Bangers',
                      fontSize: 36,
                      color: NameDropTheme.gold,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    celebrity.occupation,
                    style: const TextStyle(
                      fontSize: 14,
                      color: NameDropTheme.brightGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
