import 'package:annoto/repositories/scoresheet_repository.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:annoto/services/pgn_validator.dart';
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
  List<bool> _plyValidity = [];
  bool _initialised = false;
  bool _headersExpanded = true;
  bool _movesExpanded = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      final pgn = ModalRoute.of(context)!.settings.arguments as String? ?? '';
      _parsePgn(pgn);
      _runValidation();
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

  void _runValidation() {
    final sans = <String>[];
    for (final move in _moves) {
      sans.add(move.white.text.trim());
      sans.add(move.black.text.trim());
    }
    while (sans.isNotEmpty && sans.last.isEmpty) {
      sans.removeLast();
    }

    final plyValidity = validateMoves(sans);
    setState(() {
      _plyValidity = plyValidity;
    });
  }

  Future<void> _confirm() async {
    _runValidation();
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
                                  constraints: const BoxConstraints(
                                    minHeight: 44,
                                    maxHeight: 44,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
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
                    ..._moves.asMap().entries.map(
                      (entry) => _buildMoveRow(context, entry.value, entry.key),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: fillColor,
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.chevron_left, size: 22),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveRow(BuildContext context, _MovePair move, int index) {
    final theme = Theme.of(context);
    final whitePlyIndex = index * 2;
    final blackPlyIndex = index * 2 + 1;
    final whiteInvalid =
        whitePlyIndex < _plyValidity.length && !_plyValidity[whitePlyIndex];
    final blackInvalid =
        blackPlyIndex < _plyValidity.length && !_plyValidity[blackPlyIndex];

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
              style:
                  whiteInvalid
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
              decoration: InputDecoration(
                hintText: 'White',
                enabledBorder:
                    whiteInvalid
                        ? OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.error),
                        )
                        : null,
                focusedBorder:
                    whiteInvalid
                        ? OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.error),
                        )
                        : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: move.black,
              style:
                  blackInvalid
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
              decoration: InputDecoration(
                hintText: 'Black',
                enabledBorder:
                    blackInvalid
                        ? OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.error),
                        )
                        : null,
                focusedBorder:
                    blackInvalid
                        ? OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.error),
                        )
                        : null,
              ),
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
