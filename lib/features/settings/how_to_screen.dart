import 'package:flutter/material.dart';

class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  static const _sections = [
    (
      title: 'Home',
      actions: [
        'Tap the settings icon to open the settings panel.',
        'Tap the + button to choose how to add a scoresheet image.',
        'Tap the filter icon to unfold the filters upward from the bottom controls.',
        'Use AND or OR to combine tournament, round, white player, and black player selections and narrow the game cards.',
      ],
    ),
    (
      title: 'Settings',
      actions: [
        'Tap Appearance to change theme, font size, and font.',
        'Tap Account to sign in or sign out.',
        'Tap AI provider after signing in to select the active provider.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filled(
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: fillColor,
            foregroundColor: theme.colorScheme.onSurface,
          ),
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, size: 22),
        ),
        title: const Text('How to'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final section in _sections) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    for (final action in section.actions) ...[
                      Text(action, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
