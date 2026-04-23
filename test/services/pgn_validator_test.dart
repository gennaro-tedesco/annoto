import 'package:annoto/services/pgn_validator.dart';
import 'package:flutter_test/flutter_test.dart';

const _annotatedPgn = '''
[Event "Annotated"]
[Result "*"]

1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. f3 O-O 6. Be3 e5 7. Nge2 Nc6 8. d5 { only after Nc6 do we push d5 } 8... Ne7 9. Qd2 { here black has two choices } 9... Ne8 (9... c6 10. g4 cxd5 11. cxd5 Bd7) 10. g4 f5 *
''';

const _multiGamePgn = '''
[Event "First"]
[Result "*"]

1. e4 e5 *

[Event "Second"]
[Result "*"]

1. e4 e5 2. Qh5 Nc6 3. Qxe7+ *
''';

void main() {
  group('validateMoves', () {
    test('marks all legal plies as valid', () {
      final validity = validateMoves(['e4', 'e5', 'Nf3', 'Nc6']);

      expect(validity, [true, true, true, true]);
    });

    test('marks first invalid ply and all following plies as invalid', () {
      final validity = validateMoves(['e4', 'e5', 'InvalidMove', 'Nc6']);

      expect(validity, [true, true, false, false]);
    });
  });

  group('hasInvalidPgnMoves', () {
    test('accepts annotated PGN with comments and variations', () {
      expect(hasInvalidPgnMoves(_annotatedPgn), isFalse);
    });

    test('rejects PGN with an illegal move in the main line', () {
      const pgn = '''
[Event "Invalid"]
[Result "*"]

1. e4 e5 2. Qh5 Nc6 3. Qxe7+ *
''';

      expect(hasInvalidPgnMoves(pgn), isTrue);
    });

    test('rejects collection when a later game is invalid', () {
      expect(hasInvalidPgnMoves(_multiGamePgn), isTrue);
    });
  });
}
