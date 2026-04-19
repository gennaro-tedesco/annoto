import 'package:annoto/repositories/scoresheet_repository.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:flutter/material.dart';

class _MovePair {
  _MovePair({required this.number, String white = '', String black = ''})
    : white = TextEditingController(text: white),
      black = TextEditingController(text: black);

  final int number;
  final TextEditingController white;
  final TextEditingController black;

  void dispose() {
    white.dispose();
    black.dispose();
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  static const routeName = '/review';

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _tagOrder = [
    'White',
    'Black',
    'Event',
    'Site',
    'Date',
    'Round',
    'Result',
  ];

  final Map<String, TextEditingController> _headerControllers = {};
  List<_MovePair> _moves = [];
  bool _initialised = false;
  bool _headersExpanded = true;
  bool _movesExpanded = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      final pgn = ModalRoute.of(context)!.settings.arguments as String? ?? '';
      _parsePgn(pgn);
      _initialised = true;
    }
  }

  @override
  void dispose() {
    for (final c in _headerControllers.values) {
      c.dispose();
    }
    for (final move in _moves) {
      move.dispose();
    }
    super.dispose();
  }

  void _parsePgn(String pgn) {
    final headerRegex = RegExp(r'\[(\w+)\s+"([^"]*)"\]');
    final headers = <String, String>{};
    for (final match in headerRegex.allMatches(pgn)) {
      headers[match.group(1)!] = match.group(2)!;
    }
    for (final tag in _tagOrder) {
      _headerControllers[tag] = TextEditingController(
        text: headers[tag] ?? '?',
      );
    }

    final movesMatch = RegExp(r'\n\n(.+)', dotAll: true).firstMatch(pgn);
    final movesText = movesMatch?.group(1)?.trim() ?? pgn;
    _moves = _parseMoves(movesText);
  }

  List<_MovePair> _parseMoves(String text) {
    final regex = RegExp(r'(\d+)\.\s*(\S+)(?:\s+(\S+))?');
    return regex
        .allMatches(text)
        .map(
          (m) => _MovePair(
            number: int.parse(m.group(1)!),
            white: m.group(2) ?? '',
            black: m.group(3) ?? '',
          ),
        )
        .toList();
  }

  String _serialisePgn() {
    final buffer = StringBuffer();
    for (final tag in _tagOrder) {
      final value = _headerControllers[tag]?.text.trim() ?? '?';
      buffer.writeln('[$tag "$value"]');
    }
    buffer.writeln();
    for (final move in _moves) {
      buffer.write('${move.number}. ${move.white.text}');
      if (move.black.text.isNotEmpty) buffer.write(' ${move.black.text}');
      buffer.write(' ');
    }
    final result = _headerControllers['Result']?.text.trim() ?? '*';
    buffer.write(result);
    return buffer.toString().trim();
  }

  Future<void> _confirm() async {
    final pgn = _serialisePgn();
    try {
      await scoresheetRepository.save(pgn);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      NotificationService.showError('Failed to save scoresheet.');
    }
  }

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
        title: const Text('Review'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  _buildSectionToggle(
                    context: context,
                    title: 'Headers',
                    expanded: _headersExpanded,
                    onPressed: () {
                      setState(() => _headersExpanded = !_headersExpanded);
                    },
                  ),
                  if (_headersExpanded)
                    ..._tagOrder.map(
                      (tag) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(
                                tag,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _headerControllers[tag],
                                decoration: InputDecoration(
                                  hintText: tag,
                                  isDense: true,
                                  constraints: BoxConstraints(
                                    minHeight: 44,
                                    maxHeight: 44,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Divider(color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 4),
                  _buildSectionToggle(
                    context: context,
                    title: 'Moves',
                    expanded: _movesExpanded,
                    onPressed: () {
                      setState(() => _movesExpanded = !_movesExpanded);
                    },
                  ),
                  if (_movesExpanded)
                    ..._moves.map((move) => _buildMoveRow(context, move)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _confirm(),
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveRow(BuildContext context, _MovePair move) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${move.number}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: move.white,
              decoration: const InputDecoration(hintText: 'White'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: move.black,
              decoration: const InputDecoration(hintText: 'Black'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionToggle({
    required BuildContext context,
    required String title,
    required bool expanded,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          foregroundColor: theme.colorScheme.onSurface,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ),
          ],
        ),
      ),
    );
  }
}
