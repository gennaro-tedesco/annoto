import 'package:annoto/models/scoresheet.dart';
import 'package:flutter/material.dart';

class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key});

  static const routeName = '/game';

  @override
  Widget build(BuildContext context) {
    final scoresheet = ModalRoute.of(context)!.settings.arguments as Scoresheet;
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
        title: Text(scoresheet.filename),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SelectableText(
              scoresheet.pgn,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
