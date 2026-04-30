import 'dart:async';

import 'package:annoto/app/themes.dart';
import 'package:annoto/repositories/game_analysis_repository.dart';
import 'package:annoto/services/chess_engine_service.dart';
import 'package:flutter/foundation.dart';

enum GameAnalysisStatus { idle, running, done, error }

class GameAnalysisProgress {
  const GameAnalysisProgress({
    required this.completedPlies,
    required this.totalPlies,
    required this.evaluations,
    required this.status,
    this.errorMessage,
  });

  final int completedPlies;
  final int totalPlies;
  final List<EngineEvaluation?> evaluations;
  final GameAnalysisStatus status;
  final String? errorMessage;
}

class GameAnalysisController {
  GameAnalysisController({
    required this.engineService,
    required this.repository,
    required this.scoresheetId,
    required this.chapterIndex,
  });

  final ChessEngineService engineService;
  final GameAnalysisRepository repository;
  final String scoresheetId;
  final int chapterIndex;

  final _progress = ValueNotifier<GameAnalysisProgress>(
    const GameAnalysisProgress(
      completedPlies: 0,
      totalPlies: 0,
      evaluations: [],
      status: GameAnalysisStatus.idle,
    ),
  );

  ValueListenable<GameAnalysisProgress> get progress => _progress;

  bool _canceled = false;
  bool _disposed = false;

  Future<void> loadExisting(int totalPlies) async {
    final stored = await repository.loadChapter(scoresheetId, chapterIndex);
    if (stored == null) return;
    final evals = List<EngineEvaluation?>.filled(totalPlies, null);
    for (final p in stored.plies) {
      if (p.ply < totalPlies) {
        evals[p.ply] = EngineEvaluation(
          cp: p.cp,
          mate: p.mate,
          bestMove: p.bestMove,
          pv: p.pv,
          depth: p.depth,
        );
      }
    }
    _emit(
      evaluations: evals,
      totalPlies: totalPlies,
      completedPlies: stored.completedPlies,
      status: stored.completedPlies >= totalPlies
          ? GameAnalysisStatus.done
          : GameAnalysisStatus.idle,
    );
  }

  Future<void> start({required List<String> mainlinePositions}) async {
    if (_disposed) return;
    _canceled = false;

    final total = mainlinePositions.length;
    final current = List<EngineEvaluation?>.from(
      _progress.value.evaluations.length == total
          ? _progress.value.evaluations
          : List<EngineEvaluation?>.filled(total, null),
    );

    _emit(
      evaluations: current,
      totalPlies: total,
      completedPlies: current.where((e) => e != null).length,
      status: GameAnalysisStatus.running,
    );

    for (int i = 0; i < total; i++) {
      if (_canceled || _disposed) break;
      if (current[i] != null) continue;

      final depth = analysisDepthNotifier.value;
      final fen = mainlinePositions[i];

      try {
        final raw = await engineService.analyzePly(fen, depth);
        if (_canceled || _disposed) break;

        final isBlackTurn = fen.split(' ')[1] == 'b';
        final normalizedCp = raw.cp != null
            ? (isBlackTurn ? -raw.cp! : raw.cp!)
            : null;
        final normalizedMate = raw.mate != null
            ? (isBlackTurn ? -raw.mate! : raw.mate!)
            : null;

        final eval = EngineEvaluation(
          cp: normalizedCp,
          mate: normalizedMate,
          bestMove: raw.bestMove,
          pv: raw.pv.take(16).toList(),
          depth: raw.depth,
        );

        current[i] = eval;

        await repository.upsertPly(
          scoresheetId,
          chapterIndex,
          StoredPlyEvaluation(
            ply: i,
            fen: fen,
            depth: depth,
            cp: normalizedCp,
            mate: normalizedMate,
            bestMove: raw.bestMove,
            pv: raw.pv.take(16).toList(),
          ),
          totalPlies: total,
        );

        _emit(
          evaluations: List.unmodifiable(current),
          totalPlies: total,
          completedPlies: current.where((e) => e != null).length,
          status: GameAnalysisStatus.running,
        );
      } catch (e) {
        if (_canceled || _disposed) break;
        _emit(
          evaluations: List.unmodifiable(current),
          totalPlies: total,
          completedPlies: current.where((e) => e != null).length,
          status: GameAnalysisStatus.error,
          errorMessage: e.toString(),
        );
        return;
      }
    }

    if (_disposed) return;

    final completed = current.where((e) => e != null).length;
    _emit(
      evaluations: List.unmodifiable(current),
      totalPlies: total,
      completedPlies: completed,
      status: _canceled
          ? (completed > 0 ? GameAnalysisStatus.idle : GameAnalysisStatus.idle)
          : GameAnalysisStatus.done,
    );
  }

  Future<void> cancel() async {
    _canceled = true;
    await engineService.cancelGameAnalysis();
  }

  void dispose() {
    _disposed = true;
    _canceled = true;
    _progress.dispose();
  }

  void _emit({
    required List<EngineEvaluation?> evaluations,
    required int totalPlies,
    required int completedPlies,
    required GameAnalysisStatus status,
    String? errorMessage,
  }) {
    if (_disposed) return;
    _progress.value = GameAnalysisProgress(
      completedPlies: completedPlies,
      totalPlies: totalPlies,
      evaluations: evaluations,
      status: status,
      errorMessage: errorMessage,
    );
  }
}
