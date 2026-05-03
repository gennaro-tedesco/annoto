import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StoredPlyEvaluation {
  const StoredPlyEvaluation({
    required this.ply,
    required this.fen,
    required this.depth,
    this.cp,
    this.mate,
    this.bestMove,
    required this.pv,
  });

  final int ply;
  final String fen;
  final int depth;
  final int? cp;
  final int? mate;
  final String? bestMove;
  final List<String> pv;

  Map<String, dynamic> toJson() => {
    'ply': ply,
    'fen': fen,
    'depth': depth,
    'cp': cp,
    'mate': mate,
    'bestMove': bestMove,
    'pv': pv,
  };

  factory StoredPlyEvaluation.fromJson(Map<String, dynamic> json) =>
      StoredPlyEvaluation(
        ply: json['ply'] as int,
        fen: json['fen'] as String,
        depth: json['depth'] as int,
        cp: json['cp'] as int?,
        mate: json['mate'] as int?,
        bestMove: json['bestMove'] as String?,
        pv: (json['pv'] as List<dynamic>).cast<String>(),
      );
}

class StoredChapterAnalysis {
  const StoredChapterAnalysis({
    required this.totalPlies,
    required this.completedPlies,
    required this.plies,
  });

  final int totalPlies;
  final int completedPlies;
  final List<StoredPlyEvaluation> plies;
}

class _SimpleMutex {
  Future<void> _last = Future.value();

  Future<T> protect<T>(Future<T> Function() fn) {
    final result = _last.then((_) => fn());
    _last = result.then((_) {}, onError: (_) {});
    return result;
  }
}

class GameAnalysisRepository {
  final _mutex = _SimpleMutex();

  Future<String> _filePath(String scoresheetId) async {
    final base = await getApplicationDocumentsDirectory();
    return '${base.path}/scoresheets/$scoresheetId.analysis.json';
  }

  Future<Map<String, dynamic>> _readJson(String scoresheetId) async {
    final path = await _filePath(scoresheetId);
    final file = File(path);
    if (!await file.exists()) return {'version': 1, 'chapters': {}};
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {'version': 1, 'chapters': {}};
    }
  }

  Future<void> _writeJson(
    String scoresheetId,
    Map<String, dynamic> data,
  ) async {
    final path = await _filePath(scoresheetId);
    await File(path).writeAsString(jsonEncode(data));
  }

  Future<StoredChapterAnalysis?> loadChapter(
    String scoresheetId,
    int chapter,
  ) async {
    final data = await _readJson(scoresheetId);
    final chapters = (data['chapters'] as Map).cast<String, dynamic>();
    final chapterData = chapters['$chapter'] as Map<String, dynamic>?;
    if (chapterData == null) return null;
    final pliesJson = (chapterData['plies'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return StoredChapterAnalysis(
      totalPlies: chapterData['totalPlies'] as int,
      completedPlies: chapterData['completedPlies'] as int,
      plies: pliesJson.map(StoredPlyEvaluation.fromJson).toList(),
    );
  }

  Future<void> upsertPly(
    String scoresheetId,
    int chapter,
    StoredPlyEvaluation ply, {
    required int totalPlies,
  }) async {
    await _mutex.protect(() async {
      final data = await _readJson(scoresheetId);
      final chapters = (data['chapters'] as Map).cast<String, dynamic>();
      final chapterData =
          (chapters['$chapter'] as Map<String, dynamic>?) ??
          {'totalPlies': totalPlies, 'completedPlies': 0, 'plies': []};

      final pliesList = (chapterData['plies'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final existing = pliesList.indexWhere((p) => p['ply'] == ply.ply);
      if (existing >= 0) {
        pliesList[existing] = ply.toJson();
      } else {
        pliesList.add(ply.toJson());
      }

      chapterData['totalPlies'] = totalPlies;
      chapterData['completedPlies'] = pliesList.length;
      chapters['$chapter'] = chapterData;
      data['chapters'] = chapters;

      await _writeJson(scoresheetId, data);
    });
  }

  Future<void> deleteAll(String scoresheetId) async {
    final path = await _filePath(scoresheetId);
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

final gameAnalysisRepository = GameAnalysisRepository();
