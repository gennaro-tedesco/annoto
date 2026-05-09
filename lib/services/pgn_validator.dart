import 'dart:math';

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

Position positionAtPly(List<String> sans, int plyIndex) {
  Position position = Chess.initial;

  for (var i = 0; i < plyIndex && i < sans.length; i++) {
    final san = sans[i];
    if (san.isEmpty) break;

    try {
      final move = position.parseSan(san);
      if (move == null) break;
      position = position.play(move);
    } catch (_) {
      break;
    }
  }

  return position;
}

List<String> suggestMoves(Position position, String typedSan) {
  final typed = typedSan.trim();
  final legal = <String>{};

  for (final entry in position.legalMoves.entries) {
    final from = entry.key;

    for (final to in entry.value.squares) {
      for (final promo in [null, Role.queen]) {
        final move = NormalMove(from: from, to: to, promotion: promo);
        if (!position.isLegal(move)) continue;

        try {
          final (_, san) = position.makeSan(move);
          if (san != typed) legal.add(san);
        } catch (_) {}
      }
    }
  }

  if (legal.isEmpty) return [];

  final scored =
      legal
          .map(
            (san) => (
              san: san,
              pieceMatch: _pieceType(typed) == _pieceType(san) ? 1 : 0,
              dist: _destinationDistance(typed, san),
              lev: _levenshtein(typed, san),
            ),
          )
          .toList()
        ..sort((a, b) {
          if (a.pieceMatch != b.pieceMatch) {
            return b.pieceMatch.compareTo(a.pieceMatch);
          }
          if (a.dist != b.dist) return a.dist.compareTo(b.dist);
          return a.lev.compareTo(b.lev);
        });

  return scored.take(3).map((s) => s.san).toList();
}

String _pieceType(String san) {
  if (san.isEmpty) return 'P';
  return 'NBRQK'.contains(san[0]) ? san[0] : 'P';
}

({int file, int rank})? _parseDestination(String san) {
  final matches = RegExp(r'[a-h][1-8]').allMatches(san).toList();
  if (matches.isEmpty) return null;

  final sq = matches.last.group(0)!;

  return (
    file: sq.codeUnitAt(0) - 'a'.codeUnitAt(0),
    rank: sq.codeUnitAt(1) - '1'.codeUnitAt(0),
  );
}

int _destinationDistance(String san1, String san2) {
  final d1 = _parseDestination(san1);
  final d2 = _parseDestination(san2);

  if (d1 == null || d2 == null) return 7;

  return max((d1.file - d2.file).abs(), (d1.rank - d2.rank).abs());
}

int _levenshtein(String a, String b) {
  final m = a.length;
  final n = b.length;
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

  for (var i = 0; i <= m; i++) {
    dp[i][0] = i;
  }

  for (var j = 0; j <= n; j++) {
    dp[0][j] = j;
  }

  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      dp[i][j] = a[i - 1] == b[j - 1]
          ? dp[i - 1][j - 1]
          : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce(min);
    }
  }

  return dp[m][n];
}
