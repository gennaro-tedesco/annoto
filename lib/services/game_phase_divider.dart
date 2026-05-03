import 'package:dartchess/dartchess.dart';

class GameDivision {
  final int? middle;
  final int? end;
  final int plies;

  const GameDivision({
    required this.middle,
    required this.end,
    required this.plies,
  });
}

enum GamePhase { opening, middlegame, endgame }

GamePhase phaseForPly({
  required int ply,
  required GameDivision division,
}) {
  if (division.end != null && ply >= division.end!) {
    return GamePhase.endgame;
  }

  if (division.middle != null && ply >= division.middle!) {
    return GamePhase.middlegame;
  }

  return GamePhase.opening;
}

GameDivision divideGame(List<Board> boards) {
  int? middle;
  const minimumOpeningPlies = 6;
  final firstMiddlegameCandidate = minimumOpeningPlies > boards.length
      ? boards.length
      : minimumOpeningPlies;

  for (var i = firstMiddlegameCandidate; i < boards.length; i++) {
    final board = boards[i];

    if (majorsAndMinors(board) <= 10 ||
        backrankSparse(board) ||
        mixedness(board) > 150) {
      middle = i;
      break;
    }
  }

  int? end;

  if (middle != null) {
    for (var i = middle; i < boards.length; i++) {
      final board = boards[i];

      if (majorsAndMinors(board) <= 6) {
        end = i;
        break;
      }
    }
  }

  return GameDivision(middle: middle, end: end, plies: boards.length);
}

int majorsAndMinors(Board board) {
  return (board.knights | board.bishops | board.rooks | board.queens).size;
}

bool backrankSparse(Board board) {
  final whiteBackRankPieces = (board.white & SquareSet.firstRank).size;
  final blackBackRankPieces = (board.black & SquareSet.eighthRank).size;

  return whiteBackRankPieces < 4 || blackBackRankPieces < 4;
}

int mixedness(Board board) {
  var score = 0;

  final whiteSquares = board.white.squares.toList();
  final blackSquares = board.black.squares.toList();

  for (final white in whiteSquares) {
    for (final black in blackSquares) {
      final distance = chebyshevDistance(white, black);

      if (distance == 1) {
        score += 16;
      } else if (distance == 2) {
        score += 8;
      } else if (distance == 3) {
        score += 4;
      } else if (distance == 4) {
        score += 2;
      }
    }
  }

  return score;
}

int chebyshevDistance(Square a, Square b) {
  final fileDistance = (a.file - b.file).abs();
  final rankDistance = (a.rank - b.rank).abs();
  return fileDistance > rankDistance ? fileDistance : rankDistance;
}
