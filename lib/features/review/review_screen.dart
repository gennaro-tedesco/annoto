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
  List<_MovePair> _moves = [];
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      final pgn = ModalRoute.of(context)!.settings.arguments as String? ?? '';
      _moves = _parsePgn(pgn);
      _initialised = true;
    }
  }

  @override
  void dispose() {
    for (final move in _moves) {
      move.dispose();
    }
    super.dispose();
  }

  List<_MovePair> _parsePgn(String pgn) {
    final regex = RegExp(r'(\d+)\.\s*(\S+)(?:\s+(\S+))?');
    return regex
        .allMatches(pgn)
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
    for (final move in _moves) {
      buffer.write('${move.number}. ${move.white.text}');
      if (move.black.text.isNotEmpty) buffer.write(' ${move.black.text}');
      buffer.write(' ');
    }
    buffer.write('*');
    return buffer.toString().trim();
  }

  void _confirm() {
    _serialisePgn();
    NotificationService.showInfo('Scoresheet saved.');
    Navigator.of(context).pop();
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _moves.length,
                itemBuilder: (context, index) =>
                    _buildMoveRow(context, _moves[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirm,
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
}
