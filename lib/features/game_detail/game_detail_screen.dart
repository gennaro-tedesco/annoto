import 'package:annoto/models/move_pair.dart';
import 'package:annoto/models/scoresheet.dart';
import 'package:annoto/repositories/scoresheet_repository.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:annoto/services/pgn_validator.dart';
import 'package:annoto/widgets/section_toggle.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({super.key});

  static const routeName = '/game';

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  List<String> _games = [];
  int _currentChapter = 0;
  final Map<String, TextEditingController> _headerControllers = {};
  List<MovePair> _moves = [];
  List<bool> _plyValidity = [];
  bool _initialised = false;
  bool _headersExpanded = true;
  bool _movesExpanded = true;
  late Scoresheet _scoresheet;
  String _initialFullPgn = '';
  String _initialPgn = '';
  MovePair? _editingMove;

  static const double _inputCardsHeight = 30.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _scoresheet = ModalRoute.of(context)!.settings.arguments as Scoresheet;
      _games = splitPgnGames(_scoresheet.pgn);
      if (_games.isEmpty) _games = [_scoresheet.pgn];
      _parsePgn(_games[0]);
      _runValidation();
      _initialFullPgn = _scoresheet.pgn.trim();
      _initialPgn = serialisePgn(_headerControllers, _moves);
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

  void _attachFocusListeners(MovePair move) {
    void listener() {
      if (!move.whiteFocus.hasFocus && !move.blackFocus.hasFocus) {
        setState(() => _editingMove = null);
      }
    }

    move.whiteFocus.addListener(listener);
    move.blackFocus.addListener(listener);
  }

  bool get _isDirty => serialisePgn(_headerControllers, _moves) != _initialPgn;

  String get _currentPgn => serialisePgn(_headerControllers, _moves);

  String get _fullPgn {
    final games = List<String>.of(_games);
    games[_currentChapter] = _currentPgn;
    return games.length > 1 ? games.join('\n\n') : games.first;
  }

  bool get _hasPendingChanges => _fullPgn != _initialFullPgn;

  void _parsePgn(String pgn) {
    _moves = parsePgn(pgn, _headerControllers);
    for (final move in _moves) {
      _attachFocusListeners(move);
    }
  }

  void _runValidation() {
    final sans = _moves
        .expand((m) => [m.white.text.trim(), m.black.text.trim()])
        .toList();
    while (sans.isNotEmpty && sans.last.isEmpty) {
      sans.removeLast();
    }
    setState(() => _plyValidity = validateMoves(sans));
  }

  void _renumberMoves() {
    for (var i = 0; i < _moves.length; i++) {
      _moves[i].number = i + 1;
    }
  }

  void _deleteMovePair(MovePair move) {
    setState(() {
      _moves.remove(move);
      if (_editingMove == move) _editingMove = null;
      move.dispose();
      _renumberMoves();
    });
    _runValidation();
  }

  void _insertMovePairBelow(MovePair move) {
    final index = _moves.indexOf(move);
    if (index == -1) return;
    final newMove = MovePair(number: move.number + 1);
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

  void _loadChapter(int index) {
    if (index == _currentChapter) return;
    if (_isDirty) {
      _games[_currentChapter] = _currentPgn;
    }
    for (final c in _headerControllers.values) {
      c.dispose();
    }
    _headerControllers.clear();
    for (final m in _moves) {
      m.dispose();
    }
    _moves.clear();
    _parsePgn(_games[index]);
    _runValidation();
    setState(() {
      _currentChapter = index;
      _initialPgn = serialisePgn(_headerControllers, _moves);
      _editingMove = null;
    });
  }

  String _chapterLabel(int index) {
    return chapterLabelForPgn(_games[index], index);
  }

  Future<void> _share() async {
    final path = await scoresheetRepository.getFilePath(_scoresheet.id);
    await Share.shareXFiles([XFile(path, mimeType: 'application/x-chess-pgn')]);
  }

  Future<void> _save() async {
    if (!_hasPendingChanges) return;
    _runValidation();
    final fullPgn = _fullPgn;
    _games[_currentChapter] = _currentPgn;
    try {
      await scoresheetRepository.update(_scoresheet.id, fullPgn);
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
                  if (_games.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PopupMenuButton<int>(
                        tooltip: 'Select game',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_outlined, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Game ${_currentChapter + 1} / ${_games.length}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const Icon(Icons.expand_more, size: 16),
                          ],
                        ),
                        onSelected: _loadChapter,
                        itemBuilder: (_) => [
                          for (int i = 0; i < _games.length; i++)
                            PopupMenuItem(
                              value: i,
                              child: Text(_chapterLabel(i)),
                            ),
                        ],
                      ),
                    ),
                  SectionToggle(
                    title: 'Headers',
                    expanded: _headersExpanded,
                    onPressed: () {
                      setState(() => _headersExpanded = !_headersExpanded);
                    },
                  ),
                  if (_headersExpanded)
                    ...kPgnTagOrder.map(
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
                                style: theme.textTheme.bodySmall,
                                controller: _headerControllers[tag],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: tag,
                                  hintStyle: theme.textTheme.bodySmall
                                      ?.copyWith(
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                  isDense: true,
                                  constraints: BoxConstraints(
                                    minHeight: _inputCardsHeight,
                                    maxHeight: _inputCardsHeight,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 36),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Divider(color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 4),
                  SectionToggle(
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
                    onPressed: _share,
                    style: IconButton.styleFrom(
                      backgroundColor: fillColor,
                      foregroundColor: theme.colorScheme.onSurface,
                      side: _plyValidity.any((v) => !v)
                          ? BorderSide(color: theme.colorScheme.error)
                          : null,
                    ),
                    icon: const Icon(Icons.share, size: 20),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    onPressed: _hasPendingChanges ? _save : null,
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

  Widget _buildMoveRow(BuildContext context, MovePair move, int index) {
    final theme = Theme.of(context);
    final isEditing = _editingMove == move;
    final hintStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );
    final whitePlyIndex = index * 2;
    final blackPlyIndex = index * 2 + 1;
    final whiteInvalid =
        whitePlyIndex < _plyValidity.length && !_plyValidity[whitePlyIndex];
    final blackInvalid =
        blackPlyIndex < _plyValidity.length && !_plyValidity[blackPlyIndex];

    final comments = _commentTexts(move);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    onTap: () {
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
                        style: whiteInvalid
                            ? TextStyle(color: theme.colorScheme.error)
                            : null,
                        decoration: InputDecoration(
                          hintText: 'White',
                          hintStyle: hintStyle,
                          isDense: true,
                          constraints: BoxConstraints(
                            minHeight: _inputCardsHeight,
                            maxHeight: _inputCardsHeight,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          enabledBorder: whiteInvalid
                              ? OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.error,
                                  ),
                                )
                              : null,
                          focusedBorder: whiteInvalid
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
                    onTap: () {
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
                        style: blackInvalid
                            ? TextStyle(color: theme.colorScheme.error)
                            : null,
                        decoration: InputDecoration(
                          hintText: 'Black',
                          hintStyle: hintStyle,
                          isDense: true,
                          constraints: BoxConstraints(
                            minHeight: _inputCardsHeight,
                            maxHeight: _inputCardsHeight,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          enabledBorder: blackInvalid
                              ? OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.error,
                                  ),
                                )
                              : null,
                          focusedBorder: blackInvalid
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
                const SizedBox(width: 36),
              ],
            ),
            if (comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 6, 36, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: comments
                      .map(
                        (comment) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '{ $comment }',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _commentTexts(MovePair move) {
    return [
          ...move.whiteStartingComments,
          ...move.whiteComments,
          ...move.blackStartingComments,
          ...move.blackComments,
        ]
        .map((comment) => comment.trim())
        .where((comment) => comment.isNotEmpty)
        .toList();
  }
}
