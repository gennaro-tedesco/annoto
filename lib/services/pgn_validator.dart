import 'package:annoto/models/move_pair.dart';
import 'package:dartchess/dartchess.dart';

List<bool> validateMoves(List<String> sans) {
  Position position = Chess.initial;
  final validity = <bool>[];
  var foundInvalidMove = false;

  for (final san in sans) {
    if (foundInvalidMove || san.isEmpty) {
      validity.add(false);
      foundInvalidMove = true;
      continue;
    }

    final Move? move;
    try {
      move = position.parseSan(san);
    } catch (_) {
      validity.add(false);
      foundInvalidMove = true;
      continue;
    }
    if (move == null) {
      validity.add(false);
      foundInvalidMove = true;
      continue;
    }

    validity.add(true);
    position = position.play(move);
  }

  return validity;
}

bool hasInvalidPgnMoves(String pgn) {
  final games = splitPgnGames(pgn);
  final gamesToValidate = games.isNotEmpty ? games : [pgn];

  for (final gamePgn in gamesToValidate) {
    final game = parsePgnGame(gamePgn);
    final sans = game.moves.mainline().map((node) => node.san).toList();
    if (sans.isEmpty) continue;

    Position position = PgnGame.startingPosition(game.headers);
    for (final san in sans) {
      final Move? move;
      try {
        move = position.parseSan(san);
      } catch (_) {
        return true;
      }
      if (move == null) return true;
      position = position.play(move);
    }
  }

  return false;
}
