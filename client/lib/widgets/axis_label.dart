import 'package:flutter/material.dart';

import '../theme.dart';

class AxisLabel extends StatelessWidget {
  final String letter;

  const AxisLabel(this.letter, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 28,
              shadows: [
                Shadow(
                  color: NameDropTheme.gold.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
      ),
    );
  }
}
