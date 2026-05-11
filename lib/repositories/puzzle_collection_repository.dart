import 'dart:convert';
import 'dart:io';

import 'package:annoto/models/move_pair.dart';
import 'package:annoto/models/puzzle.dart';
import 'package:annoto/models/puzzle_collection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class PuzzleCollectionRepository {
  Future<void> _indexWriteQueue = Future.value();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/puzzles');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _dir();
    return File('${dir.path}/index.json');
  }

  Future<List<Map<String, dynamic>>> _readIndex() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _writeIndex(List<Map<String, dynamic>> entries) async {
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(entries));
  }

  Future<void> _updateIndex(
    Future<void> Function(List<Map<String, dynamic>> entries) update,
  ) {
    final operation = _indexWriteQueue.catchError((_) {}).then((_) async {
      final entries = await _readIndex();
      await update(entries);
      await _writeIndex(entries);
    });
    _indexWriteQueue = operation.catchError((_) {});
    return operation;
  }

  Future<List<PuzzleCollection>> getAll() async {
    final dir = await _dir();
    final index = await _readIndex();
    final collections = <PuzzleCollection>[];
    for (final entry in index) {
      final id = entry['id'] as String?;
      if (id == null) continue;
      final jsonFile = File('${dir.path}/$id.json');
      if (!await jsonFile.exists()) continue;
      try {
        final content = await jsonFile.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        final puzzles = list
            .cast<Map<String, dynamic>>()
            .map(PuzzleCollection.puzzleFromJson)
            .toList();
        final rawResults = (entry['results'] as Map<String, dynamic>?) ?? {};
        final results = rawResults.map(
          (k, v) => MapEntry(
            int.parse(k),
            v == 'solved' ? PuzzleStatus.solved : PuzzleStatus.failed,
          ),
        );
        collections.add(
          PuzzleCollection(
            id: id,
            name: entry['name'] as String,
            puzzles: puzzles,
            createdAt: DateTime.parse(entry['createdAt'] as String),
            lastVisited: (entry['lastVisited'] as int?) ?? 0,
            results: results,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return collections;
  }

  Future<PuzzleCollection> save(String name, String pgn) async {
    final games = splitPgnGames(pgn);
    final rawPuzzles = games
        .map(PuzzleCollection.rawPuzzleFromPgnGame)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (rawPuzzles.isEmpty) {
      throw const FormatException('No valid puzzles found in PGN.');
    }

    final dir = await _dir();
    final id = _uuid.v4();
    final now = DateTime.now();

    await File('${dir.path}/$id.json').writeAsString(jsonEncode(rawPuzzles));

    await _updateIndex((index) async {
      index.insert(0, {
        'id': id,
        'name': name,
        'createdAt': now.toIso8601String(),
      });
    });

    final puzzles = rawPuzzles.map(PuzzleCollection.puzzleFromJson).toList();
    return PuzzleCollection(
      id: id,
      name: name,
      puzzles: puzzles,
      createdAt: now,
    );
  }

  Future<void> updateResults(String id, Map<int, PuzzleStatus> results) async {
    await _updateIndex((entries) async {
      final i = entries.indexWhere((e) => e['id'] == id);
      if (i == -1) return;
      final serialized = results.map((k, v) => MapEntry(k.toString(), v.name));
      entries[i] = {...entries[i], 'results': serialized};
    });
  }

  Future<void> updateLastVisited(String id, int index) async {
    await _updateIndex((entries) async {
      final i = entries.indexWhere((e) => e['id'] == id);
      if (i == -1) return;
      entries[i] = {...entries[i], 'lastVisited': index};
    });
  }

  Future<void> delete(String id) async {
    final dir = await _dir();
    final jsonFile = File('${dir.path}/$id.json');
    if (await jsonFile.exists()) await jsonFile.delete();

    await _updateIndex((index) async {
      index.removeWhere((e) => e['id'] == id);
    });
  }
}

final puzzleCollectionRepository = PuzzleCollectionRepository();
