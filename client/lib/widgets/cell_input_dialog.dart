import 'package:flutter/material.dart';

import '../models/celebrity.dart';
import '../models/game_cell.dart';
import '../services/celebrity_service.dart';
import '../theme.dart';

sealed class CellInputResult {}

class CellInputAnswer extends CellInputResult {
  final Celebrity celebrity;
  CellInputAnswer(this.celebrity);
}

class CellInputSkip extends CellInputResult {}

class CellInputDialog extends StatefulWidget {
  final CellSlot slot;
  final CelebrityService service;
  final int skipsRemaining;

  const CellInputDialog({
    super.key,
    required this.slot,
    required this.service,
    required this.skipsRemaining,
  });

  @override
  State<CellInputDialog> createState() => _CellInputDialogState();
}

class _CellInputDialogState extends State<CellInputDialog>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  String? _errorText;
  bool _isValidating = false;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Name someone: ${slot.label}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'First name starts with ${slot.requiredFirstInitial}, '
            'last name starts with ${slot.requiredLastInitial}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              );
            },
            child: TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_isValidating,
              textCapitalization: TextCapitalization.words,
              style: Theme.of(context).textTheme.bodyLarge,
              cursorColor: NameDropTheme.gold,
              decoration: InputDecoration(
                hintText: 'Type a celebrity name...',
                errorText: _errorText,
                suffixIcon: _isValidating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NameDropTheme.gold,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: NameDropTheme.gold),
                        onPressed: _submit,
                      ),
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.skipsRemaining > 0)
                TextButton.icon(
                  onPressed: _isValidating
                      ? null
                      : () => Navigator.of(context).pop(CellInputSkip()),
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: Text('Skip (${widget.skipsRemaining} left)'),
                  style: TextButton.styleFrom(
                    foregroundColor: NameDropTheme.hotCoral,
                  ),
                )
              else
                const SizedBox.shrink(),
              TextButton(
                onPressed: _isValidating
                    ? null
                    : () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isValidating) return;

    setState(() => _isValidating = true);

    final celebrity = await widget.service.validate(
      text,
      widget.slot.requiredFirstInitial,
      widget.slot.requiredLastInitial,
    );

    if (!mounted) return;

    if (celebrity != null) {
      Navigator.of(context).pop(CellInputAnswer(celebrity));
    } else {
      setState(() {
        _isValidating = false;
      });
      _shakeController.forward(from: 0);
      setState(() {
        _errorText = "We don't know that one — try someone else";
      });
    }
  }
}
