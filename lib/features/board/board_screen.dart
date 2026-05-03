import 'dart:async';

import 'package:annoto/app/ui_sizes.dart';
import 'package:annoto/app/themes.dart';
import 'package:annoto/models/move_pair.dart';
import 'package:annoto/models/scoresheet.dart';
import 'package:annoto/features/settings/engine_settings_screen.dart';
import 'package:annoto/repositories/game_analysis_repository.dart';
import 'package:annoto/services/chess_engine_service.dart';
import 'package:annoto/services/engine_service_scope.dart';
import 'package:annoto/services/game_analysis_controller.dart';
import 'package:annoto/services/game_phase_divider.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:annoto/widgets/eval_graph.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

const boardColorSchemes = <(String, ChessboardColorScheme)>[
  ('Brown', ChessboardColorScheme.brown),
  ('Blue', ChessboardColorScheme.blue),
  ('Green', ChessboardColorScheme.green),
  ('Grey', ChessboardColorScheme.grey),
  ('Olive', ChessboardColorScheme.olive),
];

const _annotationColors = <CommentShapeColor, Color>{
  CommentShapeColor.green: Color(0xAA4CAF50),
  CommentShapeColor.red: Color(0xAAEF5350),
  CommentShapeColor.yellow: Color(0xAAFBC02D),
  CommentShapeColor.blue: Color(0xAA42A5F5),
};

ChessboardColorScheme _schemeByLabel(String label) =>
    boardColorSchemes
        .where((e) => e.$1 == label)
        .map((e) => e.$2)
        .firstOrNull ??
    ChessboardColorScheme.brown;

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key}) : engineMode = false, engineService = null;

  const BoardScreen.engine({super.key, required this.engineService})
    : engineMode = true;

  static const routeName = '/board';

  final bool engineMode;
  final ChessEngineService? engineService;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  static const double _boardWidthFactor = 0.9;
  static const double _engineBoardWidthFactor = 0.92;
  static const Duration _engineAnimationDuration = Duration(milliseconds: 100);
  static const int _pvFoldDepth = 10;
  static const double _panelOutlineAlpha = 0.08;
  static const double _boardSelectorsGap = 6.0;
  static const double _selectorGap = 4.0;
  static const double _selectorSidePadding = 8.0;
  static const double _chapterDrawerWidthFactor = 0.7;
  static const double _engineGaugeHeight = AppControlSize.compact * 0.6;
  static const double _chapterDrawerMaxWidth = 320.0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _chapterSearchController =
      TextEditingController();
  List<String> _games = [];
  int _currentChapter = 0;
  late PgnGame<PgnNodeData> _game;
  final _positionMap = <PgnChildNode<PgnNodeData>, Position>{};
  final _moveMap = <PgnChildNode<PgnNodeData>, Move>{};
  final _parentMap = <PgnChildNode<PgnNodeData>, PgnNode<PgnNodeData>>{};
  List<PgnChildNode<PgnNodeData>> _path = [];
  NormalMove? _promotionMove;
  Side _orientation = Side.white;
  double _verticalDragAccum = 0.0;
  late ChessboardColorScheme _colorScheme;
  late PieceSet _pieceSet;
  bool _initialised = false;
  final _currentRowKey = GlobalKey();
  final _moveScrollController = ScrollController();
  final _verticalMoveScrollController = ScrollController();
  late final ChessEngineService _engine;
  late final bool _ownsEngine;
  Timer? _debounce;
  bool _engineReady = false;
  bool _engineStarting = false;
  bool _engineEnabled = false;
  int _multiPv = 1;
  List<EngineEvaluation> _evaluations = [];
  StreamSubscription<List<EngineEvaluation>>? _analysisSub;
  final _expandedPvs = <int>{};
  GameAnalysisController? _gameAnalysis;
  bool _showAnalysisGraph = false;
  GameDivision _gameDivision = const GameDivision(
    middle: null,
    end: null,
    plies: 0,
  );

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
      final scopedService = EngineServiceScope.maybeOf(context);
      _engine = widget.engineService ?? scopedService ?? ChessEngineService();
      _ownsEngine = widget.engineService == null && scopedService == null;
      _engineReady = _engine.isStarted;
      if (widget.engineMode) {
        _game = PgnGame.parsePgn('', initHeaders: PgnGame.emptyHeaders);
        _buildMaps(_game.moves, Chess.initial);
        _gameDivision = divideGame(_mainlineBoards());
      } else {
        final scoresheet =
            ModalRoute.of(context)!.settings.arguments as Scoresheet;
        _games = splitPgnGames(scoresheet.pgn);
        if (_games.isEmpty) _games = [scoresheet.pgn];
        _game = PgnGame.parsePgn(_games[0], initHeaders: PgnGame.emptyHeaders);
        _buildMaps(_game.moves, PgnGame.startingPosition(_game.headers));
        _gameDivision = divideGame(_mainlineBoards());
      }
      _colorScheme = _schemeByLabel(boardColorSchemeNotifier.value);
      _pieceSet = PieceSet.values.firstWhere(
        (s) => s.name == boardPieceSetNotifier.value,
        orElse: () => PieceSet.cburnett,
      );
      selectedEnginePackageNotifier.addListener(_onEnginePackageChanged);
      if (!widget.engineMode) {
        _buildGameAnalysisController();
      }
      _initialised = true;
    }
  }

  void _onEnginePackageChanged() {
    setState(() {
      _engineReady = false;
      _engineEnabled = false;
      _evaluations = [];
    });
  }

  void _buildGameAnalysisController() {
    final scoresheet =
        ModalRoute.of(context)?.settings.arguments as Scoresheet?;
    if (scoresheet == null) return;
    final controller = GameAnalysisController(
      engineService: _engine,
      repository: gameAnalysisRepository,
      scoresheetId: scoresheet.id,
      chapterIndex: _currentChapter,
    );
    _gameAnalysis = controller;
    final mainlineFens = _mainlineFens();
    controller.loadExisting(mainlineFens).then((_) {
      if (!mounted || _gameAnalysis != controller) return;
      final hasResults = controller.progress.value.evaluations.any(
        (e) => e != null,
      );
      if (hasResults) setState(() => _showAnalysisGraph = true);
    });
    controller.progress.addListener(_onAnalysisProgressChanged);
  }

  void _onAnalysisProgressChanged() {
    if (!mounted) return;
    final progress = _gameAnalysis?.progress.value;
    if (progress?.status == GameAnalysisStatus.error &&
        progress?.errorMessage != null) {
      NotificationService.showError(
        'Analysis error: ${progress!.errorMessage}',
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    selectedEnginePackageNotifier.removeListener(_onEnginePackageChanged);
    _chapterSearchController.dispose();
    _debounce?.cancel();
    _analysisSub?.cancel();
    _moveScrollController.dispose();
    _verticalMoveScrollController.dispose();
    _engine.stopAnalysis();
    if (_ownsEngine) _engine.dispose();
    _gameAnalysis?.progress.removeListener(_onAnalysisProgressChanged);
    _gameAnalysis?.dispose();
    super.dispose();
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

  List<String> _mainlineFens() {
    final fens = <String>[];
    Position pos = PgnGame.startingPosition(_game.headers);
    for (final node in _mainLine) {
      final move = pos.parseSan(node.data.san);
      if (move == null) break;
      pos = pos.play(move);
      fens.add(pos.fen);
    }
    return fens;
  }

  List<Board> _mainlineBoards() {
    final boards = <Board>[];
    Position pos = PgnGame.startingPosition(_game.headers);
    for (final node in _mainLine) {
      final move = pos.parseSan(node.data.san);
      if (move == null) break;
      pos = pos.play(move);
      boards.add(pos.board);
    }
    return boards;
  }

  void _navigateToPly(int ply) {
    final mainline = _mainLine;
    if (mainline.isEmpty) return;
    final clamped = ply.clamp(0, mainline.length - 1);
    _navigate(_pathTo(mainline[clamped]));
  }

  void _loadChapter(int index) {
    if (index == _currentChapter) return;
    _chapterSearchController.clear();
    _analysisSub?.cancel();
    _analysisSub = null;
    _engine.stopAnalysis();
    _gameAnalysis?.progress.removeListener(_onAnalysisProgressChanged);
    _gameAnalysis?.dispose();
    _gameAnalysis = null;
    _positionMap.clear();
    _moveMap.clear();
    _parentMap.clear();
    final newGame = PgnGame.parsePgn(
      _games[index],
      initHeaders: PgnGame.emptyHeaders,
    );
    _buildMaps(newGame.moves, PgnGame.startingPosition(newGame.headers));
    setState(() {
      _currentChapter = index;
      _game = newGame;
      _gameDivision = divideGame(_mainlineBoards());
      _path = [];
      _promotionMove = null;
      _evaluations = [];
      _expandedPvs.clear();
      _engineEnabled = false;
      _showAnalysisGraph = false;
    });
    _buildGameAnalysisController();
  }

  void _openChapterDrawer() {
    _chapterSearchController.clear();
    _scaffoldKey.currentState?.openDrawer();
  }

  Widget _buildChapterDrawer(ThemeData theme) {
    final query = _chapterSearchController.text.trim().toLowerCase();
    final chapterEntries = _games.asMap().entries.where((entry) {
      if (query.isEmpty) return true;
      return _chapterLabel(
        entry.value,
        entry.key,
      ).toLowerCase().contains(query);
    }).toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text('Chapters', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                itemCount: chapterEntries.length,
                separatorBuilder: (_, _) =>
                    Divider(color: theme.colorScheme.outlineVariant, height: 1),
                itemBuilder: (context, index) {
                  final entry = chapterEntries[index];
                  final chapterIndex = entry.key;
                  final selected = chapterIndex == _currentChapter;
                  return ListTile(
                    selected: selected,
                    title: Text(
                      _chapterLabel(entry.value, chapterIndex),
                      style: theme.textTheme.bodyMedium,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _loadChapter(chapterIndex);
                    },
                  );
                },
              ),
            ),
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _chapterSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search chapter',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _chapterSearchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _chapterSearchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close, size: 16),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _chapterLabel(String pgn, int index) {
    final tags = parsePgnTags(pgn);
    return _boardTitle(tags) ?? _boardSubtitle(tags) ?? 'Game ${index + 1}';
  }

  String? _boardTitle(Map<String, String> headers) {
    String? tag(String key) {
      final value = headers[key];
      return (value == null || value.isEmpty || value.startsWith('?'))
          ? null
          : value;
    }

    final white = tag('White');
    final black = tag('Black');
    return (white != null && black != null) ? '$white − $black' : null;
  }

  String? _boardSubtitle(Map<String, String> headers) {
    String? tag(String key) {
      final value = headers[key];
      return (value == null || value.isEmpty || value.startsWith('?'))
          ? null
          : value;
    }

    final event = tag('Event');
    final round = tag('Round');
    final parts = [event, if (round != null) 'Round $round'].nonNulls.toList();
    return parts.isEmpty ? null : parts.join(' · ');
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
      _evaluations = [];
      _expandedPvs.clear();
    });
    if (_engineEnabled) {
      _debounce?.cancel();
      _engine.stopAnalysis();
      _debounce = Timer(const Duration(milliseconds: 200), _startAnalysis);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentRowKey.currentContext != null) {
        Scrollable.ensureVisible(
          _currentRowKey.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else if (_moveScrollController.hasClients) {
        _moveScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else if (_verticalMoveScrollController.hasClients) {
        final offset = newPath.isNotEmpty && newPath.last.children.isEmpty
            ? _verticalMoveScrollController.position.maxScrollExtent
            : 0.0;
        _verticalMoveScrollController.animateTo(
          offset,
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
    _gameDivision = divideGame(_mainlineBoards());

    _navigate([..._path, newChild]);
  }

  bool _isPromotionPawnMove(NormalMove move) {
    final pos = _currentPosition;
    return move.promotion == null &&
        pos.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.first && pos.turn == Side.black) ||
            (move.to.rank == Rank.eighth && pos.turn == Side.white));
  }

  Future<void> _toggleEngine() async {
    if (_engineStarting) return;
    if (_engine.jobKind.value == EngineJobKind.gameAnalysis) {
      NotificationService.showInfo('Game analysis in progress');
      return;
    }
    if (selectedEnginePackageNotifier.value == null) {
      NotificationService.showInfo('Select an engine first');
      return;
    }
    if (!_engineReady) {
      setState(() => _engineStarting = true);
      try {
        await _engine.init();
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
      _engine.stopAnalysis();
      setState(() => _evaluations = []);
    }
  }

  void _setMultiPv(int n) {
    if (_multiPv == n) return;
    setState(() => _multiPv = n);
    if (_engineEnabled) _startAnalysis();
  }

  void _startAnalysis() {
    if (!mounted) return;
    _analysisSub?.cancel();
    setState(() {
      _evaluations = [];
      _expandedPvs.clear();
    });
    try {
      _analysisSub = _engine
          .startAnalysis(_currentPosition.fen, multiPv: _multiPv)
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

  List<(int, bool, String)> _pvToSan(List<String> pv) {
    final result = <(int, bool, String)>[];
    Position pos = _currentPosition;
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
    final textStyle = widget.engineMode
        ? theme.textTheme.bodyLarge?.copyWith(
            fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) + 2,
          )
        : theme.textTheme.bodyMedium;
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

  int _cpFromWhite(int cp) => _currentPosition.turn == Side.white ? cp : -cp;

  Widget _buildEvalLine(ThemeData theme, EngineEvaluation eval, int pvIndex) {
    final String? evalText;
    if (eval.mate != null) {
      final mate = _currentPosition.turn == Side.white
          ? eval.mate!
          : -eval.mate!;
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
    final textStyle = widget.engineMode
        ? theme.textTheme.bodyLarge?.copyWith(
            fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) + 2,
          )
        : theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            child: evalText != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      evalText,
                      style: textStyle?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                : null,
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

  Future<void> _onAnalysisButtonTap({bool rerun = false}) async {
    final controller = _gameAnalysis;
    if (controller == null) return;

    final status = controller.progress.value.status;

    if (_engine.jobKind.value == EngineJobKind.liveAnalysis) {
      NotificationService.showInfo('Disable engine before running analysis');
      return;
    }

    if (selectedEnginePackageNotifier.value == null) {
      NotificationService.showInfo('Select an engine first');
      return;
    }

    if (status == GameAnalysisStatus.running) {
      await controller.cancel();
      return;
    }

    if (!rerun &&
        (status == GameAnalysisStatus.done ||
            controller.progress.value.evaluations.any((e) => e != null))) {
      setState(() => _showAnalysisGraph = !_showAnalysisGraph);
      return;
    }

    if (!_engine.isStarted) {
      setState(() => _engineStarting = true);
      try {
        await _engine.init();
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
          });
          NotificationService.showError('Engine failed to start: $error');
        }
        return;
      }
    }

    setState(() => _showAnalysisGraph = true);
    try {
      await controller.start(
        mainlinePositions: _mainlineFens(),
        refresh: rerun,
      );
    } catch (error) {
      if (mounted) {
        NotificationService.showError('Analysis failed: $error');
      }
    }
  }

  Widget _buildAnalysisGraphPanel(ThemeData theme) {
    final panelColor = Color.alphaBlend(
      theme.colorScheme.outline.withValues(alpha: _panelOutlineAlpha),
      theme.scaffoldBackgroundColor,
    );
    final progress = _gameAnalysis?.progress.value;
    if (progress == null) {
      return ColoredBox(color: panelColor);
    }
    final isRunning = progress.status == GameAnalysisStatus.running;
    return ColoredBox(
      color: panelColor,
      child: Stack(
        children: [
          EvalGraph(
            evaluations: progress.evaluations,
            totalPlies: progress.totalPlies,
            activePly: _onMainLine ? _path.length - 1 : -1,
            onTapPly: _navigateToPly,
            division: _gameDivision,
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface.withValues(
                  alpha: 0.85,
                ),
                foregroundColor: theme.colorScheme.onSurface,
              ),
              tooltip: isRunning ? 'Stop analysis' : 'Re-run analysis',
              icon: isRunning
                  ? const Icon(Icons.stop_rounded, size: 18)
                  : const Icon(LucideIcons.rotate_ccw),
              onPressed: isRunning
                  ? () => unawaited(_onAnalysisButtonTap())
                  : () => unawaited(_onAnalysisButtonTap(rerun: true)),
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final firstMove = _game.moves.children.firstOrNull;
    final isAtFirstMove = _path.length == 1 && _path.first == firstMove;
    final isFirst = _path.isEmpty;
    final isLast = _currentNode.children.isEmpty;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _games.length > 1
          ? SizedBox(
              width:
                  (MediaQuery.sizeOf(context).width * _chapterDrawerWidthFactor)
                      .clamp(0.0, _chapterDrawerMaxWidth),
              child: _buildChapterDrawer(theme),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (widget.engineMode) {
              return constraints.maxWidth > constraints.maxHeight
                  ? _buildEngineLandscapeBody(theme, constraints)
                  : _buildEnginePortraitBody(theme, constraints);
            }

            final boardSize = constraints.maxWidth * _boardWidthFactor;
            final selectorWidth = constraints.maxWidth;

            if (constraints.maxWidth > constraints.maxHeight) {
              return _buildLandscapeBody(theme, constraints);
            }

            return Column(
              children: [
                const SizedBox(height: 12),
                _buildMetadata(theme),
                const SizedBox(height: 12),
                _buildBoardArea(constraints.maxWidth, boardSize),
                const SizedBox(height: _boardSelectorsGap),
                _buildSelectors(theme, selectorWidth),
                if (_engineEnabled) ...[
                  const SizedBox(height: _selectorGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _selectorSidePadding,
                    ),
                    child: SizedBox(
                      height: _engineGaugeHeight,
                      child: _buildEvalGauge(theme),
                    ),
                  ),
                ],
                if (_engineEnabled)
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _buildEvalPanel(theme)),
                        SizedBox(
                          height: 1,
                          child: ColoredBox(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        Expanded(child: _buildMoveList(theme)),
                      ],
                    ),
                  )
                else if (_showAnalysisGraph &&
                    (_gameAnalysis?.progress.value.evaluations.any(
                          (e) => e != null,
                        ) ??
                        false))
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _buildMoveList(theme)),
                        SizedBox(
                          height: 1,
                          child: ColoredBox(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        Expanded(child: _buildAnalysisGraphPanel(theme)),
                      ],
                    ),
                  )
                else
                  Expanded(child: _buildMoveList(theme)),
              ],
            );
          },
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
                icon: const Icon(Icons.navigate_before),
                onPressed: isFirst
                    ? null
                    : () => _navigate(_path.sublist(0, _path.length - 1)),
                onLongPress: firstMove == null || isAtFirstMove
                    ? null
                    : () => _navigate([firstMove]),
              ),
              const SizedBox(width: 35),
              IconButton(
                iconSize: 35,
                icon: const Icon(Icons.navigate_next),
                onPressed: isLast
                    ? null
                    : () => _navigate([..._path, _currentNode.children.first]),
                onLongPress: isLast
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

  Widget _buildChessboard(double boardSize) {
    final shapes = _currentShapes;

    return GestureDetector(
      onVerticalDragStart: (_) => _verticalDragAccum = 0.0,
      onVerticalDragUpdate: (details) =>
          _verticalDragAccum += details.delta.dy.abs(),
      onVerticalDragEnd: (details) {
        if (_verticalDragAccum < boardSize * 0.7) return;
        if ((details.primaryVelocity ?? 0).abs() < 50.0) return;
        setState(
          () => _orientation = _orientation == Side.white
              ? Side.black
              : Side.white,
        );
      },
      child: Chessboard(
        size: boardSize,
        fen: _currentPosition.fen,
        orientation: _orientation,
        lastMove: _currentLastMove,
        settings: ChessboardSettings(
          colorScheme: _colorScheme,
          pieceAssets: _pieceSet.assets,
          animationDuration: _engineAnimationDuration,
          dragFeedbackScale: 1.0,
          dragTargetKind: DragTargetKind.none,
        ),
        shapes: shapes.isEmpty ? null : shapes,
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
    );
  }

  Widget _buildBoardArea(double availableWidth, double boardSize) {
    final sideZoneWidth = ((availableWidth - boardSize) / 2).clamp(
      0.0,
      double.infinity,
    );
    final isFirst = _path.isEmpty;
    final isLast = _currentNode.children.isEmpty;

    return SizedBox(
      width: availableWidth,
      height: boardSize,
      child: Stack(
        children: [
          Center(child: _buildChessboard(boardSize)),
          if (sideZoneWidth > 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: sideZoneWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: isFirst
                    ? null
                    : () => _navigate(_path.sublist(0, _path.length - 1)),
              ),
            ),
          if (sideZoneWidth > 0)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: sideZoneWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: isLast
                    ? null
                    : () => _navigate([..._path, _currentNode.children.first]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLandscapeBody(ThemeData theme, BoxConstraints constraints) {
    final halfWidth = constraints.maxWidth / 2;
    const columnOverhead = _boardSelectorsGap + AppControlSize.compact;
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
              if (_engineEnabled) ...[
                const SizedBox(height: _selectorGap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _selectorSidePadding,
                  ),
                  child: SizedBox(
                    height: _engineGaugeHeight,
                    child: _buildEvalGauge(theme),
                  ),
                ),
              ],
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
              const SizedBox(height: 8),
              _buildMetadata(theme),
              const SizedBox(height: 8),
              if (_engineEnabled)
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildEvalPanel(theme)),
                      SizedBox(
                        height: 1,
                        child: ColoredBox(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      Expanded(child: _buildMoveList(theme)),
                    ],
                  ),
                )
              else if (_showAnalysisGraph &&
                  (_gameAnalysis?.progress.value.evaluations.any(
                        (e) => e != null,
                      ) ??
                      false))
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildMoveList(theme)),
                      SizedBox(
                        height: 1,
                        child: ColoredBox(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      Expanded(child: _buildAnalysisGraphPanel(theme)),
                    ],
                  ),
                )
              else
                Expanded(child: _buildMoveList(theme)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnginePortraitBody(ThemeData theme, BoxConstraints constraints) {
    final boardSize = constraints.maxWidth * _engineBoardWidthFactor;
    final boardBlockHeight =
        boardSize +
        _boardSelectorsGap +
        AppControlSize.compact +
        (_engineEnabled ? _selectorGap + _engineGaugeHeight : 0);
    final boardTop = ((constraints.maxHeight - boardBlockHeight) / 2).clamp(
      0.0,
      double.infinity,
    );
    final boardBottom = boardTop + boardBlockHeight;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            top: boardTop,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBoardArea(constraints.maxWidth, boardSize),
                const SizedBox(height: _boardSelectorsGap),
                _buildSelectors(theme, constraints.maxWidth),
                if (_engineEnabled) ...[
                  const SizedBox(height: _selectorGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _selectorSidePadding,
                    ),
                    child: SizedBox(
                      height: _engineGaugeHeight,
                      child: _buildEvalGauge(theme),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_engineEnabled && boardBottom < constraints.maxHeight)
            Positioned(
              top: boardBottom,
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildEvalPanel(theme),
            ),
        ],
      ),
    );
  }

  Widget _buildEngineLandscapeBody(
    ThemeData theme,
    BoxConstraints constraints,
  ) {
    final halfWidth = constraints.maxWidth / 2;
    const columnOverhead = _boardSelectorsGap + AppControlSize.compact;
    final boardSize =
        ((constraints.maxHeight - columnOverhead) * _engineBoardWidthFactor)
            .clamp(0.0, halfWidth - _selectorSidePadding * 2);
    final hasMoves = _game.moves.children.isNotEmpty;

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
              if (_engineEnabled) ...[
                const SizedBox(height: _selectorGap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _selectorSidePadding,
                  ),
                  child: SizedBox(
                    height: _engineGaugeHeight,
                    child: _buildEvalGauge(theme),
                  ),
                ),
              ],
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
              if (_engineEnabled) Expanded(child: _buildEvalPanel(theme)),
              if (hasMoves && _engineEnabled)
                SizedBox(
                  height: 1,
                  child: ColoredBox(color: theme.colorScheme.outlineVariant),
                ),
              if (hasMoves) Expanded(child: _buildMoveList(theme)),
            ],
          ),
        ),
      ],
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
    final players = _boardTitle(_game.headers);
    final tournament = _boardSubtitle(_game.headers);

    final metadataColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (players != null)
          Text(
            players,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        if (players != null && result != null)
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

    if (_games.length <= 1) return metadataColumn;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          child: IconButton(
            tooltip: 'Select chapter',
            padding: EdgeInsets.zero,
            onPressed: _openChapterDrawer,
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_outlined, size: 18),
                Text(
                  '${_currentChapter + 1}/${_games.length}',
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

  Widget _buildEvalGauge(ThemeData theme) {
    const maxGaugePawns = 7;
    double whiteRatio = 0.5;
    int depth = 0;
    String? evalText;

    if (_evaluations.isNotEmpty) {
      final eval = _evaluations.first;
      depth = eval.depth;
      if (eval.mate != null) {
        final mate = _currentPosition.turn == Side.white
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

  Widget _buildSelectors(ThemeData theme, double boardSize) {
    const buttonSize = AppControlSize.compact;
    const primaryIconSize = AppIconSize.inlineAction;
    const secondaryIconSize = AppIconSize.smallStatus;
    const buttonConstraints = BoxConstraints.tightFor(
      width: buttonSize,
      height: buttonSize,
    );
    const sideSlotWidth = buttonSize * 4 + _selectorGap * 3;

    Widget wrapCompactControl(Widget child) {
      return SizedBox(width: buttonSize, height: buttonSize, child: child);
    }

    final paletteBtn = wrapCompactControl(
      PopupMenuButton<ChessboardColorScheme>(
        iconSize: primaryIconSize,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.palette_outlined),
        tooltip: 'Board colour',
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(maxHeight: 300),
        onSelected: (scheme) {
          final label = boardColorSchemes.firstWhere((e) => e.$2 == scheme).$1;
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
    );

    final piecesBtn = wrapCompactControl(
      PopupMenuButton<PieceSet>(
        iconSize: primaryIconSize,
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
          for (final set in [
            PieceSet.alpha,
            PieceSet.cburnett,
            PieceSet.merida,
          ])
            PopupMenuItem(value: set, child: Text(set.label)),
        ],
      ),
    );

    final flipBtn = wrapCompactControl(
      IconButton(
        iconSize: primaryIconSize,
        constraints: buttonConstraints,
        padding: EdgeInsets.zero,
        icon: const Icon(LucideIcons.rotate_ccw),
        tooltip: 'Flip board',
        onPressed: () => setState(
          () => _orientation = _orientation == Side.white
              ? Side.black
              : Side.white,
        ),
      ),
    );

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
        onPressed: () => unawaited(_toggleEngine()),
        onLongPress: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EngineSettingsScreen())),
      ),
    );

    final analysisProgress = _gameAnalysis?.progress.value;
    final analysisStatus = analysisProgress?.status ?? GameAnalysisStatus.idle;
    final analysisHasResults =
        analysisProgress?.evaluations.any((e) => e != null) ?? false;

    final analysisBtn = !widget.engineMode
        ? wrapCompactControl(
            IconButton(
              iconSize: primaryIconSize,
              constraints: buttonConstraints,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: analysisStatus == GameAnalysisStatus.error
                    ? theme.colorScheme.error
                    : (_showAnalysisGraph && analysisHasResults)
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              icon: analysisStatus == GameAnalysisStatus.running
                  ? SizedBox.square(
                      dimension: primaryIconSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: (analysisProgress!.totalPlies > 0)
                                ? analysisProgress.completedPlies /
                                      analysisProgress.totalPlies
                                : null,
                            strokeWidth: 2,
                          ),
                          if (analysisProgress.totalPlies > 0)
                            Text(
                              '${(analysisProgress.completedPlies / analysisProgress.totalPlies * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const Icon(LucideIcons.activity),
              tooltip: analysisStatus == GameAnalysisStatus.running
                  ? 'Stop analysis'
                  : 'Analyse game',
              onPressed: () => unawaited(_onAnalysisButtonTap()),
              onLongPress: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EngineSettingsScreen()),
              ),
            ),
          )
        : null;

    final boardControlsGroup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        paletteBtn,
        const SizedBox(width: _selectorGap),
        piecesBtn,
        const SizedBox(width: _selectorGap),
        flipBtn,
      ],
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

    final engineControlsGroup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (analysisBtn != null) ...[
          analysisBtn,
          const SizedBox(width: _selectorGap),
        ],
        cpuBtn,
        const SizedBox(width: _selectorGap),
        incrementBtn,
        const SizedBox(width: _selectorGap),
        decrementBtn,
      ],
    );

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
                  child: SizedBox(
                    width: sideSlotWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: boardControlsGroup,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: sideSlotWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: engineControlsGroup,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoveList(ThemeData theme) {
    final movesPanelColor = Color.alphaBlend(
      theme.colorScheme.outline.withValues(alpha: _panelOutlineAlpha),
      theme.scaffoldBackgroundColor,
    );
    final mainLine = _mainLine;
    if (mainLine.isEmpty && _game.moves.children.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_engineEnabled) {
      final pgnChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'PGN',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontSize: 10,
            height: 1,
          ),
        ),
      );
      final tokens = <Widget>[];
      int ply = 0;
      PgnNode<PgnNodeData> node = _game.moves;

      void addVariation(PgnChildNode varStart, int varPly, int depth) {
        final indent = depth > 0 ? '  ' * depth : '';
        tokens.add(
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 2),
            child: Text(
              '$indent(',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
        final varLine = _collectLinePath(varStart);
        for (int j = 0; j < varLine.length; j++) {
          final vNode = varLine[j];
          final vPly = varPly + j;
          final vIsWhite = vPly % 2 == 0;
          final vMoveNum = (vPly + 2) ~/ 2;
          if (vIsWhite || j == 0) {
            tokens.add(
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 2),
                child: Text(
                  vIsWhite ? '$vMoveNum.' : '$vMoveNum…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            );
          }
          final isVActive = _path.isNotEmpty && _path.last == vNode;
          tokens.addAll(_commentTokens(theme, vNode.data.startingComments));
          tokens.add(
            _buildInlineMoveTile(
              theme,
              vNode.data.san,
              isVActive,
              () => _navigate(_pathTo(vNode)),
              key: isVActive ? _currentRowKey : null,
            ),
          );
          tokens.addAll(_commentTokens(theme, vNode.data.comments));
          for (int k = 1; k < vNode.children.length; k++) {
            addVariation(vNode.children[k], vPly + 1, depth + 1);
          }
        }
        tokens.add(
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 4),
            child: Text(
              ')',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
      }

      while (node.children.isNotEmpty) {
        final mainChild = node.children.first;
        final isWhite = ply % 2 == 0;
        final moveNumber = (ply + 2) ~/ 2;

        if (isWhite) {
          tokens.add(
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Text(
                '$moveNumber.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          );
        }

        final isMainActive = _path.isNotEmpty && _path.last == mainChild;
        tokens.addAll(_commentTokens(theme, mainChild.data.startingComments));
        tokens.add(
          _buildInlineMoveTile(
            theme,
            mainChild.data.san,
            isMainActive,
            () => _navigate(_pathTo(mainChild)),
            key: isMainActive ? _currentRowKey : null,
          ),
        );
        tokens.addAll(_commentTokens(theme, mainChild.data.comments));

        for (int k = 1; k < node.children.length; k++) {
          addVariation(node.children[k], ply, 0);
        }

        node = mainChild;
        ply++;
      }

      return ColoredBox(
        color: movesPanelColor ?? theme.colorScheme.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 3),
              child: pgnChip,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _moveScrollController,
                child: Row(children: tokens),
              ),
            ),
          ],
        ),
      );
    }

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
      for (final (node, startPly)
          in (branches[r] ?? <(PgnNode<PgnNodeData>, int)>[])) {
        widgets.add(_buildAllVariations(theme, node, startPly));
      }
    }

    return ColoredBox(
      color: movesPanelColor ?? theme.colorScheme.background,
      child: ListView(
        controller: _verticalMoveScrollController,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: widgets,
      ),
    );
  }

  Widget _buildInlineMoveTile(
    ThemeData theme,
    String san,
    bool active,
    VoidCallback onTap, {
    Key? key,
  }) {
    return GestureDetector(
      key: key,
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
          style:
              (widget.engineMode
                      ? theme.textTheme.bodyLarge?.copyWith(
                          fontSize:
                              (theme.textTheme.bodyLarge?.fontSize ?? 16) + 2,
                        )
                      : theme.textTheme.bodyLarge)
                  ?.copyWith(
                    color: active ? theme.colorScheme.onPrimary : null,
                    fontWeight: active ? FontWeight.w600 : null,
                  ),
        ),
      ),
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
      whiteStartingComments: wNode?.data.startingComments,
      whiteComments: wNode?.data.comments,
      blackStartingComments: bNode?.data.startingComments,
      blackComments: bNode?.data.comments,
      isWhiteActive:
          _onMainLine &&
          wNode != null &&
          _path.isNotEmpty &&
          _path.last == wNode,
      isBlackActive:
          _onMainLine &&
          bNode != null &&
          _path.isNotEmpty &&
          _path.last == bNode,
      onWhiteTap: wNode != null ? () => _navigate(_pathTo(wNode)) : null,
      onBlackTap: bNode != null ? () => _navigate(_pathTo(bNode)) : null,
    );
  }

  Widget _buildAllVariations(
    ThemeData theme,
    PgnNode<PgnNodeData> branchNode,
    int startPly,
  ) {
    final blocks = <Widget>[];
    for (int k = 1; k < branchNode.children.length; k++) {
      blocks.add(
        _buildVariationBlock(theme, branchNode.children[k], startPly, 0),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  Widget _buildVariationBlock(
    ThemeData theme,
    PgnChildNode<PgnNodeData> startNode,
    int startPly,
    int depth,
  ) {
    final linePath = _collectLinePath(startNode);
    final items = <Widget>[
      _buildVariationInlineRow(theme, linePath, startPly, depth),
    ];

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

  Widget _buildVariationInlineRow(
    ThemeData theme,
    List<PgnChildNode<PgnNodeData>> nodes,
    int startPly,
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
      }

      final node = nodes[j];
      final isActive = _path.isNotEmpty && _path.last == node;
      tokens.addAll(_commentTokens(theme, node.data.startingComments));
      tokens.add(
        _buildInlineMoveTile(
          theme,
          node.data.san,
          isActive,
          () => _navigate(_pathTo(node)),
        ),
      );
      tokens.addAll(_commentTokens(theme, node.data.comments));
    }

    return Padding(
      key: _path.isNotEmpty && nodes.contains(_path.last)
          ? _currentRowKey
          : null,
      padding: EdgeInsets.fromLTRB(8.0 + depth * 20, 3, 8, 3),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 4,
        children: tokens,
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
    List<String>? whiteStartingComments,
    List<String>? whiteComments,
    List<String>? blackStartingComments,
    List<String>? blackComments,
    required bool isWhiteActive,
    required bool isBlackActive,
    required VoidCallback? onWhiteTap,
    required VoidCallback? onBlackTap,
  }) {
    final comments = [
      ...displayPgnCommentTexts(whiteStartingComments),
      ...displayPgnCommentTexts(whiteComments),
      ...displayPgnCommentTexts(blackStartingComments),
      ...displayPgnCommentTexts(blackComments),
    ];

    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        final tileWidth = ((constraints.maxWidth - 64) / 2).clamp(0.0, 96.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        startsOnBlack ? '$moveNumber...' : '$moveNumber.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: tileWidth,
                      child: whiteSan != null && !startsOnBlack
                          ? _moveTile(
                              theme,
                              whiteSan,
                              isWhiteActive,
                              onWhiteTap!,
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: tileWidth,
                      child: blackSan != null
                          ? _moveTile(
                              theme,
                              blackSan,
                              isBlackActive,
                              onBlackTap!,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              if (comments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(44, 6, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: comments
                        .map(
                          (comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              comment,
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
      },
    );
  }

  List<Widget> _commentTokens(ThemeData theme, List<String>? comments) {
    return displayPgnCommentTexts(comments)
        .map(
          (comment) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              comment,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        )
        .toList();
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
          style: theme.textTheme.bodyLarge?.copyWith(
            color: active ? theme.colorScheme.onPrimary : null,
            fontWeight: active ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }

  ISet<Shape> get _currentShapes {
    if (_path.isEmpty) {
      return const ISetConst({});
    }

    final node = _path.last.data;
    final shapes = <Shape>{};
    for (final parsedComment in [
      ...parsePgnComments(node.startingComments),
      ...parsePgnComments(node.comments),
    ]) {
      for (final shape in parsedComment.shapes) {
        final boardShape = _toBoardShape(shape);
        if (boardShape != null) {
          shapes.add(boardShape);
        }
      }
    }
    return shapes.lock;
  }

  Shape? _toBoardShape(PgnCommentShape shape) {
    final color = _annotationColors[shape.color];
    if (color == null) {
      return null;
    }

    if (shape.from == shape.to) {
      return Circle(color: color, orig: shape.from);
    }

    return Arrow(color: color, orig: shape.from, dest: shape.to);
  }
}
