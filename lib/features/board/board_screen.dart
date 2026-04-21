import 'package:annoto/app/themes.dart';
import 'package:annoto/models/scoresheet.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

const boardColorSchemes = <(String, ChessboardColorScheme)>[
  ('Brown', ChessboardColorScheme.brown),
  ('Blue', ChessboardColorScheme.blue),
  ('Green', ChessboardColorScheme.green),
  ('IC', ChessboardColorScheme.ic),
  ('Blue 2', ChessboardColorScheme.blue2),
  ('Blue 3', ChessboardColorScheme.blue3),
  ('Blue Marble', ChessboardColorScheme.blueMarble),
  ('Canvas', ChessboardColorScheme.canvas),
  ('Green Plastic', ChessboardColorScheme.greenPlastic),
  ('Grey', ChessboardColorScheme.grey),
  ('Horsey', ChessboardColorScheme.horsey),
  ('Leather', ChessboardColorScheme.leather),
  ('Maple', ChessboardColorScheme.maple),
  ('Maple 2', ChessboardColorScheme.maple2),
  ('Marble', ChessboardColorScheme.marble),
  ('Metal', ChessboardColorScheme.metal),
  ('Newspaper', ChessboardColorScheme.newspaper),
  ('Olive', ChessboardColorScheme.olive),
  ('Pink Pyramid', ChessboardColorScheme.pinkPyramid),
  ('Purple', ChessboardColorScheme.purple),
  ('Purple Diag', ChessboardColorScheme.purpleDiag),
  ('Wood', ChessboardColorScheme.wood),
  ('Wood 2', ChessboardColorScheme.wood2),
  ('Wood 3', ChessboardColorScheme.wood3),
  ('Wood 4', ChessboardColorScheme.wood4),
];

ChessboardColorScheme _schemeByLabel(String label) =>
    boardColorSchemes
        .where((e) => e.$1 == label)
        .map((e) => e.$2)
        .firstOrNull ??
    ChessboardColorScheme.brown;

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  static const routeName = '/board';

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late final PgnGame<PgnNodeData> _game;
  final _positionMap = <PgnChildNode<PgnNodeData>, Position>{};
  final _moveMap = <PgnChildNode<PgnNodeData>, Move>{};
  final _parentMap = <PgnChildNode<PgnNodeData>, PgnNode<PgnNodeData>>{};
  List<PgnChildNode<PgnNodeData>> _path = [];
  NormalMove? _promotionMove;
  Side _orientation = Side.white;
  late ChessboardColorScheme _colorScheme;
  late PieceSet _pieceSet;
  bool _initialised = false;
  final _currentRowKey = GlobalKey();

  static const _pieceSymbols = {
    'N': '♘',
    'B': '♗',
    'R': '♖',
    'Q': '♕',
    'K': '♔',
  };

  String _toFigurine(String san) {
    if (san.isEmpty) return san;
    final symbol = _pieceSymbols[san[0]];
    return symbol != null ? '$symbol${san.substring(1)}' : san;
  }

  Position get _currentPosition =>
      _path.isEmpty ? Chess.initial : _positionMap[_path.last]!;

  PgnNode<PgnNodeData> get _currentNode =>
      _path.isEmpty ? _game.moves : _path.last;

  Move? get _currentLastMove => _path.isEmpty ? null : _moveMap[_path.last];

  List<PgnChildNode<PgnNodeData>> get _mainLine {
    final nodes = <PgnChildNode<PgnNodeData>>[];
    PgnNode<PgnNodeData> node = _game.moves;
    while (node.children.isNotEmpty) {
      final child = node.children.first;
      nodes.add(child);
      node = child;
    }
    return nodes;
  }

  int get _divergeIndex {
    final ml = _mainLine;
    for (int i = 0; i < _path.length; i++) {
      if (i >= ml.length || ml[i] != _path[i]) return i;
    }
    return _path.length;
  }

  bool get _onMainLine => _divergeIndex == _path.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      final scoresheet =
          ModalRoute.of(context)!.settings.arguments as Scoresheet;
      _game = PgnGame.parsePgn(
        scoresheet.pgn,
        initHeaders: PgnGame.emptyHeaders,
      );
      _buildMaps(_game.moves, Chess.initial);
      _colorScheme = _schemeByLabel(boardColorSchemeNotifier.value);
      _pieceSet = PieceSet.values.firstWhere(
        (s) => s.name == boardPieceSetNotifier.value,
        orElse: () => PieceSet.cburnett,
      );
      _initialised = true;
    }
  }

  void _buildMaps(PgnNode<PgnNodeData> node, Position pos) {
    for (final child in node.children) {
      final move = pos.parseSan(child.data.san);
      if (move == null) continue;
      final newPos = pos.play(move);
      _positionMap[child] = newPos;
      _moveMap[child] = move;
      _parentMap[child] = node;
      _buildMaps(child, newPos);
    }
  }

  List<PgnChildNode<PgnNodeData>> _pathTo(PgnChildNode<PgnNodeData> target) {
    final path = <PgnChildNode<PgnNodeData>>[];
    PgnNode<PgnNodeData>? node = target;
    while (node is PgnChildNode<PgnNodeData>) {
      path.add(node);
      node = _parentMap[node];
    }
    return path.reversed.toList();
  }

  void _navigate(List<PgnChildNode<PgnNodeData>> newPath) {
    setState(() {
      _path = List.of(newPath);
      _promotionMove = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentRowKey.currentContext != null) {
        Scrollable.ensureVisible(
          _currentRowKey.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onMove(Move move, {bool? viaDragAndDrop}) {
    if (move is NormalMove && _isPromotionPawnMove(move)) {
      setState(() => _promotionMove = move);
      return;
    }
    _commitMove(move);
  }

  void _onPromotionSelection(Role? role) {
    if (role == null) {
      setState(() => _promotionMove = null);
      return;
    }
    if (_promotionMove != null) {
      _commitMove(_promotionMove!.withPromotion(role));
    }
  }

  void _commitMove(Move move) {
    final pos = _currentPosition;
    if (!pos.isLegal(move)) return;
    final (_, san) = pos.makeSan(move);

    for (final child in _currentNode.children) {
      if (child.data.san == san) {
        _navigate([..._path, child]);
        return;
      }
    }

    final newChild = PgnChildNode(PgnNodeData(san: san));
    _currentNode.children.add(newChild);
    final newPos = pos.play(move);
    _positionMap[newChild] = newPos;
    _moveMap[newChild] = move;
    _parentMap[newChild] = _currentNode;

    _navigate([..._path, newChild]);
  }

  bool _isPromotionPawnMove(NormalMove move) {
    final pos = _currentPosition;
    return move.promotion == null &&
        pos.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.first && pos.turn == Side.black) ||
            (move.to.rank == Rank.eighth && pos.turn == Side.white));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final boardSize = screenWidth * 0.9;
    final isFirst = _path.isEmpty;
    final isLast = _currentNode.children.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildMetadata(theme),
            const SizedBox(height: 12),
            Center(
              child: Chessboard(
                size: boardSize,
                fen: _currentPosition.fen,
                orientation: _orientation,
                lastMove: _currentLastMove,
                settings: ChessboardSettings(
                  colorScheme: _colorScheme,
                  pieceAssets: _pieceSet.assets,
                  dragFeedbackScale: 1.0,
                ),
                game: GameData(
                  playerSide: PlayerSide.both,
                  sideToMove: _currentPosition.turn,
                  validMoves: makeLegalMoves(_currentPosition),
                  isCheck: _currentPosition.isCheck,
                  promotionMove: _promotionMove,
                  onMove: _onMove,
                  onPromotionSelection: _onPromotionSelection,
                ),
              ),
            ),
            const SizedBox(height: 2),
            _buildSelectors(theme),
            const SizedBox(height: 2),
            Expanded(child: _buildMoveList(theme)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: fillColor,
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                icon: const Icon(Icons.chevron_left, size: 22),
              ),
              const Spacer(),
              IconButton(
                iconSize: 35,
                icon: const Icon(Icons.first_page),
                onPressed: isFirst ? null : () => _navigate([]),
              ),
              IconButton(
                iconSize: 35,
                icon: const Icon(Icons.navigate_before),
                onPressed: isFirst
                    ? null
                    : () => _navigate(_path.sublist(0, _path.length - 1)),
              ),
              IconButton(
                iconSize: 35,
                icon: const Icon(Icons.navigate_next),
                onPressed: isLast
                    ? null
                    : () =>
                        _navigate([..._path, _currentNode.children.first]),
              ),
              IconButton(
                iconSize: 35,
                icon: const Icon(Icons.last_page),
                onPressed: isLast
                    ? null
                    : () {
                        var node = _currentNode;
                        final ext = <PgnChildNode<PgnNodeData>>[];
                        while (node.children.isNotEmpty) {
                          final child = node.children.first;
                          ext.add(child);
                          node = child;
                        }
                        _navigate([..._path, ...ext]);
                      },
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadata(ThemeData theme) {
    String? tag(String key) {
      final v = _game.headers[key];
      return (v == null || v.isEmpty || v.startsWith('?')) ? null : v;
    }

    final white = tag('White');
    final black = tag('Black');
    final result = tag('Result');
    final event = tag('Event');
    final round = tag('Round');
    final players =
        (white != null && black != null) ? '$white − $black' : null;
    final parts = [event, if (round != null) 'Round $round'].nonNulls.toList();
    final tournament = parts.isEmpty ? null : parts.join(' · ');

    return Column(
      children: [
        if (players != null)
          Text(
            players,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        if (result != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              result,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (tournament != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              tournament,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildSelectors(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 29,
          height: 29,
          child: PopupMenuButton<ChessboardColorScheme>(
            iconSize: 18,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Board colour',
            position: PopupMenuPosition.under,
            constraints: const BoxConstraints(maxHeight: 300),
            onSelected: (scheme) {
              final label = boardColorSchemes
                  .firstWhere((e) => e.$2 == scheme)
                  .$1;
              boardColorSchemeNotifier.value = label;
              setState(() => _colorScheme = scheme);
            },
            itemBuilder: (_) => [
              for (final (label, scheme) in boardColorSchemes)
                PopupMenuItem(
                  value: scheme,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: scheme.darkSquare,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Text(label),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 29,
          height: 29,
          child: PopupMenuButton<PieceSet>(
            iconSize: 18,
            padding: EdgeInsets.zero,
            icon: const Icon(LucideIcons.chess_king),
            tooltip: 'Piece set',
            position: PopupMenuPosition.under,
            constraints: const BoxConstraints(maxHeight: 300),
            onSelected: (set) {
              boardPieceSetNotifier.value = set.name;
              setState(() => _pieceSet = set);
            },
            itemBuilder: (_) => [
              for (final set in PieceSet.values)
                PopupMenuItem(value: set, child: Text(set.label)),
            ],
          ),
        ),
        IconButton(
          iconSize: 18,
          constraints: BoxConstraints.tightFor(width: 29, height: 29),
          padding: EdgeInsets.zero,
          icon: const Icon(LucideIcons.rotate_ccw),
          tooltip: 'Flip board',
          onPressed: () => setState(
            () => _orientation = _orientation == Side.white
                ? Side.black
                : Side.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMoveList(ThemeData theme) {
    final mainLine = _mainLine;
    if (mainLine.isEmpty && _game.moves.children.isEmpty) {
      return const SizedBox.shrink();
    }

    // Collect every branch point in the tree, keyed by the row after which
    // the variation block should be inserted.
    //   root's children[1+]       → insertAfterRow 0, startPly 0
    //   mainLine[j]'s children[1+] → insertAfterRow (j+1)~/2, startPly j+1
    final branches = <int, List<(PgnNode<PgnNodeData>, int)>>{};

    void addBranch(PgnNode<PgnNodeData> node, int startPly, int row) {
      if (node.children.length > 1) {
        (branches[row] ??= []).add((node, startPly));
      }
    }

    addBranch(_game.moves, 0, 0);
    for (int j = 0; j < mainLine.length; j++) {
      addBranch(mainLine[j], j + 1, (j + 1) ~/ 2);
    }

    final mainRowCount = (mainLine.length + 1) ~/ 2;

    // endRow covers main rows plus any branch rows that fall past the last row
    // (possible when mainLine.length is even and the last node has children).
    final endRow = branches.isEmpty
        ? mainRowCount
        : branches.keys.fold(
            mainRowCount,
            (prev, k) => k + 1 > prev ? k + 1 : prev,
          );

    if (endRow == 0) return const SizedBox.shrink();

    final widgets = <Widget>[];
    for (int r = 0; r < endRow; r++) {
      if (r < mainRowCount) {
        widgets.add(_buildMainRow(theme, r, mainLine));
      }
      for (final (node, startPly) in (branches[r] ?? <(PgnNode<PgnNodeData>, int)>[])) {
        widgets.add(_buildAllVariations(theme, node, startPly));
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: widgets,
    );
  }

  Widget _buildMainRow(
    ThemeData theme,
    int rowIndex,
    List<PgnChildNode<PgnNodeData>> mainLine,
  ) {
    final wPly = rowIndex * 2;
    final bPly = rowIndex * 2 + 1;
    final wNode = wPly < mainLine.length ? mainLine[wPly] : null;
    final bNode = bPly < mainLine.length ? mainLine[bPly] : null;
    final isCurrentRow =
        _onMainLine && _path.isNotEmpty && rowIndex == (_path.length - 1) ~/ 2;

    return _buildMoveRow(
      key: isCurrentRow ? _currentRowKey : ValueKey('m$rowIndex'),
      theme: theme,
      moveNumber: rowIndex + 1,
      whiteSan: wNode?.data.san,
      blackSan: bNode?.data.san,
      isWhiteActive: _onMainLine &&
          wNode != null &&
          _path.isNotEmpty &&
          _path.last == wNode,
      isBlackActive: _onMainLine &&
          bNode != null &&
          _path.isNotEmpty &&
          _path.last == bNode,
      onWhiteTap: wNode != null ? () => _navigate(_pathTo(wNode)) : null,
      onBlackTap: bNode != null ? () => _navigate(_pathTo(bNode)) : null,
    );
  }

  // Render all non-main-line children of branchNode as variation blocks.
  Widget _buildAllVariations(
    ThemeData theme,
    PgnNode<PgnNodeData> branchNode,
    int startPly,
  ) {
    final blocks = <Widget>[];
    for (int k = 1; k < branchNode.children.length; k++) {
      blocks.add(_buildVariationBlock(theme, branchNode.children[k], startPly, 0));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  // Render one variation branch inline, recursing for any sub-branches.
  // startPly = position ply (0 = initial) before startNode's move.
  // depth = indentation level (0 = top variation, 1 = nested, …).
  Widget _buildVariationBlock(
    ThemeData theme,
    PgnChildNode<PgnNodeData> startNode,
    int startPly,
    int depth,
  ) {
    // Follow first children to build the "main path" of this variation.
    final linePath = _collectLinePath(startNode);
    final items = <Widget>[
      _buildVariationInlineRow(theme, linePath, startPly, depth),
    ];

    // Any node in the line that has additional children spawns nested blocks.
    for (int j = 0; j < linePath.length; j++) {
      final node = linePath[j];
      final movePly = startPly + j + 1;
      for (int k = 1; k < node.children.length; k++) {
        items.add(
          _buildVariationBlock(theme, node.children[k], movePly, depth + 1),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }

  // Walk first children from startNode, collecting the linear path.
  List<PgnChildNode<PgnNodeData>> _collectLinePath(
    PgnChildNode<PgnNodeData> startNode,
  ) {
    final path = <PgnChildNode<PgnNodeData>>[startNode];
    PgnNode<PgnNodeData> node = startNode;
    while (node.children.isNotEmpty) {
      final next = node.children.first;
      path.add(next);
      node = next;
    }
    return path;
  }

  // Render a sequence of moves as an inline Wrap at the given indentation depth.
  Widget _buildVariationInlineRow(
    ThemeData theme,
    List<PgnChildNode<PgnNodeData>> nodes,
    int startPly, // position ply before nodes[0]'s move
    int depth,
  ) {
    final tokens = <Widget>[];
    for (int j = 0; j < nodes.length; j++) {
      final positionPly = startPly + j;
      final isWhiteTurn = positionPly % 2 == 0;
      final moveNumber = (positionPly + 2) ~/ 2;

      if (isWhiteTurn || j == 0) {
        tokens.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 1),
            child: Text(
              isWhiteTurn ? '$moveNumber.' : '$moveNumber…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
      }

      final node = nodes[j];
      final isActive = _path.isNotEmpty && _path.last == node;
      tokens.add(_buildInlineMoveTile(theme, node.data.san, isActive, () => _navigate(_pathTo(node))));
    }

    return Padding(
      key: _path.isNotEmpty && nodes.contains(_path.last) ? _currentRowKey : null,
      padding: EdgeInsets.fromLTRB(8.0 + depth * 20, 3, 8, 3),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 4,
        children: tokens,
      ),
    );
  }

  Widget _buildInlineMoveTile(
    ThemeData theme,
    String san,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        margin: const EdgeInsets.only(right: 1),
        decoration: active
            ? BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(5),
              )
            : null,
        child: Text(
          _toFigurine(san),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: active ? theme.colorScheme.onPrimary : null,
            fontWeight: active ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMoveRow({
    Key? key,
    required ThemeData theme,
    required int moveNumber,
    bool startsOnBlack = false,
    required String? whiteSan,
    required String? blackSan,
    required bool isWhiteActive,
    required bool isBlackActive,
    required VoidCallback? onWhiteTap,
    required VoidCallback? onBlackTap,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              child: Text(
                startsOnBlack ? '$moveNumber...' : '$moveNumber.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: whiteSan != null && !startsOnBlack
                  ? _moveTile(theme, whiteSan, isWhiteActive, onWhiteTap!)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 96,
              child: blackSan != null
                  ? _moveTile(theme, blackSan, isBlackActive, onBlackTap!)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moveTile(
    ThemeData theme,
    String san,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: active
            ? BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        child: Text(
          _toFigurine(san),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: active ? theme.colorScheme.onPrimary : null,
            fontWeight: active ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }
}
