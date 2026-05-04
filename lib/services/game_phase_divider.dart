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

GamePhase phaseForPly({required int ply, required GameDivision division}) {
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

  for (var i = 0; i < boards.length; i++) {
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
    for (var i = 0; i < boards.length; i++) {
      final board = boards[i];

      if (majorsAndMinors(board) <= 6) {
        end = i;
        break;
      }
    }
  }

  final validMiddle = middle != null && (end == null || middle < end)
      ? middle
      : null;

  return GameDivision(middle: validMiddle, end: end, plies: boards.length);
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
  var total = 0;

  for (var rank = 0; rank <= 6; rank++) {
    for (var file = 0; file <= 6; file++) {
      var whiteCount = 0;
      var blackCount = 0;

      for (var dr = 0; dr <= 1; dr++) {
        for (var df = 0; df <= 1; df++) {
          final sq = Square(file + df + (rank + dr) * 8);
          if (board.white.has(sq)) {
            whiteCount++;
          } else if (board.black.has(sq)) {
            blackCount++;
          }
        }
      }

      total += _mixednessScore(rank + 1, whiteCount, blackCount);
    }
  }

  return total;
}

int _mixednessScore(int y, int white, int black) {
  if (white == 0 && black == 0) return 0;

  if (white == 1 && black == 0) return 1 + (8 - y);
  if (white == 2 && black == 0) return y > 2 ? 2 + (y - 2) : 0;
  if (white == 3 && black == 0) return y > 1 ? 3 + (y - 1) : 0;
  if (white == 4 && black == 0) return y > 1 ? 3 + (y - 1) : 0;

  if (white == 0 && black == 1) return 1 + y;
  if (white == 1 && black == 1) return 5 + (4 - y).abs();
  if (white == 2 && black == 1) return 4 + (y - 1);
  if (white == 3 && black == 1) return 5 + (y - 1);

  if (white == 0 && black == 2) return y < 6 ? 2 + (6 - y) : 0;
  if (white == 1 && black == 2) return 4 + (7 - y);
  if (white == 2 && black == 2) return 7;

  if (white == 0 && black == 3) return y < 7 ? 3 + (7 - y) : 0;
  if (white == 1 && black == 3) return 5 + (7 - y);

  if (white == 0 && black == 4) return y < 7 ? 3 + (7 - y) : 0;

  return 0;
}
