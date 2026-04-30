import 'dart:async';

import 'package:annoto/app/themes.dart';
import 'package:annoto/services/chess_engine.dart';
import 'package:flutter/foundation.dart';

enum EngineJobKind { idle, liveAnalysis, gameAnalysis }

@visibleForTesting
EngineEvaluation? parseInfoLine(String line, Map<int, EngineEvaluation> pvMap) {
  if (!line.startsWith('info ') || !line.contains('score')) return null;

  final cpMatch = RegExp(r'\bscore cp (-?\d+)\b').firstMatch(line);
  final mateMatch = RegExp(r'\bscore mate (-?\d+)\b').firstMatch(line);
  final pvMatch = RegExp(r'\bpv (.+)$').firstMatch(line);
  final depthMatch = RegExp(r'\bdepth (\d+)\b').firstMatch(line);
  final multipvMatch = RegExp(r'\bmultipv (\d+)\b').firstMatch(line);

  final pvIndex = multipvMatch != null ? int.parse(multipvMatch.group(1)!) : 1;
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
      : (pvMap[pvIndex]?.pv ?? []);

  final eval = EngineEvaluation(
    cp: cp,
    mate: mate,
    bestMove: pv.isNotEmpty ? pv.first : pvMap[pvIndex]?.bestMove,
    pv: pv,
    depth: depth,
  );
  pvMap[pvIndex] = eval;
  return eval;
}

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
  final _bridge = OexChessEngine();
  StreamSubscription<String>? _stdoutSub;
  StreamController<List<EngineEvaluation>>? _controller;
  Timer? _pollTimer;

  bool _started = false;

  bool get isStarted => _started;
  bool _searching = false;
  bool _acceptingAnalysis = false;
  int _analysisGeneration = 0;
  final _pvMap = <int, EngineEvaluation>{};
  final jobKind = ValueNotifier<EngineJobKind>(EngineJobKind.idle);
  EngineEvaluation? _lastSinglePv;

  Completer<void>? _initCompleter;
  Completer<void>? _uciOkCompleter;
  Completer<void>? _readyOkCompleter;
  Completer<void>? _bestMoveCompleter;

  Future<void> init() async {
    if (_started) return;
    final existingInit = _initCompleter;
    if (existingInit != null) return existingInit.future;

    final initCompleter = Completer<void>();
    _initCompleter = initCompleter;

    final packageName = selectedEnginePackageNotifier.value;
    if (packageName == null) {
      _initCompleter = null;
      throw StateError('No engine selected');
    }

    try {
      _stdoutSub = _bridge.output.listen(_onStdout);
      _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        unawaited(_drainOutput());
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await _bridge.start(packageName);
    } catch (error) {
      _initCompleter = null;
      await _stdoutSub?.cancel();
      _stdoutSub = null;
      rethrow;
    }

    _uciOkCompleter = Completer<void>();
    await _bridge.send('uci');
    await _waitFor(_uciOkCompleter!, const Duration(seconds: 5));
    _started = true;
    _initCompleter = null;
    initCompleter.complete();

    return initCompleter.future;
  }

  void _onStdout(String line) {
    if (line.startsWith('id name ')) {
      engineNameNotifier.value = line.substring('id name '.length).trim();
    }

    final trimmed = line.trim();

    if (trimmed == 'uciok') {
      final completer = _uciOkCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
      _uciOkCompleter = null;
      unawaited(_bridge.send('ucinewgame'));
      return;
    }

    if (trimmed == 'readyok') {
      final completer = _readyOkCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
      _readyOkCompleter = null;
      return;
    }

    if (line.startsWith('bestmove ')) {
      _searching = false;
      final completer = _bestMoveCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
      _bestMoveCompleter = null;
      return;
    }

    if (parseInfoLine(line, _pvMap) == null) return;

    if (jobKind.value == EngineJobKind.gameAnalysis) {
      _lastSinglePv = _pvMap[1];
      return;
    }

    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    if (!_acceptingAnalysis) return;

    final entries = _pvMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    controller.add(entries.map((e) => e.value).toList());
  }

  Future<void> _waitFor(Completer<void> completer, Duration timeout) async {
    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {}
  }

  Future<void> _drainOutput() async {
    if (!_started) return;
    final lines = await _bridge.drainOutput();
    for (final line in lines) {
      _onStdout(line);
    }
  }

  Stream<List<EngineEvaluation>> startAnalysis(String fen, {int multiPv = 1}) {
    if (!_started) throw StateError('Engine not initialized');
    if (jobKind.value == EngineJobKind.gameAnalysis) {
      throw StateError('Game analysis is active');
    }

    final old = _controller;
    if (old != null && !old.isClosed) old.close();

    final controller = StreamController<List<EngineEvaluation>>.broadcast();
    _controller = controller;

    final generation = ++_analysisGeneration;
    _acceptingAnalysis = false;
    _pvMap.clear();
    jobKind.value = EngineJobKind.liveAnalysis;
    unawaited(_sendAnalysisCommands(fen, multiPv, generation));

    return controller.stream;
  }

  Future<void> _sendAnalysisCommands(
    String fen,
    int multiPv,
    int generation,
  ) async {
    if (_searching) {
      _bestMoveCompleter = Completer<void>();
      await _bridge.send('stop');
      await _waitFor(_bestMoveCompleter!, const Duration(seconds: 2));
      if (generation != _analysisGeneration) return;
    } else {
      await _bridge.send('stop');
    }
    _searching = false;

    await _bridge.send(
      'setoption name Threads value ${engineThreadsNotifier.value}',
    );
    await _bridge.send('setoption name Hash value ${engineHashNotifier.value}');
    await _bridge.send('setoption name MultiPV value $multiPv');

    _readyOkCompleter = Completer<void>();
    await _bridge.send('isready');
    await _waitFor(_readyOkCompleter!, const Duration(seconds: 2));
    if (generation != _analysisGeneration) return;

    await _bridge.send('position fen $fen');
    await _bridge.send('go infinite');
    _searching = true;
    _acceptingAnalysis = true;
  }

  void stopAnalysis() {
    _analysisGeneration++;
    _acceptingAnalysis = false;
    unawaited(_bridge.send('stop'));
    _searching = false;
    final c = _controller;
    if (c != null && !c.isClosed) c.close();
    _controller = null;
    if (jobKind.value == EngineJobKind.liveAnalysis) {
      jobKind.value = EngineJobKind.idle;
    }
  }

  Future<EngineEvaluation> analyzePly(String fen, int depth) async {
    if (!_started) throw StateError('Engine not initialized');
    if (jobKind.value == EngineJobKind.liveAnalysis) {
      throw StateError('Live engine analysis is active');
    }
    jobKind.value = EngineJobKind.gameAnalysis;
    _lastSinglePv = null;
    _pvMap.clear();

    if (_searching) {
      _bestMoveCompleter = Completer<void>();
      await _bridge.send('stop');
      await _waitFor(_bestMoveCompleter!, const Duration(seconds: 2));
    } else {
      await _bridge.send('stop');
    }
    _searching = false;

    await _bridge.send(
      'setoption name Threads value ${engineThreadsNotifier.value}',
    );
    await _bridge.send('setoption name Hash value ${engineHashNotifier.value}');
    await _bridge.send('setoption name MultiPV value 1');

    _readyOkCompleter = Completer<void>();
    await _bridge.send('isready');
    await _waitFor(_readyOkCompleter!, const Duration(seconds: 2));

    await _bridge.send('position fen $fen');
    _bestMoveCompleter = Completer<void>();
    await _bridge.send('go depth $depth');
    _searching = true;

    await _waitFor(_bestMoveCompleter!, Duration(seconds: depth * 5));
    _searching = false;

    final result = _lastSinglePv;
    if (result == null) throw StateError('No evaluation received from engine');
    return result;
  }

  Future<void> cancelGameAnalysis() async {
    if (jobKind.value != EngineJobKind.gameAnalysis) return;
    if (_searching) {
      _bestMoveCompleter = Completer<void>();
      await _bridge.send('stop');
      await _waitFor(_bestMoveCompleter!, const Duration(seconds: 2));
    }
    _searching = false;
    jobKind.value = EngineJobKind.idle;
  }

  void finishGameAnalysis() {
    if (jobKind.value == EngineJobKind.gameAnalysis) {
      jobKind.value = EngineJobKind.idle;
    }
  }

  Future<void> dispose() async {
    stopAnalysis();
    _pollTimer?.cancel();
    _pollTimer = null;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    await _bridge.stop();
    _started = false;
    engineNameNotifier.value = null;
  }
}
