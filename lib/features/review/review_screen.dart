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

  List<String> _suggestionsForPly(
    int plyIndex,
    TextEditingController controller,
  ) {
    final allSans = _moves
        .expand((m) => [m.white.text.trim(), m.black.text.trim()])
        .toList();
    final position = positionAtPly(allSans, plyIndex);
    return suggestMoves(position, controller.text.trim());
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

  Widget _buildMoveField({
    required int plyIndex,
    required bool invalid,
    required TextEditingController controller,
    required String hintText,
    required TextStyle hintStyle,
  }) {
    final theme = Theme.of(context);

    if (!invalid) {
      return TextField(
        controller: controller,
        onChanged: (_) => _runValidation(),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: hintStyle,
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
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final suggestions = _suggestionsForPly(
          plyIndex,
          controller,
        ).take(5).toList();

        return MenuAnchor(
          style: MenuStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),
          menuChildren: [
            for (final san in suggestions)
              SizedBox(
                width: constraints.maxWidth,
                height: _inputCardsHeight,
                child: MenuItemButton(
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    controller.text = san;
                    _runValidation();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(san, style: theme.textTheme.bodyLarge),
                    ),
                  ),
                ),
              ),
          ],
          builder: (context, menuController, child) {
            return Stack(
              children: [
                TextField(
                  controller: controller,
                  onChanged: (_) => _runValidation(),
                  style: TextStyle(color: theme.colorScheme.error),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: hintStyle,
                    isDense: true,
                    constraints: const BoxConstraints(
                      minHeight: _inputCardsHeight,
                      maxHeight: _inputCardsHeight,
                    ),
                    contentPadding: const EdgeInsets.only(
                      left: 16,
                      top: 8,
                      bottom: 8,
                      right: 28,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.error),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 28,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (suggestions.isEmpty) return;
                      if (menuController.isOpen) {
                        menuController.close();
                      } else {
                        menuController.open();
                      }
                    },
                    child: Center(
                      child: Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMoveRow(BuildContext context, MovePair move, int index) {
    final theme = Theme.of(context);
    final hintStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );
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
                child: _buildMoveField(
                  plyIndex: whitePlyIndex,
                  invalid: whiteInvalid,
                  controller: move.white,
                  hintText: 'White',
                  hintStyle: hintStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMoveField(
                  plyIndex: blackPlyIndex,
                  invalid: blackInvalid,
                  controller: move.black,
                  hintText: 'Black',
                  hintStyle: hintStyle,
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
