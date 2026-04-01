import 'package:flutter/material.dart';

class AxisLabel extends StatelessWidget {
  final String letter;

  const AxisLabel(this.letter, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
