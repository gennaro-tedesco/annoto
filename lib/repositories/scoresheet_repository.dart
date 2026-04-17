import 'dart:convert';
import 'dart:io';

import 'package:annoto/models/scoresheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ScoresheetRepository {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/scoresheets');
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

  Future<List<Scoresheet>> getAll() async {
    final dir = await _dir();
    final index = await _readIndex();
    final scoresheets = <Scoresheet>[];
    for (final entry in index) {
      final pgnFile = File('${dir.path}/${entry['id']}.pgn');
      if (!await pgnFile.exists()) continue;
      final pgn = await pgnFile.readAsString();
      scoresheets.add(Scoresheet.fromJson(entry, pgn));
    }
    return scoresheets;
  }

  Future<Scoresheet> save(String pgn) async {
    final dir = await _dir();
    final id = _uuid.v4();
    final now = DateTime.now();
    final filename = _formatFilename(now);

    await File('${dir.path}/$id.pgn').writeAsString(pgn);

    final index = await _readIndex();
    final entry = Scoresheet(
      id: id,
      filename: filename,
      createdAt: now,
      pgn: pgn,
    );
    index.insert(0, entry.toJson());
    await _writeIndex(index);

    return entry;
  }

  Future<void> delete(String id) async {
    final dir = await _dir();
    final pgnFile = File('${dir.path}/$id.pgn');
    if (await pgnFile.exists()) await pgnFile.delete();

    final index = await _readIndex();
    index.removeWhere((e) => e['id'] == id);
    await _writeIndex(index);
  }

  String _formatFilename(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return 'scoresheet_$y$mo${d}_$h$mi$s';
  }
}

final scoresheetRepository = ScoresheetRepository();
