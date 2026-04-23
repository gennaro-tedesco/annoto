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
  MovePair({required this.number, String white = '', String black = ''})
    : white = TextEditingController(text: white),
      black = TextEditingController(text: black),
      whiteFocus = FocusNode(),
      blackFocus = FocusNode();

  int number;
  final TextEditingController white;
  final TextEditingController black;
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

List<String> extractMainlineSans(String pgn) =>
    parsePgnGame(pgn).moves.mainline().map((node) => node.san).toList();

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
  return _movePairsFromSans(extractMainlineSans(firstGame));
}

List<MovePair> _movePairsFromSans(List<String> sans) {
  final moves = <MovePair>[];
  for (var i = 0; i < sans.length; i += 2) {
    moves.add(
      MovePair(
        number: (i ~/ 2) + 1,
        white: sans[i],
        black: i + 1 < sans.length ? sans[i + 1] : '',
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
    buffer.write('${move.number}. ${move.white.text}');
    if (move.black.text.isNotEmpty) buffer.write(' ${move.black.text}');
    buffer.write(' ');
  }
  final result = headerControllers['Result']?.text.trim() ?? '*';
  buffer.write(result);
  return buffer.toString().trim();
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
