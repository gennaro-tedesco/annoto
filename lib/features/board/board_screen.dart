import 'package:annoto/models/scoresheet.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  static const routeName = '/board';

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late final List<String> _fens;
  late final List<Move?> _lastMoves;
  late final List<String> _sans;
  late final Map<String, String> _tags;
  int _index = 0;
  Side _orientation = Side.white;
  ChessboardColorScheme _colorScheme = ChessboardColorScheme.brown;
  PieceSet _pieceSet = PieceSet.cburnett;
  bool _initialised = false;
  final _currentRowKey = GlobalKey();

  static const _colorSchemes = <(String, ChessboardColorScheme)>[
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      final scoresheet =
          ModalRoute.of(context)!.settings.arguments as Scoresheet;
      _tags = _parseTags(scoresheet.pgn);
      _buildPositions(scoresheet.pgn);
      _initialised = true;
    }
  }

  Map<String, String> _parseTags(String pgn) {
    final tags = <String, String>{};
    for (final m
        in RegExp(r'^\[(\w+)\s+"(.*)"\]$', multiLine: true).allMatches(pgn)) {
      final v = m.group(2)!;
      if (v.isNotEmpty && v != '?') tags[m.group(1)!] = v;
    }
    return tags;
  }

  void _buildPositions(String pgn) {
    final movesMatch = RegExp(r'\n\n(.+)', dotAll: true).firstMatch(pgn);
    final movesText = movesMatch?.group(1)?.trim() ?? pgn;
    final sans = <String>[];
    for (final m
        in RegExp(r'(\d+)\.\s*(\S+)(?:\s+(\S+))?').allMatches(movesText)) {
      final white = m.group(2) ?? '';
      if (white.isNotEmpty) sans.add(white);
      final black = m.group(3);
      if (black != null && black.isNotEmpty) sans.add(black);
    }
    final fens = <String>[Chess.initial.fen];
    final lastMoves = <Move?>[null];
    final validSans = <String>[];
    Position pos = Chess.initial;
    for (final san in sans) {
      try {
        final move = pos.parseSan(san);
        if (move == null) break;
        pos = pos.play(move);
        fens.add(pos.fen);
        lastMoves.add(move);
        validSans.add(san);
      } catch (_) {
        break;
      }
    }
    _fens = fens;
    _lastMoves = lastMoves;
    _sans = validSans;
  }

  void _navigate(int newIndex) {
    setState(() => _index = newIndex);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final boardSize = screenWidth * 0.9;
    final isFirst = _index == 0;
    final isLast = _index == _fens.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildMetadata(theme),
            const SizedBox(height: 12),
            Center(
              child: Chessboard.fixed(
                size: boardSize,
                fen: _fens[_index],
                orientation: _orientation,
                lastMove: _lastMoves[_index],
                settings: ChessboardSettings(
                  colorScheme: _colorScheme,
                  pieceAssets: _pieceSet.assets,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildSelectors(theme),
            const SizedBox(height: 4),
            Expanded(child: _buildMoveList(theme)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                icon: const Icon(Icons.first_page),
                onPressed: isFirst ? null : () => _navigate(0),
              ),
              IconButton(
                icon: const Icon(Icons.navigate_before),
                onPressed: isFirst ? null : () => _navigate(_index - 1),
              ),
              IconButton(
                icon: const Icon(Icons.navigate_next),
                onPressed: isLast ? null : () => _navigate(_index + 1),
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: isLast ? null : () => _navigate(_fens.length - 1),
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
    final white = _tags['White'];
    final black = _tags['Black'];
    final result = _tags['Result'];
    final event = _tags['Event'];
    final round = _tags['Round'];
    final players =
        (white != null && black != null) ? '$white \u2212 $black' : null;
    final parts = [
      event,
      if (round != null) 'Round $round',
    ].nonNulls.toList();
    final tournament = parts.isEmpty ? null : parts.join(' \u00b7 ');

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
        PopupMenuButton<ChessboardColorScheme>(
          icon: const Icon(Icons.palette_outlined),
          tooltip: 'Board colour',
          position: PopupMenuPosition.under,
          constraints: const BoxConstraints(maxHeight: 300),
          onSelected: (scheme) => setState(() => _colorScheme = scheme),
          itemBuilder: (_) => [
            for (final (label, scheme) in _colorSchemes)
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
        PopupMenuButton<PieceSet>(
          icon: const Icon(LucideIcons.chess_king),
          tooltip: 'Piece set',
          position: PopupMenuPosition.under,
          constraints: const BoxConstraints(maxHeight: 300),
          onSelected: (set) => setState(() => _pieceSet = set),
          itemBuilder: (_) => [
            for (final set in PieceSet.values)
              PopupMenuItem(value: set, child: Text(set.label)),
          ],
        ),
        IconButton(
          icon: const Icon(LucideIcons.rotate_ccw),
          tooltip: 'Flip board',
          onPressed: () => setState(
            () => _orientation =
                _orientation == Side.white ? Side.black : Side.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMoveList(ThemeData theme) {
    if (_sans.isEmpty) return const SizedBox.shrink();
    final rowCount = (_sans.length + 1) ~/ 2;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rowCount,
      itemBuilder: (context, i) {
        final whitePly = i * 2;
        final blackPly = i * 2 + 1;
        final whiteFen = whitePly + 1;
        final blackFen = blackPly + 1;
        final isCurrentRow = _index > 0 && i == (_index - 1) ~/ 2;
        return _buildMoveRow(
          key: isCurrentRow ? _currentRowKey : ValueKey(i),
          theme: theme,
          moveNumber: i + 1,
          whiteSan: _sans[whitePly],
          blackSan: blackPly < _sans.length ? _sans[blackPly] : null,
          isWhiteActive: _index == whiteFen,
          isBlackActive: _index == blackFen,
          onWhiteTap: () => _navigate(whiteFen),
          onBlackTap:
              blackPly < _sans.length ? () => _navigate(blackFen) : null,
        );
      },
    );
  }

  Widget _buildMoveRow({
    Key? key,
    required ThemeData theme,
    required int moveNumber,
    required String whiteSan,
    required String? blackSan,
    required bool isWhiteActive,
    required bool isBlackActive,
    required VoidCallback onWhiteTap,
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
                '$moveNumber.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: _moveTile(theme, whiteSan, isWhiteActive, onWhiteTap),
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
