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

final pgnMoveRegex = RegExp(r'(\d+)\.\s*(\S+)(?:\s+(\S+))?');

const _kResultTokens = {'1-0', '0-1', '1/2-1/2', '*'};

final _headerRegex = RegExp(r'\[(\w+)\s+"([^"]*)"\]');
final _movesBlockRegex = RegExp(r'\n\n(.+)', dotAll: true);

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

List<MovePair> parsePgn(
  String pgn,
  Map<String, TextEditingController> headerControllers,
) {
  final headers = <String, String>{};
  for (final m in _headerRegex.allMatches(pgn)) {
    headers[m.group(1)!] = m.group(2)!;
  }
  for (final tag in kPgnTagOrder) {
    headerControllers[tag] = TextEditingController(text: headers[tag] ?? '?');
  }
  final movesText = _movesBlockRegex.firstMatch(pgn)?.group(1)?.trim() ?? pgn;
  return parsePgnMoves(movesText);
}

List<MovePair> parsePgnMoves(String text) {
  return pgnMoveRegex.allMatches(text).map((m) {
    final rawBlack = m.group(3);
    return MovePair(
      number: int.parse(m.group(1)!),
      white: m.group(2) ?? '',
      black: rawBlack != null && _kResultTokens.contains(rawBlack)
          ? ''
          : rawBlack ?? '',
    );
  }).toList();
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
