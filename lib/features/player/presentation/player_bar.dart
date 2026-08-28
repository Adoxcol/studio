import 'package:flutter/material.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: const SizedBox(
        height: 72,
        child: Center(child: Text('Not playing')),
      ),
    );
  }
}
