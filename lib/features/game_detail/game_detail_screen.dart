import 'package:annoto/models/scoresheet.dart';
import 'package:annoto/repositories/scoresheet_repository.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:annoto/services/pgn_validator.dart';
import 'package:flutter/material.dart';

class _MovePair {
  _MovePair({required this.number, String white = '', String black = ''})
    : white = TextEditingController(text: white),
      black = TextEditingController(text: black),
      whiteFocus = FocusNode(),
      blackFocus = FocusNode();

  int number;
  final TextEditingController white;
  final TextEditingController black;
  final FocusNode whiteFocus;
  final FocusNode blackFocus;

  void dispose() {
    white.dispose();
    black.dispose();
    whiteFocus.dispose();
    blackFocus.dispose();
  }
}

class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({super.key});

  static const routeName = '/game';

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
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
  late Scoresheet _scoresheet;
  String _initialPgn = '';
  _MovePair? _editingMove;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _scoresheet = ModalRoute.of(context)!.settings.arguments as Scoresheet;
      _parsePgn(_scoresheet.pgn);
      _runValidation();
      _initialPgn = _serialisePgn();
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

  void _attachFocusListeners(_MovePair move) {
    void listener() {
      if (!move.whiteFocus.hasFocus && !move.blackFocus.hasFocus) {
        setState(() => _editingMove = null);
      }
    }
    move.whiteFocus.addListener(listener);
    move.blackFocus.addListener(listener);
  }

  bool get _isDirty => _serialisePgn() != _initialPgn;

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
    for (final move in _moves) {
      _attachFocusListeners(move);
    }
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

  void _renumberMoves() {
    for (var i = 0; i < _moves.length; i++) {
      _moves[i].number = i + 1;
    }
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

  void _deleteMovePair(_MovePair move) {
    setState(() {
      _moves.remove(move);
      if (_editingMove == move) _editingMove = null;
      move.dispose();
      _renumberMoves();
    });
    _runValidation();
  }

  void _insertMovePairBelow(_MovePair move) {
    final index = _moves.indexOf(move);
    if (index == -1) return;
    final newMove = _MovePair(number: move.number + 1);
    _attachFocusListeners(newMove);
    setState(() {
      _moves.insert(index + 1, newMove);
      _renumberMoves();
      _editingMove = newMove;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newMove.whiteFocus.requestFocus();
    });
    _runValidation();
  }

  Future<void> _save() async {
    if (!_isDirty) return;
    _runValidation();
    final pgn = _serialisePgn();
    try {
      await scoresheetRepository.update(_scoresheet.id, pgn);
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
                                onChanged: (_) => setState(() {}),
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
                    onPressed: _isDirty ? _save : null,
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
    final isEditing = _editingMove == move;
    final hintStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
    );
    final whitePlyIndex = index * 2;
    final blackPlyIndex = index * 2 + 1;
    final whiteInvalid =
        whitePlyIndex < _plyValidity.length && !_plyValidity[whitePlyIndex];
    final blackInvalid =
        blackPlyIndex < _plyValidity.length && !_plyValidity[blackPlyIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Dismissible(
        key: ObjectKey(move),
        direction: DismissDirection.horizontal,
        background: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.delete, color: theme.colorScheme.onError),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            _deleteMovePair(move);
          } else {
            _insertMovePairBelow(move);
          }
          return false;
        },
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
              child: GestureDetector(
                onLongPress: () {
                  setState(() => _editingMove = move);
                  move.whiteFocus.requestFocus();
                },
                child: AbsorbPointer(
                  absorbing: !isEditing,
                  child: TextField(
                    focusNode: move.whiteFocus,
                    readOnly: !isEditing,
                    controller: move.white,
                    onChanged: (_) => _runValidation(),
                    style:
                        whiteInvalid
                            ? TextStyle(color: theme.colorScheme.error)
                            : null,
                    decoration: InputDecoration(
                      hintText: 'White',
                      hintStyle: hintStyle,
                      enabledBorder:
                          whiteInvalid
                              ? OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.error,
                                ),
                              )
                              : null,
                      focusedBorder:
                          whiteInvalid
                              ? OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.error,
                                ),
                              )
                              : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onLongPress: () {
                  setState(() => _editingMove = move);
                  move.blackFocus.requestFocus();
                },
                child: AbsorbPointer(
                  absorbing: !isEditing,
                  child: TextField(
                    focusNode: move.blackFocus,
                    readOnly: !isEditing,
                    controller: move.black,
                    onChanged: (_) => _runValidation(),
                    style:
                        blackInvalid
                            ? TextStyle(color: theme.colorScheme.error)
                            : null,
                    decoration: InputDecoration(
                      hintText: 'Black',
                      hintStyle: hintStyle,
                      enabledBorder:
                          blackInvalid
                              ? OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.error,
                                ),
                              )
                              : null,
                      focusedBorder:
                          blackInvalid
                              ? OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.error,
                                ),
                              )
                              : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
