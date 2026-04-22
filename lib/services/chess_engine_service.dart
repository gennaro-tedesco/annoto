import 'dart:async';

import 'package:annoto/app/themes.dart';
import 'package:stockfish/stockfish.dart';

class EngineEvaluation {
  const EngineEvaluation({
    required this.cp,
    required this.mate,
    required this.bestMove,
    required this.pv,
    required this.depth,
  });

  final int? cp;
  final int? mate;
  final String? bestMove;
  final List<String> pv;
  final int depth;
}

class ChessEngineService {
  Stockfish? _engine;
  StreamSubscription<String>? _stdoutSub;
  StreamController<List<EngineEvaluation>>? _controller;

  bool _waitingForUciOk = false;
  bool _waitingForReady = false;
  String _pendingFen = '';
  final _pvMap = <int, EngineEvaluation>{};

  Future<void> init() async {
    if (_engine != null) return;
    final engine = Stockfish();
    _engine = engine;
    while (engine.state.value != StockfishState.ready) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _stdoutSub = engine.stdout.listen(_onStdout);
    _waitingForUciOk = true;
    engine.stdin = 'uci';
  }

  void _onStdout(String line) {
    if (_waitingForUciOk) {
      if (line.startsWith('id name ')) {
        engineNameNotifier.value = line.substring('id name '.length).trim();
      }
      if (line.trim() == 'uciok') {
        _waitingForUciOk = false;
        _engine!.stdin = 'ucinewgame';
      }
      return;
    }

    if (_waitingForReady) {
      if (line.trim() == 'readyok') {
        _waitingForReady = false;
        _pvMap.clear();
        _engine!.stdin = 'position fen $_pendingFen';
        _engine!.stdin = 'go infinite';
      }
      return;
    }

    final controller = _controller;
    if (controller == null || controller.isClosed) return;

    if (line.startsWith('info ') && line.contains('score')) {
      final cpMatch = RegExp(r'\bscore cp (-?\d+)\b').firstMatch(line);
      final mateMatch = RegExp(r'\bscore mate (-?\d+)\b').firstMatch(line);
      final pvMatch = RegExp(r'\bpv (.+)$').firstMatch(line);
      final depthMatch = RegExp(r'\bdepth (\d+)\b').firstMatch(line);
      final multipvMatch = RegExp(r'\bmultipv (\d+)\b').firstMatch(line);

      final pvIndex = multipvMatch != null
          ? int.parse(multipvMatch.group(1)!)
          : 1;
      final depth = depthMatch != null ? int.parse(depthMatch.group(1)!) : 0;

      int? cp;
      int? mate;
      if (cpMatch != null) {
        cp = int.tryParse(cpMatch.group(1)!);
      } else if (mateMatch != null) {
        mate = int.tryParse(mateMatch.group(1)!);
      }

      final pv = pvMatch != null
          ? pvMatch.group(1)!.trim().split(RegExp(r'\s+'))
          : (_pvMap[pvIndex]?.pv ?? []);

      _pvMap[pvIndex] = EngineEvaluation(
        cp: cp,
        mate: mate,
        bestMove: pv.isNotEmpty ? pv.first : _pvMap[pvIndex]?.bestMove,
        pv: pv,
        depth: depth,
      );

      final entries = _pvMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      controller.add(entries.map((e) => e.value).toList());
    }

    if (line.startsWith('bestmove ')) {
      if (!controller.isClosed) controller.close();
      _controller = null;
    }
  }

  Stream<List<EngineEvaluation>> startAnalysis(String fen, {int multiPv = 1}) {
    final engine = _engine;
    if (engine == null) throw StateError('Engine not initialized');

    final old = _controller;
    if (old != null && !old.isClosed) old.close();

    final controller = StreamController<List<EngineEvaluation>>.broadcast();
    _controller = controller;

    _pendingFen = fen;
    _waitingForReady = true;

    engine.stdin = 'stop';
    engine.stdin = 'setoption name Threads value ${engineThreadsNotifier.value}';
    engine.stdin = 'setoption name Hash value ${engineHashNotifier.value}';
    engine.stdin = 'setoption name MultiPV value $multiPv';
    engine.stdin = 'isready';

    return controller.stream;
  }

  void stopAnalysis() {
    _engine?.stdin = 'stop';
    _waitingForReady = false;
    final c = _controller;
    if (c != null && !c.isClosed) c.close();
    _controller = null;
  }

  Future<void> dispose() async {
    stopAnalysis();
    await _stdoutSub?.cancel();
    _engine?.dispose();
    _engine = null;
    _stdoutSub = null;
  }
}
