import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

const kPgnTagOrder = [
  'White',
  'Black',
  'Event',
  'Site',
  'Date',
  'Round',
  'Result',
];

class MovePair {
  MovePair({
    required this.number,
    String white = '',
    String black = '',
    List<String>? whiteStartingComments,
    List<String>? whiteComments,
    List<String>? blackStartingComments,
    List<String>? blackComments,
  }) : white = TextEditingController(text: white),
       black = TextEditingController(text: black),
       whiteStartingComments = List.unmodifiable(whiteStartingComments ?? []),
       whiteComments = List.unmodifiable(whiteComments ?? []),
       blackStartingComments = List.unmodifiable(blackStartingComments ?? []),
       blackComments = List.unmodifiable(blackComments ?? []),
       whiteFocus = FocusNode(),
       blackFocus = FocusNode();

  int number;
  final TextEditingController white;
  final TextEditingController black;
  final List<String> whiteStartingComments;
  final List<String> whiteComments;
  final List<String> blackStartingComments;
  final List<String> blackComments;
  final FocusNode whiteFocus;
  final FocusNode blackFocus;

  void dispose() {
    white.dispose();
    black.dispose();
    whiteFocus.dispose();
    blackFocus.dispose();
  }
}

PgnGame<PgnNodeData> parsePgnGame(String pgn) =>
    PgnGame.parsePgn(pgn, initHeaders: PgnGame.emptyHeaders);

Map<String, String> parsePgnTags(String pgn) {
  final headers = parsePgnGame(pgn).headers;
  final tags = <String, String>{};
  for (final entry in headers.entries) {
    final value = entry.value.trim();
    if (value.isEmpty || value == '?') continue;
    tags[entry.key] = value;
  }
  return tags;
}

String chapterLabelForPgn(String pgn, int index) {
  final tags = parsePgnTags(pgn);
  final chapterName = tags['ChapterName'];
  if (chapterName != null) return chapterName;
  final white = tags['White'];
  final black = tags['Black'];
  if (white != null && black != null) return '$white vs $black';
  return 'Game ${index + 1}';
}

List<MovePair> parsePgn(
  String pgn,
  Map<String, TextEditingController> headerControllers,
) {
  final firstGame = splitPgnGames(pgn).firstOrNull ?? pgn;
  final headers = parsePgnTags(firstGame);
  for (final tag in kPgnTagOrder) {
    headerControllers[tag] = TextEditingController(text: headers[tag] ?? '?');
  }
  return _movePairsFromGame(parsePgnGame(firstGame));
}

List<MovePair> _movePairsFromGame(PgnGame<PgnNodeData> game) {
  final mainline = game.moves.mainline().toList();
  final moves = <MovePair>[];
  for (var i = 0; i < mainline.length; i += 2) {
    final whiteNode = mainline[i];
    final blackNode = i + 1 < mainline.length ? mainline[i + 1] : null;
    moves.add(
      MovePair(
        number: (i ~/ 2) + 1,
        white: whiteNode.san,
        black: blackNode?.san ?? '',
        whiteStartingComments: whiteNode.startingComments,
        whiteComments: whiteNode.comments,
        blackStartingComments: blackNode?.startingComments,
        blackComments: blackNode?.comments,
      ),
    );
  }
  return moves;
}

String serialisePgn(
  Map<String, TextEditingController> headerControllers,
  List<MovePair> moves,
) {
  final buffer = StringBuffer();
  for (final tag in kPgnTagOrder) {
    final value = headerControllers[tag]?.text.trim() ?? '?';
    buffer.writeln('[$tag "$value"]');
  }
  buffer.writeln();
  for (final move in moves) {
    _writeComments(buffer, move.whiteStartingComments);
    buffer.write('${move.number}. ${move.white.text}');
    _writeComments(buffer, move.whiteComments);
    if (move.black.text.isNotEmpty) {
      _writeComments(buffer, move.blackStartingComments);
      buffer.write(' ${move.black.text}');
      _writeComments(buffer, move.blackComments);
    }
    buffer.write(' ');
  }
  final result = headerControllers['Result']?.text.trim() ?? '*';
  buffer.write(result);
  return buffer.toString().trim();
}

void _writeComments(StringBuffer buffer, List<String> comments) {
  for (final comment in comments) {
    final trimmed = comment.trim();
    if (trimmed.isEmpty) continue;
    buffer.write('{ $trimmed } ');
  }
}

List<String> splitPgnGames(String pgn) {
  final trimmed = pgn.trim();
  if (trimmed.isEmpty) return [];
  final games = PgnGame.parseMultiGamePgn(
    trimmed,
    initHeaders: PgnGame.emptyHeaders,
  );
  return games
      .where(
        (game) => game.headers.isNotEmpty || game.moves.children.isNotEmpty,
      )
      .map((game) => game.makePgn().trim())
      .where((game) => game.isNotEmpty)
      .toList();
}
