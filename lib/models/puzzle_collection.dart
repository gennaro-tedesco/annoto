import 'package:annoto/models/puzzle.dart';
import 'package:dartchess/dartchess.dart';

class PuzzleCollection {
  const PuzzleCollection({
    required this.id,
    required this.name,
    required this.puzzles,
    required this.createdAt,
    this.lastVisited = 0,
    this.results = const {},
  });

  final String id;
  final String name;
  final List<Puzzle> puzzles;
  final DateTime createdAt;
  final int lastVisited;
  final Map<int, PuzzleStatus> results;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  static Puzzle puzzleFromJson(Map<String, dynamic> json) => Puzzle(
    problemId: 0,
    first: json['first'] as String? ?? '',
    type: json['type'] as String? ?? '',
    fen: json['fen'] as String,
    moves: json['moves'] as String,
  );

  static Map<String, dynamic>? rawPuzzleFromPgnGame(String pgnGame) {
    final PgnGame<PgnNodeData> game;
    try {
      game = PgnGame.parsePgn(pgnGame, initHeaders: PgnGame.emptyHeaders);
    } catch (_) {
      return null;
    }

    final fen = game.headers['FEN'];
    if (fen == null || fen.isEmpty) return null;

    final type = game.headers['Event'] ?? '';
    final first = game.headers['Black'] ?? '';

    final Position startPos;
    try {
      startPos = Chess.fromSetup(Setup.parseFen(fen));
    } catch (_) {
      return null;
    }

    final uciMoves = <String>[];
    Position pos = startPos;
    PgnNode<PgnNodeData> node = game.moves;
    while (node.children.isNotEmpty) {
      final child = node.children.first;
      final move = pos.parseSan(child.data.san);
      if (move == null) break;
      uciMoves.add(move.uci);
      pos = pos.play(move);
      node = child;
    }

    if (uciMoves.isEmpty) return null;

    return {
      'type': type,
      'first': first,
      'fen': fen,
      'moves': uciMoves.join(';'),
    };
  }
}
