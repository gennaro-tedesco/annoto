import 'package:annoto/app/themes.dart';
import 'package:annoto/app/ui_sizes.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

class BoardEditorScreen extends StatefulWidget {
  const BoardEditorScreen({super.key});

  @override
  State<BoardEditorScreen> createState() => _BoardEditorScreenState();
}

class _BoardEditorScreenState extends State<BoardEditorScreen> {
  static const double _boardWidthFactor = 0.92;
  static const double _boardSelectorsGap = 6.0;
  static const double _selectorGap = 4.0;
  static const double _selectorSidePadding = 8.0;
  static const double _bottomNavBarVerticalPadding = 12.0;
  static const double _paletteBoardGap = 12.0;
  static const double _palettePanelPadding = 4.0;
  static const double _editorPanelGap = 12.0;
  static const double _fenPaletteGap = 18.0;
  static const double _controlsSectionGap = 32.0;
  static const double _controlsRightPadding = 12.0;
  static const double _engineGaugeHeight = AppControlSize.compact * 0.6;

  static const _paletteRoles = [
    Role.queen,
    Role.rook,
    Role.bishop,
    Role.knight,
    Role.pawn,
    Role.king,
  ];

  late ChessboardColorScheme _colorScheme;
  late PieceSet _pieceSet;
  Side _orientation = Side.white;
  double _verticalDragAccum = 0.0;
  Offset? _verticalDragStartPosition;
  DateTime? _verticalDragStartTime;
  Side _sideToMove = Side.white;
  bool _whiteKingSide = false;
  bool _whiteQueenSide = false;
  bool _blackKingSide = false;
  bool _blackQueenSide = false;
  Map<Square, Piece> _pieces = {};
  Piece? _selectedPiece;
  late final TextEditingController _fenController;
  bool _syncingFen = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _fenController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _initialised = true;
      _colorScheme = _schemeByLabel(boardColorSchemeNotifier.value);
      _pieceSet = PieceSet.values.firstWhere(
        (s) => s.name == boardPieceSetNotifier.value,
        orElse: () => PieceSet.cburnett,
      );
      _fenController.text = _buildFen();
    }
  }

  @override
  void dispose() {
    _fenController.dispose();
    super.dispose();
  }

  ChessboardColorScheme _schemeByLabel(String label) =>
      boardColorSchemes
          .where((e) => e.$1 == label)
          .map((e) => e.$2)
          .firstOrNull ??
      ChessboardColorScheme.brown;

  String _buildFen() {
    final boardFen = writeFen(_pieces);
    final turn = _sideToMove == Side.white ? 'w' : 'b';
    final castling = _buildCastlingString();
    return '$boardFen $turn $castling - 0 1';
  }

  String _buildCastlingString() {
    final sb = StringBuffer();
    if (_whiteKingSide) sb.write('K');
    if (_whiteQueenSide) sb.write('Q');
    if (_blackKingSide) sb.write('k');
    if (_blackQueenSide) sb.write('q');
    return sb.isEmpty ? '-' : sb.toString();
  }

  bool _isValid() {
    try {
      final setup = Setup.parseFen(_buildFen());
      Chess.fromSetup(setup);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _syncFenController() {
    _syncingFen = true;
    _fenController.text = _buildFen();
    _syncingFen = false;
  }

  void _onFenChanged(String value) {
    if (_syncingFen) return;
    try {
      final setup = Setup.parseFen(value.trim());
      setState(() {
        _pieces = {
          for (final (square, piece) in setup.board.pieces) square: piece,
        };
        _sideToMove = setup.turn;
        _whiteKingSide = setup.castlingRights.has(Square.h1);
        _whiteQueenSide = setup.castlingRights.has(Square.a1);
        _blackKingSide = setup.castlingRights.has(Square.h8);
        _blackQueenSide = setup.castlingRights.has(Square.a8);
      });
    } catch (_) {}
  }

  void _onDroppedPiece(Square? origin, Square destination, Piece piece) {
    setState(() {
      if (origin != null) _pieces.remove(origin);
      _pieces[destination] = piece;
    });
    _syncFenController();
  }

  void _onDiscardedPiece(Square square) {
    setState(() => _pieces.remove(square));
    _syncFenController();
  }

  void _onEditedSquare(Square square) {
    if (_selectedPiece == null) return;
    setState(() => _pieces[square] = _selectedPiece!);
    _syncFenController();
  }

  void _clearBoard() {
    setState(() => _pieces = {});
    _syncFenController();
  }

  void _onConfirm() {
    if (!_isValid()) {
      NotificationService.showError('invalid position');
      return;
    }
    Navigator.of(context).pop(_buildFen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final isValid = _isValid();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return isLandscape
                ? _buildLandscapeBody(theme, constraints, isValid)
                : _buildPortraitBody(theme, constraints, isValid);
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: _bottomNavBarVerticalPadding,
          ),
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
              IconButton.filled(
                onPressed: _onConfirm,
                style: isValid
                    ? null
                    : IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.38,
                        ),
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                icon: const Icon(Icons.check, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitBody(
    ThemeData theme,
    BoxConstraints constraints,
    bool isValid,
  ) {
    final boardSize = constraints.maxWidth * _boardWidthFactor;
    final boardBlockHeight =
        boardSize +
        _boardSelectorsGap +
        AppControlSize.compact +
        _selectorGap +
        _engineGaugeHeight;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, inner) {
              final squareSize = boardSize / 8;
              final viewPadding = MediaQuery.viewPaddingOf(context);
              final bottomNavBarHeight =
                  viewPadding.bottom +
                  kMinInteractiveDimension +
                  _bottomNavBarVerticalPadding * 2;
              final screenCenterOffset =
                  (bottomNavBarHeight - viewPadding.top) / 2;
              final boardTop =
                  ((inner.maxHeight - boardBlockHeight) / 2 +
                          screenCenterOffset)
                      .clamp(
                        0.0,
                        (inner.maxHeight - boardBlockHeight).toDouble(),
                      );
              final boardBottom = boardTop + boardSize;
              final palettePanelHeight = squareSize + _palettePanelPadding * 2;
              final topColor = _orientation == Side.white
                  ? Side.black
                  : Side.white;
              final bottomColor = _orientation == Side.white
                  ? Side.white
                  : Side.black;
              return SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: inner.maxHeight - boardTop + _paletteBoardGap,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFenField(theme, boardSize),
                            const SizedBox(height: _fenPaletteGap),
                            SizedBox(
                              width: boardSize,
                              height: palettePanelHeight,
                              child: _buildPiecePalette(
                                theme,
                                topColor,
                                squareSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: boardTop,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBoardArea(constraints.maxWidth, boardSize),
                          const SizedBox(height: _selectorGap),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _selectorSidePadding,
                            ),
                            child: SizedBox(
                              height: _engineGaugeHeight,
                              child: _buildValidityGauge(theme, isValid),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (boardBottom < inner.maxHeight)
                      Positioned(
                        top: boardBottom + _paletteBoardGap,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Center(
                                child: SizedBox(
                                  width: boardSize,
                                  height: palettePanelHeight,
                                  child: _buildPiecePalette(
                                    theme,
                                    bottomColor,
                                    squareSize,
                                  ),
                                ),
                              ),
                              const SizedBox(height: _editorPanelGap),
                              _buildControlsRow(theme, boardSize),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeBody(
    ThemeData theme,
    BoxConstraints constraints,
    bool isValid,
  ) {
    final halfWidth = constraints.maxWidth / 2;
    const fixedColumnOverhead =
        _palettePanelPadding * 4 +
        _paletteBoardGap * 2 +
        _selectorGap +
        _engineGaugeHeight;
    final boardSize = ((constraints.maxHeight - fixedColumnOverhead) / 1.25)
        .clamp(0.0, halfWidth - _selectorSidePadding * 2);
    final squareSize = boardSize / 8;
    final palettePanelHeight = squareSize + _palettePanelPadding * 2;
    final topColor = _orientation == Side.white ? Side.black : Side.white;
    final bottomColor = _orientation == Side.white ? Side.white : Side.black;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: halfWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: boardSize,
                height: palettePanelHeight,
                child: _buildPiecePalette(theme, topColor, squareSize),
              ),
              const SizedBox(height: _paletteBoardGap),
              _buildBoardArea(halfWidth, boardSize),
              const SizedBox(height: _selectorGap),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _selectorSidePadding,
                ),
                child: SizedBox(
                  height: _engineGaugeHeight,
                  child: _buildValidityGauge(theme, isValid),
                ),
              ),
              const SizedBox(height: _paletteBoardGap),
              SizedBox(
                width: boardSize,
                height: palettePanelHeight,
                child: _buildPiecePalette(theme, bottomColor, squareSize),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 1,
          child: ColoredBox(color: theme.colorScheme.outlineVariant),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildControlsRow(theme, double.infinity),
              const SizedBox(height: _editorPanelGap),
              _buildFenField(theme, double.infinity),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoardArea(double availableWidth, double boardSize) {
    return SizedBox(
      width: availableWidth,
      height: boardSize,
      child: Center(
        child: Listener(
          onPointerDown: (event) {
            _verticalDragAccum = 0.0;
            _verticalDragStartPosition = event.position;
            _verticalDragStartTime = DateTime.now();
          },
          onPointerMove: (event) => _verticalDragAccum += event.delta.dy.abs(),
          onPointerUp: (event) {
            final startPosition = _verticalDragStartPosition;
            final startTime = _verticalDragStartTime;
            _verticalDragStartPosition = null;
            _verticalDragStartTime = null;
            if (startPosition == null || startTime == null) return;
            if (_verticalDragAccum < boardSize * 0.7) return;
            final elapsedSeconds =
                DateTime.now().difference(startTime).inMilliseconds / 1000;
            if (elapsedSeconds <= 0) return;
            final velocity =
                (event.position.dy - startPosition.dy) / elapsedSeconds;
            if (velocity.abs() < 50.0) return;
            setState(
              () => _orientation = _orientation == Side.white
                  ? Side.black
                  : Side.white,
            );
          },
          onPointerCancel: (_) {
            _verticalDragStartPosition = null;
            _verticalDragStartTime = null;
          },
          child: ChessboardEditor(
            size: boardSize,
            orientation: _orientation,
            pieces: _pieces,
            pointerMode: _selectedPiece != null
                ? EditorPointerMode.edit
                : EditorPointerMode.drag,
            settings: ChessboardSettings(
              colorScheme: _colorScheme,
              pieceAssets: _pieceSet.assets,
              dragFeedbackScale: 1.0,
              dragTargetKind: DragTargetKind.none,
            ),
            onDroppedPiece: _onDroppedPiece,
            onDiscardedPiece: _onDiscardedPiece,
            onTappedPiece: _onDiscardedPiece,
            onEditedSquare: _onEditedSquare,
          ),
        ),
      ),
    );
  }

  Widget _buildValidityGauge(ThemeData theme, bool isValid) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: ColoredBox(
        color: isValid
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : theme.colorScheme.error.withValues(alpha: 0.18),
      ),
    );
  }

  Widget _buildPiecePalette(ThemeData theme, Side color, double squareSize) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(_palettePanelPadding),
        child: SizedBox(
          width: double.infinity,
          height: squareSize,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final role in _paletteRoles)
                _buildPaletteItem(
                  theme,
                  Piece(color: color, role: role),
                  squareSize,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteItem(ThemeData theme, Piece piece, double squareSize) {
    final isSelected = _selectedPiece == piece;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedPiece = _selectedPiece == piece ? null : piece;
      }),
      child: Draggable<Piece>(
        data: piece,
        feedback: PieceDragFeedback(
          squareSize: squareSize,
          piece: piece,
          pieceAssets: _pieceSet.assets,
          scale: 1.0,
          offset: Offset.zero,
        ),
        childWhenDragging: SizedBox(width: squareSize, height: squareSize),
        onDragStarted: () {
          if (_selectedPiece != null) setState(() => _selectedPiece = null);
        },
        child: Container(
          width: squareSize,
          height: squareSize,
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: PieceWidget(
            piece: piece,
            size: squareSize,
            pieceAssets: _pieceSet.assets,
          ),
        ),
      ),
    );
  }

  Widget _buildControlsRow(ThemeData theme, double boardSize) {
    Widget labelChip(String label) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(label, style: theme.textTheme.bodyLarge),
        ),
      );
    }

    Widget sideToMoveButton(Side side) {
      final active = _sideToMove == side;
      return InkWell(
        onTap: () {
          setState(() => _sideToMove = side);
          _syncFenController();
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PieceWidget(
                piece: Piece(color: side, role: Role.king),
                size: 28,
                pieceAssets: _pieceSet.assets,
              ),
              const SizedBox(height: 4),
              _RadioDot(selected: active),
            ],
          ),
        ),
      );
    }

    Widget castlingSelector(
      String label,
      bool selected,
      VoidCallback onPressed,
    ) {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RadioDot(selected: selected),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget castlingRow(Side side) {
      final kingSide = side == Side.white ? _whiteKingSide : _blackKingSide;
      final queenSide = side == Side.white ? _whiteQueenSide : _blackQueenSide;
      void toggleKingSide() {
        setState(() {
          if (side == Side.white) {
            _whiteKingSide = !_whiteKingSide;
          } else {
            _blackKingSide = !_blackKingSide;
          }
        });
        _syncFenController();
      }

      void toggleQueenSide() {
        setState(() {
          if (side == Side.white) {
            _whiteQueenSide = !_whiteQueenSide;
          } else {
            _blackQueenSide = !_blackQueenSide;
          }
        });
        _syncFenController();
      }

      return Row(
        children: [
          PieceWidget(
            piece: Piece(color: side, role: Role.king),
            size: 28,
            pieceAssets: _pieceSet.assets,
          ),
          const SizedBox(width: 8),
          castlingSelector('O-O', kingSide, toggleKingSide),
          const SizedBox(width: 2),
          castlingSelector('O-O-O', queenSide, toggleQueenSide),
        ],
      );
    }

    Widget sideToMoveRow() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          sideToMoveButton(Side.white),
          const SizedBox(width: 4),
          sideToMoveButton(Side.black),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _selectorSidePadding),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelChip('castling rights'),
                    const SizedBox(height: 2),
                    castlingRow(Side.white),
                    const SizedBox(height: 2),
                    castlingRow(Side.black),
                  ],
                ),
                const SizedBox(width: _controlsSectionGap),
                Padding(
                  padding: const EdgeInsets.only(right: _controlsRightPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      labelChip('to move'),
                      const SizedBox(height: 2),
                      sideToMoveRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFenField(ThemeData theme, double boardSize) {
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    return Center(
      child: SizedBox(
        width: boardSize,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _selectorSidePadding),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      'FEN',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _fenController,
                      onChanged: _onFenChanged,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: InputDecoration(
                        hintText: 'Paste a FEN position',
                        filled: true,
                        fillColor: fillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear board',
                    onPressed: _clearBoard,
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
