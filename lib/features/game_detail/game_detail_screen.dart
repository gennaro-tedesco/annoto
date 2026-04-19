import 'package:annoto/models/scoresheet.dart';
import 'package:flutter/material.dart';

class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key});

  static const routeName = '/game';

  @override
  Widget build(BuildContext context) {
    final scoresheet = ModalRoute.of(context)!.settings.arguments as Scoresheet;
    final theme = Theme.of(context);
    final tags = _parsePgnTags(scoresheet.pgn);
    final players = _joinNonEmpty([
      _joinNonEmpty([tags['White'], tags['Black']], ' - '),
      tags['Result'],
    ], ' - ');
    final eventRound = _joinNonEmpty([tags['Event'], tags['Round']], ' - ');
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (players != null)
              Text(players, style: theme.textTheme.titleMedium),
            if (eventRound != null)
              Text(eventRound, style: theme.textTheme.bodySmall),
          ],
        ),
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

  Map<String, String> _parsePgnTags(String pgn) {
    final tags = <String, String>{};
    final exp = RegExp(r'^\[(\w+)\s+"(.*)"\]$', multiLine: true);
    for (final match in exp.allMatches(pgn)) {
      final value = match.group(2)?.trim();
      if (value == null || value.isEmpty || value == '?') continue;
      tags[match.group(1)!] = value;
    }
    return tags;
  }

  String? _joinNonEmpty(List<String?> parts, String separator) {
    final values = parts
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isEmpty) return null;
    return values.join(separator);
  }
}
