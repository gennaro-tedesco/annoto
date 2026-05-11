import 'dart:async';
import 'dart:math' as math;

import 'package:annoto/app/themes.dart';
import 'package:annoto/app/ui_sizes.dart';
import 'package:annoto/models/puzzle.dart';
import 'package:annoto/models/puzzle_collection.dart';
import 'package:annoto/repositories/puzzle_collection_repository.dart';
import 'package:annoto/services/chess_engine_service.dart';
import 'package:annoto/services/engine_service_scope.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

ChessboardColorScheme _schemeByLabel(String label) =>
    boardColorSchemes
        .where((e) => e.$1 == label)
        .map((e) => e.$2)
        .firstOrNull ??
    ChessboardColorScheme.brown;

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  static const routeName = '/puzzle';

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with SingleTickerProviderStateMixin {
  static const double _boardWidthFactor = 0.9;
  static const Duration _opponentReplyDelay = Duration(milliseconds: 500);
  static const double _sideIndicatorSize = 10.0;
  static const double _selectorSidePadding = 8.0;
  static const double _boardSelectorsGap = 6.0;
  static const double _selectorGap = 4.0;
  static const double _engineGaugeHeight = AppControlSize.compact * 0.6;
  static const double _panelOutlineAlpha = 0.08;
  static const double _enginePanelMaxHeight = 100.0;
  static const double _bottomNavBarVerticalPadding = 12.0;
  static const double _navButtonWidthFactor = 0.3;
  static const int _pvFoldDepth = 10;
  static const _pieceSymbols = {
    'N': '♘',
    'B': '♗',
    'R': '♖',
    'Q': '♕',
    'K': '♔',
  };

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  late PuzzleCollection _collection;
  int _currentChapter = 0;
  final Map<int, PuzzleStatus> _chapterResults = {};

  late Puzzle _puzzle;
  Position _position = Chess.initial;
  List<String> _solutionMoves = const [];
  Side _solvingSide = Side.white;
  int _currentMoveIndex = 0;
  PuzzleStatus _status = PuzzleStatus.notStarted;
  NormalMove? _promotionMove;
  Move? _lastMove;
  bool _opponentReplying = false;
  int _puzzleGeneration = 0;
  bool _initialised = false;

  final List<Position> _positionHistory = [];
  final List<Move> _moveHistory = [];
  int _historyViewIndex = -1;
  bool _showingSolution = false;

  late ChessboardColorScheme _colorScheme;
  late PieceSet _pieceSet;

  ChessEngineService? _engine;
  bool _engineReady = false;
  bool _engineStarting = false;
  bool _engineEnabled = false;
  List<EngineEvaluation> _evaluations = [];
  StreamSubscription<List<EngineEvaluation>>? _analysisSub;
  final _expandedPvs = <int>{};
  int _multiPv = 1;

  Position get _boardPosition =>
      _historyViewIndex >= 0 ? _positionHistory[_historyViewIndex] : _position;

  Move? get _boardLastMove {
    if (_historyViewIndex > 0) return _moveHistory[_historyViewIndex - 1];
    if (_historyViewIndex == 0) return null;
    return _lastMove;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _colorScheme = _schemeByLabel(boardColorSchemeNotifier.value);
      _pieceSet = PieceSet.values.firstWhere(
        (s) => s.name == boardPieceSetNotifier.value,
        orElse: () => PieceSet.cburnett,
      );
      _collection =
          ModalRoute.of(context)!.settings.arguments as PuzzleCollection;
      _chapterResults.addAll(_collection.results);
      final start = _collection.lastVisited.clamp(
        0,
        _collection.puzzles.length - 1,
      );
      _currentChapter = start;
      _puzzle = _collection.puzzles[start];
      _initPuzzle(_puzzle);
      _engine = EngineServiceScope.maybeOf(context);
      if (_engine != null) _engineReady = _engine!.isStarted;
      _initialised = true;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _analysisSub?.cancel();
    if (_engineEnabled) _engine?.stopAnalysis();
    super.dispose();
  }

  void _initPuzzle(Puzzle puzzle) {
    _puzzleGeneration++;
    _pulseController.stop();
    _pulseController.value = 0;

    final Position pos;
    try {
      pos = Chess.fromSetup(Setup.parseFen(puzzle.fen));
    } catch (_) {
      _status = PuzzleStatus.failed;
      return;
    }

    final moves = puzzle.solutionMoves;
    if (moves.isEmpty) {
      _status = PuzzleStatus.failed;
      return;
    }

    final firstMove = Move.parse(moves.first);
    if (firstMove == null || !pos.isLegal(firstMove)) {
      _status = PuzzleStatus.failed;
      return;
    }

    _position = pos;
    _solutionMoves = moves;
    _solvingSide = pos.turn;
    _currentMoveIndex = 0;
    _status = PuzzleStatus.inProgress;
    _lastMove = null;
    _promotionMove = null;
    _opponentReplying = false;
    _positionHistory.clear();
    _positionHistory.add(pos);
    _moveHistory.clear();
    _historyViewIndex = -1;
    _showingSolution = false;

    if (_engineEnabled) _startAnalysis();
  }

  void _persistResults() {
    unawaited(
      puzzleCollectionRepository.updateResults(
        _collection.id,
        Map.of(_chapterResults),
      ),
    );
  }

  void _loadChapter(int index) {
    if (_status == PuzzleStatus.wrongMove) {
      _chapterResults[_currentChapter] = PuzzleStatus.failed;
      _persistResults();
    }
    setState(() {
      _currentChapter = index;
      _puzzle = _collection.puzzles[index];
      _initPuzzle(_puzzle);
    });
    unawaited(
      puzzleCollectionRepository.updateLastVisited(_collection.id, index),
    );
  }

  void _openChapterDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _reset() {
    setState(() => _initPuzzle(_puzzle));
  }

  void _clearAllResults() {
    setState(() => _chapterResults.clear());
    _persistResults();
  }

  void _historyGoTo(int index) {
    if (index < 0 || index >= _positionHistory.length) return;
    setState(() => _historyViewIndex = index);
    if (_engineEnabled) _startAnalysis();
  }

  void _setMultiPv(int n) {
    if (_multiPv == n) return;
    setState(() => _multiPv = n);
    if (_engineEnabled) _startAnalysis();
  }

  Future<void> _showSolution() async {
    if (_showingSolution) return;
    final initial = _positionHistory.isNotEmpty
        ? _positionHistory.first
        : _position;
    setState(() {
      _status = PuzzleStatus.failed;
      _chapterResults[_currentChapter] = PuzzleStatus.failed;
      _showingSolution = true;
      _positionHistory
        ..clear()
        ..add(initial);
      _moveHistory.clear();
      _historyViewIndex = 0;
      _position = initial;
      _lastMove = null;
    });
    _persistResults();

    Position pos = initial;
    for (final uci in _solutionMoves) {
      if (!mounted || !_showingSolution) break;
      final move = Move.parse(uci);
      if (move == null || !pos.isLegal(move)) break;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || !_showingSolution) break;
      final newPos = pos.play(move);
      pos = newPos;
      _positionHistory.add(newPos);
      _moveHistory.add(move);
      setState(() {
        _historyViewIndex = _positionHistory.length - 1;
        _position = newPos;
        _lastMove = move;
      });
    }

    if (mounted) {
      setState(() => _showingSolution = false);
      if (_engineEnabled) _startAnalysis();
    }
  }

  void _onMove(Move move, {bool? viaDragAndDrop}) {
    if (_historyViewIndex >= 0) {
      _handleHistoryMove(move);
      return;
    }
    if (move is NormalMove && _isPromotionPawnMove(move)) {
      setState(() => _promotionMove = move);
      return;
    }
    _handleUserMove(move);
  }

  void _onPromotionSelection(Role? role) {
    if (role == null) {
      setState(() => _promotionMove = null);
      return;
    }
    if (_promotionMove != null) {
      final move = _promotionMove!.withPromotion(role);
      setState(() => _promotionMove = null);
      if (_historyViewIndex >= 0) {
        _handleHistoryMove(move);
      } else {
        _handleUserMove(move);
      }
    }
  }

  bool _isPromotionPawnMove(NormalMove move) {
    final pos = _boardPosition;
    return move.promotion == null &&
        pos.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.first && pos.turn == Side.black) ||
            (move.to.rank == Rank.eighth && pos.turn == Side.white));
  }

  void _handleHistoryMove(Move move) {
    if (move is NormalMove && _isPromotionPawnMove(move)) {
      setState(() => _promotionMove = move);
      return;
    }
    final currentPos = _boardPosition;
    if (!currentPos.isLegal(move)) return;
    final newPos = currentPos.play(move);
    _positionHistory.removeRange(
      _historyViewIndex + 1,
      _positionHistory.length,
    );
    _moveHistory.removeRange(_historyViewIndex, _moveHistory.length);
    _positionHistory.add(newPos);
    _moveHistory.add(move);
    setState(() => _historyViewIndex = _positionHistory.length - 1);
    if (_engineEnabled) _startAnalysis();
  }

  void _markSolved() {
    _status = PuzzleStatus.solved;
    _historyViewIndex = _positionHistory.length - 1;
    if (_chapterResults[_currentChapter] != PuzzleStatus.failed) {
      _chapterResults[_currentChapter] = PuzzleStatus.solved;
    }
    if (_currentChapter < _collection.puzzles.length - 1) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _handleUserMove(Move move) {
    if (_status == PuzzleStatus.solved ||
        _status == PuzzleStatus.failed ||
        _opponentReplying) {
      return;
    }

    if (!_position.isLegal(move)) return;

    final expected = _solutionMoves[_currentMoveIndex];
    if (move.uci != expected) {
      setState(() {
        _status = PuzzleStatus.wrongMove;
        _chapterResults[_currentChapter] = PuzzleStatus.failed;
      });
      _persistResults();
      return;
    }

    final newPos = _position.play(move);
    _positionHistory.add(newPos);
    _moveHistory.add(move);
    setState(() {
      _position = newPos;
      _lastMove = move;
      _currentMoveIndex++;
      _status = PuzzleStatus.inProgress;
    });

    if (_engineEnabled) _startAnalysis();

    if (_currentMoveIndex >= _solutionMoves.length) {
      setState(() => _markSolved());
      _persistResults();
      return;
    }

    final generation = _puzzleGeneration;
    setState(() => _opponentReplying = true);
    Future.delayed(_opponentReplyDelay, () => _playOpponentReply(generation));
  }

  void _playOpponentReply(int generation) {
    if (!mounted) return;
    if (generation != _puzzleGeneration) return;
    final replyUci = _solutionMoves[_currentMoveIndex];
    final replyMove = Move.parse(replyUci);
    if (replyMove == null || !_position.isLegal(replyMove)) {
      setState(() {
        _status = PuzzleStatus.failed;
        _opponentReplying = false;
        _chapterResults[_currentChapter] = PuzzleStatus.failed;
      });
      _persistResults();
      return;
    }

    final newPos = _position.play(replyMove);
    _positionHistory.add(newPos);
    _moveHistory.add(replyMove);
    setState(() {
      _position = newPos;
      _lastMove = replyMove;
      _currentMoveIndex++;
      _opponentReplying = false;
    });

    if (_engineEnabled) _startAnalysis();

    if (_currentMoveIndex >= _solutionMoves.length) {
      setState(() => _markSolved());
      _persistResults();
    }
  }

  Future<void> _toggleEngine() async {
    final engine = _engine;
    if (engine == null) return;
    if (_engineStarting) return;
    if (selectedEnginePackageNotifier.value == null) {
      NotificationService.showInfo('Select an engine first');
      return;
    }
    if (!_engineReady) {
      setState(() => _engineStarting = true);
      try {
        await engine.init();
        if (!mounted) return;
        setState(() {
          _engineReady = true;
          _engineStarting = false;
        });
      } catch (error) {
        if (mounted) {
          setState(() {
            _engineReady = false;
            _engineStarting = false;
            _engineEnabled = false;
          });
          NotificationService.showError('Engine failed to start: $error');
        }
        return;
      }
    }
    final enabling = !_engineEnabled;
    setState(() => _engineEnabled = enabling);
    if (enabling) {
      _startAnalysis();
    } else {
      _analysisSub?.cancel();
      _analysisSub = null;
      engine.stopAnalysis();
      setState(() => _evaluations = []);
    }
  }

  void _startAnalysis() {
    final engine = _engine;
    if (engine == null || !mounted) return;
    _analysisSub?.cancel();
    setState(() {
      _evaluations = [];
      _expandedPvs.clear();
    });
    try {
      _analysisSub = engine
          .startAnalysis(_boardPosition.fen, multiPv: _multiPv)
          .listen((evals) {
            if (mounted) setState(() => _evaluations = evals);
          });
    } catch (error) {
      if (mounted) {
        setState(() => _engineEnabled = false);
        NotificationService.showError('Engine analysis failed: $error');
      }
    }
  }

  int _cpFromWhite(int cp) => _boardPosition.turn == Side.white ? cp : -cp;

  double _winningChancesFromCp(int cp) {
    const multiplier = -0.00368208;
    return (2 / (1 + math.exp(multiplier * cp.clamp(-1000, 1000))) - 1).clamp(
      -1.0,
      1.0,
    );
  }

  double? _winningChances(EngineEvaluation eval) {
    final cp = eval.cp;
    if (cp != null) return _winningChancesFromCp(cp);
    final mate = eval.mate;
    if (mate == null || mate == 0) return null;
    return _winningChancesFromCp(mate > 0 ? 1000 : -1000);
  }

  String _toFigurine(String san) {
    if (san.isEmpty) return san;
    final symbol = _pieceSymbols[san[0]];
    return symbol != null ? '$symbol${san.substring(1)}' : san;
  }

  List<(int, bool, String)> _pvToSan(List<String> pv) {
    final result = <(int, bool, String)>[];
    Position pos = _boardPosition;
    for (final uci in pv) {
      final move = Move.parse(uci);
      if (move == null || !pos.isLegal(move)) break;
      final isWhite = pos.turn == Side.white;
      final moveNum = pos.fullmoves;
      final (newPos, san) = pos.makeSan(move);
      result.add((moveNum, isWhite, san));
      pos = newPos;
    }
    return result;
  }

  List<Widget> _buildPvTokens(
    ThemeData theme,
    List<(int, bool, String)> tokens,
  ) {
    final textStyle = theme.textTheme.bodyMedium;
    final widgets = <Widget>[];
    for (int i = 0; i < tokens.length; i++) {
      final (moveNum, isWhite, san) = tokens[i];
      if (isWhite || i == 0) {
        widgets.add(
          Text(
            isWhite ? '$moveNum. ' : '$moveNum… ',
            style: textStyle?.copyWith(color: theme.colorScheme.outline),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(_toFigurine(san), style: textStyle),
        ),
      );
    }
    return widgets;
  }

  int _engineArrowCategory(double loss) {
    if (loss >= 0.2) return 2;
    if (loss >= 0.1) return 1;
    return 0;
  }

  Color _engineArrowColor(int category, double strength, int categoryIndex) {
    final alpha = (0.86 - categoryIndex * 0.16).clamp(0.38, 0.86);
    if (category == 2) {
      return const Color(0xFFEF5350).withValues(alpha: alpha);
    }
    if (category == 1) {
      return const Color(0xFFFBC02D).withValues(alpha: alpha);
    }
    return Color.lerp(
      const Color(0xFF81C784),
      const Color(0xFF2E7D32),
      strength,
    )!.withValues(alpha: alpha);
  }

  ISet<Shape> _engineShapes() {
    if (_evaluations.isEmpty) return const ISetConst({});
    final baseline = _winningChances(_evaluations.first);
    if (baseline == null) return const ISetConst({});

    final shapes = <Shape>{};
    final seenMoves = <String>{};
    final categoryCounts = <int, int>{};

    for (final eval in _evaluations) {
      final uci = eval.pv.firstOrNull ?? eval.bestMove;
      if (uci == null || !seenMoves.add(uci)) continue;
      final move = Move.parse(uci);
      if (move is! NormalMove || !_boardPosition.isLegal(move)) continue;
      final winningChances = _winningChances(eval);
      if (winningChances == null) continue;
      final loss = (baseline - winningChances).clamp(0.0, 1.0);
      final category = _engineArrowCategory(loss);
      final categoryIndex = categoryCounts[category] ?? 0;
      categoryCounts[category] = categoryIndex + 1;
      final strength = category == 0 ? 1 - (loss / 0.1).clamp(0.0, 1.0) : 0.0;
      shapes.add(
        Arrow(
          color: _engineArrowColor(category, strength, categoryIndex),
          orig: move.from,
          dest: move.to,
          scale: 0.42,
        ),
      );
    }
    return shapes.lock;
  }

  PlayerSide get _playerSide {
    if (_historyViewIndex >= 0) return PlayerSide.both;
    if (_status == PuzzleStatus.solved ||
        _status == PuzzleStatus.failed ||
        _opponentReplying) {
      return PlayerSide.none;
    }
    return _solvingSide == Side.white ? PlayerSide.white : PlayerSide.black;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final hasMultiple = _collection.puzzles.length > 1;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildChapterDrawer(theme),
      drawerEnableOpenDragGesture: false,
      bottomNavigationBar: SafeArea(
        top: false,
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
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > constraints.maxHeight) {
              return _buildLandscapeBody(
                context,
                theme,
                constraints,
                hasMultiple,
              );
            }

            final boardSize = constraints.maxWidth * _boardWidthFactor;
            return Column(
              children: [
                const SizedBox(height: 12),
                _buildMetadata(theme),
                const SizedBox(height: 12),
                _buildBoardArea(constraints.maxWidth, boardSize),
                const SizedBox(height: _boardSelectorsGap),
                _buildSelectors(theme, constraints.maxWidth),
                const SizedBox(height: _selectorGap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _selectorSidePadding,
                  ),
                  child: SizedBox(
                    height: _engineGaugeHeight,
                    child: _engineEnabled ? _buildEvalGauge(theme) : null,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildBelowBoard(theme),
                        _buildMoveNavButtons(theme),
                        const SizedBox(height: _selectorGap),
                        _buildSolutionLine(theme),
                        if (_engineEnabled) ...[
                          const SizedBox(height: _selectorGap),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: _enginePanelMaxHeight,
                            ),
                            child: _buildEvalPanel(theme),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (hasMultiple) _buildNavButtons(context, theme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeBody(
    BuildContext context,
    ThemeData theme,
    BoxConstraints constraints,
    bool hasMultiple,
  ) {
    final halfWidth = constraints.maxWidth / 2;
    const columnOverhead =
        _boardSelectorsGap +
        AppControlSize.compact +
        _selectorGap +
        _engineGaugeHeight;
    final boardSize =
        ((constraints.maxHeight - columnOverhead) * _boardWidthFactor).clamp(
          0.0,
          halfWidth - _selectorSidePadding * 2,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: halfWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBoardArea(halfWidth, boardSize),
              const SizedBox(height: _boardSelectorsGap),
              _buildSelectors(theme, halfWidth),
              const SizedBox(height: _selectorGap),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _selectorSidePadding,
                ),
                child: SizedBox(
                  height: _engineGaugeHeight,
                  child: _engineEnabled ? _buildEvalGauge(theme) : null,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 1,
          child: ColoredBox(color: theme.colorScheme.outlineVariant),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildMetadata(theme),
                      const SizedBox(height: 8),
                      _buildBelowBoard(theme),
                      _buildMoveNavButtons(theme),
                      const SizedBox(height: _selectorGap),
                      _buildSolutionLine(theme),
                      if (_engineEnabled) ...[
                        const SizedBox(height: _selectorGap),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: _enginePanelMaxHeight,
                          ),
                          child: _buildEvalPanel(theme),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasMultiple)
                _buildNavButtons(context, theme, availableWidth: halfWidth - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadata(ThemeData theme) {
    final metadataColumn = Text(
      _puzzle.type,
      style: theme.textTheme.titleMedium,
      textAlign: TextAlign.center,
    );

    if (_collection.puzzles.length <= 1) return metadataColumn;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          child: IconButton(
            tooltip: 'Select puzzle',
            padding: EdgeInsets.zero,
            onPressed: _openChapterDrawer,
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_outlined, size: 18),
                Text(
                  '${_currentChapter + 1}/${_collection.puzzles.length}',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: Center(child: metadataColumn)),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget? _buildChapterDrawer(ThemeData theme) {
    if (_collection.puzzles.length <= 1) return null;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Puzzles', style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Clear all results',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      LucideIcons.refresh_cw,
                      size: AppIconSize.inlineAction,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _clearAllResults();
                    },
                  ),
                ],
              ),
            ),
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                itemCount: _collection.puzzles.length,
                separatorBuilder: (_, _) =>
                    Divider(color: theme.colorScheme.outlineVariant, height: 1),
                itemBuilder: (context, index) {
                  final puzzle = _collection.puzzles[index];
                  final selected = index == _currentChapter;
                  final result = _chapterResults[index];
                  return Material(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        _loadChapter(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${index + 1} ${puzzle.type}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            if (result == PuzzleStatus.solved)
                              const Icon(
                                Icons.check,
                                size: AppIconSize.smallStatus,
                                color: Colors.green,
                              )
                            else if (result == PuzzleStatus.failed)
                              Icon(
                                Icons.close,
                                size: AppIconSize.smallStatus,
                                color: theme.colorScheme.error,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardArea(double availableWidth, double boardSize) {
    final terminal =
        (_status == PuzzleStatus.solved || _status == PuzzleStatus.failed) &&
        _historyViewIndex < 0;
    return SizedBox(
      width: availableWidth,
      height: boardSize,
      child: Center(
        child: IgnorePointer(
          ignoring: terminal,
          child: _buildChessboard(boardSize),
        ),
      ),
    );
  }

  Widget _buildChessboard(double boardSize) {
    final shapes = _engineEnabled
        ? _engineShapes()
        : const ISetConst<Shape>({});
    final boardPos = _boardPosition;
    return Chessboard(
      size: boardSize,
      fen: boardPos.fen,
      orientation: _solvingSide,
      lastMove: _boardLastMove,
      settings: ChessboardSettings(
        colorScheme: _colorScheme,
        pieceAssets: _pieceSet.assets,
        dragFeedbackScale: 1.0,
        dragTargetKind: DragTargetKind.none,
      ),
      shapes: shapes.isEmpty ? null : shapes,
      game: GameData(
        playerSide: _playerSide,
        sideToMove: boardPos.turn,
        validMoves: makeLegalMoves(boardPos),
        isCheck: boardPos.isCheck,
        promotionMove: _promotionMove,
        onMove: _onMove,
        onPromotionSelection: _onPromotionSelection,
      ),
    );
  }

  Widget _buildSelectors(ThemeData theme, double boardSize) {
    const buttonSize = AppControlSize.compact;
    const primaryIconSize = AppIconSize.inlineAction;
    const buttonConstraints = BoxConstraints.tightFor(
      width: buttonSize,
      height: buttonSize,
    );

    Widget wrapCompactControl(Widget child) {
      return SizedBox(width: buttonSize, height: buttonSize, child: child);
    }

    final resetBtn = wrapCompactControl(
      IconButton(
        iconSize: primaryIconSize,
        constraints: buttonConstraints,
        padding: EdgeInsets.zero,
        icon: const Icon(LucideIcons.refresh_cw),
        tooltip: 'Reset puzzle',
        onPressed: _reset,
      ),
    );

    const secondaryIconSize = AppIconSize.smallStatus;

    final cpuBtn = wrapCompactControl(
      IconButton(
        iconSize: primaryIconSize,
        constraints: buttonConstraints,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: _engineEnabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
        icon: _engineStarting
            ? SizedBox.square(
                dimension: primaryIconSize,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.cpu),
        tooltip: _engineStarting
            ? 'Starting engine'
            : _engineEnabled
            ? 'Disable engine'
            : 'Enable engine',
        onPressed: _engine == null ? null : () => unawaited(_toggleEngine()),
      ),
    );

    final incrementBtn = wrapCompactControl(
      IconButton(
        iconSize: secondaryIconSize,
        constraints: buttonConstraints,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.add),
        onPressed: _engineEnabled && _multiPv < 5
            ? () => _setMultiPv(_multiPv + 1)
            : null,
      ),
    );

    final decrementBtn = wrapCompactControl(
      IconButton(
        iconSize: secondaryIconSize,
        constraints: buttonConstraints,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.remove),
        onPressed: _engineEnabled && _multiPv > 1
            ? () => _setMultiPv(_multiPv - 1)
            : null,
      ),
    );

    final canShowSolution =
        !_showingSolution &&
        (_status == PuzzleStatus.inProgress ||
            _status == PuzzleStatus.wrongMove ||
            _status == PuzzleStatus.notStarted);

    final solutionBtn = canShowSolution
        ? wrapCompactControl(
            IconButton(
              iconSize: primaryIconSize,
              constraints: buttonConstraints,
              padding: EdgeInsets.zero,
              icon: const Icon(LucideIcons.lightbulb),
              tooltip: 'Show solution',
              onPressed: () => unawaited(_showSolution()),
            ),
          )
        : null;

    return Center(
      child: SizedBox(
        width: boardSize,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _selectorSidePadding),
          child: SizedBox(
            height: buttonSize,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      resetBtn,
                      if (solutionBtn != null) ...[
                        const SizedBox(width: _selectorGap),
                        solutionBtn,
                      ],
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      cpuBtn,
                      const SizedBox(width: _selectorGap),
                      incrementBtn,
                      const SizedBox(width: _selectorGap),
                      decrementBtn,
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

  Widget _buildEvalGauge(ThemeData theme) {
    const maxGaugePawns = 7;
    double whiteRatio = 0.5;
    int depth = 0;
    String? evalText;

    if (_evaluations.isNotEmpty) {
      final eval = _evaluations.first;
      depth = eval.depth;
      if (eval.mate != null) {
        final mate = _boardPosition.turn == Side.white
            ? eval.mate!
            : -eval.mate!;
        whiteRatio = mate > 0 ? 1.0 : 0.0;
        evalText = '#$mate';
      } else if (eval.cp != null) {
        final cp = _cpFromWhite(eval.cp!);
        final maxGaugeCentipawns = maxGaugePawns * 100;
        whiteRatio =
            (cp.clamp(-maxGaugeCentipawns, maxGaugeCentipawns) +
                maxGaugeCentipawns) /
            (maxGaugeCentipawns * 2);
        final pawns = cp / 100.0;
        evalText = pawns >= 0
            ? '+${pawns.toStringAsFixed(2)}'
            : pawns.toStringAsFixed(2);
      }
    }

    final labelParts = [
      if (evalText != null) evalText,
      if (depth > 0) 'd$depth',
    ];
    final gaugeLabel = labelParts.join(' / ');
    final labelTextStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.primary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black87),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: 0,
                top: 0,
                bottom: 0,
                width: w * whiteRatio,
                child: const ColoredBox(color: Colors.white),
              ),
              Positioned(
                left: w / 2 - 0.5,
                top: 0,
                bottom: 0,
                child: Container(width: 1, color: Colors.grey.shade500),
              ),
              if (gaugeLabel.isNotEmpty)
                Center(child: Text(gaugeLabel, style: labelTextStyle)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEvalPanel(ThemeData theme) {
    final panelColor = Color.alphaBlend(
      theme.colorScheme.outline.withValues(alpha: _panelOutlineAlpha),
      theme.scaffoldBackgroundColor,
    );

    if (_evaluations.isEmpty) {
      return ColoredBox(
        color: panelColor,
        child: const Center(
          child: SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    return ColoredBox(
      color: panelColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          for (int i = 0; i < _evaluations.length; i++)
            _buildEvalLine(theme, _evaluations[i], i),
        ],
      ),
    );
  }

  Widget _buildEvalLine(ThemeData theme, EngineEvaluation eval, int pvIndex) {
    final String? evalText;
    if (eval.mate != null) {
      final mate = _boardPosition.turn == Side.white ? eval.mate! : -eval.mate!;
      evalText = '#$mate';
    } else if (eval.cp != null) {
      final pawns = _cpFromWhite(eval.cp!) / 100.0;
      evalText = pawns >= 0
          ? '+${pawns.toStringAsFixed(2)}'
          : pawns.toStringAsFixed(2);
    } else {
      evalText = null;
    }

    final pvTokens = _pvToSan(eval.pv);
    final isExpanded = _expandedPvs.contains(pvIndex);
    final canFold = pvTokens.length > _pvFoldDepth;
    final visibleTokens = canFold && !isExpanded
        ? pvTokens.sublist(0, _pvFoldDepth)
        : pvTokens;
    final textStyle = theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (evalText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                evalText,
                style: textStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._buildPvTokens(theme, visibleTokens),
                  if (canFold && !isExpanded)
                    GestureDetector(
                      onTap: () => setState(() => _expandedPvs.add(pvIndex)),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '…',
                              style: textStyle?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (canFold && isExpanded)
                    GestureDetector(
                      onTap: () => setState(() => _expandedPvs.remove(pvIndex)),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.chevron_left,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionLine(ThemeData theme) {
    final spans = <InlineSpan>[];
    final count = _historyViewIndex >= 0 ? _moveHistory.length : 0;
    for (int i = 0; i < count; i++) {
      final pos = _positionHistory[i];
      final (_, san) = pos.makeSan(_moveHistory[i]);
      final isWhite = pos.turn == Side.white;
      final isCurrent = _historyViewIndex > 0 && i == _historyViewIndex - 1;
      if (isWhite || i == 0) {
        spans.add(
          TextSpan(
            text: isWhite ? '${pos.fullmoves}. ' : '${pos.fullmoves}… ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: '${_toFigurine(san)} ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isCurrent ? theme.colorScheme.primary : null,
            fontWeight: isCurrent ? FontWeight.w600 : null,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: RichText(
          text: TextSpan(style: theme.textTheme.bodyMedium, children: spans),
        ),
      ),
    );
  }

  Widget _buildBelowBoard(ThemeData theme) {
    final dotColor = _solvingSide == Side.white ? Colors.white : Colors.black;
    final Widget? status = _status == PuzzleStatus.solved
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('puzzle solved!', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.chess_king,
                size: AppIconSize.inlineAction,
                color: Colors.green,
              ),
            ],
          )
        : _status == PuzzleStatus.wrongMove
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('wrong move, try again', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              Transform.rotate(
                angle: math.pi,
                child: Icon(
                  LucideIcons.chess_king,
                  size: AppIconSize.inlineAction,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          )
        : _status == PuzzleStatus.failed && _historyViewIndex < 0
        ? Text(
            'puzzle error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: _sideIndicatorSize,
            height: _sideIndicatorSize,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outline, width: 1),
            ),
          ),
          SizedBox(
            height: 34,
            child: status == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(child: status),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveNavButtons(ThemeData theme) {
    final inHistory = _historyViewIndex >= 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 35,
          icon: const Icon(Icons.navigate_before),
          onPressed: inHistory && _historyViewIndex > 0
              ? () => _historyGoTo(_historyViewIndex - 1)
              : null,
          onLongPress: inHistory && _historyViewIndex > 0
              ? () => _historyGoTo(0)
              : null,
        ),
        const SizedBox(width: 35),
        IconButton(
          iconSize: 35,
          icon: const Icon(Icons.navigate_next),
          onPressed:
              inHistory && _historyViewIndex < _positionHistory.length - 1
              ? () => _historyGoTo(_historyViewIndex + 1)
              : null,
          onLongPress:
              inHistory && _historyViewIndex < _positionHistory.length - 1
              ? () => _historyGoTo(_positionHistory.length - 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildNavButtons(
    BuildContext context,
    ThemeData theme, {
    double? availableWidth,
  }) {
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final buttonWidth =
        (availableWidth ?? MediaQuery.of(context).size.width) *
        _navButtonWidthFactor;

    final hasNext = _currentChapter < _collection.puzzles.length - 1;
    final pulseNext = _status == PuzzleStatus.solved && hasNext;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: buttonWidth,
            child: Material(
              color: fillColor,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _currentChapter > 0
                    ? () => _loadChapter(_currentChapter - 1)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.fast_rewind, size: 18),
                      const SizedBox(width: 6),
                      Text('PREV', style: theme.textTheme.labelMedium),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = pulseNext
                  ? 1.0 + _pulseController.value * 0.05
                  : 1.0;
              final glowColor = pulseNext
                  ? theme.colorScheme.primary.withValues(
                      alpha: 0.3 + _pulseController.value * 0.3,
                    )
                  : Colors.transparent;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: buttonWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: pulseNext
                        ? [
                            BoxShadow(
                              color: glowColor,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: pulseNext
                        ? Color.lerp(
                            fillColor,
                            theme.colorScheme.primary,
                            0.15 + _pulseController.value * 0.1,
                          )!
                        : fillColor,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: hasNext
                          ? () => _loadChapter(_currentChapter + 1)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('NEXT', style: theme.textTheme.labelMedium),
                            const SizedBox(width: 6),
                            const Icon(Icons.fast_forward, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
