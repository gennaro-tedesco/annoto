import 'package:annoto/models/move_pair.dart';
import 'package:annoto/repositories/scoresheet_repository.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:annoto/services/pgn_validator.dart';
import 'package:annoto/widgets/section_toggle.dart';
import 'package:flutter/material.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  static const routeName = '/review';

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final Map<String, TextEditingController> _headerControllers = {};
  List<MovePair> _moves = [];
  List<bool> _plyValidity = [];
  bool _initialised = false;
  bool _headersExpanded = true;
  bool _movesExpanded = true;

  static const double _inputCardsHeight = 30.0;

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
    _moves = parsePgn(pgn, _headerControllers);
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

  Future<void> _confirm() async {
    _runValidation();
    final pgn = serialisePgn(_headerControllers, _moves);
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

  Widget _buildMoveRow(BuildContext context, MovePair move, int index) {
    final theme = Theme.of(context);
    final whitePlyIndex = index * 2;
    final blackPlyIndex = index * 2 + 1;
    final whiteInvalid =
        whitePlyIndex < _plyValidity.length && !_plyValidity[whitePlyIndex];
    final blackInvalid =
        blackPlyIndex < _plyValidity.length && !_plyValidity[blackPlyIndex];

    final comments = movePairCommentTexts(move);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                child: whiteInvalid
                    ? _InvalidMoveField(
                        controller: move.white,
                        hint: 'White',
                        getSuggestions: () {
                          final allSans = _moves
                              .expand(
                                (m) => [
                                  m.white.text.trim(),
                                  m.black.text.trim(),
                                ],
                              )
                              .toList();
                          return suggestMoves(
                            positionAtPly(allSans, whitePlyIndex),
                            move.white.text.trim(),
                          );
                        },
                        onSelected: _runValidation,
                      )
                    : TextField(
                        controller: move.white,
                        onChanged: (_) => _runValidation(),
                        decoration: InputDecoration(
                          hintText: 'White',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          isDense: true,
                          constraints: const BoxConstraints(
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
              const SizedBox(width: 8),
              Expanded(
                child: blackInvalid
                    ? _InvalidMoveField(
                        controller: move.black,
                        hint: 'Black',
                        getSuggestions: () {
                          final allSans = _moves
                              .expand(
                                (m) => [
                                  m.white.text.trim(),
                                  m.black.text.trim(),
                                ],
                              )
                              .toList();
                          return suggestMoves(
                            positionAtPly(allSans, blackPlyIndex),
                            move.black.text.trim(),
                          );
                        },
                        onSelected: _runValidation,
                      )
                    : TextField(
                        controller: move.black,
                        onChanged: (_) => _runValidation(),
                        decoration: InputDecoration(
                          hintText: 'Black',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          isDense: true,
                          constraints: const BoxConstraints(
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
    );
  }
}

class _InvalidMoveField extends StatefulWidget {
  const _InvalidMoveField({
    required this.controller,
    required this.hint,
    required this.getSuggestions,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String hint;
  final List<String> Function() getSuggestions;
  final VoidCallback onSelected;

  @override
  State<_InvalidMoveField> createState() => _InvalidMoveFieldState();
}

class _InvalidMoveFieldState extends State<_InvalidMoveField> {
  final _key = GlobalKey();

  Future<void> _showSuggestions() async {
    final box = _key.currentContext!.findRenderObject()! as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screenSize = MediaQuery.of(context).size;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 16,
        offset.dy + size.height / 2,
        screenSize.width,
        screenSize.height - offset.dy - size.height / 2,
      ),
      items: widget
          .getSuggestions()
          .map(
            (san) => PopupMenuItem<String>(
              value: san,
              height: 32,
              child: Text(san, style: Theme.of(context).textTheme.bodyLarge),
            ),
          )
          .toList(),
    );
    if (selected != null && mounted) {
      widget.controller.text = selected;
      widget.onSelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      key: _key,
      child: TextField(
        controller: widget.controller,
        onChanged: (_) => widget.onSelected(),
        style: TextStyle(color: theme.colorScheme.error),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          isDense: true,
          constraints: const BoxConstraints(minHeight: 30, maxHeight: 30),
          contentPadding: const EdgeInsets.only(
            left: 16,
            top: 8,
            bottom: 8,
            right: 4,
          ),
          suffixIcon: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showSuggestions,
            child: Center(
              child: Icon(
                Icons.auto_awesome,
                size: 14,
                color: theme.colorScheme.error,
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            maxHeight: 30,
            maxWidth: 28,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: theme.colorScheme.error),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }
}
