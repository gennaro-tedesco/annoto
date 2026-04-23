import 'package:annoto/models/move_pair.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _annotatedPgn = '''
[Event "Annotated"]
[White "White"]
[Black "Black"]
[Result "*"]

1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. f3 O-O 6. Be3 e5 7. Nge2 Nc6 8. d5 { only after Nc6 do we push d5 } 8... Ne7 9. Qd2 { here black has two choices } 9... Ne8 (9... c6 10. g4 cxd5 11. cxd5 Bd7) 10. g4 f5 *

[Event "Second"]
[Result "*"]

1. e4 e5 *
''';

void main() {
  test('parsePgn reads headers and mainline moves from annotated PGN', () {
    final headerControllers = <String, TextEditingController>{};

    final moves = parsePgn(_annotatedPgn, headerControllers);

    expect(headerControllers['Event']?.text, 'Annotated');
    expect(headerControllers['White']?.text, 'White');
    expect(headerControllers['Black']?.text, 'Black');
    expect(moves.length, 10);
    expect(moves[7].white.text, 'd5');
    expect(moves[7].black.text, 'Ne7');
    expect(moves[8].white.text, 'Qd2');
    expect(moves[8].black.text, 'Ne8');
    expect(moves[9].white.text, 'g4');
    expect(moves[9].black.text, 'f5');
  });

  test('splitPgnGames splits multi-game PGN via dartchess parser', () {
    final games = splitPgnGames(_annotatedPgn);

    expect(games.length, 2);
    expect(parsePgnTags(games.first)['Event'], 'Annotated');
    expect(parsePgnTags(games.last)['Event'], 'Second');
  });

  test('chapterLabelForPgn prefers ChapterName', () {
    const pgn = '''
[ChapterName "Sämisch chapter"]
[White "White"]
[Black "Black"]
[Result "*"]

1. d4 Nf6 *
''';

    expect(chapterLabelForPgn(pgn, 0), 'Sämisch chapter');
  });
}
