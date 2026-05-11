enum PuzzleStatus { notStarted, inProgress, wrongMove, solved, failed }

class Puzzle {
  const Puzzle({
    required this.problemId,
    required this.first,
    required this.type,
    required this.fen,
    required this.moves,
  });

  final int problemId;
  final String first;
  final String type;
  final String fen;
  final String moves;

  List<String> get solutionMoves =>
      moves.split(';').map((m) => m.trim().replaceAll('-', '')).toList();
}
