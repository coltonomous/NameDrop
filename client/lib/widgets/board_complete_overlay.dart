import 'package:flutter/material.dart';

import '../theme.dart';
import 'fireworks.dart';

/// Shown over the finished board: fireworks, a headline, and a Continue
/// button through to the results.
class BoardCompleteOverlay extends StatefulWidget {
  final VoidCallback onContinue;

  const BoardCompleteOverlay({super.key, required this.onContinue});

  @override
  State<BoardCompleteOverlay> createState() => _BoardCompleteOverlayState();
}

class _BoardCompleteOverlayState extends State<BoardCompleteOverlay>
    with SingleTickerProviderStateMixin {
  // The headline pops in, then Continue fades in a beat later so a stray tap
  // left over from entering the last name can't skip the celebration.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();
  late final _headline = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.5, curve: Curves.elasticOut),
  );
  late final _button = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.7, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _headline.dispose();
    _button.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          dismissible: false,
          color: NameDropTheme.navy.withValues(alpha: 0.8),
        ),
        if (!reduceMotion) const Fireworks(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: reduceMotion ? kAlwaysCompleteAnimation : _headline,
                child: Text(
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
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _button,
                builder: (context, child) => Opacity(
                  opacity: reduceMotion ? 1 : _button.value,
                  child: IgnorePointer(
                    ignoring: !reduceMotion && _button.value < 0.5,
                    child: child,
                  ),
                ),
                child: FilledButton(
                  onPressed: widget.onContinue,
                  child: const Text('CONTINUE'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
