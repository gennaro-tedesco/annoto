import 'package:annoto/services/chess_engine.dart';
import 'package:annoto/services/chess_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExternalChessEngine.fromMap', () {
    test('parses name and packageName', () {
      final engine = ExternalChessEngine.fromMap({
        'name': 'Stockfish',
        'packageName': 'org.dreamauth.stockfish',
      });
      expect(engine.name, 'Stockfish');
      expect(engine.packageName, 'org.dreamauth.stockfish');
    });

    test('round-trips via toMap', () {
      const engine = ExternalChessEngine(
        name: 'Leela',
        packageName: 'org.leela.chess',
      );
      final restored = ExternalChessEngine.fromMap(engine.toMap());
      expect(restored.name, engine.name);
      expect(restored.packageName, engine.packageName);
    });
  });

  group('engine list mapping', () {
    test('maps a list of raw maps to ExternalChessEngine instances', () {
      final raw = [
        {'name': 'Stockfish', 'packageName': 'org.dreamauth.stockfish'},
        {'name': 'Leela', 'packageName': 'org.leela.chess'},
      ];
      final engines = raw
          .map((item) => ExternalChessEngine.fromMap(item))
          .toList();
      expect(engines.length, 2);
      expect(engines[0].name, 'Stockfish');
      expect(engines[1].packageName, 'org.leela.chess');
    });

    test('handles empty list', () {
      final engines = <ExternalChessEngine>[];
      expect(engines, isEmpty);
    });
  });

  group('UCI info line parsing', () {
    final pvMap = <int, EngineEvaluation>{};

    setUp(() => pvMap.clear());

    EngineEvaluation? parse(String line) => parseInfoLine(line, pvMap);

    test('parses centipawn score', () {
      final eval = parse(
        'info depth 12 seldepth 18 multipv 1 score cp 34 pv e2e4 e7e5 g1f3',
      );
      expect(eval, isNotNull);
      expect(eval!.cp, 34);
      expect(eval.mate, isNull);
      expect(eval.depth, 12);
      expect(eval.pv, ['e2e4', 'e7e5', 'g1f3']);
    });

    test('parses negative centipawn score', () {
      final eval = parse('info depth 8 score cp -120 pv d7d5');
      expect(eval!.cp, -120);
      expect(eval.mate, isNull);
    });

    test('parses mate score', () {
      final eval = parse('info depth 15 score mate 3 pv h5f7');
      expect(eval, isNotNull);
      expect(eval!.mate, 3);
      expect(eval.cp, isNull);
    });

    test('parses negative mate score', () {
      final eval = parse('info depth 10 score mate -2 pv a1a8');
      expect(eval!.mate, -2);
    });

    test('parses multipv index', () {
      parse('info depth 5 multipv 1 score cp 10 pv e2e4');
      parse('info depth 5 multipv 2 score cp -5 pv d2d4');
      expect(pvMap.length, 2);
      expect(pvMap[1]!.cp, 10);
      expect(pvMap[2]!.cp, -5);
    });

    test('returns null for non-info line', () {
      expect(parse('uciok'), isNull);
      expect(parse('readyok'), isNull);
      expect(parse('bestmove e2e4 ponder e7e5'), isNull);
    });

    test('returns null for info line without score', () {
      expect(parse('info nodes 12345 nps 500000'), isNull);
    });

    test('does not crash on malformed input', () {
      expect(() => parse('info score cp notanumber pv'), returnsNormally);
      expect(() => parse(''), returnsNormally);
      expect(() => parse('info depth score'), returnsNormally);
    });
  });

  group('UCI bestmove parsing', () {
    test('bestmove line is recognised', () {
      const line = 'bestmove e2e4 ponder e7e5';
      expect(line.startsWith('bestmove '), isTrue);
    });

    test('bestmove without ponder is recognised', () {
      const line = 'bestmove (none)';
      expect(line.startsWith('bestmove '), isTrue);
    });
  });
}
